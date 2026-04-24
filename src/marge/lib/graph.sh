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

graph_set_status() {
    local id="$1" status="$2"
    local tmp="$MARGE_DIR/epic.json.tmp"
    jq --arg id "$id" --arg s "$status" '
        .tickets |= map(if .id==$id then .status=$s else . end)
    ' "$MARGE_DIR/epic.json" > "$tmp"
    mv "$tmp" "$MARGE_DIR/epic.json"
}

graph_set_field() {
    local id="$1" key="$2" value="$3"
    local tmp="$MARGE_DIR/epic.json.tmp"
    jq --arg id "$id" --arg k "$key" --arg v "$value" '
        .tickets |= map(if .id==$id then .[$k]=$v else . end)
    ' "$MARGE_DIR/epic.json" > "$tmp"
    mv "$tmp" "$MARGE_DIR/epic.json"
}

graph_incr_pivots() {
    local id="$1"
    local tmp="$MARGE_DIR/epic.json.tmp"
    jq --arg id "$id" '
        .tickets |= map(if .id==$id then .pivots = ((.pivots // 0) + 1) else . end)
    ' "$MARGE_DIR/epic.json" > "$tmp"
    mv "$tmp" "$MARGE_DIR/epic.json"
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

graph_render_tree() {
    jq -r '
        .tickets[]
        | [.id, .status, .title] | @tsv
    ' "$MARGE_DIR/epic.json" | while IFS=$'\t' read -r id status title; do
        local icon color
        case "$status" in
            done)          icon="✓"; color="$C_GREEN"   ;;
            in_progress)   icon="↻"; color="$C_CYAN"    ;;
            needs_pivot)   icon="↯"; color="$C_YELLOW"  ;;
            needs_human)   icon="!"; color="$C_MAGENTA" ;;
            failed)        icon="✗"; color="$C_RED"     ;;
            *)             icon="○"; color="$C_DIM"     ;;
        esac
        printf "  %b%s%b  %s %b%s%b\n" "$color" "$icon" "$C_RESET" "$id" "$C_DIM" "$title" "$C_RESET" >&2
    done
}
