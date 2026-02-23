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

## CI expectations

- **Step 2.3 as source of truth**: Each repo’s main CI workflow (`.github/workflows/ci.yml`) must run `./scripts/test.sh` — not raw pytest/npm/etc directly unless wrapped by `scripts/test.sh`.
- **Conventional Commits + PR title format**: If workflows enforce PR title or commit message checks, use Conventional Commits (e.g. `feat:`, `fix:`, `chore:`) and ensure PR titles match the expected pattern (e.g. `feat(scope): description`).
- **Local CI with act (optional)**: To run GitHub Actions locally, install [act](https://github.com/nektos/act) (`brew install act` on macOS). The release orchestrator can run `act push -W .github/workflows/ci.yml` per repo when using `--apply`. Use `--skip-ci-local` to skip this step.

## Release Orchestration (Federated SemVer)

Infra orchestrates releases; each repo owns its own `VERSION` file and `scripts/semver-bump.sh`. Infra triggers tagging and pushes tags only (never pushes branches).

### Federated SemVer

- Each repo (backend, frontend, infra) has `VERSION` and `scripts/semver-bump.sh`.
- `semver-bump.sh` analyzes conventional commits since the last tag and determines bump type (major/minor/patch).
- Infra calls each repo’s `semver-bump.sh --dry-run` to build a release plan.
- Infra runs tests, then (with approval) runs `semver-bump.sh --apply` per repo and pushes tags.
- Branches are never pushed by the orchestrator.

### Required layout

```
project/
├── examifyr-infra/
├── examifyr-backend/
└── examifyr-frontend/
```

Each repo must have `scripts/semver-bump.sh` and `VERSION` at the repo root.

### Typical flows

- **One repo changed**: Only that repo shows a bump in the plan; others are noop.
- **Two repos changed**: Both show bumps; both get `--apply` and tag push.
- **All three changed**: All three are bumped and tagged.

### Commands (run from examifyr-infra)

```bash
# Dry-run (default): show release plan, no changes
./scripts/release-orchestrate.sh --dry-run

# Apply: run tests, prompt for approval, apply bumps, push tags
./scripts/release-orchestrate.sh --apply

# Apply without prompt (e.g. CI)
./scripts/release-orchestrate.sh --apply --yes

# Custom backend URL for runtime smoke (default: http://127.0.0.1:8000)
BASE_URL=http://127.0.0.1:8000 ./scripts/release-orchestrate.sh --apply
```

### Pre-flight checks (must pass)

1. Repo paths exist.
2. Each repo has `scripts/semver-bump.sh` and `VERSION`.
3. All working trees clean.
4. All branches allowed: `main`, `master`, or `feature/*`.
5. `origin` fetched.

### Testing gates (before apply)

- Step 2.3: `./scripts/test.sh` in backend, frontend, infra.
- If backend is in the release plan (bump ≠ noop): runtime smoke test at `BASE_URL`. Backend must already be running.

### What the orchestrator does NOT do

- Does not deploy.
- Does not push branches.
- Does not start servers (backend must be running for smoke tests).

### Dirty repo or wrong branch

- **Dirty**: Script exits. Fix with `git status`, then commit, stash, or discard.
- **Wrong branch**: Only `main`, `master`, or `feature/*` allowed. Switch manually and re-run.