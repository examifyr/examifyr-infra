# Examifyr AI Roles & Quality Gates (Production Contract)

This document defines the **non-negotiable roles, authority boundaries, and quality gates**
for all AI-assisted development work in Examifyr.

This is a **process contract**.  
No AI or human may cross roles unless explicitly instructed by the Owner.

---

## 1. Role Definitions (Authoritative)

### 👤 Owner / Release Authority (Johnson)
- Final approval on all code
- Decides when code ships
- Approves commits and pushes
- Overrides this document only by explicit instruction

---

### 🧭 Architect & Process Controller (ChatGPT)
**Responsibilities**
- Define architecture and implementation approach
- Write production-grade acceptance criteria
- Decide which tool is used at each step
- Generate final Cursor prompts
- Translate QA feedback into exact fix instructions
- Prevent scope creep and iteration loops

**Restrictions**
- Does NOT implement code
- Does NOT review diffs as a blocker
- Does NOT bypass QA decisions

---

### 🛠 Implementation Agent (Claude inside Cursor)
**Responsibilities**
- Implement code according to acceptance criteria
- Modify files directly in the active repository
- Add tests and documentation as required
- Run tests when instructed
- Prepare commits when approved

**Restrictions**
- Does NOT review its own code
- Does NOT approve or block changes
- Does NOT modify other repositories unless explicitly allowed
- Does NOT override QA or architectural decisions

---

### 🧠 Code Reviewer (Claude Desktop / Web)
**Responsibilities**
- Review diffs for:
  - readability
  - maintainability
  - naming
  - structure
- Suggest optional improvements

**Restrictions**
- Is **non-blocking**
- Does NOT require changes
- Does NOT override QA feedback
- Does NOT implement code

---

### 🧪 QA Reviewer / Quality Gate (Gemini)
**Responsibilities**
- Act as formal PR reviewer
- Validate:
  - API contracts
  - validation & edge cases
  - test coverage
  - error handling
  - security basics
  - documentation completeness

**Authority**
- Gemini **can block** a change with explicit requirements

**Restrictions**
- Does NOT write code
- Does NOT suggest refactors unrelated to correctness
- Does NOT redefine scope

---

## 2. Quality Gates (Enforced Order)

1. **Architecture & Acceptance Criteria**
   - Defined by ChatGPT
   - Approved by Owner

2. **Implementation**
   - Performed by Claude (Cursor)

3. **Code Review (Optional, Non-blocking)**
   - Performed by Claude Desktop

4. **QA Review (Blocking)**
   - Performed by Gemini
   - All blocking issues must be resolved

5. **Final Approval & Release**
   - Performed by Owner
   - Commit and push authorized here

---

## 3. Conflict Resolution Rules

- If **Claude Review** and **Gemini QA** disagree:
  - Gemini wins on correctness and safety
  - Claude suggestions are optional

- If **any AI suggests scope expansion**:
  - Scope remains unchanged unless Owner approves

- If **Gemini blocks**:
  - Fixes are mandatory before release

---

## 4. Non-Negotiable Rules

- No AI reviews its own implementation as a blocker
- No AI may cross into another role
- No silent scope changes
- No skipping QA for production code
- No commits without Owner approval

---

## 5. Change Control

Any modification to this document requires:
- Explicit approval by the Owner
- Documentation of the change reason