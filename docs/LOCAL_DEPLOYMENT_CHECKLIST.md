# Examifyr Local Deployment Checklist

**Single source of truth**: examifyr-infra. Global-first, repo-specific overrides where needed.

## Local development setup

### Backend (examifyr-backend)
- Start: `./start-local.sh` (or equivalent)
- Base URL: `http://127.0.0.1:8000`
- Deploy target: Render

### Frontend (examifyr-frontend)
- Start: `npm run dev` (or equivalent)
- Base URL: `http://localhost:3000`
- Deploy target: Vercel

### Infra (examifyr-infra)
- No runtime; docs + scripts only
- Step 2.3: `./scripts/test.sh`

## Step 2.3 – Repo checks (mandatory before PR)

In each repo, run:
```bash
./scripts/test.sh
```

This is the canonical local gate. CI runs the same script.

## Release-ready flow

Use the thin wrapper in each repo:
```bash
./scripts/release-ready.sh
```

- **Backend**: Runs `test.sh` + runtime smoke (when `BACKEND_SMOKE=1`)
- **Frontend**: Runs `test.sh` only
- **Infra**: Runs `test.sh` only

The wrapper locates `examifyr-infra/tools/release-core.sh` from the sibling infra repo and invokes it.
