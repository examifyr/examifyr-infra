# Examifyr AI Workspace

This folder defines how AI tools (Claude, Gemini) are used across the Examifyr ecosystem.

## Primary AI Roles
- Claude → Architect + Code Generator
- Gemini → QA, review, validation

## Rules
1. Claude must read `claude-context.md` before any task
2. Tasks must use one of the prompt templates in `prompts/`
3. Architecture decisions must be logged in `decisions.md`
4. AI must never assume missing context

## Repositories Covered
- examifyr-backend
- examifyr-frontend
- examifyr-infra