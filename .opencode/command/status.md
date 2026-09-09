---
description: List all available templates — workflows, actions, and rulesets.
agent: build
---

# Status

Report the current state of all templates:

1. **Reusable workflows** — list all `reusable_*.yml` in `.github/workflows/` with their inputs
2. **Composite actions** — list all `.github/actions/*/action.yml` with their inputs
3. **Rulesets** — list all `.github/rulesets/*.json` with their target and rules
4. **Self-tests** — list all `test_*.yml` and which workflow they test
5. **Docs** — check if `docs/workflows.md` and `docs/rulesets.md` match the actual files

Present as a summary table. Flag any template without a corresponding doc entry.
