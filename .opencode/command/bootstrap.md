---
description: Scaffold new templates — guided creation of workflow, action, or ruleset.
agent: build
---

# Bootstrap

Guide the user through adding a new template:

1. **Ask type**: reusable workflow, composite action, or ruleset?
2. **Ask scope**: global (all repos) or technology-specific (e.g. nodejs, go, python)?
3. **Ask name and purpose** — what does it do, what inputs does it need?
4. **Create the file** following conventions:
   - Workflow: `.github/workflows/reusable_<scope>-<verb>.yml` with `workflow_call`
   - Action: `.github/actions/<name>/action.yml` with `runs.using: composite`
   - Ruleset: `.github/rulesets/<scope>-<name>.json` in GitHub API format
5. **Create self-test** if it's a workflow
6. **Update docs**: `docs/workflows.md`, `docs/rulesets.md`, `docs/INDEX.md`, `README.md`
7. **Run validation**: `yamllint` + `markdownlint` to confirm everything is clean
