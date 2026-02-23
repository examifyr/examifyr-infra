# Examifyr Infra

This repository is the **source of truth** for the Examifyr platform.

## Purpose
- Architecture documentation
- Standards
- Shared scripts
- Onboarding reference

## Repositories
- examifyr-frontend
- examifyr-backend

## Key Documents
- docs/ARCHITECTURE.md
- standards/README_STANDARD.md

## Workflow
1. Infra defines rules
2. App repos reference infra
3. No duplication of specs

## Local Development
Each repo provides its own `start-local.sh`, aligned with infra standards.

## Step 2.3 – Repo checks
Run:
```bash
./scripts/test.sh
```
This script is the single source of truth for repo checks, and CI runs it.

## Release Orchestration (Local)

The release orchestrator runs centralized local checks across all Examifyr repos before you open PRs. It does **not** deploy; it only validates that local tests pass.

### Prerequisites (new laptop)

- **Folder layout**: Clone all three repos as siblings:
  ```
  project/
  ├── examifyr-infra/
  ├── examifyr-backend/
  └── examifyr-frontend/
  ```
- **Tools**: Git, Bash. Optional: `gh` (GitHub CLI) for per-repo release flow.
- **Backend**: Python 3.11+ with venv; run from `examifyr-backend`.
- **Frontend**: Node.js with npm; run from `examifyr-frontend`.
- **Backend runtime**: For full checks, the backend must be running. Start it with:
  ```bash
  cd examifyr-backend && ./start-local.sh
  ```

### Commands

From `examifyr-infra`:

```bash
# Dry-run: print what would happen, no changes
./scripts/release-orchestrate.sh --dry-run

# Real run: execute all checks
./scripts/release-orchestrate.sh

# Custom backend URL (default: http://127.0.0.1:8000)
./scripts/release-orchestrate.sh --base-url http://localhost:8000
```

### What it checks

1. **Repo paths** – backend, frontend, infra exist as siblings.
2. **Working trees** – all repos must be clean (no uncommitted changes). If dirty, the script stops and tells you which repo and how to fix it.
3. **Remotes** – each repo has `origin`; fetches from origin.
4. **Branches** – if any repo is not on `main`, you are prompted: create a feature branch from main? (y/n). If no, the script exits.
5. **Step 2.3** – runs `./scripts/test.sh` in each repo (backend, frontend, infra).
6. **Backend runtime smoke** – if the backend is reachable at the base URL, runs `./scripts/runtime-smoke-test.sh`. If not reachable, prints how to start it and exits.

### What it does NOT do

- Does not deploy.
- Does not create PRs, tags, or releases.
- Does not modify code; only runs tests and checks.

### Dirty repos or wrong branch

- **Dirty working tree**: The script exits immediately. Resolve with `git status`, then `commit`, `stash`, or `discard` in that repo.
- **Not on main**: The script lists repos not on main and asks: create feature branches? (y/n). If you choose no, it exits. Switch to main manually and re-run, or choose yes to create feature branches from main.