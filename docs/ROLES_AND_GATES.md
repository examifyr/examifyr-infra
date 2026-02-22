# Examifyr Roles & Quality Gates

**Canonical docs** live in examifyr-infra. See also `docs/ai-roles-and-quality-gates.md` for detailed role definitions.

## Quality gates (enforced order)

| Gate | Description | Blocking? |
|------|-------------|-----------|
| Local Step 2.3 | `./scripts/test.sh` passes | Yes |
| Backend runtime smoke | `scripts/runtime-smoke-test.sh` (backend only) | Yes (when releasing) |
| CI green | All GitHub Actions checks pass | Yes |
| Claude code review | Readability, maintainability | No |
| Gemini QA | Correctness, security, API contracts | Yes |

## Release label rules

- **Never** apply `release` unless CI is green on the PR
- Tag creation happens only after merge, only when PR has label `release`
- Semantic version tags: `v0.1.0`, `v0.1.1`, etc.

## Roles (summary)

- **Owner (Johnson)**: Final approval, decides when code ships
- **Architect (ChatGPT)**: Acceptance criteria, architecture; does not implement
- **Implementation (Claude in Cursor)**: Implements; does not self-approve
- **Code Reviewer (Claude)**: Non-blocking review
- **QA (Gemini)**: Blocking review; can require fixes
