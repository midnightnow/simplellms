#!/usr/bin/env bash
# Pluggable agent backend.
#
# Selects a coding agent via $MARGE_AGENT (claude | gemini | amp | echo).
# The `echo` backend is a dry-run that returns canned JSON — used for tests.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# agent_run <prompt-text> [cwd]
# prints agent response to stdout. cwd defaults to current directory.
agent_run() {
    local prompt="$1"
    local cwd="${2:-$PWD}"

    case "$MARGE_AGENT" in
        claude)
            command -v claude >/dev/null 2>&1 || die "claude CLI not found. install Claude Code: https://claude.ai/claude-code"
            ( cd "$cwd" && printf "%s" "$prompt" | claude -p --output-format text 2>/dev/null ) \
                || die "claude CLI failed"
            ;;
        gemini)
            command -v gemini >/dev/null 2>&1 || die "gemini CLI not found"
            ( cd "$cwd" && printf "%s" "$prompt" | gemini 2>/dev/null )
            ;;
        amp)
            command -v amp >/dev/null 2>&1 || die "amp CLI not found"
            ( cd "$cwd" && printf "%s" "$prompt" | amp 2>/dev/null )
            ;;
        echo)
            # dry-run. If $MARGE_ECHO_FIXTURE points at a file, return its
            # contents (use-case: replay a canned plan/review in tests).
            # Otherwise return a minimal JSON envelope so agent_run_json
            # at least parses something.
            if [[ -n "${MARGE_ECHO_FIXTURE:-}" && -f "$MARGE_ECHO_FIXTURE" ]]; then
                cat "$MARGE_ECHO_FIXTURE"
            else
                printf '{"dry_run":true,"cwd":%s,"prompt_chars":%d}\n' \
                    "$(jq -Rn --arg c "$cwd" '$c')" \
                    "${#prompt}"
            fi
            ;;
        *)
            die "unknown MARGE_AGENT='$MARGE_AGENT' (expected: claude|gemini|amp|echo)"
            ;;
    esac
}

# agent_run_json <prompt-text> [cwd]
# Expects the agent to return a JSON object (we tell it to via the prompt).
# Extracts the first balanced JSON object from the response, even if the
# agent wrapped it in ``` fences or surrounded it with commentary.
agent_run_json() {
    local raw
    raw="$(agent_run "$@")"

    # Strip ```json ... ``` fences if present
    local stripped
    stripped="$(printf "%s" "$raw" | awk '
        /^```/ { in_fence = !in_fence; next }
        in_fence { print }
        !in_fence && !printed_any && /^[^`]/ { buf = buf $0 "\n" }
        END { if (buf != "") print buf }
    ')"
    [[ -z "$stripped" ]] && stripped="$raw"

    # Find the first balanced {...} object
    local obj
    obj="$(printf "%s" "$stripped" | python3 -c '
import sys, json, re
s = sys.stdin.read()
# scan for balanced braces starting at the first {
start = s.find("{")
if start < 0:
    sys.exit(1)
depth = 0
for i, ch in enumerate(s[start:], start):
    if ch == "{": depth += 1
    elif ch == "}":
        depth -= 1
        if depth == 0:
            candidate = s[start:i+1]
            try:
                json.loads(candidate)
                print(candidate)
                sys.exit(0)
            except Exception:
                pass
sys.exit(1)
' 2>/dev/null)" || {
        err "agent returned non-JSON response:"
        printf "%s\n" "$raw" | head -40 >&2
        return 1
    }

    printf "%s\n" "$obj"
}
