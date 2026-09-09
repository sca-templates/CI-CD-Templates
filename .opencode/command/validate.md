---
description: Validate all templates — YAML lint, markdown lint, and structural checks.
agent: build
---

# Validate

Run structural validation on all templates:

1. **YAML lint** all `.yml`/`.yaml` files: `yamllint .github/`
2. **Markdown lint** all `.md` files: `npx markdownlint-cli2 "**/*.md"`
3. **Structural checks**:
   - Every `reusable_*.yml` has `workflow_call` trigger
   - Every `test_*.yml` calls a reusable workflow from this repo
   - Every `.github/actions/*/action.yml` has `runs.using: composite`
   - Every `.github/rulesets/*.json` is valid JSON with `name`, `target`, `rules`

Report pass/fail for each category. Fix any failures and re-run until green.
