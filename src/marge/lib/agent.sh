#!/usr/bin/env bash
# Pluggable agent backend.
#
# Selects a coding agent via $MARGE_AGENT (claude | gemini | amp | echo).
# The `echo` backend is a dry-run that returns canned JSON — used for tests.
#
# Every real-agent invocation is wrapped with `timeout $MARGE_TIMEOUT`
# (default 600s = 10min). On timeout or non-zero exit, stderr is captured
# to a log file if $MARGE_AGENT_LOG is set, so callers can surface it
# instead of silently dying.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

: "${MARGE_TIMEOUT:=600}"

# Pick whichever timeout binary is on PATH: GNU `timeout` on Linux,
# `gtimeout` on macOS with coreutils-from-Homebrew, or empty on bare macOS.
# If empty, we skip the timeout — the safety net is lost but the tool still
# works. Print a one-time warning so users know.
_MARGE_TIMEOUT_CMD=""
if command -v timeout >/dev/null 2>&1; then
    _MARGE_TIMEOUT_CMD="timeout $MARGE_TIMEOUT"
elif command -v gtimeout >/dev/null 2>&1; then
    _MARGE_TIMEOUT_CMD="gtimeout $MARGE_TIMEOUT"
fi

# _agent_exec <cmd> <cwd> <prompt>
# Runs `cmd` with the timeout wrapper (if available), piping prompt on
# stdin. Captures stderr to $MARGE_AGENT_LOG if set. Returns the command's
# exit code (124 if the timeout fired).
_agent_exec() {
    local cmd="$1" cwd="$2" prompt="$3"
    local stderr_sink="${MARGE_AGENT_LOG:-/dev/null}"
    if [[ -z "$_MARGE_TIMEOUT_CMD" && -z "${_MARGE_TIMEOUT_WARNED:-}" ]]; then
        warn "no 'timeout' or 'gtimeout' on PATH — agent calls will not be time-capped. install coreutils for safety."
        _MARGE_TIMEOUT_WARNED=1
    fi
    local rc
    ( cd "$cwd" && printf "%s" "$prompt" | $_MARGE_TIMEOUT_CMD $cmd 2>>"$stderr_sink" )
    rc=$?
    case "$rc" in
        0)   return 0 ;;
        124) err "agent timeout after ${MARGE_TIMEOUT}s (cmd: $cmd)"; return 124 ;;
        *)   err "agent '$cmd' exited $rc — see ${MARGE_AGENT_LOG:-stderr}"; return "$rc" ;;
    esac
}

# agent_run <prompt-text> [cwd]
# prints agent response to stdout. cwd defaults to current directory.
agent_run() {
    local prompt="$1"
    local cwd="${2:-$PWD}"

    case "$MARGE_AGENT" in
        claude)
            command -v claude >/dev/null 2>&1 \
                || die "MARGE_AGENT=claude but 'claude' CLI not found. install Claude Code or set MARGE_AGENT=echo"
            _agent_exec "claude -p --output-format text" "$cwd" "$prompt"
            ;;
        gemini)
            command -v gemini >/dev/null 2>&1 || die "gemini CLI not found"
            _agent_exec "gemini" "$cwd" "$prompt"
            ;;
        amp)
            command -v amp >/dev/null 2>&1 || die "amp CLI not found"
            _agent_exec "amp" "$cwd" "$prompt"
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

    # Find the first balanced {...} object. The Python balanced-brace scanner
    # is tolerant of commentary, fenced blocks, or leading prose — it just
    # walks looking for the first syntactically-valid top-level object.
    local obj
    obj="$(printf "%s" "$raw" | python3 -c '
import sys, json
s = sys.stdin.read()
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
        err "agent returned non-JSON response (first 40 lines):"
        printf "%s\n" "$raw" | head -40 >&2
        return 1
    }

    printf "%s\n" "$obj"
}
