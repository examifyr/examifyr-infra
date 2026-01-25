# Architectural & Product Decisions – Examifyr

This document records **important technical, architectural, and process decisions**
made during the development of the Examifyr platform.

The purpose is to:
- Preserve context
- Avoid re-litigating past decisions
- Enable fast onboarding on new machines or contributors
- Create a reliable source of truth

---

## 1. Decision Logging Rules

- Only **meaningful decisions** are recorded
- Tactical or trivial choices are excluded
- Each decision includes:
    - Context
    - Decision
    - Rationale
    - Consequences

---

## 2. Recorded Decisions

---

### D-001: Monorepo vs Multi-Repo Strategy

**Date:** 2026-01-24  
**Status:** Approved

**Context:**  
Examifyr consists of multiple logical components:
- Frontend (Next.js)
- Backend (FastAPI)
- Infrastructure & standards
- AI collaboration artifacts

**Decision:**  
Use **multiple repositories**:
- `examifyr-frontend`
- `examifyr-backend`
- `examifyr-infra`

**Rationale:**
- Clear ownership boundaries
- Independent lifecycles
- Cleaner CI/CD in the future
- Infra repo acts as the source of truth

**Consequences:**
- Slightly more coordination overhead
- Better long-term scalability and clarity

---

### D-002: Local Development via Scripts

**Date:** 2026-01-24  
**Status:** Approved

**Context:**  
Running multiple commands manually is error-prone and slow, especially on new machines.

**Decision:**  
Each project must provide a `start-local.sh` script that:
- Detects running instances
- Terminates conflicting processes
- Starts services with correct configuration

**Rationale:**
- One-command local startup
- Consistent behavior across machines
- Easier onboarding

**Consequences:**
- Slight upfront scripting effort
- Long-term productivity gain

---

### D-003: Backend Technology Choice

**Date:** 2026-01-24  
**Status:** Approved

**Context:**  
The backend needs to be:
- Fast
- Python-based
- API-first
- Easy to integrate with AI workflows

**Decision:**  
Use **FastAPI** with **Uvicorn**.

**Rationale:**
- Strong typing
- Async support
- Excellent developer experience
- Native OpenAPI support

**Consequences:**
- Requires understanding async patterns
- Very strong long-term foundation

---

### D-004: Frontend Technology Choice

**Date:** 2026-01-24  
**Status:** Approved

**Context:**  
Frontend must support:
- Rapid iteration
- Modern UI patterns
- API-driven architecture

**Decision:**  
Use **Next.js (React)** for frontend.

**Rationale:**
- Mature ecosystem
- First-class developer tooling
- Easy API integration
- Scales from MVP to production

**Consequences:**
- Requires Node.js toolchain
- Well-understood tradeoff

---

### D-005: CORS Handling Strategy

**Date:** 2026-01-24  
**Status:** Approved

**Context:**  
Frontend and backend run on different ports during local development.

**Decision:**  
Configure explicit CORS middleware in FastAPI allowing:
- `http://localhost:3000`
- `http://127.0.0.1:3000`

**Rationale:**
- Clear, explicit configuration
- Avoids wildcard origins in production
- Improves security posture

**Consequences:**
- Must update CORS list when new origins are added

---

### D-006: AI Collaboration Model

**Date:** 2026-01-24  
**Status:** Approved

**Context:**  
Multiple AI systems are used during development.

**Decision:**  
Adopt a **role-based AI model**:
- Claude → Builder / Implementer
- Gemini → QA / Reviewer
- Human → Architect / Final Authority

**Rationale:**
- Clear responsibility boundaries
- Prevents AI conflict
- Improves output quality

**Consequences:**
- Requires discipline in how AI is used
- Strong long-term leverage

---

### D-007: Infrastructure as Documentation

**Date:** 2026-01-24  
**Status:** Approved

**Context:**  
Infrastructure decisions often get lost across repos.

**Decision:**  
`examifyr-infra` acts as:
- Canonical documentation
- Standards definition
- AI collaboration source of truth

**Rationale:**
- Centralized knowledge
- Easier onboarding
- Cleaner evolution

**Consequences:**
- Must keep infra repo up to date
- Becomes a critical dependency

---

## 3. Future Decisions

All future decisions should:
- Follow the same format
- Be appended, not rewritten
- Reference prior decisions when relevant

---

**Last updated:** 2026-01-24