#!/usr/bin/env bash
# Release-core: strict release automation
# Invoked from sibling repos via scripts/release-ready.sh
# Usage: release-core.sh <repo_name> [--dry-run]
# repo_name: backend|frontend|infra
# Env: BACKEND_SMOKE=1 to run backend runtime smoke (backend only)
# Env: DRY_RUN=true or arg --dry-run for non-interactive analysis

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
REPO_NAME="${1:-}"
BACKEND_SMOKE="${BACKEND_SMOKE:-0}"
BASE_URL="${BASE_URL:-http://127.0.0.1:8000}"

# Parse DRY_RUN: from env or from args
DRY_RUN="${DRY_RUN:-false}"
for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then
    DRY_RUN="true"
    break
  fi
done

# shellcheck source=tools/lib/git.sh
source "${LIB_DIR}/git.sh"
# shellcheck source=tools/lib/github.sh
source "${LIB_DIR}/github.sh"

# Override err to exit (libs only print)
err() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

if [[ -z "$REPO_NAME" ]]; then
  err "Usage: release-core.sh <repo_name>. repo_name: backend|frontend|infra. Use BACKEND_SMOKE=1 for backend runtime smoke."
fi

# Must run from the target repo root (called from examifyr-backend, examifyr-frontend, or examifyr-infra)
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || err "Not in a git repository"
cd "$REPO_ROOT"

if [[ "$DRY_RUN" == "true" ]]; then
  BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  echo "=== DRY RUN MODE ==="
  echo "Current branch: $BRANCH"
  echo "Repo: $REPO_NAME"
  echo ""
  echo "Would run: git fetch origin && git rebase origin/main"
  echo "Would run: ./scripts/test.sh (Step 2.3)"
  if [[ "$REPO_NAME" == "backend" && "$BACKEND_SMOKE" == "1" && -f "./scripts/runtime-smoke-test.sh" ]]; then
    echo "Would run: runtime smoke test against ${BASE_URL}"
  fi
  echo "Would push branch to origin"
  echo "Would find or create PR to main"
  echo "Would check CI status (require green)"
  echo "Would prompt: Apply release label?"
  echo "Would print next steps (Claude review, Gemini QA, merge)"
  echo ""
  echo "No git state was modified."
  exit 0
fi

# 1. Assert repo is clean
log "Checking repo is clean..."
git_assert_clean || err "Repo is dirty. Commit or stash changes, then retry."

# 2. Ensure current branch is feature/*
log "Checking branch..."
git_assert_branch "feature/" || err "Switch to a feature branch first: git checkout -b feature/your-branch-name"

# 3. Fetch + rebase onto origin/main
log "Syncing with origin/main..."
git_sync_rebase

# 4. Run repo's ./scripts/test.sh
log "Running ./scripts/test.sh..."
if [[ ! -f "./scripts/test.sh" ]]; then
  err "scripts/test.sh not found"
fi
chmod +x ./scripts/test.sh
./scripts/test.sh

# 5. If backend and BACKEND_SMOKE=1 and runtime-smoke-test.sh exists, run it
if [[ "$REPO_NAME" == "backend" && "$BACKEND_SMOKE" == "1" && -f "./scripts/runtime-smoke-test.sh" ]]; then
  log "Running backend runtime smoke test against ${BASE_URL}..."
  chmod +x ./scripts/runtime-smoke-test.sh
  BASE_URL="$BASE_URL" ./scripts/runtime-smoke-test.sh
fi

# 6. Push branch to origin
log "Tests passed. Pushing branch..."
git_push_branch

# 7. Find or create PR to main
PR_NUM="$(github_pr_number)"
if [[ -z "$PR_NUM" ]]; then
  log "Creating PR to main..."
  gh pr create --base main --fill --body "## Release checklist
- [ ] Local Step 2.3 passed (\`./scripts/test.sh\`)
- [ ] Backend runtime smoke passed (backend only)
- [ ] CI green
- [ ] Claude approved
- [ ] Gemini approved
- [ ] If release: apply \`release\` label only after CI green"
  PR_NUM="$(github_pr_number)"
  if [[ -z "$PR_NUM" ]]; then
    err "Failed to create or detect PR"
  fi
  log "Created PR #$PR_NUM"
else
  log "Using existing PR #$PR_NUM"
fi

# 8. Check CI status - require green before proceeding
log "Checking CI status..."
if ! github_pr_checks_green "$PR_NUM"; then
  err "CI is not green. Fix failing checks before applying release label. Do NOT apply release label."
fi

# 9. Ask terminal yes/no: Apply release label?
log "CI is green."
printf 'Apply release label to this PR now? [y/N]: '
read -r ans
if [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]]; then
  github_pr_add_label "$PR_NUM" "release"
  log "Applied label 'release' to PR #$PR_NUM"
else
  log "Skipped applying release label."
fi

# 10. Print final next steps
log ""
log "=== Next steps ==="
log "1. Claude code review"
log "2. Gemini QA approval"
log "3. Merge PR to main"
log "4. (If release label applied) GitHub Action will create tag + release notes after merge"
log ""
