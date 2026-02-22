#!/usr/bin/env bash
# GitHub helpers: PR number, CI status, apply label

set -euo pipefail

log() { printf '%s\n' "$1"; }
err() { printf 'ERROR: %s\n' "$1" >&2; }

# Get PR number for current branch (or empty if none)
github_pr_number() {
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD)"
  gh pr list --head "$branch" --base main --json number -q '.[0].number // empty' 2>/dev/null || echo ""
}

# Check if PR has all checks green via gh pr view statusCheckRollup
# Returns 0 if green or no checks, 1 if failing
github_pr_checks_green() {
  local pr_num="$1"
  if [[ -z "$pr_num" ]]; then
    err "No PR number provided"
    return 1
  fi

  local pr_status
  pr_status="$(gh pr view "$pr_num" --json statusCheckRollup -q '.statusCheckRollup // []' 2>/dev/null)"
  if [[ -z "$pr_status" || "$pr_status" == "[]" ]]; then
    # No checks configured, consider green
    return 0
  fi

  # conclusion: SUCCESS = pass, FAILURE/CANCELLED/etc = fail, null = pending
  local failed
  failed="$(echo "$pr_status" | jq -r '[.[] | select(.conclusion != null and .conclusion != "SUCCESS")] | length' 2>/dev/null || echo "0")"
  if [[ "$failed" != "0" ]]; then
    err "PR has failing checks:"
    echo "$pr_status" | jq -r '.[] | select(.conclusion != null and .conclusion != "SUCCESS") | "  - \(.name): \(.conclusion)"' 2>/dev/null || true
    return 1
  fi

  local pending
  pending="$(echo "$pr_status" | jq -r '[.[] | select(.conclusion == null)] | length' 2>/dev/null || echo "0")"
  if [[ "$pending" != "0" ]]; then
    err "PR has pending checks (wait for CI to complete):"
    echo "$pr_status" | jq -r '.[] | select(.conclusion == null) | "  - \(.name): pending"' 2>/dev/null || true
    return 1
  fi

  return 0
}

# Apply label to PR
github_pr_add_label() {
  local pr_num="$1"
  local label="$2"
  if [[ -z "$pr_num" ]]; then
    err "No PR number provided"
    return 1
  fi
  gh pr edit "$pr_num" --add-label "$label"
}
