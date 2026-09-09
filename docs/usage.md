# Usage

How to consume CI-CD templates from this repository.

## Referencing reusable workflows

```yaml
# .github/workflows/ci.yml in the consumer repo
name: CI

on:
  push:
    branches: [main]
  pull_request:

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
    with:
      release-type: "node"
    secrets: inherit
```

## Referencing composite actions

```yaml
# Inside a job step
steps:
  - name: Mint release bot token
    id: app-token
    uses: sca-templates/cicd-templates/.github/actions/mint-app-token@main
    with:
      client-id: ${{ secrets.APP_ID }}
      private-key: ${{ secrets.APP_PRIVATE_KEY }}

  - name: Promote image tag
    uses: sca-templates/cicd-templates/.github/actions/gitops-bump-image@main
    with:
      environment: dev
      service: sca-api
      image-tag: v1.2.3
      bot-token: ${{ steps.app-token.outputs.token }}
```

## Manual deployments (GitOps promote)

Promotion to `dev`, `qa` and `prod` is a manual action. Each service repo declares a thin `workflow_dispatch` wrapper that calls the shared workflow:

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

What happens per environment:

- **dev** — `image.tag` is bumped and committed directly to `main` in the GitOps repository; ArgoCD syncs `dev` immediately.
- **qa** — same direct commit; the QA team runs detailed tests against the new image.
- **prod** — a pull request is opened instead of a direct commit. It is gated: an open release-please PR in the service repository is required before the promotion PR is allowed. A human approves and merges the PR, then ArgoCD deploys to `prod`.

The environments differ in sync policy; `infra-kubernetes` remains the single declarative source applied by ArgoCD to every cluster.

## Applying rulesets

See [rulesets.md](rulesets.md) for API and Terraform examples.

## Versioning

Pin to a major version tag for auto-patches:

```yaml
uses: sca-templates/cicd-templates/.github/workflows/shared-validate-static.yml@v1
```

Or pin to a SHA for maximum safety:

```yaml
uses: sca-templates/cicd-templates/.github/workflows/shared-validate-static.yml@a1b2c3d
```

## Secrets

Most workflows accept `secrets: inherit` for internal repos. For least-privilege, map explicitly:

```yaml
jobs:
  release:
    uses: sca-templates/cicd-templates/.github/workflows/shared-release-flow.yml@main
    secrets:
      APP_ID: ${{ secrets.APP_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

Required secrets:

| Secret | Used by | Description |
|---|---|---|
| `APP_ID` + `APP_PRIVATE_KEY` | `shared-release-flow`, `shared-gitops-promote` | GitHub App credentials; mint a short-lived token with `mint-app-token` |
| `RELEASE_GPG_PRIVATE_KEY` | `shared-release-flow` (optional) | GPG key to sign release tags |

The GitHub App used for promotion must be installed on both the service repository (read: release PR gate) and `infra-kubernetes` (write: image tag bumps).
