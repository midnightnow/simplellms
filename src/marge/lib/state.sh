#!/usr/bin/env bash
# State layer: read/write the .marge/ directory inside the target repo.
#
# Layout:
#   <repo>/.marge/
#     epic.md          — original user-supplied epic text
#     epic.json        — ticket graph (authoritative)
#     tickets/<ID>.md  — per-ticket human-readable spec + history
#     batches/<N>.json — record of each dispatch round
#     log.md           — append-only orchestrator log

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

state_init() {
    local root; root="$(git rev-parse --show-toplevel)"
    MARGE_DIR="$root/$MARGE_ROOT"
    mkdir -p "$MARGE_DIR"/{tickets,batches,worktrees}
    : > "$MARGE_DIR/log.md.lock" 2>/dev/null || true
    export MARGE_DIR
}

state_epic_exists() { [[ -f "$MARGE_DIR/epic.json" ]]; }

state_write_epic_md() {
    printf "%s\n" "$1" > "$MARGE_DIR/epic.md"
}

state_write_epic_json() {
    # validate on write so a bad plan fails loud
    printf "%s" "$1" | jq empty 2>/dev/null || die "epic.json failed jq parse"
    printf "%s" "$1" | jq '.' > "$MARGE_DIR/epic.json.tmp"
    mv "$MARGE_DIR/epic.json.tmp" "$MARGE_DIR/epic.json"
}

state_read_epic_json() { cat "$MARGE_DIR/epic.json"; }

state_write_ticket_md() {
    local id="$1" md="$2"
    printf "%s\n" "$md" > "$MARGE_DIR/tickets/${id}.md"
}

state_append_ticket_log() {
    local id="$1" note="$2"
    {
        printf "\n---\n"
        printf "**%s** — %s\n\n" "$(_ts)" "$note"
    } >> "$MARGE_DIR/tickets/${id}.md"
}

state_next_batch_id() {
    local n
    n=$(find "$MARGE_DIR/batches" -maxdepth 1 -name 'batch-*.json' 2>/dev/null | wc -l | tr -d ' ')
    printf "%03d" $((n + 1))
}

state_write_batch() {
    local id="$1" json="$2"
    printf "%s" "$json" | jq '.' > "$MARGE_DIR/batches/batch-${id}.json"
}

state_log() {
    local msg="$*"
    printf "[%s] %s\n" "$(_ts)" "$msg" >> "$MARGE_DIR/log.md"
}

state_summary() {
    local total done_ pending in_prog failed human pivot
    local json; json="$(state_read_epic_json)"
    total=$(jq '.tickets | length' <<< "$json")
    done_=$(jq '[.tickets[] | select(.status=="done")] | length' <<< "$json")
    pending=$(jq '[.tickets[] | select(.status=="pending")] | length' <<< "$json")
    in_prog=$(jq '[.tickets[] | select(.status=="in_progress")] | length' <<< "$json")
    failed=$(jq '[.tickets[] | select(.status=="failed")] | length' <<< "$json")
    human=$(jq '[.tickets[] | select(.status=="needs_human")] | length' <<< "$json")
    pivot=$(jq '[.tickets[] | select(.status=="needs_pivot")] | length' <<< "$json")
    printf "total=%d done=%d pending=%d in_progress=%d needs_pivot=%d needs_human=%d failed=%d" \
        "$total" "$done_" "$pending" "$in_prog" "$pivot" "$human" "$failed"
}
