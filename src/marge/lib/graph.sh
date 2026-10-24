#!/usr/bin/env bash
# Ticket graph operations. Reads/writes $MARGE_DIR/epic.json via jq.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/state.sh"

# Return ticket IDs (one per line) whose status=pending and all deps=done.
graph_ready_tickets() {
    jq -r '
        .tickets as $all
        | ($all | map(select(.status=="done") | .id)) as $done
        | $all[]
        | select(.status == "pending")
        | select(
            (.dependencies // []) | all(. as $d | $done | index($d))
          )
        | .id
    ' "$MARGE_DIR/epic.json"
}

graph_ticket() {
    local id="$1"
    jq --arg id "$id" '.tickets[] | select(.id==$id)' "$MARGE_DIR/epic.json"
}

# Concurrency-safe: every mutator uses a per-PID-per-ticket tmp file so
# parallel workers can't clobber each other, and only promotes the tmp
# file to epic.json if jq succeeds. If jq fails, epic.json is untouched
# and the bad tmp is removed.
_graph_mutate() {
    local filter="$1"; shift  # remaining args are forwarded to jq
    local tmp="$MARGE_DIR/epic.json.tmp.$$.$RANDOM"
    if jq "$@" "$filter" "$MARGE_DIR/epic.json" > "$tmp" && [[ -s "$tmp" ]]; then
        mv "$tmp" "$MARGE_DIR/epic.json"
        return 0
    fi
    rm -f "$tmp"
    err "graph mutation failed (jq filter: ${filter:0:60}...)"
    return 1
}

graph_set_status() {
    local id="$1" status="$2"
    _graph_mutate '.tickets |= map(if .id==$id then .status=$s else . end)' \
        --arg id "$id" --arg s "$status"
}

graph_set_field() {
    local id="$1" key="$2" value="$3"
    _graph_mutate '.tickets |= map(if .id==$id then .[$k]=$v else . end)' \
        --arg id "$id" --arg k "$key" --arg v "$value"
}

graph_incr_pivots() {
    local id="$1"
    _graph_mutate '.tickets |= map(if .id==$id then .pivots = ((.pivots // 0) + 1) else . end)' \
        --arg id "$id"
}

graph_pivots() {
    local id="$1"
    jq -r --arg id "$id" '.tickets[] | select(.id==$id) | (.pivots // 0)' "$MARGE_DIR/epic.json"
}

graph_has_pending() {
    local n
    n=$(jq '[.tickets[] | select(.status=="pending" or .status=="needs_pivot")] | length' "$MARGE_DIR/epic.json")
    (( n > 0 ))
}

graph_has_ready() {
    [[ -n "$(graph_ready_tickets)" ]]
}

graph_stuck() {
    # no ready tickets but pending ones exist → deadlock (cycle or missing dep)
    ! graph_has_ready && graph_has_pending
}

graph_acceptance() {
    local id="$1"
    jq -r --arg id "$id" '
        .tickets[] | select(.id==$id) | (.acceptance_criteria // []) | .[] | "- " + .
    ' "$MARGE_DIR/epic.json"
}

graph_spec() {
    local id="$1"
    jq -r --arg id "$id" '.tickets[] | select(.id==$id) | .spec' "$MARGE_DIR/epic.json"
}

graph_title() {
    local id="$1"
    jq -r --arg id "$id" '.tickets[] | select(.id==$id) | .title' "$MARGE_DIR/epic.json"
}

graph_agent() {
    local id="$1"
    jq -r --arg id "$id" '.tickets[] | select(.id==$id) | (.agent // "")' "$MARGE_DIR/epic.json"
}

# graph_set_subtasks <id> <json-array>
# Replace a ticket's subtasks array wholesale (used by `marge expand`).
graph_set_subtasks() {
    local id="$1" subtasks="$2"
    _graph_mutate '.tickets |= map(if .id==$id then .subtasks=$st else . end)' \
        --arg id "$id" --argjson st "$subtasks"
}

# graph_subtasks <id> — print the ticket's subtasks array (or [] if none).
graph_subtasks() {
    local id="$1"
    jq -c --arg id "$id" '.tickets[] | select(.id==$id) | (.subtasks // [])' "$MARGE_DIR/epic.json"
}

_graph_status_icon() {
    # sets globals icon/color for a status string
    case "$1" in
        done)          icon="✓"; color="$C_GREEN"   ;;
        in_progress)   icon="↻"; color="$C_CYAN"    ;;
        needs_pivot)   icon="↯"; color="$C_YELLOW"  ;;
        needs_human)   icon="!"; color="$C_MAGENTA" ;;
        failed)        icon="✗"; color="$C_RED"     ;;
        *)             icon="○"; color="$C_DIM"     ;;
    esac
}

graph_render_tree() {
    # Emits one row per ticket, followed by one row per subtask (depth 1)
    # indented beneath its parent. Depth is the first TSV column.
    jq -r '
        .tickets[]
        | ([0, .id, .status, .title] | @tsv),
          ((.subtasks // [])[] | [1, .id, .status, .title] | @tsv)
    ' "$MARGE_DIR/epic.json" | while IFS=$'\t' read -r depth id status title; do
        local icon color indent=""
        _graph_status_icon "$status"
        if (( depth > 0 )); then indent="    └─ "; fi
        printf "  %s%b%s%b  %s %b%s%b\n" "$indent" "$color" "$icon" "$C_RESET" "$id" "$C_DIM" "$title" "$C_RESET" >&2
    done
}
