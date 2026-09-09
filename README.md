# CI-CD-Templates

Centralized, reusable CI/CD templates for the [sca-templates](https://github.com/sca-templates) organization. Global and technology-specific workflows, composite actions, and GitHub Rulesets.

## What's inside

```text
.github/
├── workflows/        # Shared workflows (workflow_call)
├── actions/          # Composite actions
├── rulesets/         # GitHub Rulesets (JSON, API-exportable)
├── ISSUE_TEMPLATE/   # Issue templates
├── PULL_REQUEST_TEMPLATE.md
├── CODEOWNERS
└── dependabot.yml
```

## Available templates

### Shared workflows

| Workflow | File | Description |
|---|---|---|
| Static Validation | `shared-validate-static.yml` | Markdown, YAML, shell, actionlint |
| Security Scan | `shared-security-scan.yml` | gitleaks, osv-scanner, license check |
| Release Flow | `shared-release-flow.yml` | release-please + signed tags |
| QA Lock Check | `shared-qa-lock-check.yml` | Block merges while release PR open |
| CodeQL | `shared-codeql.yml` | CodeQL static analysis (GitHub Actions) |
| Scorecard | `shared-scorecard.yml` | OpenSSF Scorecard supply-chain security |

### Stack workflows

| Workflow | File | Description |
|---|---|---|
| Node API | `stack-node.yml` | Node.js/Express: install, lint, test |
| Nest API | `stack-nest.yml` | NestJS: install, lint, format, test, build |

### Rulesets

| Ruleset | File | Description |
|---|---|---|
| Main Protected | `main-protected.json` | Require review, squash merge, status checks |
| Branch Naming | `allowed-branches-only.json` | Enforce branch naming conventions |

## Quick start

```yaml
# .github/workflows/ci.yml in your repo
name: CI
on: [push, pull_request]

jobs:
  validate:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-validate-static.yml@main
  security:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-security-scan.yml@main
  release:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-release-flow.yml@main
    secrets:
      APP_ID: ${{ secrets.APP_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

See [docs/usage.md](docs/usage.md) for full reference.

## Documentation

- [Documentation index](docs/INDEX.md)
- [Workflows catalog](docs/workflows.md)
- [Rulesets catalog](docs/rulesets.md)
- [Usage guide](docs/usage.md)

## License

MIT
