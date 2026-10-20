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

# Claude Code's `-p` (headless) mode prompts for permission on every file
# write and shell command, which can never resolve when there's no human
# at the terminal. For autonomous orchestration we set the permission
# mode to `bypassPermissions` by default — this is acceptable because
# every ticket runs in an isolated git worktree, so the blast radius is
# bounded to a throwaway branch the user reviews before merging. Users
# who prefer the safer `acceptEdits` mode (auto-accepts file edits but
# still prompts for shell commands) can override.
: "${MARGE_CLAUDE_PERMISSION_MODE:=bypassPermissions}"
: "${MARGE_LOCAL_URL:=http://localhost:1234/v1}"
: "${MARGE_LOCAL_MODEL:=qwen3.6-27b}"
: "${MARGE_LOCAL_API_KEY:=lm-studio}"

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

# agent_run <prompt-text> [cwd] [agent-override]
# prints agent response to stdout. cwd defaults to current directory.
agent_run() {
    local prompt="$1"
    local cwd="${2:-$PWD}"
    local backend="${3:-$MARGE_AGENT}"

    case "$backend" in
        claude)
            command -v claude >/dev/null 2>&1 \
                || die "MARGE_AGENT=claude but 'claude' CLI not found. install Claude Code or set MARGE_AGENT=echo"
            _agent_exec "claude -p --output-format text --permission-mode $MARGE_CLAUDE_PERMISSION_MODE" "$cwd" "$prompt"
            ;;
        gemini)
            command -v gemini >/dev/null 2>&1 || die "gemini CLI not found"
            # Headless gemini refuses to run in an untrusted dir (every fresh
            # worktree is untrusted); `env` because _agent_exec word-splits
            # $cmd, so a bare VAR=val prefix would be treated as a command.
            # NOTE (2026-10-16): the personal-OAuth free tier is gone
            # ("IneligibleTierError ... migrate to Antigravity"); set
            # GEMINI_API_KEY (AI Studio) or this backend dies at auth.
            _agent_exec "env GEMINI_CLI_TRUST_WORKSPACE=true gemini -p '' --yolo" "$cwd" "$prompt"
            ;;
        amp)
            command -v amp >/dev/null 2>&1 || die "amp CLI not found"
            _agent_exec "amp" "$cwd" "$prompt"
            ;;
        codex)
            command -v codex >/dev/null 2>&1 || die "codex CLI not found"
            _agent_exec "codex exec --approve-for-me -" "$cwd" "$prompt"
            ;;
        qwen)
            command -v qwen >/dev/null 2>&1 || die "qwen CLI not found"
            _agent_exec "qwen -p '' --yolo" "$cwd" "$prompt"
            ;;
        opencode)
            command -v opencode >/dev/null 2>&1 || die "opencode CLI not found"
            _agent_exec "opencode run" "$cwd" "$prompt"
            ;;
        goose)
            command -v goose >/dev/null 2>&1 || die "goose CLI not found"
            _agent_exec "goose run -i -" "$cwd" "$prompt"
            ;;
        aider)
            command -v aider >/dev/null 2>&1 || die "aider CLI not found"
            local msg_tmp
            msg_tmp="$(mktemp -t marge-aider-msg.XXXXXX)"
            printf "%s" "$prompt" > "$msg_tmp"
            local rc=0
            _agent_exec "aider --yes-always --no-auto-commits --message-file $msg_tmp" "$cwd" "" || rc=$?
            rm -f "$msg_tmp"
            return "$rc"
            ;;
        local)
            # Local model execution (safe for clinic/patient data residency).
            # Prefers codex --oss (LM Studio) or aider against $MARGE_LOCAL_URL,
            # falling back to direct OpenAI-compatible HTTP chat completions.
            if command -v codex >/dev/null 2>&1 && [[ "$PWD" != "$cwd" || -d "$cwd/.git" || -f "$cwd/.git" ]]; then
                _agent_exec "codex exec --oss --local-provider lmstudio -m $MARGE_LOCAL_MODEL --approve-for-me -" "$cwd" "$prompt"
            else
                local payload
                payload="$(jq -n --arg model "$MARGE_LOCAL_MODEL" --arg content "$prompt" \
                    '{model: $model, temperature: 0.1, messages: [{role: "user", content: $content}]}')"
                curl -sf -m "$MARGE_TIMEOUT" -X POST "${MARGE_LOCAL_URL%/}/chat/completions" \
                    -H "Content-Type: application/json" \
                    -H "Authorization: Bearer $MARGE_LOCAL_API_KEY" \
                    -d "$payload" | jq -r '.choices[0].message.content // empty'
            fi
            ;;
        echo)
            # dry-run. If $MARGE_ECHO_FIXTURE points at a file, return its
            # contents (use-case: replay a canned plan/review in tests).
            # Otherwise return a minimal JSON envelope so agent_run_json
            # at least parses something.
            if [[ -n "${MARGE_ECHO_FIXTURE:-}" && -f "$MARGE_ECHO_FIXTURE" ]]; then
                cat "$MARGE_ECHO_FIXTURE"
            else
                printf '{"dry_run":true,"agent":%s,"cwd":%s,"prompt_chars":%d}\n' \
                    "$(jq -Rn --arg a "$backend" '$a')" \
                    "$(jq -Rn --arg c "$cwd" '$c')" \
                    "${#prompt}"
            fi
            ;;
        *)
            die "unknown MARGE_AGENT='$backend' (expected: claude|gemini|amp|codex|qwen|opencode|goose|aider|local|echo)"
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
