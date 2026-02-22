# Examifyr Release Checklist

**Single source of truth**: examifyr-infra. Repo-specific overrides only when necessary.

## Pre-release gates (all must pass)

1. **Local Step 2.3** — `./scripts/test.sh` passes in the repo
2. **Backend runtime smoke** — (backend only) `scripts/runtime-smoke-test.sh` passes; run with `BACKEND_SMOKE=1` via `./scripts/release-ready.sh`
3. **CI green** — All GitHub Actions checks pass on the PR
4. **Claude code review** — Non-blocking review completed
5. **Gemini QA** — Blocking approval; all issues resolved

## Release label rules

- **Never** apply the `release` label until CI is green on the PR
- The release label is explicit release intent
- Only apply after all checks pass

## Tag creation (automated)

- Tags are created **only** by GitHub Actions **after merge** when the merged PR has label `release`
- No manual tags for releases
- Semantic versioning: `v0.1.0`, `v0.1.1`, etc.
- Default: bump PATCH; start at `v0.1.0` if no tags exist

## Deploy targets

- **Backend**: Render
- **Frontend**: Vercel

## Workflow summary

1. Create feature branch, implement, run local checks
2. Push, open PR to main
3. Wait for CI green
4. Claude review → Gemini QA
5. If releasing: apply `release` label **only after** CI green
6. Merge to main
7. GitHub Action creates tag + release notes (if label present)
