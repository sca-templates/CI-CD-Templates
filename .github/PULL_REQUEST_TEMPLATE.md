# Pull Request

## Description

<!-- Describe the change and why it is needed. -->

## Type of change

- [ ] feat (new template, action, or ruleset)
- [ ] fix (corrects behavior of an existing template)
- [ ] docs (documentation only)
- [ ] ci (CI/CD tooling, linters, or repository governance)
- [ ] refactor (no behavior change)

## Checklist

- [ ] YAML valid for changed workflows/actions (`yamllint`)
- [ ] Markdown valid for changed docs (`markdownlint-cli2`)
- [ ] Reusable workflows are **flat** in `.github/workflows/` (no subdirectories)
- [ ] `workflow_call` triggers define explicit inputs and secrets
- [ ] Composite actions use `runs.using: composite`
- [ ] No `@latest` or unpinned `@main` references (actions pinned to commit SHA)
- [ ] Self-test workflow exists for new `shared-*` workflows
- [ ] Docs updated in `docs/` and `README.md` in the same commit
- [ ] No secrets, tokens, or credentials introduced

## Testing

<!-- How was this change verified? E.g. ran the affected workflow locally, PR CI passed. -->