#!/usr/bin/env bash
# Git helpers: sync/rebase, clean tree check, branch check, safe push

set -euo pipefail

log() { printf '%s\n' "$1"; }
err() { printf 'ERROR: %s\n' "$1" >&2; }

# Check repo is clean (no uncommitted changes)
git_assert_clean() {
  if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    err "Repository has uncommitted changes:"
    git status -s
    return 1
  fi
  if [[ -n "$(git status --porcelain)" ]]; then
    err "Repository has uncommitted or untracked files:"
    git status -s
    return 1
  fi
  return 0
}

# Ensure current branch matches prefix (e.g. feature/*)
git_assert_branch() {
  local prefix="$1"
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "$branch" != ${prefix}* ]]; then
    err "Current branch '$branch' does not match '$prefix*'. Switch with: git checkout -b $prefix/your-name"
    return 1
  fi
  return 0
}

# Fetch and rebase onto origin/main (no merge)
git_sync_rebase() {
  log "Fetching origin..."
  git fetch origin
  log "Rebasing onto origin/main..."
  git rebase origin/main
}

# Safe push (only after tests pass)
git_push_branch() {
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD)"
  log "Pushing branch $branch to origin..."
  git push -u origin "$branch"
}
