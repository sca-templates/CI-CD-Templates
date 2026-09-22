# CI-CD-Templates — AI Agent Guide

## What this repo is

Centralized CI/CD templates for the `sca-templates` organization on GitHub. Stores reusable workflows, composite actions, and GitHub Rulesets consumed by all repos in the organization.

This is **not** a deployable application. It is a library of automation primitives.

## Repository structure

```text
.github/
├── workflows/        # Reusable workflows (flat, no subdirs — GitHub constraint)
│   ├── shared-*.yml  # Cross-repo workflows, callable via workflow_call
│   └── self-*.yml    # This repo's own runs of the shared workflows
├── actions/          # Composite actions (subdirs allowed)
│   └── <action-name>/action.yml
├── rulesets/         # GitHub Rulesets (JSON, API-exportable)
│   └── <ruleset>.json
├── ISSUE_TEMPLATE/   # Issue templates
├── PULL_REQUEST_TEMPLATE.md
├── CODEOWNERS
└── dependabot.yml
docs/                 # Catalog and usage docs
```

## Conventions

- English only: content, commits, PR descriptions.
- Conventional commits: `feat(templates): …`, `ci(workflows): …`, `docs(readme): …`.
- Reusable workflows are **flat** in `.github/workflows/` — use the `shared-` prefix for cross-repo workflows and `stack-` for technology-specific ones.
- Composite actions use subdirectories under `.github/actions/`.
- Rulesets are JSON files exportable via the GitHub Rulesets API.
- **Git writes are the user's**: do not `git commit`/`git push` on your own.
- **Never commit** secrets, tokens, or credentials.

## Technology categories

Technologies are identified by prefix in filenames:

- `shared-*` → global (all repos): `shared-security-scan`, `shared-release-flow`, `shared-qa-lock-check`, `shared-codeql`, `shared-service-promote`, `shared-adopt-prod`, `shared-enforce-latest`
- `stack-node` → Node.js/Express (install, lint, test)
- `stack-nest` → NestJS (install, lint, format, test, build)
- Future: `stack-go-*`, `stack-python-*`, etc.

> Local linting (markdown, YAML, shell, actionlint) is consumer-side via
> pre-commit; no shared workflow ships these checks.

## How consumers use this

```yaml
jobs:
  security:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-security-scan.yml@main
```

Workflows use `workflow_call` trigger. Composite actions use `runs.using: composite`.

## Documentation

Start at [docs/INDEX.md](docs/INDEX.md).

## Sibling repos

- [infra-kubernetes](https://github.com/sca-templates/infra-kubernetes) — GitOps platform
- [sca-docs](https://github.com/sca-templates/sca-docs) — Organization-wide documentation vault

## Reference docs

Fetch from [sca-docs](https://github.com/sca-templates/sca-docs) (raw URLs):

- `00-ecosystem/platform-overview.md` — ecosystem vision
- `00-ecosystem/conventions.md` — naming, links, catalogs

Base URL: `https://raw.githubusercontent.com/sca-templates/sca-docs/main/<path>`
