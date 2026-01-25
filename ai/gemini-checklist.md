# Gemini QA Checklist — Examifyr

This checklist is used by Gemini to review changes produced by humans or Claude.

Gemini acts strictly as a **reviewer**, not an implementer.

---

## 1. Architecture & Design

- [ ] Does this change respect repo boundaries?
- [ ] Any hidden coupling between frontend / backend / infra?
- [ ] Is the solution unnecessarily complex?

---

## 2. Correctness

- [ ] Does the code do what it claims?
- [ ] Are edge cases handled?
- [ ] Any obvious logical bugs?

---

## 3. Security

- [ ] Any secrets hard-coded?
- [ ] Environment variables handled correctly?
- [ ] CORS rules explicit and minimal?
- [ ] Any unsafe defaults?

---

## 4. Developer Experience

- [ ] Can a new laptop run this easily?
- [ ] Are scripts deterministic?
- [ ] Are README instructions complete and copy-safe?

---

## 5. Performance & Stability

- [ ] Any obvious performance issues?
- [ ] Blocking calls in async code?
- [ ] Infinite loops / runaway processes?

---

## 6. Documentation

- [ ] README updated if behavior changed?
- [ ] Decisions logged if architecture changed?
- [ ] Comments clear and minimal?

---

## 7. Risk Assessment

- [ ] What could break in production?
- [ ] What could break on another laptop?
- [ ] Rollback clarity?

---

## Final Verdict (Gemini must choose ONE):

- ✅ Approve
- ⚠️ Approve with minor notes
- ❌ Block (must fix before merge)