#!/usr/bin/env bash
# Release Orchestrator: centralized local checks for all Examifyr repos.
# Runs from examifyr-infra. Requires sibling folders: examifyr-backend, examifyr-frontend.
# Usage: ./scripts/release-orchestrate.sh [--dry-run] [--base-url URL]
# Flags: --dry-run (print only, no changes), --base-url (default http://127.0.0.1:8000)

set -euo pipefail

INFRA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$INFRA_ROOT/.." && pwd)"
BACKEND_ROOT="${PROJECT_ROOT}/examifyr-backend"
FRONTEND_ROOT="${PROJECT_ROOT}/examifyr-frontend"
BASE_URL="http://127.0.0.1:8000"
DRY_RUN="false"

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN="true"; shift ;;
    --base-url) [[ -n "${2:-}" ]] || err "--base-url requires a value"; BASE_URL="$2"; shift 2 ;;
    *) echo "Unknown flag: $1. Use --dry-run or --base-url URL" >&2; exit 1 ;;
  esac
done

log() { printf '%s\n' "$1"; }
err() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

log "=== Examifyr Release Orchestrator ==="
log ""

if [[ "$DRY_RUN" == "true" ]]; then
  log "DRY RUN: No changes will be made."
  log ""
fi

# a) Verify required repo paths exist
log "Checking repo paths..."
if [[ ! -d "$BACKEND_ROOT" ]]; then
  err "examifyr-backend not found at $BACKEND_ROOT. Clone it as sibling to examifyr-infra."
fi
if [[ ! -d "$FRONTEND_ROOT" ]]; then
  err "examifyr-frontend not found at $FRONTEND_ROOT. Clone it as sibling to examifyr-infra."
fi
log "  backend:  $BACKEND_ROOT"
log "  frontend: $FRONTEND_ROOT"
log "  infra:    $INFRA_ROOT"
log ""

# b) For each repo: ensure clean working tree
log "Checking working trees..."
for name in backend frontend infra; do
  case "$name" in
    backend)  dir="$BACKEND_ROOT" ;;
    frontend) dir="$FRONTEND_ROOT" ;;
    infra)    dir="$INFRA_ROOT" ;;
  esac
  if [[ -n "$(cd "$dir" && git status --porcelain)" ]]; then
    err "$name has uncommitted changes. Resolve first:
  cd $dir
  git status
  Then: commit, stash, or discard changes."
  fi
  log "  $name: clean"
done
log ""

# c) Ensure origin remote and fetch
log "Fetching from origin..."
for name in backend frontend infra; do
  case "$name" in
    backend)  dir="$BACKEND_ROOT" ;;
    frontend) dir="$FRONTEND_ROOT" ;;
    infra)    dir="$INFRA_ROOT" ;;
  esac
  if ! (cd "$dir" && git remote get-url origin &>/dev/null); then
    err "$name has no origin remote. Add it: cd $dir && git remote add origin <url>"
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    log "  $name: would fetch"
  else
    (cd "$dir" && git fetch origin) || err "Failed to fetch $name"
    log "  $name: fetched"
  fi
done
log ""

# d) Ensure each repo on main and up to date (or offer to create feature branch)
log "Checking branches..."
not_on_main=()
for name in backend frontend infra; do
  case "$name" in
    backend)  dir="$BACKEND_ROOT" ;;
    frontend) dir="$FRONTEND_ROOT" ;;
    infra)    dir="$INFRA_ROOT" ;;
  esac
  branch="$(cd "$dir" && git rev-parse --abbrev-ref HEAD)"
  if [[ "$branch" != "main" && "$branch" != "master" ]]; then
    not_on_main+=("$name:$branch")
  fi
done

if [[ ${#not_on_main[@]} -gt 0 ]]; then
  log "Some repos are not on main:"
  printf '  %s\n' "${not_on_main[@]}"
  if [[ "$DRY_RUN" == "true" ]]; then
    log "  (Dry-run: would prompt to create feature branches)"
  else
    printf "Create feature branches from main for these repos? (y/n): "
    read -r ans
    case "${ans:-}" in
      [yY]|[yY][eE][sS])
        for entry in "${not_on_main[@]}"; do
          name="${entry%%:*}"
          case "$name" in
            backend)  dir="$BACKEND_ROOT" ;;
            frontend) dir="$FRONTEND_ROOT" ;;
            infra)    dir="$INFRA_ROOT" ;;
          esac
          (cd "$dir" && git checkout main 2>/dev/null || git checkout master) || true
          (cd "$dir" && git pull --ff-only origin main 2>/dev/null || git pull --ff-only origin master) || true
          new_branch="feature/release-${name}-$(date +%Y%m%d-%H%M)"
          (cd "$dir" && git checkout -b "$new_branch")
          log "  $name: created $new_branch"
        done
        ;;
      *)
        err "Exiting. Switch repos to main manually, or re-run and choose y."
        ;;
    esac
  fi
  log ""
fi

if [[ "$DRY_RUN" != "true" ]]; then
  # Sync main
  for name in backend frontend infra; do
    case "$name" in
      backend)  dir="$BACKEND_ROOT" ;;
      frontend) dir="$FRONTEND_ROOT" ;;
      infra)    dir="$INFRA_ROOT" ;;
    esac
    branch="$(cd "$dir" && git rev-parse --abbrev-ref HEAD)"
    if [[ "$branch" == "main" || "$branch" == "master" ]]; then
      (cd "$dir" && git pull --ff-only "origin" "$branch") || err "Failed to pull $name"
    fi
  done
  log "Main branches synced."
  log ""
fi

# e) Run Step 2.3 tests per repo
log "=== Step 2.3: Running ./scripts/test.sh ==="
backend_ok="false"
frontend_ok="false"
infra_ok="false"

if [[ "$DRY_RUN" == "true" ]]; then
  log "  backend:  Would run ./scripts/test.sh"
  log "  frontend: Would run ./scripts/test.sh"
  log "  infra:    Would run ./scripts/test.sh"
  backend_ok="true"
  frontend_ok="true"
  infra_ok="true"
else
  log "  backend..."
  if (cd "$BACKEND_ROOT" && chmod +x scripts/test.sh 2>/dev/null; ./scripts/test.sh); then
    backend_ok="true"
    log "  backend:  PASS"
  else
    log "  backend:  FAIL"
  fi

  log "  frontend..."
  if (cd "$FRONTEND_ROOT" && chmod +x scripts/test.sh 2>/dev/null; ./scripts/test.sh); then
    frontend_ok="true"
    log "  frontend: PASS"
  else
    log "  frontend: FAIL"
  fi

  log "  infra..."
  if (cd "$INFRA_ROOT" && chmod +x scripts/test.sh 2>/dev/null; ./scripts/test.sh); then
    infra_ok="true"
    log "  infra:    PASS"
  else
    log "  infra:    FAIL"
  fi
fi
log ""

# f) Backend runtime smoke tests
log "=== Backend Runtime Smoke Tests ==="
BASE_URL="${BASE_URL%/}"
if [[ "$DRY_RUN" == "true" ]]; then
  log "  Would check $BASE_URL/health"
  log "  Would run: BASE_URL=$BASE_URL ./scripts/runtime-smoke-test.sh"
  backend_smoke_ok="true"
else
  # Check if backend is reachable
  if ! curl -sS --max-time 3 -o /dev/null -w "%{http_code}" "$BASE_URL/health" 2>/dev/null | grep -q 200; then
    err "Backend not reachable at $BASE_URL.
Start backend first:
  cd $BACKEND_ROOT && ./start-local.sh"
  fi
  log "  Backend reachable at $BASE_URL"
  if (cd "$BACKEND_ROOT" && chmod +x scripts/runtime-smoke-test.sh 2>/dev/null; BASE_URL="$BASE_URL" ./scripts/runtime-smoke-test.sh); then
    backend_smoke_ok="true"
    log "  Runtime smoke: PASS"
  else
    backend_smoke_ok="false"
    log "  Runtime smoke: FAIL"
  fi
fi
log ""

# g) Final summary
log "=== Summary ==="
if [[ "$DRY_RUN" == "true" ]]; then
  log "DRY RUN complete. No changes made."
  log "Run without --dry-run to execute checks."
else
  log "Backend  Step 2.3:    $([[ "$backend_ok" == true ]] && echo PASS || echo FAIL)"
  log "Frontend Step 2.3:    $([[ "$frontend_ok" == true ]] && echo PASS || echo FAIL)"
  log "Infra    Step 2.3:    $([[ "$infra_ok" == true ]] && echo PASS || echo FAIL)"
  log "Backend  Runtime:    $([[ "${backend_smoke_ok:-false}" == true ]] && echo PASS || echo FAIL)"
  if [[ "$backend_ok" != "true" || "$frontend_ok" != "true" || "$infra_ok" != "true" || "${backend_smoke_ok:-false}" != "true" ]]; then
    log ""
    log "Some checks failed. Fix failures before opening PRs."
    exit 1
  fi
  log ""
  log "All checks passed. Next:"
  log "  1. Open PRs per repo (use scripts/release-ready.sh in each repo)"
  log "  2. CI must be green before applying release label"
  log "  3. This script does NOT deploy."
fi
log ""
