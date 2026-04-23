#!/usr/bin/env bash
# Git worktree management for parallel ticket execution.
#
# Each in-flight ticket gets its own worktree under .marge/worktrees/<ID>/
# on a branch like marge/<epic-slug>/<id>. On success the branch is left
# for the user to merge (we never auto-merge). On pivot, the branch is
# reset and reused.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

worktree_path() {
    local id="$1"
    printf "%s/worktrees/%s" "$MARGE_DIR" "$id"
}

worktree_branch() {
    local id="$1"
    local slug; slug=$(jq -r '.slug // "epic"' "$MARGE_DIR/epic.json")
    printf "marge/%s/%s" "$slug" "$id"
}

worktree_ensure() {
    local id="$1"
    local path; path="$(worktree_path "$id")"
    local branch; branch="$(worktree_branch "$id")"
    local root; root="$(git rev-parse --show-toplevel)"

    if [[ -d "$path" ]]; then
        printf "%s\n" "$path"
        return 0
    fi

    # base branch: whatever the user is currently on when marge starts
    local base; base="$(cat "$MARGE_DIR/.base-ref" 2>/dev/null || git rev-parse HEAD)"

    if git -C "$root" show-ref --verify --quiet "refs/heads/$branch"; then
        git -C "$root" worktree add "$path" "$branch" >/dev/null 2>&1 \
            || die "failed to add worktree at $path on existing branch $branch"
    else
        git -C "$root" worktree add -b "$branch" "$path" "$base" >/dev/null 2>&1 \
            || die "failed to add worktree at $path from $base"
    fi
    printf "%s\n" "$path"
}

worktree_reset() {
    local id="$1"
    local path; path="$(worktree_path "$id")"
    [[ -d "$path" ]] || return 0
    local base; base="$(cat "$MARGE_DIR/.base-ref")"
    git -C "$path" reset --hard "$base" >/dev/null 2>&1 || true
    git -C "$path" clean -fd >/dev/null 2>&1 || true
}

worktree_diff() {
    local id="$1"
    local path; path="$(worktree_path "$id")"
    local base; base="$(cat "$MARGE_DIR/.base-ref")"
    [[ -d "$path" ]] || { echo ""; return 0; }
    git -C "$path" diff "$base"...HEAD 2>/dev/null
    git -C "$path" diff 2>/dev/null
}

worktree_record_base() {
    git rev-parse HEAD > "$MARGE_DIR/.base-ref"
}

worktree_prune() {
    local id="$1"
    local path; path="$(worktree_path "$id")"
    local root; root="$(git rev-parse --show-toplevel)"
    [[ -d "$path" ]] || return 0
    git -C "$root" worktree remove --force "$path" >/dev/null 2>&1 || rm -rf "$path"
}

worktree_list() {
    git worktree list 2>/dev/null | grep -F "$MARGE_DIR/worktrees/" || true
}
