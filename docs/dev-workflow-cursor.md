# Examifyr Development Workflow (Cursor + Claude + Gemini)

This document records the standard development workflow used in Examifyr.
It reflects the workflow already in use and is intended for consistency
across machines and over time.

---

## Tools and Roles

- **Cursor**: Primary IDE and Git interface
- **Claude (inside Cursor Agent)**: Writes and refactors code
- **Gemini**: Reviews diffs for correctness, security, and gaps
- **Human (Johnson)**: Runs locally, approves commits, pushes changes

---

## Repository Scope

- **examifyr-backend**: FastAPI backend
- **examifyr-frontend**: Next.js frontend
- **examifyr-infra**: Documentation, standards, scripts, AI governance

Only one repository is opened in Cursor at a time.

---

## Standard Workflow

### 1. Open repo in Cursor
- File → Open Project
- Or: `cursor .`

### 2. Start local services
Backend:
```bash
./start-local.sh