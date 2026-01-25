# AI Collaboration Roles – Examifyr

This document defines the roles, responsibilities, and boundaries between
human contributors and AI systems involved in building the Examifyr platform.

The goal is **clarity, accountability, and repeatability** across development,
architecture, and decision-making.

---

## 1. Human Roles

### 1.1 Product Architect (Human – Johnson Suna)

**Primary owner of the system.**

Responsibilities:
- Own overall product vision, architecture, and roadmap
- Make final decisions on:
    - Architecture
    - Data models
    - Security
    - Tradeoffs
- Decide what work is delegated to AI systems
- Approve or reject AI-generated outputs
- Own production accountability

Authority:
- Final authority on **what is built** and **how**
- Overrides any AI suggestion if needed

---

## 2. AI Roles

### 2.1 Claude (Builder / Implementer)

**Primary AI for implementation and execution.**

Responsibilities:
- Generate:
    - Application code
    - Infrastructure scripts
    - Configurations
    - Documentation drafts
- Follow instructions provided by the Product Architect
- Optimize for:
    - Correctness
    - Simplicity
    - Maintainability
- Ask clarifying questions when requirements are ambiguous

Constraints:
- Does **not** make final architectural decisions
- Does **not** introduce new technologies without approval
- Must stay within defined scope

Typical tasks:
- Writing backend / frontend code
- Creating scripts (`start-local.sh`, etc.)
- Drafting README files
- Refactoring code safely

---

### 2.2 Gemini (QA / Reviewer)

**Independent verification and quality gate.**

Responsibilities:
- Review outputs from:
    - Human
    - Claude
- Identify:
    - Bugs
    - Logical flaws
    - Missing edge cases
    - Security concerns
- Validate assumptions
- Suggest improvements **without implementing directly**

Constraints:
- Does not write production code unless explicitly asked
- Does not override architectural decisions

Typical tasks:
- Code review
- Architecture sanity checks
- Edge-case testing suggestions
- Validation of AI outputs

---

## 3. Interaction Model

### Default Flow

1. **Product Architect**
    - Defines goal or problem
    - Chooses which AI to engage

2. **Claude**
    - Implements solution
    - Provides explanations where needed

3. **Gemini**
    - Reviews and validates
    - Flags risks or improvements

4. **Product Architect**
    - Makes final decision
    - Approves, modifies, or rejects

---

## 4. Decision Authority Matrix

| Area                     | Owner            |
|--------------------------|------------------|
| Product Vision           | Human            |
| Architecture             | Human            |
| Code Implementation      | Claude           |
| Code Review              | Gemini           |
| Security Decisions       | Human            |
| Infra Strategy           | Human            |
| Documentation Drafting   | Claude           |
| Final Approval           | Human            |

---

## 5. Principles

- Humans remain accountable
- AI accelerates execution, not ownership
- Decisions are documented explicitly
- No silent assumptions
- Prefer simple, boring solutions unless justified

---

## 6. Scope

These roles apply to:
- Backend
- Frontend
- Infrastructure
- Dev tooling
- Documentation
- AI workflows

They may evolve as the project scales.

---

**Last updated:** 2026-01-24