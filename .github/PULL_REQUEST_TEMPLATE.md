# Pull Request

## Description

<!-- Describe the change and why it is needed. -->

## Motivation and context

<!-- Why is this change required? What problem does it solve? If it fixes an open issue, link it here. -->

## Ticket

<!-- Link the ticket via GitHub Autolinks: [Task 123](https://otherticket.com) -->

## Type of change

- [ ] feat (new template, action, or ruleset)
- [ ] fix (corrects behavior of an existing template)
- [ ] docs (documentation only)
- [ ] ci (CI/CD tooling, linters, or repository governance)
- [ ] refactor (no behavior change)

## Checklist

- [ ] Reusable workflows are **flat** in `.github/workflows/` (no subdirectories)
- [ ] `workflow_call` triggers define explicit inputs and secrets
- [ ] Composite actions use `runs.using: composite`
- [ ] No `@latest` or unpinned `@main` references (actions pinned to commit SHA)
- [ ] Self-test workflow exists for new `shared-*` workflows
- [ ] Docs updated in `docs/` and `README.md` in the same commit
- [ ] No secrets, tokens, or credentials introduced

## Testing

<!-- How was this change verified? E.g. ran the affected workflow locally, PR CI passed. -->

## Screenshots

<!-- If applicable, add screenshots to help explain the change. Otherwise remove this section. -->

## Release notes

<!-- Update the release notes accordingly, or mark N/A. -->

## Additional context

<!-- Any other context reviewers should know about. -->

## Linked issues

<!-- e.g. - [ ] Fixes #123 — delete this section if not applicable. -->

## Linked pull requests

<!-- e.g. - [ ] Depends on #000 — delete this section if not applicable. -->
