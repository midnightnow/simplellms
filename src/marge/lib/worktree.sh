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
    local slug; slug=$(jq -r '.slug // "epic"' "$MARGE_DIR/epic.json" 2>/dev/null || echo "epic")
    [[ -z "$slug" || "$slug" == "null" ]] && slug="epic"
    printf "marge/%s/%s" "$slug" "$id"
}

worktree_epic_branch() {
    local slug; slug=$(jq -r '.slug // "epic"' "$MARGE_DIR/epic.json" 2>/dev/null || echo "epic")
    [[ -z "$slug" || "$slug" == "null" ]] && slug="epic"
    printf "marge/%s/epic" "$slug"
}

worktree_ensure_epic() {
    local path; path="$MARGE_DIR/worktrees/epic"
    local branch; branch="$(worktree_epic_branch)"
    local root; root="$(git rev-parse --show-toplevel)"
    local base; base="$(cat "$MARGE_DIR/.base-ref" 2>/dev/null || git rev-parse HEAD)"

    if [[ -d "$path" ]]; then
        printf "%s\n" "$path"
        return 0
    fi

    if git -C "$root" show-ref --verify --quiet "refs/heads/$branch"; then
        git -C "$root" worktree add "$path" "$branch" >/dev/null 2>&1 \
            || die "failed to add epic worktree at $path on existing branch $branch"
    else
        git -C "$root" worktree add -b "$branch" "$path" "$base" >/dev/null 2>&1 \
            || die "failed to add epic worktree at $path from $base"
    fi
    printf "%s\n" "$path"
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

    # Ensure the epic integration branch and worktree exist
    worktree_ensure_epic >/dev/null 2>&1 || true

    local epic_branch; epic_branch="$(worktree_epic_branch)"
    local base; base="$(cat "$MARGE_DIR/.base-ref" 2>/dev/null || git rev-parse HEAD)"

    local start_point="$base"
    if git -C "$root" show-ref --verify --quiet "refs/heads/$epic_branch"; then
        start_point="$epic_branch"
    fi

    if git -C "$root" show-ref --verify --quiet "refs/heads/$branch"; then
        git -C "$root" worktree add "$path" "$branch" >/dev/null 2>&1 \
            || die "failed to add worktree at $path on existing branch $branch"
    else
        git -C "$root" worktree add -b "$branch" "$path" "$start_point" >/dev/null 2>&1 \
            || die "failed to add worktree at $path from $start_point"
    fi
    git -C "$path" rev-parse HEAD > "$path/.ticket-base" 2>/dev/null || true
    printf "%s\n" "$path"
}

worktree_commit() {
    local id="$1"
    local title="${2:-$id}"
    local path; path="$(worktree_path "$id")"
    [[ -d "$path" ]] || return 0

    git -C "$path" add -A
    if ! git -C "$path" diff --cached --quiet 2>/dev/null; then
        git -C "$path" \
            -c user.name="M.A.R.G.E. Orchestrator" \
            -c user.email="marge@simplellms.local" \
            commit -m "feat($id): $title" >/dev/null 2>&1 || true
    fi
}

worktree_merge_into_epic() {
    local id="$1"
    local title="${2:-$id}"
    local epic_path; epic_path="$(worktree_ensure_epic)"
    local branch; branch="$(worktree_branch "$id")"

    if ! git -C "$epic_path" \
        -c user.name="M.A.R.G.E. Orchestrator" \
        -c user.email="marge@simplellms.local" \
        merge --no-ff "$branch" -m "merge($id): integrate $id into epic" >/dev/null 2>&1; then
        git -C "$epic_path" merge --abort >/dev/null 2>&1 || true
        return 1
    fi
    return 0
}

worktree_reset() {
    local id="$1"
    local path; path="$(worktree_path "$id")"
    [[ -d "$path" ]] || return 0
    local reset_target; reset_target="$(cat "$path/.ticket-base" 2>/dev/null || cat "$MARGE_DIR/.base-ref" 2>/dev/null || echo "HEAD")"
    git -C "$path" reset --hard "$reset_target" >/dev/null 2>&1 || true
    git -C "$path" clean -fd >/dev/null 2>&1 || true
}

worktree_diff() {
    local id="$1"
    local path; path="$(worktree_path "$id")"
    [[ -d "$path" ]] || { echo ""; return 0; }
    local t_base; t_base="$(cat "$path/.ticket-base" 2>/dev/null || cat "$MARGE_DIR/.base-ref" 2>/dev/null || echo "HEAD")"
    # `git add -N` marks every untracked file as "intent to add" without
    # staging content, so subsequent `git diff` reports them as new-file
    # additions. Without this, scaffolding tickets (which create new files
    # the agent was told NOT to commit) produce an empty diff and review
    # silently marks the ticket failed.
    git -C "$path" add -N -A . >/dev/null 2>&1 || true
    git -C "$path" diff "$t_base"...HEAD 2>/dev/null
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
