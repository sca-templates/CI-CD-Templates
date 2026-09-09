# CLAUDE.md — repo-specific guidance

## Authority

**AGENTS.md is authoritative for this repository.** Read it first, then
[docs/INDEX.md](docs/INDEX.md).

## Working here

- **The user commits and pushes — never execute `git commit`, `git push`, or
  any other git write on your own.** Draft commits/messages freely, but do not
  stage, reset, amend or otherwise mutate git history without explicit
  authorization.
- This repo is a **library of CI/CD automation primitives** — reusable workflows,
  composite actions, and GitHub Rulesets. It is not a deployable application.
- Reusable workflows must be **flat** in `.github/workflows/` (GitHub constraint).
  Use `shared-` prefix for cross-repo workflows and `stack-` for technology-specific ones.
- Composite actions go in subdirectories under `.github/actions/`.
- Rulesets are JSON files in `.github/rulesets/`, exportable via the GitHub API.
- English only: content, commits, PR descriptions.
- Never commit secrets, tokens, or credentials.

## Documentation

Start at [docs/INDEX.md](docs/INDEX.md). The `docs/` directory contains the
catalog of available workflows, rulesets, and usage instructions.

## Sibling repos

- [infra-kubernetes](https://github.com/sca-templates/infra-kubernetes) — GitOps platform
- [sca-docs](https://github.com/sca-templates/sca-docs) — Organization docs vault
