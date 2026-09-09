# Shared Workflows

All shared workflows live flat in `.github/workflows/` (GitHub does not support subdirectories). Consumers call them via `uses:`.

## Catalog

| Workflow | File | Description |
|---|---|---|
| Static Validation | `shared-validate-static.yml` | Markdown, YAML, shell, actionlint |
| Security Scan | `shared-security-scan.yml` | gitleaks, osv-scanner, license check |
| Release Flow | `shared-release-flow.yml` | release-please + signed tags |
| QA Lock Check | `shared-qa-lock-check.yml` | Block merges while release PR open |
| CodeQL | `shared-codeql.yml` | CodeQL static analysis (GitHub Actions) |
| Scorecard | `shared-scorecard.yml` | OpenSSF Scorecard supply-chain security |
| GitOps Promote | `shared-gitops-promote.yml` | Promote service image tags into `infra-kubernetes` (commit or PR, prod release gate) |

## Usage

```yaml
jobs:
  validate:
    uses: sca-templates/cicd-templates/.github/workflows/shared-validate-static.yml@main
    with:
      markdown-lint: true
      yaml-lint: true
      actionlint: true

  security:
    uses: sca-templates/cicd-templates/.github/workflows/shared-security-scan.yml@main

  release:
    uses: sca-templates/cicd-templates/.github/workflows/shared-release-flow.yml@main
    secrets:
      APP_ID: ${{ secrets.APP_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

### GitOps promote (manual dispatch wrapper)

Promotions are manual. Each service repo declares a thin `workflow_dispatch` wrapper that calls the shared workflow, so a human picks the environment and image tag:

```yaml
# .github/workflows/deploy.yml in the service repo
name: Deploy

on:
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [dev, qa, prod]
      image-tag:
        required: true
        type: string

jobs:
  deploy:
    uses: sca-templates/cicd-templates/.github/workflows/shared-gitops-promote.yml@main
    with:
      environment: ${{ inputs.environment }}
      service: <service-name>
      image-tag: ${{ inputs.image-tag }}
    secrets: inherit
```

Behavior by environment:

| Environment | Applies to `infra-kubernetes` via | Notes |
|---|---|---|
| dev | direct commit to `main` | fastest feedback loop |
| qa | direct commit to `main` | team runs detailed tests |
| prod | pull request + human approval | gated: requires an open release-please PR first |

See [usage.md](usage.md) for the full reference.

## Adding a new technology

1. Create `shared_<tech>-*.yml` in `.github/workflows/`
2. Add composite actions under `.github/actions/<tech>/`
3. Add rulesets under `.github/rulesets/<tech>-*.json`
4. Update this file, `docs/INDEX.md`, and `README.md`
