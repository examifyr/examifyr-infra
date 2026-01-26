#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '%s\n' "$1"
}

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

has_npm_script() {
  local script_name="$1"
  local value

  value="$(npm pkg get "scripts.${script_name}" 2>/dev/null || echo "null")"
  case "$value" in
    null|"null"|"undefined"|"" )
      return 1
      ;;
    * )
      return 0
      ;;
  esac
}

if [[ -f "package.json" ]]; then
  log "package.json detected: running npm ci"
  npm ci

  if has_npm_script "lint"; then
    log "Running npm run lint"
    npm run lint
  elif has_npm_script "test"; then
    log "Running npm test"
    npm test
  elif has_npm_script "build"; then
    log "Running npm run build"
    npm run build
  else
    fail "No npm scripts found: expected lint, test, or build."
  fi

  log "npm checks passed"
  exit 0
fi

log "No package.json detected: running repo structure checks"

missing=()
[[ -f "README.md" ]] || missing+=("README.md")
[[ -d "ai" ]] || missing+=("ai/")
[[ -d "docs" ]] || missing+=("docs/")
[[ -d "templates" ]] || missing+=("templates/")

if [[ ${#missing[@]} -gt 0 ]]; then
  fail "Missing required repo paths: ${missing[*]}"
fi

log "Checking for forbidden tracked artifacts"
forbidden=()
while IFS= read -r -d '' file; do
  case "$file" in
    .idea/*|*/.idea/*) forbidden+=("$file") ;;
    .vscode/*|*/.vscode/*) forbidden+=("$file") ;;
    .DS_Store|*/.DS_Store) forbidden+=("$file") ;;
    .env|*/.env) forbidden+=("$file") ;;
    .env.*|*/.env.*) forbidden+=("$file") ;;
    .venv/*|*/.venv/*) forbidden+=("$file") ;;
    node_modules/*|*/node_modules/*) forbidden+=("$file") ;;
  esac
done < <(git ls-files -z)

if [[ ${#forbidden[@]} -gt 0 ]]; then
  log "Tracked forbidden artifacts found:"
  printf ' - %s\n' "${forbidden[@]}"
  fail "Remove these files from git history and keep them ignored."
fi

if command -v shellcheck >/dev/null 2>&1; then
  log "Running shellcheck on tracked .sh files"
  mapfile -t sh_files < <(git ls-files "*.sh")
  if [[ ${#sh_files[@]} -gt 0 ]]; then
    shellcheck "${sh_files[@]}"
  else
    log "No tracked .sh files found"
  fi
else
  log "shellcheck not installed; skipping"
fi

log "Running git diff --check"
git diff --check || fail "git diff --check reported whitespace errors."

log "Repo checks passed"
