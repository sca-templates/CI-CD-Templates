---
name: template-lifecycle
description: Manage CI/CD templates — create, update, and validate reusable workflows, composite actions, and rulesets. Use when the user asks to add a new workflow/action/ruleset, modify existing templates, or validate the template structure.
---

# Template lifecycle

## How templates work

This repo provides CI/CD automation primitives consumed by all repos in the
`sca-templates` organization via `uses:` references:

```yaml
# Consumer repo calls this:
jobs:
  security:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-security-scan.yml@main
```

## Adding a new reusable workflow

1. Create `.github/workflows/shared-<name>.yml` with `workflow_call` trigger.
2. Define explicit `inputs` (type, default, description) and `secrets` if needed.
3. Create a self-test: `.github/workflows/self-<name>.yml` that calls it.
4. Update `docs/workflows.md` with the new entry.
5. Follow naming convention: `shared-<scope>-<verb>.yml`

## Adding a new composite action

1. Create `.github/actions/<name>/action.yml` with `runs.using: composite`.
2. Define inputs with descriptions and defaults.
3. Update `docs/workflows.md`.

## Adding a new ruleset

1. Create `.github/rulesets/<name>.json` in GitHub Rulesets API format.
2. Update `docs/rulesets.md`.

## Adding a new technology category

1. Workflows: `.github/workflows/stack-<tech>-*.yml`
2. Actions: `.github/actions/<tech>/action.yml`
3. Rulesets: `.github/rulesets/<tech>-*.json`
4. Update all docs: `INDEX.md`, `workflows.md`, `rulesets.md`, `README.md`

## Validation checklist

- [ ] YAML valid (yamllint)
- [ ] Markdown linted (markdownlint)
- [ ] Reusable workflow is **flat** in `.github/workflows/` (no subdirs)
- [ ] `workflow_call` trigger defined with explicit inputs
- [ ] Self-test workflow exists and calls the reusable workflow
- [ ] Docs updated in the same commit

## Armor rules

- **Reusable workflows MUST be flat** in `.github/workflows/` — GitHub does not
  support subdirectories for reusable workflows.
- **No `latest` tags** in action references — pin to SHA or version tag.
- **Git writes are the user's** — never commit or push on your own.
- **Never commit** secrets, tokens, or credentials.
