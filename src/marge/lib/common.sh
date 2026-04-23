#!/usr/bin/env bash
# Shared utilities for M.A.R.G.E. orchestrator.
# Sourced by every other script in src/marge/.

set -euo pipefail

MARGE_VERSION="0.1.0"

: "${MARGE_ROOT:=.marge}"
: "${MARGE_AGENT:=claude}"
: "${MARGE_CONCURRENCY:=1}"
: "${MARGE_MAX_PIVOTS:=1}"
: "${MARGE_COLOR:=auto}"

if [[ "$MARGE_COLOR" == "auto" ]]; then
    if [[ -t 1 ]]; then MARGE_COLOR=1; else MARGE_COLOR=0; fi
fi

if [[ "$MARGE_COLOR" == "1" ]]; then
    C_RESET='\033[0m'
    C_DIM='\033[2m'
    C_BOLD='\033[1m'
    C_CYAN='\033[0;36m'
    C_GREEN='\033[0;32m'
    C_YELLOW='\033[1;33m'
    C_RED='\033[0;31m'
    C_MAGENTA='\033[0;35m'
    C_BLUE='\033[0;34m'
else
    C_RESET='' C_DIM='' C_BOLD='' C_CYAN='' C_GREEN='' C_YELLOW='' C_RED='' C_MAGENTA='' C_BLUE=''
fi

_ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

log()   { printf "%b[marge]%b %s\n"            "$C_CYAN"    "$C_RESET" "$*" >&2; }
info()  { printf "%b[marge]%b %s\n"            "$C_BLUE"    "$C_RESET" "$*" >&2; }
ok()    { printf "%b[marge]%b %b%s%b\n"        "$C_GREEN"   "$C_RESET" "$C_GREEN" "$*" "$C_RESET" >&2; }
warn()  { printf "%b[marge]%b %b%s%b\n"        "$C_YELLOW"  "$C_RESET" "$C_YELLOW" "$*" "$C_RESET" >&2; }
err()   { printf "%b[marge]%b %b%s%b\n"        "$C_RED"     "$C_RESET" "$C_RED" "$*" "$C_RESET" >&2; }
step()  { printf "\n%b▸ %s%b\n"               "$C_BOLD$C_MAGENTA" "$*" "$C_RESET" >&2; }
dim()   { printf "%b%s%b\n"                   "$C_DIM"     "$*"       "$C_RESET" >&2; }

die() { err "$*"; exit 1; }

require_cmd() {
    local missing=()
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if (( ${#missing[@]} > 0 )); then
        die "missing required commands: ${missing[*]}"
    fi
}

require_git_repo() {
    git rev-parse --show-toplevel >/dev/null 2>&1 \
        || die "not inside a git repository. run 'git init' first."
}

slugify() {
    # stdin → lowercase, non-alnum → '-', collapse, trim
    tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' | cut -c1-40
}

# absolute path of the directory containing the calling script
script_dir() {
    local src="${BASH_SOURCE[1]}"
    cd "$(dirname "$src")" && pwd
}

MARGE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARGE_SRC_DIR="$(dirname "$MARGE_LIB_DIR")"
export MARGE_LIB_DIR MARGE_SRC_DIR
