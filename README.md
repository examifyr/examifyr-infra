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