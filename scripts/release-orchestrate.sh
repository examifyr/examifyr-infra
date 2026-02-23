#!/usr/bin/env bash
# Federated SemVer Release Orchestrator: infra orchestrates, each repo owns VERSION + semver-bump.sh.
# Runs from examifyr-infra. Requires sibling folders: examifyr-backend, examifyr-frontend.
# Usage: ./scripts/release-orchestrate.sh [--dry-run] [--apply] [--yes] [--base-url URL]
#         [--ci-static-only] [--ci-local] [--skip-ci-local]
# Default: --dry-run. --apply requires approval unless --yes.

set -euo pipefail

log() { printf '%s\n' "$1"; }
err() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

post_merge_summary() {
  log "=== Post-merge verification (manual) ==="
  log "Open Actions tab on GitHub: confirm latest runs for backend, frontend, infra on main are green."
  log ""
}

INFRA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$INFRA_ROOT/.." && pwd)"
BACKEND_ROOT="${PROJECT_ROOT}/examifyr-backend"
FRONTEND_ROOT="${PROJECT_ROOT}/examifyr-frontend"
BASE_URL="http://127.0.0.1:8000"
DRY_RUN="true"
APPLY="false"
YES="false"
CI_STATIC_ONLY="false"
CI_LOCAL=""
SKIP_CI_LOCAL="false"

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)       DRY_RUN="true"; shift ;;
    --apply)         APPLY="true"; DRY_RUN="false"; shift ;;
    --yes)           YES="true"; shift ;;
    --base-url)      [[ -n "${2:-}" ]] || err "--base-url requires a value"; BASE_URL="$2"; shift 2 ;;
    --ci-static-only) CI_STATIC_ONLY="true"; shift ;;
    --ci-local)      CI_LOCAL="true"; shift ;;
    --skip-ci-local) SKIP_CI_LOCAL="true"; shift ;;
    *) err "Unknown flag: $1. Use --dry-run, --apply, --yes, --base-url, --ci-static-only, --ci-local, --skip-ci-local" ;;
  esac
done

# act availability
ACT_AVAILABLE="false"
if command -v act &>/dev/null; then
  ACT_AVAILABLE="true"
fi

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

# --- CI static check helpers (defined early for --ci-static-only) ---
ci_static_check_repo() {
  local repo_name="$1"
  local repo_root="$2"
  local workflows_dir="$repo_root/.github/workflows"
  local ci_yml="$workflows_dir/ci.yml"
  local main_workflow=""
  local has_test_sh=""
  local has_pr=""
  local has_push=""
  local git_mode=""
  local ci_chmod=""

  if [[ ! -d "$workflows_dir" ]]; then
    err "CI check [$repo_name]: .github/workflows does not exist. Add .github/workflows/ with at least one workflow YAML."
  fi

  local yaml_count=0
  for f in "$workflows_dir"/*.yml "$workflows_dir"/*.yaml; do
    [[ -e "$f" ]] || continue
    ((yaml_count++)) || true
  done
  if [[ "$yaml_count" -eq 0 ]]; then
    err "CI check [$repo_name]: .github/workflows has no workflow YAML files. Add at least one (e.g. ci.yml)."
  fi

  if [[ -f "$ci_yml" ]]; then
    main_workflow="$ci_yml"
  else
    for wf in "$workflows_dir"/*.yml "$workflows_dir"/*.yaml; do
      [[ -e "$wf" ]] || continue
      if grep -qE 'scripts/test\.sh|\./scripts/test\.sh' "$wf" 2>/dev/null; then
        main_workflow="$wf"
        break
      fi
    done
  fi

  if [[ -z "$main_workflow" ]]; then
    err "CI check [$repo_name]: No main CI workflow found. Add .github/workflows/ci.yml that runs ./scripts/test.sh (Step 2.3)."
  fi

  has_test_sh="$(grep -E 'scripts/test\.sh|\./scripts/test\.sh' "$main_workflow" 2>/dev/null || true)"
  if [[ -z "$has_test_sh" ]]; then
    err "CI check [$repo_name]: Main workflow ($main_workflow) must run ./scripts/test.sh as the single source of truth (Step 2.3)."
  fi

  has_pr="$(grep -A 20 '^on:' "$main_workflow" 2>/dev/null | grep -E '^\s*pull_request:' || true)"
  has_push="$(grep -A 20 '^on:' "$main_workflow" 2>/dev/null | grep -E '^\s*push:' || true)"
  if [[ -z "$has_pr" ]] || [[ -z "$has_push" ]]; then
    err "CI check [$repo_name]: Main workflow ($main_workflow) must trigger on BOTH pull_request and push. Add:
  on:
    pull_request:
    push:"
  fi

  if [[ "$repo_name" == "backend" ]] || [[ "$repo_name" == "infra" ]]; then
    local test_sh="$repo_root/scripts/test.sh"
    if [[ -f "$test_sh" ]]; then
      git_mode="$(cd "$repo_root" && git ls-files -s -- scripts/test.sh 2>/dev/null | awk '{print $1}')"
      ci_chmod="$(grep -E 'chmod.*\+x.*scripts|chmod.*scripts/test' "$main_workflow" 2>/dev/null || true)"
      if [[ "$git_mode" != "100755" ]] && [[ -z "$ci_chmod" ]]; then
        err "CI check [$repo_name]: scripts/test.sh must be executable in git (chmod +x; mode 100755) OR CI must run 'chmod +x scripts/test.sh' before use. File: $test_sh"
      fi
    fi
  fi

  log "CI static check [$repo_name]: OK"
}

ci_commit_pr_doc_check() {
  local workflows_dir="$INFRA_ROOT/.github/workflows"
  local has_pr_check=""
  local has_commit_check=""
  local readme_mentions=""

  for wf in "$workflows_dir"/*.yml "$workflows_dir"/*.yaml; do
    [[ -e "$wf" ]] || continue
    if grep -qiE 'pr.title|pr_title|pull_request.*title' "$wf" 2>/dev/null; then has_pr_check="yes"; fi
    if grep -qiE 'commit.message|commit_message|conventional' "$wf" 2>/dev/null; then has_commit_check="yes"; fi
  done

  if [[ -n "$has_pr_check" ]] || [[ -n "$has_commit_check" ]]; then
    readme_mentions="$(grep -iE 'conventional commit|PR title|pr title' "$INFRA_ROOT/README.md" 2>/dev/null || true)"
    if [[ -z "$readme_mentions" ]]; then
      err "CI check [infra]: Workflows enforce PR title/commit checks but README does not document expected Conventional Commits + PR title format. Add a 'CI expectations' section."
    fi
  fi
  log "CI commit/PR doc check: OK"
}

# --- CI-static-only mode: run only static checks, then exit ---
if [[ "$CI_STATIC_ONLY" == "true" ]]; then
  log "Running CI static checks (--ci-static-only)..."
  ci_static_check_repo "backend" "$BACKEND_ROOT"
  ci_static_check_repo "frontend" "$FRONTEND_ROOT"
  ci_static_check_repo "infra" "$INFRA_ROOT"
  ci_commit_pr_doc_check
  log ""
  post_merge_summary
  log "CI static checks passed."
  exit 0
fi

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

# --- CI static checks (run before tagging) ---
log "Running CI static checks..."
ci_static_check_repo "backend" "$BACKEND_ROOT"
ci_static_check_repo "frontend" "$FRONTEND_ROOT"
ci_static_check_repo "infra" "$INFRA_ROOT"
ci_commit_pr_doc_check
log "CI static checks passed."
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
  if [[ "$SKIP_CI_LOCAL" != "true" ]] && [[ "$ACT_AVAILABLE" == "true" ]]; then
    log "Local CI (act) commands that would run:"
    for name in backend frontend infra; do
      case "$name" in
        backend)  dir="$BACKEND_ROOT" ;;
        frontend) dir="$FRONTEND_ROOT" ;;
        infra)    dir="$INFRA_ROOT" ;;
      esac
      if [[ -f "$dir/.github/workflows/ci.yml" ]]; then
        log "  $name: cd $dir && act push -W .github/workflows/ci.yml --dry-run"
      fi
    done
    log ""
  fi
  log "Dry-run complete. Run with --apply to execute."
  post_merge_summary
  exit 0
fi

# --- Apply mode: act (local CI) ---
RUN_ACT="false"
if [[ "$SKIP_CI_LOCAL" == "true" ]]; then
  RUN_ACT="false"
elif [[ "$ACT_AVAILABLE" == "true" ]]; then
  RUN_ACT="true"
else
  err "act not installed. Install with: brew install act (macOS) or see https://github.com/nektos/act. Or pass --skip-ci-local to skip local CI run."
fi

if [[ "$RUN_ACT" == "true" ]]; then
  log "=== Local CI (act) ==="
  for name in backend frontend infra; do
    case "$name" in
      backend)  dir="$BACKEND_ROOT" ;;
      frontend) dir="$FRONTEND_ROOT" ;;
      infra)    dir="$INFRA_ROOT" ;;
    esac
    if [[ -f "$dir/.github/workflows/ci.yml" ]]; then
      log "  $name..."
      if ! (cd "$dir" && act push -W .github/workflows/ci.yml 2>&1); then
        err "act failed for $name. Check logs above. Fix CI or run with --skip-ci-local."
      fi
      log "  $name: act PASS"
    fi
  done
  log ""
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
post_merge_summary
