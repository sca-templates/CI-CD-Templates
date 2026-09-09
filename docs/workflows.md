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
| Node API | `stack-node.yml` | Node.js/Express: install, lint, test |
| Nest API | `stack-nest.yml` | NestJS: install, lint, format, test, build |

## Usage

```yaml
jobs:
  validate:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-validate-static.yml@main
    with:
      markdown-lint: true
      yaml-lint: true
      actionlint: true

  security:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-security-scan.yml@main

  release:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-release-flow.yml@main
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
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-gitops-promote.yml@main
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

### Stack workflows

Technology-specific workflows for application repos. Consumers call them together with the shared ones:

```yaml
jobs:
  validate:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-validate-static.yml@main

  test:
    uses: sca-templates/CI-CD-Templates/.github/workflows/stack-nest.yml@main
    with:
      node-version: "22"
      build-command: "npm run build"
```

`stack-node.yml` covers plain Node.js and Express (no build step by default); `stack-nest.yml` adds formatter and TypeScript build checks. Both accept `working-directory` for monorepos, overridable `*-command` inputs, and an optional `publish` job (`run-publish`, `image`, `publish-tag`) that builds and pushes the Docker image to GHCR.

## Adding a new technology

1. Create `stack-<tech>-*.yml` in `.github/workflows/`
2. Add composite actions under `.github/actions/<tech>/`
3. Add rulesets under `.github/rulesets/<tech>-*.json`
4. Update this file, `docs/INDEX.md`, and `README.md`
