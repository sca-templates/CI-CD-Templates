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
| Auto Label | `shared-auto-label.yml` | Assign labels to PRs from type, changed files, and stack (idempotent, add-only) |
| Node.js | `stack-node-js.yml` | JavaScript/Express: install, lint, test; optional publish |
| Node TypeScript | `stack-node-ts.yml` | TypeScript: install, lint, test, build; optional publish |
| Nest | `stack-nest.yml` | NestJS: install, lint, format, test, build; optional publish |

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

### Auto Label

Assigns labels to pull requests on PR events. Detection: conventional-commit prefixes and keywords in the title, changed files (`package-lock.json`, workflows, `SECURITY.md`, docs), Dependabot authorship, and optional stack labels (`node`, `nest`, `python`, `java`, `go`, `rust`, `php`, `dotnet`). Add-only and idempotent; can ensure the global label set exists (`ensure-labels`).

```yaml
# .github/workflows/ci.yml in a consumer repo
on:
  pull_request:
    types: [opened, reopened, synchronize]

jobs:
  label:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-auto-label.yml@main
    with:
      type-labels: true
      stack-labels: true
      ensure-labels: true
```

Requires `permissions: pull-requests: write` and `issues: write` on the calling workflow. Full reference: [docs/automations.md](automations.md).

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
```

`stack-node-js.yml` covers plain JavaScript and Express; `stack-node-ts.yml` adds a build step for TypeScript projects; `stack-nest.yml` adds formatter and build checks for NestJS. The three use the **same fixed commands** (`npm ci`, `npm run lint`, `npm run format:check`, `npm run test:ci`, `npm run build`) toggled by booleans — there are no free-form `*-command` inputs. All accept `working-directory` for monorepos and an optional `publish` job (`run-publish`, `image`, `publish-tag`) that builds and pushes the Docker image to GHCR.

> **Migration:** `stack-node.yml` was replaced by `stack-node-js.yml` and `stack-node-ts.yml`. If you called `stack-node` with custom `*-command` inputs, switch to the matching template and align your `package.json` scripts with the fixed commands above.

## Adding a new technology

1. Create `stack-<tech>-*.yml` in `.github/workflows/`
2. Add composite actions under `.github/actions/<tech>/`
3. Add rulesets under `.github/rulesets/<tech>-*.json`
4. Update this file, `docs/INDEX.md`, and `README.md`
