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
| Security Scan | `shared-security-scan.yml` | gitleaks secret scanning + osv-scanner dependency vulnerabilities |
| Release Flow | `shared-release-flow.yml` | release-please + signed tags, optional release-PR auto-merge |
| QA Lock Check | `shared-qa-lock-check.yml` | Block merges while release PR open |
| CodeQL | `shared-codeql.yml` | CodeQL static analysis (GitHub Actions) |
| Service Promote | `shared-service-promote.yml` | Sync the `dev`/`qa` ArgoCD Application to a selected revision (ArgoCD API, no git refs) |
| Adopt Prod | `shared-adopt-prod.yml` | Pin the running release tag as the prod version in the GitOps registry |
| Enforce Latest | `shared-enforce-latest.yml` | Correct GitHub `latest` to the version actually running in prod |
| Auto Label | `shared-auto-label.yml` | Assign labels to PRs from type, changed files, and stack (idempotent, add-only) |
| Changelog Notify | `shared-changelog-notify.yml` | Post release summaries to Slack or Discord; skips silently when no webhook |

### Stack workflows

| Workflow | File | Description |
|---|---|---|
| Node.js | `stack-node-js.yml` | JavaScript/Express: install, lint, test; optional publish |
| Node TypeScript | `stack-node-ts.yml` | TypeScript: install, lint, test, build; optional publish |
| Nest | `stack-nest.yml` | NestJS: install, lint, format, test, build; optional publish |

### Composite actions

| Action | File | Description |
|---|---|---|
| Configure AWS Env | `configure-aws-env` | Expand the AWS environment (`AWS_MODE` local/cloud) before any AWS step |
| ArgoCD App Sync | `argocd-app-sync` | Sync an ArgoCD Application to a revision via the API with a scoped token |
| Mint App Token | `mint-app-token` | Issue a GitHub App installation token for automation git writes |
| Notify Release | `notify-release` | Post release summaries to Slack or Discord |

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
  security:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-security-scan.yml@main
  release:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-release-flow.yml@main
    secrets:
      APP_ID: ${{ secrets.APP_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

> Local linting (markdown, YAML, shell, actionlint) is expected via pre-commit
> on each consumer; the shared catalog only ships merge-relevant gates that
> need CI. See [docs/usage.md](docs/usage.md).

```yaml
# .github/workflows/promote.yml in your service repo
name: Promote
on:
  workflow_dispatch:
    inputs:
      environment: { type: choice, options: [dev, qa] }
      branch: { type: string, default: main }
      service: { required: true }

jobs:
  promote:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-service-promote.yml@main
    with:
      environment: ${{ inputs.environment }}
      revision: ${{ inputs.branch }}
      service: ${{ inputs.service }}
    secrets: inherit
```

The promote workflow resolves the selected revision to its commit and syncs the
service's `dev`/`qa` ArgoCD Application through the ArgoCD API
(`ARGOCD_SERVER` / `ARGOCD_TOKEN` secrets, scoped to the service's apps).

See [docs/usage.md](docs/usage.md) for full reference and
[docs/service-release-model.md](docs/service-release-model.md) for the
deploy model behind ArgoCD syncs, prod pins, and the `latest` marker.

## Documentation

- [Documentation index](docs/INDEX.md)
- [Workflows catalog](docs/workflows.md)
- [Rulesets catalog](docs/rulesets.md)
- [Environments](docs/environments.md)
- [Automations](docs/automations.md)
- [Usage guide](docs/usage.md)
- [Service release model](docs/service-release-model.md)

## License

MIT
