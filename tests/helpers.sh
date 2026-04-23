#!/usr/bin/env bash
# Test helpers. Sourced by tests/run.sh.
# Zero external deps beyond what Marge itself needs (bash, git, jq, python3).

set -u  # pedantic about unset vars; tests manage their own -e with trap

SIMPLELLMS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIMPLELLMS="$SIMPLELLMS_ROOT/simplellms.sh"
MARGE="$SIMPLELLMS_ROOT/src/marge/marge.sh"

# colors (only if stdout is a tty)
if [[ -t 1 ]]; then
    T_RED='\033[0;31m' T_GREEN='\033[0;32m' T_DIM='\033[2m' T_BOLD='\033[1m' T_RESET='\033[0m' T_YELLOW='\033[0;33m'
else
    T_RED='' T_GREEN='' T_DIM='' T_BOLD='' T_RESET='' T_YELLOW=''
fi

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_NAMES=()

_tmpdirs=()

setup_repo() {
    # Create a throwaway git repo and cd into it. Returns the path via stdout.
    local d; d="$(mktemp -d -t marge-test.XXXXXX)"
    _tmpdirs+=("$d")
    git -C "$d" init -q
    git -C "$d" -c user.email=t@t -c user.name=t commit --allow-empty -q -m "initial"
    cd "$d"
    printf "%s" "$d"
}

cleanup_all() {
    cd / >/dev/null 2>&1 || true
    for d in "${_tmpdirs[@]:-}"; do
        [[ -z "$d" ]] && continue
        # prune any worktrees before rm -rf, so git doesn't leak refs elsewhere
        if [[ -d "$d/.git" ]]; then
            git -C "$d" worktree prune >/dev/null 2>&1 || true
        fi
        rm -rf "$d" 2>/dev/null || true
    done
}
trap cleanup_all EXIT

# ---------- assertions ----------

assert_eq() {
    local want="$1" got="$2" msg="${3:-values differ}"
    if [[ "$want" == "$got" ]]; then return 0; fi
    printf "    ${T_RED}assertion failed:${T_RESET} %s\n" "$msg" >&2
    printf "      want: ${T_DIM}%s${T_RESET}\n" "$want" >&2
    printf "      got:  ${T_DIM}%s${T_RESET}\n" "$got"   >&2
    return 1
}

assert_contains() {
    local hay="$1" needle="$2" msg="${3:-substring not found}"
    if [[ "$hay" == *"$needle"* ]]; then return 0; fi
    printf "    ${T_RED}assertion failed:${T_RESET} %s\n" "$msg" >&2
    printf "      looking for: ${T_DIM}%s${T_RESET}\n" "$needle" >&2
    printf "      in:          ${T_DIM}%s${T_RESET}\n" "${hay:0:400}" >&2
    return 1
}

assert_not_contains() {
    local hay="$1" needle="$2" msg="${3:-unwanted substring present}"
    if [[ "$hay" != *"$needle"* ]]; then return 0; fi
    printf "    ${T_RED}assertion failed:${T_RESET} %s\n" "$msg" >&2
    printf "      unwanted: ${T_DIM}%s${T_RESET}\n" "$needle" >&2
    return 1
}

assert_file_exists() {
    local f="$1" msg="${2:-file should exist: $1}"
    [[ -f "$f" ]] && return 0
    printf "    ${T_RED}assertion failed:${T_RESET} %s\n" "$msg" >&2
    return 1
}

assert_dir_exists() {
    local d="$1" msg="${2:-directory should exist: $1}"
    [[ -d "$d" ]] && return 0
    printf "    ${T_RED}assertion failed:${T_RESET} %s\n" "$msg" >&2
    return 1
}

assert_exit_code() {
    local want="$1" got="$2" msg="${3:-exit code mismatch}"
    if [[ "$want" == "$got" ]]; then return 0; fi
    printf "    ${T_RED}assertion failed:${T_RESET} %s (want=%s got=%s)\n" "$msg" "$want" "$got" >&2
    return 1
}

# ---------- test runner ----------

run_test() {
    local name="$1"
    TESTS_RUN=$((TESTS_RUN + 1))
    printf "  %s " "$name"
    # each test runs in a subshell so it can't leak cd/env changes
    if ( set -e; "$name" ) 2>&1 | sed 's/^/      /'; then
        # last pipe masks the subshell's status; we need PIPESTATUS
        local rc=${PIPESTATUS[0]}
        if (( rc == 0 )); then
            printf "${T_GREEN}✓${T_RESET}\n"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        fi
    fi
    printf "${T_RED}✗${T_RESET}\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_NAMES+=("$name")
    return 0  # keep going even if a test fails
}

summary() {
    printf "\n"
    if (( TESTS_FAILED == 0 )); then
        printf "${T_BOLD}${T_GREEN}all %d tests passed${T_RESET}\n" "$TESTS_RUN"
        return 0
    fi
    printf "${T_BOLD}${T_RED}%d of %d tests failed${T_RESET}\n" "$TESTS_FAILED" "$TESTS_RUN"
    for n in "${FAILED_NAMES[@]}"; do
        printf "  ${T_RED}✗${T_RESET} %s\n" "$n"
    done
    return 1
}
