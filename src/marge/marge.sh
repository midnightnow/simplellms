#!/usr/bin/env bash
# M.A.R.G.E. — the SimpleLLMs epic orchestrator.
#
# Verbs (Task-Master compatible where sensible):
#   marge init                           create .marge/ in the current git repo
#   marge plan "<epic text>"             expand an epic into a ticket graph
#   marge parse <file.md>                same as `plan`, reads from a file (PRD/EPIC/SPEC)
#   marge list                           print the ticket graph
#   marge next                           print the next ready ticket id
#   marge show <id>                      print one ticket's full details
#   marge set-status <id> <status>       manually set a ticket's status
#   marge expand <id>                    break a ticket into subtasks (TODO v0.2)
#   marge run <id>                       execute one specific ticket (no review)
#   marge review <id>                    re-run review on an already-executed ticket
#   marge execute                        full orchestrator loop: plan(if needed) → dispatch → review → repeat
#   marge summary                        one-line progress dashboard
#   marge prune                          remove all marge worktrees (destructive)
#
# Env vars:
#   MARGE_AGENT          claude | gemini | amp | echo      (default: claude)
#   MARGE_CONCURRENCY    max parallel tickets per batch     (default: 1)
#   MARGE_MAX_PIVOTS     pivots allowed per ticket          (default: 1)
#   MARGE_ROOT           state dir name inside repo         (default: .marge)

set -euo pipefail

MARGE_SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MARGE_SRC_DIR/lib/common.sh"
source "$MARGE_SRC_DIR/lib/state.sh"
source "$MARGE_SRC_DIR/lib/graph.sh"
source "$MARGE_SRC_DIR/lib/worktree.sh"
source "$MARGE_SRC_DIR/lib/agent.sh"

usage() {
    cat >&2 <<'EOF'
M.A.R.G.E. — SimpleLLMs Epic Orchestrator

Usage:
  marge init
  marge plan "<epic description>"
  marge parse <file.md>
  marge list
  marge next
  marge show <ticket-id>
  marge set-status <ticket-id> <status>
  marge run <ticket-id>
  marge review <ticket-id>
  marge execute [--concurrency N] [--agent claude|gemini|amp|echo]
  marge summary
  marge prune

See src/marge/README.md for the full pipeline.
EOF
}

# ---------- prompt rendering ----------

render_prompt() {
    # Usage: render_prompt <template-path> KEY1=val1 KEY2=val2 ...
    local template="$1"; shift
    local body; body="$(cat "$template")"
    for kv in "$@"; do
        local k="${kv%%=*}" v="${kv#*=}"
        body="${body//\{\{$k\}\}/$v}"
    done
    printf "%s" "$body"
}

# ---------- subcommands ----------

cmd_init() {
    require_cmd git jq python3
    require_git_repo
    state_init
    worktree_record_base
    ok "initialized $MARGE_DIR"
    dim "  agent=$MARGE_AGENT concurrency=$MARGE_CONCURRENCY"
}

cmd_plan() {
    require_cmd git jq python3
    require_git_repo
    state_init
    worktree_record_base

    local epic="$1"
    [[ -z "$epic" ]] && die "usage: marge plan \"<epic description>\""

    state_write_epic_md "$epic"
    state_log "plan: epic received ($(wc -c <<<"$epic" | tr -d ' ') chars)"

    step "planning with $MARGE_AGENT"
    local prompt
    prompt=$(render_prompt "$MARGE_SRC_DIR/prompts/plan.md" \
        "EPIC=$epic" \
        "SPEC_SOURCES=(none)")

    local json
    json="$(agent_run_json "$prompt")" || die "planner returned invalid JSON"

    # normalise: status=pending, ensure meta.created + marge_version + agent
    json="$(jq --arg ts "$(_ts)" --arg ver "$MARGE_VERSION" --arg ag "$MARGE_AGENT" '
        .meta.created = $ts
      | .meta.marge_version = $ver
      | .meta.agent = $ag
      | .tickets |= map(.status = (.status // "pending") | .pivots = (.pivots // 0))
    ' <<<"$json")"

    state_write_epic_json "$json"

    # write per-ticket md files
    jq -c '.tickets[]' <<<"$json" | while read -r t; do
        local id title details crit
        id=$(jq -r '.id' <<<"$t")
        title=$(jq -r '.title' <<<"$t")
        details=$(jq -r '.details // ""' <<<"$t")
        crit=$(jq -r '(.acceptance_criteria // []) | map("- " + .) | join("\n")' <<<"$t")
        state_write_ticket_md "$id" "# ${id} — ${title}

${details}

## Acceptance criteria
${crit}
"
    done

    state_log "plan: $(jq '.tickets | length' <<<"$json") tickets"
    ok "planned $(jq '.tickets | length' <<<"$json") tickets"
    cmd_list
}

cmd_parse() {
    local f="$1"
    [[ -f "$f" ]] || die "file not found: $f"
    cmd_plan "$(cat "$f")"
}

cmd_list() {
    state_init
    state_epic_exists || die "no epic planned. run 'marge plan' or 'marge parse' first."
    local title; title=$(jq -r '.meta.title // "(untitled epic)"' "$MARGE_DIR/epic.json")
    step "$title"
    graph_render_tree
    dim "  $(state_summary)"
}

cmd_next() {
    state_init
    state_epic_exists || die "no epic planned."
    graph_ready_tickets | head -1
}

cmd_show() {
    state_init
    local id="$1"
    [[ -z "$id" ]] && die "usage: marge show <ticket-id>"
    graph_ticket "$id" | jq -C '.'
}

cmd_set_status() {
    state_init
    local id="$1" status="$2"
    [[ -z "$id" || -z "$status" ]] && die "usage: marge set-status <id> <status>"
    graph_set_status "$id" "$status"
    state_append_ticket_log "$id" "manual set-status → $status"
    ok "$id → $status"
}

cmd_run() {
    state_init
    local id="$1"
    [[ -z "$id" ]] && die "usage: marge run <ticket-id>"
    local title details crit strategy
    title=$(graph_title "$id")
    details=$(graph_spec "$id")
    crit=$(graph_acceptance "$id")
    strategy=$(jq -r --arg id "$id" '.tickets[] | select(.id==$id) | .test_strategy // ""' "$MARGE_DIR/epic.json")
    [[ -z "$title" || "$title" == "null" ]] && die "unknown ticket: $id"

    local epic_title epic_desc
    epic_title=$(jq -r '.meta.title' "$MARGE_DIR/epic.json")
    epic_desc=$(jq -r '.meta.description // ""' "$MARGE_DIR/epic.json")

    local wt branch
    wt="$(worktree_ensure "$id")"
    branch="$(worktree_branch "$id")"

    graph_set_status "$id" "in_progress"
    state_append_ticket_log "$id" "run: starting in worktree $wt on $branch"

    local prompt
    prompt=$(render_prompt "$MARGE_SRC_DIR/prompts/execute.md" \
        "EPIC_TITLE=$epic_title" \
        "EPIC_DESC=$epic_desc" \
        "BRANCH=$branch" \
        "TICKET_ID=$id" \
        "TICKET_TITLE=$title" \
        "TICKET_DETAILS=$details" \
        "ACCEPTANCE_CRITERIA=$crit" \
        "TEST_STRATEGY=$strategy")

    info "  [$id] executing in $wt"
    local agent_log="$MARGE_DIR/tickets/${id}.agent.log"
    : > "$agent_log"
    if ! MARGE_AGENT_LOG="$agent_log" agent_run "$prompt" "$wt" > "$agent_log.stdout" 2>>"$agent_log"; then
        state_append_ticket_log "$id" "run: agent invocation failed. tail of $agent_log:
\`\`\`
$(tail -20 "$agent_log" 2>/dev/null)
\`\`\`"
        graph_set_status "$id" "failed"
        return 1
    fi

    state_append_ticket_log "$id" "run: agent completed"
    ok "  [$id] agent completed"
    # status stays in_progress; review step decides final
}

cmd_review() {
    state_init
    local id="$1"
    [[ -z "$id" ]] && die "usage: marge review <ticket-id>"

    local title details crit strategy diff block
    title=$(graph_title "$id")
    details=$(graph_spec "$id")
    crit=$(graph_acceptance "$id")
    strategy=$(jq -r --arg id "$id" '.tickets[] | select(.id==$id) | .test_strategy // ""' "$MARGE_DIR/epic.json")
    diff=$(worktree_diff "$id")
    local wt; wt="$(worktree_path "$id")"
    block=$(cat "$wt/.marge-block" 2>/dev/null || echo "")

    if [[ -z "$diff" && -z "$block" ]]; then
        state_append_ticket_log "$id" "review: empty diff, no block note → failed"
        graph_set_status "$id" "failed"
        warn "  [$id] empty diff — marking failed"
        return 0
    fi

    local prompt
    prompt=$(render_prompt "$MARGE_SRC_DIR/prompts/review.md" \
        "TICKET_ID=$id" \
        "TICKET_TITLE=$title" \
        "TICKET_DETAILS=$details" \
        "ACCEPTANCE_CRITERIA=$crit" \
        "TEST_STRATEGY=$strategy" \
        "DIFF=$diff" \
        "BLOCK_NOTE=$block")

    info "  [$id] reviewing"
    local review_log="$MARGE_DIR/tickets/${id}.review.log"
    : > "$review_log"
    local verdict
    if ! verdict="$(MARGE_AGENT_LOG="$review_log" agent_run_json "$prompt")"; then
        state_append_ticket_log "$id" "review: reviewer returned non-JSON → needs_human. tail of $review_log:
\`\`\`
$(tail -20 "$review_log" 2>/dev/null)
\`\`\`"
        graph_set_status "$id" "needs_human"
        return 0
    fi

    local outcome reason
    outcome=$(jq -r '.outcome' <<<"$verdict")
    reason=$(jq -r '.reason // ""' <<<"$verdict")

    state_append_ticket_log "$id" "review: $outcome — $reason"

    case "$outcome" in
        done)
            graph_set_status "$id" "done"
            ok "  [$id] ✓ done"
            ;;
        needs_pivot)
            graph_set_status "$id" "needs_pivot"
            warn "  [$id] ↯ needs_pivot — $reason"
            ;;
        needs_human)
            graph_set_status "$id" "needs_human"
            warn "  [$id] ! needs_human — $reason"
            ;;
        failed|*)
            graph_set_status "$id" "failed"
            err "  [$id] ✗ failed — $reason"
            ;;
    esac

    # store full verdict under ticket md
    state_append_ticket_log "$id" "verdict:
\`\`\`json
$(jq '.' <<<"$verdict")
\`\`\`"
}

cmd_pivot() {
    state_init
    local id="$1"
    local pivots; pivots=$(graph_pivots "$id")
    if (( pivots >= MARGE_MAX_PIVOTS )); then
        warn "  [$id] max pivots ($MARGE_MAX_PIVOTS) reached → needs_human"
        graph_set_status "$id" "needs_human"
        return 0
    fi

    local title details crit diff hint
    title=$(graph_title "$id")
    details=$(graph_spec "$id")
    crit=$(graph_acceptance "$id")
    diff=$(worktree_diff "$id")
    hint=$(jq -r --arg id "$id" '
        .tickets[] | select(.id==$id) | .last_pivot_hint // ""
    ' "$MARGE_DIR/epic.json")

    worktree_reset "$id"
    graph_incr_pivots "$id"
    graph_set_status "$id" "in_progress"

    local wt; wt="$(worktree_path "$id")"
    local prompt
    prompt=$(render_prompt "$MARGE_SRC_DIR/prompts/pivot.md" \
        "TICKET_ID=$id" \
        "TICKET_TITLE=$title" \
        "TICKET_DETAILS=$details" \
        "ACCEPTANCE_CRITERIA=$crit" \
        "DIFF=$diff" \
        "PIVOT_HINT=$hint")

    info "  [$id] pivoting (attempt $((pivots + 1)))"
    local pivot_log="$MARGE_DIR/tickets/${id}.pivot.log"
    : > "$pivot_log"
    if ! MARGE_AGENT_LOG="$pivot_log" agent_run "$prompt" "$wt" > "$pivot_log.stdout" 2>>"$pivot_log"; then
        state_append_ticket_log "$id" "pivot: agent failed. tail of $pivot_log:
\`\`\`
$(tail -20 "$pivot_log" 2>/dev/null)
\`\`\`"
        graph_set_status "$id" "failed"
        return 1
    fi
    state_append_ticket_log "$id" "pivot: attempt $((pivots + 1)) completed"
}

cmd_execute() {
    state_init
    state_epic_exists || die "no epic planned. run 'marge plan' or 'marge parse' first."

    step "M.A.R.G.E. execute — agent=$MARGE_AGENT concurrency=$MARGE_CONCURRENCY"

    # Resume safety: any ticket still marked in_progress at startup is an
    # orphan from a previous run that was killed/crashed. Reset to pending
    # so this run can pick it up. Zero downside — by definition no worker
    # is currently running for it.
    local stranded; stranded=$(jq -r '.tickets[] | select(.status=="in_progress") | .id' "$MARGE_DIR/epic.json")
    if [[ -n "$stranded" ]]; then
        warn "resetting stranded in_progress tickets: $(tr '\n' ' ' <<<"$stranded")"
        while IFS= read -r id; do
            [[ -z "$id" ]] && continue
            graph_set_status "$id" "pending"
            state_append_ticket_log "$id" "resume: stranded in_progress → pending (orphan from killed run)"
        done <<<"$stranded"
    fi

    local iter=0
    while graph_has_pending; do
        iter=$((iter + 1))

        # dispatch ready batch
        local ready; ready=$(graph_ready_tickets)
        if [[ -z "$ready" ]]; then
            # no ready tickets but some still pending → handle needs_pivot
            local pivot_ids; pivot_ids=$(jq -r '.tickets[] | select(.status=="needs_pivot") | .id' "$MARGE_DIR/epic.json")
            if [[ -n "$pivot_ids" ]]; then
                while IFS= read -r id; do
                    cmd_pivot "$id" || true
                done <<<"$pivot_ids"
                continue
            fi

            if graph_stuck; then
                err "deadlock: pending tickets but no ready set and no pivots. run 'marge list' to inspect."
                break
            fi
        fi

        # take up to $MARGE_CONCURRENCY from ready
        local batch_ids; batch_ids=$(head -n "$MARGE_CONCURRENCY" <<<"$ready")
        local batch_id; batch_id=$(state_next_batch_id)

        step "batch $batch_id — $(wc -l <<<"$batch_ids" | tr -d ' ') ticket(s): $(tr '\n' ' ' <<<"$batch_ids")"

        # parallel execution
        if (( MARGE_CONCURRENCY > 1 )); then
            local pids=()
            while IFS= read -r id; do
                [[ -z "$id" ]] && continue
                ( cmd_run "$id" ) &
                pids+=($!)
            done <<<"$batch_ids"
            for pid in "${pids[@]}"; do wait "$pid" || true; done
        else
            while IFS= read -r id; do
                [[ -z "$id" ]] && continue
                cmd_run "$id" || true
            done <<<"$batch_ids"
        fi

        # review sequentially (review is cheap; serial keeps logs readable)
        while IFS= read -r id; do
            [[ -z "$id" ]] && continue
            cmd_review "$id" || true
        done <<<"$batch_ids"

        # record batch
        state_write_batch "$batch_id" "$(jq -n \
            --arg ts "$(_ts)" \
            --arg iter "$iter" \
            --argjson ids "$(jq -R . <<<"$batch_ids" | jq -s .)" \
            --argjson graph "$(state_read_epic_json)" \
            '{batch_id: $iter|tonumber, ts: $ts, tickets: $ids, graph_snapshot_status: ($graph.tickets | map({id,status}))}')"

        dim "  $(state_summary)"
    done

    step "execute: loop finished"
    cmd_summary
}

cmd_summary() {
    state_init
    state_epic_exists || { warn "no epic"; return 0; }
    step "$(jq -r '.meta.title' "$MARGE_DIR/epic.json")"
    graph_render_tree
    local s; s=$(state_summary)
    printf "\n  %b%s%b\n" "$C_BOLD" "$s" "$C_RESET" >&2
    local needs_human; needs_human=$(jq -r '.tickets[] | select(.status=="needs_human") | .id' "$MARGE_DIR/epic.json")
    if [[ -n "$needs_human" ]]; then
        warn "needs human review: $(tr '\n' ' ' <<<"$needs_human")"
    fi
}

cmd_prune() {
    state_init
    worktree_list | awk '{print $1}' | while read -r p; do
        [[ -z "$p" ]] && continue
        warn "removing worktree $p"
        git worktree remove --force "$p" >/dev/null 2>&1 || rm -rf "$p"
    done
    ok "pruned"
}

# ---------- arg parsing ----------

main() {
    local cmd="${1:-}"; shift || true

    # parse global flags that may appear after the verb
    local passthrough=()
    while (( $# > 0 )); do
        case "$1" in
            --agent)        MARGE_AGENT="$2"; shift 2 ;;
            --concurrency)  MARGE_CONCURRENCY="$2"; shift 2 ;;
            --max-pivots)   MARGE_MAX_PIVOTS="$2"; shift 2 ;;
            -h|--help)      usage; exit 0 ;;
            *)              passthrough+=("$1"); shift ;;
        esac
    done

    case "$cmd" in
        init)        cmd_init ;;
        plan)        cmd_plan "${passthrough[@]:-}" ;;
        parse)       cmd_parse "${passthrough[@]:-}" ;;
        list|ls)     cmd_list ;;
        next)        cmd_next ;;
        show)        cmd_show "${passthrough[@]:-}" ;;
        set-status)  cmd_set_status "${passthrough[@]:-}" ;;
        run)         cmd_run "${passthrough[@]:-}" ;;
        review)      cmd_review "${passthrough[@]:-}" ;;
        execute|go)  cmd_execute ;;
        summary)     cmd_summary ;;
        prune)       cmd_prune ;;
        ""|-h|--help|help) usage ;;
        *)           err "unknown command: $cmd"; usage; exit 1 ;;
    esac
}

main "$@"
