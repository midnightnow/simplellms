#!/usr/bin/env bash
# tests/run.sh — full test suite for the M.A.R.G.E. orchestrator.
# Runs with zero external deps. Uses MARGE_AGENT=echo with canned fixtures
# so no LLM is ever called.

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/helpers.sh"

FIX="$HERE/fixtures"
export MARGE_AGENT=echo
export MARGE_COLOR=0  # keep test output deterministic

# ========================================================================
#  help / usage
# ========================================================================

test_help_shows_marge_branding() {
    local out; out="$("$SIMPLELLMS" --marge help 2>&1)"
    assert_contains "$out" "M.A.R.G.E." "help should mention M.A.R.G.E."
    assert_contains "$out" "marge init" "help should list init verb"
    assert_contains "$out" "marge execute" "help should list execute verb"
}

test_help_does_not_advertise_bart_orchestrator() {
    # B.A.R.T. is the creative-pivot persona, not the orchestrator anymore
    local out; out="$("$SIMPLELLMS" --marge help 2>&1)"
    assert_not_contains "$out" "bart init" "help should not advertise bart init"
    assert_not_contains "$out" "bart execute" "help should not advertise bart execute"
}

# ========================================================================
#  init
# ========================================================================

test_init_creates_state_dir() {
    setup_repo >/dev/null
    "$SIMPLELLMS" --marge init >/dev/null 2>&1
    assert_dir_exists ".marge" "state dir should exist"
    assert_dir_exists ".marge/tickets"
    assert_dir_exists ".marge/batches"
    assert_dir_exists ".marge/worktrees"
    assert_file_exists ".marge/.base-ref"
}

test_init_outside_git_repo_fails() {
    local d; d="$(mktemp -d -t marge-test-nongit.XXXXXX)"
    _tmpdirs+=("$d")
    cd "$d"
    "$SIMPLELLMS" --marge init >/dev/null 2>&1
    assert_exit_code 1 "$?" "init should fail with nonzero exit outside a git repo"
}

# ========================================================================
#  plan / parse
# ========================================================================

test_plan_writes_epic_json_from_fixture() {
    setup_repo >/dev/null
    "$SIMPLELLMS" --marge init >/dev/null 2>&1
    MARGE_ECHO_FIXTURE="$FIX/plan-3-tickets.json" \
        "$SIMPLELLMS" --marge plan "Tiny hello site" >/dev/null 2>&1

    assert_file_exists ".marge/epic.json"
    assert_file_exists ".marge/epic.md"

    local count; count=$(jq '.tickets | length' .marge/epic.json)
    assert_eq "3" "$count" "should have 3 tickets"

    local slug; slug=$(jq -r '.meta.slug' .marge/epic.json)
    assert_eq "hello-site" "$slug"
}

test_plan_writes_per_ticket_markdown() {
    setup_repo >/dev/null
    "$SIMPLELLMS" --marge init >/dev/null 2>&1
    MARGE_ECHO_FIXTURE="$FIX/plan-3-tickets.json" \
        "$SIMPLELLMS" --marge plan "Tiny hello site" >/dev/null 2>&1

    assert_file_exists ".marge/tickets/T001.md"
    assert_file_exists ".marge/tickets/T002.md"
    assert_file_exists ".marge/tickets/T003.md"

    local content; content="$(cat .marge/tickets/T001.md)"
    assert_contains "$content" "Create index.html" "ticket md should contain title"
    assert_contains "$content" "Acceptance criteria" "ticket md should have criteria section"
}

test_plan_normalizes_all_ticket_statuses_to_pending() {
    setup_repo >/dev/null
    "$SIMPLELLMS" --marge init >/dev/null 2>&1
    MARGE_ECHO_FIXTURE="$FIX/plan-3-tickets.json" \
        "$SIMPLELLMS" --marge plan "x" >/dev/null 2>&1

    local pending_count; pending_count=$(jq '[.tickets[] | select(.status=="pending")] | length' .marge/epic.json)
    assert_eq "3" "$pending_count" "all tickets should start pending"
}

test_plan_records_metadata() {
    setup_repo >/dev/null
    "$SIMPLELLMS" --marge init >/dev/null 2>&1
    MARGE_ECHO_FIXTURE="$FIX/plan-3-tickets.json" \
        "$SIMPLELLMS" --marge plan "x" >/dev/null 2>&1

    local version; version=$(jq -r '.meta.marge_version' .marge/epic.json)
    assert_contains "$version" "." "marge_version should be set (saw: $version)"

    local agent; agent=$(jq -r '.meta.agent' .marge/epic.json)
    assert_eq "echo" "$agent" "agent should be recorded in meta"
}

test_parse_reads_from_file() {
    setup_repo >/dev/null
    "$SIMPLELLMS" --marge init >/dev/null 2>&1
    # parse reads the epic text from a file; we still need a fixture for the
    # planner's response since the "echo" backend is a dry-run
    echo "Build a tiny hello site" > my-epic.md
    MARGE_ECHO_FIXTURE="$FIX/plan-3-tickets.json" \
        "$SIMPLELLMS" --marge parse my-epic.md >/dev/null 2>&1
    assert_file_exists ".marge/epic.json"
}

# ========================================================================
#  list / show / summary
# ========================================================================

test_list_renders_all_tickets() {
    setup_repo >/dev/null
    "$SIMPLELLMS" --marge init >/dev/null 2>&1
    MARGE_ECHO_FIXTURE="$FIX/plan-3-tickets.json" \
        "$SIMPLELLMS" --marge plan "x" >/dev/null 2>&1

    local out; out="$("$SIMPLELLMS" --marge list 2>&1)"
    assert_contains "$out" "T001"
    assert_contains "$out" "T002"
    assert_contains "$out" "T003"
    assert_contains "$out" "Tiny hello site"
}

test_show_returns_ticket_json() {
    setup_repo >/dev/null
    "$SIMPLELLMS" --marge init >/dev/null 2>&1
    MARGE_ECHO_FIXTURE="$FIX/plan-3-tickets.json" \
        "$SIMPLELLMS" --marge plan "x" >/dev/null 2>&1

    local out; out="$("$SIMPLELLMS" --marge show T003 2>&1)"
    assert_contains "$out" '"id"' "show output should be JSON-shaped"
    assert_contains "$out" "T003"
    assert_contains "$out" "Link README"
}

test_summary_includes_counts() {
    setup_repo >/dev/null
    "$SIMPLELLMS" --marge init >/dev/null 2>&1
    MARGE_ECHO_FIXTURE="$FIX/plan-3-tickets.json" \
        "$SIMPLELLMS" --marge plan "x" >/dev/null 2>&1

    local out; out="$("$SIMPLELLMS" --marge summary 2>&1)"
    assert_contains "$out" "total=3"
    assert_contains "$out" "done=0"
    assert_contains "$out" "pending=3"
}

# ========================================================================
#  next / set-status — the dependency logic
# ========================================================================

test_next_returns_first_ready_ticket() {
    setup_repo >/dev/null
    "$SIMPLELLMS" --marge init >/dev/null 2>&1
    MARGE_ECHO_FIXTURE="$FIX/plan-3-tickets.json" \
        "$SIMPLELLMS" --marge plan "x" >/dev/null 2>&1

    local nxt; nxt="$("$SIMPLELLMS" --marge next 2>/dev/null)"
    assert_eq "T001" "$nxt"
}

test_next_respects_dependencies() {
    setup_repo >/dev/null
    "$SIMPLELLMS" --marge init >/dev/null 2>&1
    MARGE_ECHO_FIXTURE="$FIX/plan-3-tickets.json" \
        "$SIMPLELLMS" --marge plan "x" >/dev/null 2>&1

    # T003 depends on T001 and T002. After only T001 is done, next should be T002 (still pending, no deps).
    "$SIMPLELLMS" --marge set-status T001 done >/dev/null 2>&1
    local nxt1; nxt1="$("$SIMPLELLMS" --marge next 2>/dev/null)"
    assert_eq "T002" "$nxt1" "after T001 done, T002 should be next"

    # After both T001 and T002 are done, next should be T003.
    "$SIMPLELLMS" --marge set-status T002 done >/dev/null 2>&1
    local nxt2; nxt2="$("$SIMPLELLMS" --marge next 2>/dev/null)"
    assert_eq "T003" "$nxt2" "after both deps done, T003 should be next"
}

test_set_status_persists_to_epic_json() {
    setup_repo >/dev/null
    "$SIMPLELLMS" --marge init >/dev/null 2>&1
    MARGE_ECHO_FIXTURE="$FIX/plan-3-tickets.json" \
        "$SIMPLELLMS" --marge plan "x" >/dev/null 2>&1

    "$SIMPLELLMS" --marge set-status T002 needs_human >/dev/null 2>&1
    local status; status=$(jq -r '.tickets[] | select(.id=="T002") | .status' .marge/epic.json)
    assert_eq "needs_human" "$status"
}

# ========================================================================
#  routing
# ========================================================================

test_bare_marge_text_routes_to_plan() {
    setup_repo >/dev/null
    "$SIMPLELLMS" --marge init >/dev/null 2>&1
    # No verb → treat the string as an epic to plan
    MARGE_ECHO_FIXTURE="$FIX/plan-3-tickets.json" \
        "$SIMPLELLMS" --marge "just a bare string epic" >/dev/null 2>&1
    assert_file_exists ".marge/epic.json"
}

test_unknown_verb_to_marge_sh_directly_errors() {
    # Calling marge.sh directly with an unknown verb should error.
    # (Through simplellms.sh, unknown verbs fall through to `plan`, which is the desired UX.)
    setup_repo >/dev/null
    "$MARGE" definitely-not-a-verb >/dev/null 2>&1
    local rc=$?
    # nonzero rc (we accept anything nonzero; `die` uses `exit` which is 1)
    if (( rc == 0 )); then
        printf "    expected nonzero exit for unknown verb, got 0\n" >&2
        return 1
    fi
}

test_legacy_bart_alias_does_not_touch_marge_state() {
    # --bart routes to `claude --profile bart` (legacy). We can't run
    # claude in tests, but we can assert that it does NOT invoke marge.sh
    # (which would create .marge/). Ensure no .marge was created.
    setup_repo >/dev/null
    # swallow exit code: claude CLI may or may not be installed; we only
    # care that marge.sh didn't run
    "$SIMPLELLMS" --bart "legacy creative pivot test" >/dev/null 2>&1 || true
    if [[ -d .marge ]]; then
        printf "    .marge/ should not exist — --bart must not invoke marge.sh\n" >&2
        return 1
    fi
}

# ========================================================================
#  schema validity
# ========================================================================

test_schema_file_is_valid_json() {
    local schema; schema="$SIMPLELLMS_ROOT/src/marge/schemas/epic.schema.json"
    jq empty < "$schema" 2>&1
    assert_exit_code 0 "$?" "epic.schema.json should be valid JSON"
}

test_fixture_validates_against_expected_shape() {
    # Sanity: our own fixture has the fields the code reads.
    local fx="$FIX/plan-3-tickets.json"
    jq -e '.meta.title and .meta.slug and (.tickets | length > 0) and (.tickets[0] | .id and .title and .status)' "$fx" >/dev/null
    assert_exit_code 0 "$?" "fixture should have the minimum required shape"
}

# ========================================================================
#  tier-A regressions — tests for the 5 critical bugs
# ========================================================================

# Fix #1 + #4: concurrent status updates must not corrupt epic.json
test_concurrent_status_updates_are_safe() {
    setup_repo >/dev/null
    "$SIMPLELLMS" --marge init >/dev/null 2>&1
    MARGE_ECHO_FIXTURE="$FIX/plan-3-tickets.json" \
        "$SIMPLELLMS" --marge plan "x" >/dev/null 2>&1

    # Fire off 20 concurrent set-status calls against different tickets.
    # Pre-fix, these raced on epic.json.tmp and frequently corrupted state.
    local pids=()
    local i
    for i in $(seq 1 20); do
        local tid tst
        case $((i % 3)) in
            0) tid=T001 ;;
            1) tid=T002 ;;
            2) tid=T003 ;;
        esac
        case $((i % 4)) in
            0) tst=pending ;;
            1) tst=done ;;
            2) tst=needs_pivot ;;
            3) tst=failed ;;
        esac
        "$SIMPLELLMS" --marge set-status "$tid" "$tst" >/dev/null 2>&1 &
        pids+=($!)
    done
    for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || true; done

    # After the storm, epic.json must still be valid JSON with all 3 tickets.
    if ! jq empty .marge/epic.json 2>/dev/null; then
        printf "    epic.json is not valid JSON after concurrent writes\n" >&2
        return 1
    fi
    local n; n=$(jq '.tickets | length' .marge/epic.json)
    assert_eq "3" "$n" "concurrent writes must preserve ticket count"

    # No stale tmp files should remain.
    local leftover; leftover=$(find .marge -maxdepth 1 -name 'epic.json.tmp.*' 2>/dev/null | head -1)
    if [[ -n "$leftover" ]]; then
        printf "    stale tmp file left behind: %s\n" "$leftover" >&2
        return 1
    fi
}

# Fix #2: stranded in_progress must be reset on next execute
test_stranded_in_progress_is_reset() {
    setup_repo >/dev/null
    "$SIMPLELLMS" --marge init >/dev/null 2>&1
    MARGE_ECHO_FIXTURE="$FIX/plan-3-tickets.json" \
        "$SIMPLELLMS" --marge plan "x" >/dev/null 2>&1

    # Simulate a killed run: leave a ticket stuck in in_progress.
    "$SIMPLELLMS" --marge set-status T001 in_progress >/dev/null 2>&1
    local before; before=$(jq -r '.tickets[] | select(.id=="T001") | .status' .marge/epic.json)
    assert_eq "in_progress" "$before" "setup: T001 should be in_progress"

    # Running execute should reset it before the loop runs. Even if the
    # loop then fails (echo backend produces no diff), the reset must
    # have happened. Echo backend completes in <1s on this fixture, so
    # we don't wrap in `timeout` (which isn't on stock macOS anyway).
    "$SIMPLELLMS" --marge execute >/dev/null 2>&1 || true

    # After execute touches it, status should no longer be in_progress
    # (either pending if reset succeeded and nothing ran, or failed/done
    # if a full run completed, but NEVER the original orphaned state).
    local after; after=$(jq -r '.tickets[] | select(.id=="T001") | .status' .marge/epic.json)
    if [[ "$after" == "in_progress" ]]; then
        printf "    T001 still in_progress after execute — reset did not happen\n" >&2
        return 1
    fi
}

# Fix #3: agent timeout wrapper is present and honors MARGE_TIMEOUT
test_agent_timeout_is_wired() {
    # Verify the code path: agent.sh must reference `timeout` and MARGE_TIMEOUT.
    # This is a structural test — actually triggering a timeout requires a
    # real hanging process, which we don't want to flake on.
    local agent_sh="$SIMPLELLMS_ROOT/src/marge/lib/agent.sh"
    grep -qE 'timeout \$MARGE_TIMEOUT|gtimeout \$MARGE_TIMEOUT' "$agent_sh" \
        || { printf "    agent.sh missing timeout wrapper\n" >&2; return 1; }
    grep -q 'MARGE_TIMEOUT:=600' "$agent_sh" \
        || { printf "    agent.sh missing default MARGE_TIMEOUT=600\n" >&2; return 1; }
    grep -q '124)' "$agent_sh" \
        || { printf "    agent.sh missing timeout exit-code (124) handler\n" >&2; return 1; }
}

# Fix #5: agent failures must leave a .agent.log / .review.log breadcrumb
test_agent_failure_paths_write_logs() {
    # Structural test: marge.sh cmd_run + cmd_review + cmd_pivot must
    # reference MARGE_AGENT_LOG and write a log file under .marge/tickets/.
    local marge_sh="$SIMPLELLMS_ROOT/src/marge/marge.sh"
    grep -q 'MARGE_AGENT_LOG=.*agent_log' "$marge_sh" \
        || { printf "    cmd_run doesn't wire MARGE_AGENT_LOG\n" >&2; return 1; }
    grep -q 'review.log' "$marge_sh" \
        || { printf "    cmd_review doesn't create review.log\n" >&2; return 1; }
    grep -q 'pivot.log' "$marge_sh" \
        || { printf "    cmd_pivot doesn't create pivot.log\n" >&2; return 1; }
}

# Script must resolve its own symlinks so PATH invocation works.
# Regression test for the bug discovered when setting up ~/.local/bin/simplellms.
test_script_works_when_invoked_via_symlink() {
    local linkdir; linkdir="$(mktemp -d -t marge-symlink.XXXXXX)"
    _tmpdirs+=("$linkdir")
    ln -s "$SIMPLELLMS" "$linkdir/simplellms-link"
    local out; out="$("$linkdir/simplellms-link" --marge help 2>&1)"
    assert_contains "$out" "M.A.R.G.E." "symlinked invocation must resolve src/marge/marge.sh"
    assert_not_contains "$out" "not found" "must not emit 'orchestrator not found' error"
}

# Fix #4 as graph-level behavior: a failing jq mutation must NOT clobber epic.json
test_failed_jq_mutation_does_not_truncate_epic_json() {
    setup_repo >/dev/null
    "$SIMPLELLMS" --marge init >/dev/null 2>&1
    MARGE_ECHO_FIXTURE="$FIX/plan-3-tickets.json" \
        "$SIMPLELLMS" --marge plan "x" >/dev/null 2>&1

    local before; before=$(wc -c < .marge/epic.json)

    # Sabotage epic.json to be unparseable, then try to set a status.
    # Pre-fix: `jq > tmp` would error, leaving tmp empty, then mv would
    # clobber epic.json with 0 bytes. Our fix checks [[ -s "$tmp" ]].
    cp .marge/epic.json .marge/epic.json.bak
    printf "not json" > .marge/epic.json
    "$SIMPLELLMS" --marge set-status T001 done >/dev/null 2>&1 || true

    # epic.json should still be whatever we sabotaged it to (unparseable),
    # NOT an empty truncation. We prove this by restoring from backup and
    # checking the backup's integrity wasn't relevant here — the key
    # invariant is that epic.json is not empty.
    local size; size=$(wc -c < .marge/epic.json)
    if [[ "$size" -eq 0 ]]; then
        printf "    epic.json was truncated to 0 bytes by failed mutation\n" >&2
        return 1
    fi
    mv .marge/epic.json.bak .marge/epic.json
}

# ========================================================================
#  syntax
# ========================================================================

test_all_shell_scripts_pass_bash_syntax() {
    local failed=0
    for f in "$SIMPLELLMS" "$MARGE" "$SIMPLELLMS_ROOT"/src/marge/lib/*.sh; do
        if ! bash -n "$f" 2>&1; then
            printf "    bash -n failed for %s\n" "$f" >&2
            failed=1
        fi
    done
    return $failed
}

# ========================================================================
#  runner
# ========================================================================

printf "${T_BOLD}M.A.R.G.E. test suite${T_RESET}  ${T_DIM}(agent=echo, no LLM calls)${T_RESET}\n\n"

for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
    run_test "$t"
done

summary
