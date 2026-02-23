#!/usr/bin/env bash
# Federated SemVer Release Orchestrator: infra orchestrates, each repo owns VERSION + semver-bump.sh.
# Runs from examifyr-infra. Requires sibling folders: examifyr-backend, examifyr-frontend.
# Usage: ./scripts/release-orchestrate.sh [--dry-run] [--apply] [--yes] [--base-url URL]
# Default: --dry-run. --apply requires approval unless --yes.

set -euo pipefail

log() { printf '%s\n' "$1"; }
err() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

INFRA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$INFRA_ROOT/.." && pwd)"
BACKEND_ROOT="${PROJECT_ROOT}/examifyr-backend"
FRONTEND_ROOT="${PROJECT_ROOT}/examifyr-frontend"
BASE_URL="http://127.0.0.1:8000"
DRY_RUN="true"
APPLY="false"
YES="false"

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN="true"; shift ;;
    --apply)   APPLY="true"; DRY_RUN="false"; shift ;;
    --yes)     YES="true"; shift ;;
    --base-url) [[ -n "${2:-}" ]] || err "--base-url requires a value"; BASE_URL="$2"; shift 2 ;;
    *) err "Unknown flag: $1. Use --dry-run, --apply, --yes, or --base-url URL" ;;
  esac
done

log "=== Federated SemVer Release Orchestrator ==="
log ""

if [[ "$DRY_RUN" == "true" ]]; then
  log "Mode: --dry-run (no changes)"
else
  log "Mode: --apply"
fi
log ""

# --- Pre-flight: repo paths ---
log "Pre-flight: repo paths..."
if [[ ! -d "$BACKEND_ROOT" ]]; then
  err "examifyr-backend not found at $BACKEND_ROOT. Clone as sibling to examifyr-infra."
fi
if [[ ! -d "$FRONTEND_ROOT" ]]; then
  err "examifyr-frontend not found at $FRONTEND_ROOT. Clone as sibling to examifyr-infra."
fi
log "  backend:  $BACKEND_ROOT"
log "  frontend: $FRONTEND_ROOT"
log "  infra:    $INFRA_ROOT"
log ""

# --- Pre-flight: semver-bump.sh + VERSION ---
log "Pre-flight: semver tools..."
for name in backend frontend infra; do
  case "$name" in
    backend)  dir="$BACKEND_ROOT" ;;
    frontend) dir="$FRONTEND_ROOT" ;;
    infra)    dir="$INFRA_ROOT" ;;
  esac
  if [[ ! -f "$dir/scripts/semver-bump.sh" ]]; then
    err "$name missing scripts/semver-bump.sh"
  fi
  if [[ ! -f "$dir/VERSION" ]]; then
    err "$name missing VERSION file"
  fi
  log "  $name: OK"
done
log ""

# --- Pre-flight: clean working tree ---
log "Pre-flight: working trees..."
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
  Then: commit, stash, or discard."
  fi
  log "  $name: clean"
done
log ""

# --- Pre-flight: branch allowed (main, master, feature/*) ---
log "Pre-flight: branches..."
for name in backend frontend infra; do
  case "$name" in
    backend)  dir="$BACKEND_ROOT" ;;
    frontend) dir="$FRONTEND_ROOT" ;;
    infra)    dir="$INFRA_ROOT" ;;
  esac
  branch="$(cd "$dir" && git rev-parse --abbrev-ref HEAD)"
  if [[ "$branch" != "main" && "$branch" != "master" && "$branch" != feature/* ]]; then
    err "$name is on branch '$branch'. Allowed: main, master, or feature/*"
  fi
  log "  $name: $branch"
done
log ""

# --- Pre-flight: fetch ---
log "Pre-flight: fetch origin..."
for name in backend frontend infra; do
  case "$name" in
    backend)  dir="$BACKEND_ROOT" ;;
    frontend) dir="$FRONTEND_ROOT" ;;
    infra)    dir="$INFRA_ROOT" ;;
  esac
  if ! (cd "$dir" && git remote get-url origin &>/dev/null); then
    err "$name has no origin remote"
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    log "  $name: would fetch"
  else
    (cd "$dir" && git fetch origin) || err "Failed to fetch $name"
    log "  $name: fetched"
  fi
done
log ""

# --- Print branch + short SHA per repo ---
log "Repo state:"
for name in backend frontend infra; do
  case "$name" in
    backend)  dir="$BACKEND_ROOT" ;;
    frontend) dir="$FRONTEND_ROOT" ;;
    infra)    dir="$INFRA_ROOT" ;;
  esac
  branch="$(cd "$dir" && git rev-parse --abbrev-ref HEAD)"
  sha="$(cd "$dir" && git rev-parse --short HEAD)"
  log "  $name: $branch @ $sha"
done
log ""

# --- Semver dry-run per repo, build release plan ---
log "=== Release Plan (semver-bump --dry-run) ==="
backend_bump="noop"
frontend_bump="noop"
infra_bump="noop"

for name in backend frontend infra; do
  case "$name" in
    backend)  dir="$BACKEND_ROOT" ;;
    frontend) dir="$FRONTEND_ROOT" ;;
    infra)    dir="$INFRA_ROOT" ;;
  esac
  out="$(cd "$dir" && chmod +x scripts/semver-bump.sh 2>/dev/null; ./scripts/semver-bump.sh --dry-run 2>&1)" || true
  if [[ "$out" == *"No version bump required."* ]]; then
    eval "${name}_bump=\"noop\""
    log "  $name: noop"
  else
    current="$(echo "$out" | grep -E '^Current version:' | sed 's/Current version:[[:space:]]*//')"
    bump_type="$(echo "$out" | grep -E '^Bump type:' | sed 's/Bump type:[[:space:]]*//')"
    next="$(echo "$out" | grep -E '^Next version:' | sed 's/Next version:[[:space:]]*//')"
    eval "${name}_bump=\"$bump_type\""
    log "  $name: bump $bump_type ${current} -> ${next} (tag v${next})"
  fi
done
log ""

# --- All noop check ---
if [[ "$backend_bump" == "noop" && "$frontend_bump" == "noop" && "$infra_bump" == "noop" ]]; then
  log "No release required."
  exit 0
fi

# --- Dry-run ends here ---
if [[ "$DRY_RUN" == "true" ]]; then
  log "Dry-run complete. Run with --apply to execute."
  exit 0
fi

# --- Apply mode: run tests ---
log "=== Testing gates ==="
log "Step 2.3: ./scripts/test.sh"
for name in backend frontend infra; do
  case "$name" in
    backend)  dir="$BACKEND_ROOT" ;;
    frontend) dir="$FRONTEND_ROOT" ;;
    infra)    dir="$INFRA_ROOT" ;;
  esac
  log "  $name..."
  (cd "$dir" && ./scripts/test.sh) || err "$name scripts/test.sh failed"
  log "  $name: PASS"
done
log ""

# --- Runtime smoke if backend in plan ---
if [[ "$backend_bump" != "noop" ]]; then
  log "Backend runtime smoke (BASE_URL=${BASE_URL})..."
  if ! curl -sS --max-time 3 -o /dev/null -w "%{http_code}" "${BASE_URL%/}/health" 2>/dev/null | grep -q 200; then
    err "Backend not reachable at ${BASE_URL}.
Start backend first:
  cd $BACKEND_ROOT && ./start-local.sh"
  fi
  (cd "$BACKEND_ROOT" && BASE_URL="${BASE_URL%/}" ./scripts/runtime-smoke-test.sh) || err "Backend runtime smoke failed"
  log "  smoke: PASS"
  log ""
fi

# --- Approval ---
if [[ "$YES" != "true" ]]; then
  printf "Apply release (run semver-bump --apply, push tags)? (y/n): "
  read -r ans
  case "${ans:-}" in
    [yY]|[yY][eE][sS]) ;;
    *) err "Aborted." ;;
  esac
fi

# --- Apply semver-bump --apply per repo with bump ---
log "=== Applying releases ==="
for name in backend frontend infra; do
  bump_val=""
  case "$name" in
    backend)  dir="$BACKEND_ROOT"; bump_val="$backend_bump" ;;
    frontend) dir="$FRONTEND_ROOT"; bump_val="$frontend_bump" ;;
    infra)    dir="$INFRA_ROOT"; bump_val="$infra_bump" ;;
  esac
  if [[ "$bump_val" != "noop" ]]; then
    log "  $name..."
    (cd "$dir" && ./scripts/semver-bump.sh --apply) || err "$name semver-bump --apply failed"
    log "  $name: applied"
  fi
done
log ""

# --- Push tags only ---
log "Pushing tags..."
for name in backend frontend infra; do
  bump_val=""
  case "$name" in
    backend)  bump_val="$backend_bump" ;;
    frontend) bump_val="$frontend_bump" ;;
    infra)    bump_val="$infra_bump" ;;
  esac
  if [[ "$bump_val" != "noop" ]]; then
    case "$name" in
      backend)  dir="$BACKEND_ROOT" ;;
      frontend) dir="$FRONTEND_ROOT" ;;
      infra)    dir="$INFRA_ROOT" ;;
    esac
    (cd "$dir" && git push origin --tags) || err "Failed to push tags for $name"
    log "  $name: tags pushed"
  fi
done
log ""
log "Release complete. Branches were NOT pushed."
log ""
