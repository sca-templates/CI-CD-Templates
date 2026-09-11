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
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-validate-static.yml@main
    with:
      markdown-lint: true
      yaml-lint: true
      actionlint: true

  security:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-security-scan.yml@main

  release:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-release-flow.yml@main
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
    uses: sca-templates/CI-CD-Templates/.github/actions/mint-app-token@main
    with:
      client-id: ${{ secrets.APP_ID }}
      private-key: ${{ secrets.APP_PRIVATE_KEY }}

  - name: Promote image tag
    uses: sca-templates/CI-CD-Templates/.github/actions/gitops-bump-image@main
    with:
      environment: dev
      service: sca-api
      image-tag: v1.2.3
      bot-token: ${{ steps.app-token.outputs.token }}
```

## Node, TypeScript and Nest stack workflows

Technology-specific CI for application repos. Pick the template for your stack — `stack-node-js` (JavaScript), `stack-node-ts` (TypeScript, adds a build step) or `stack-nest` (NestJS, adds format and build checks):

```yaml
# .github/workflows/ci.yml in a NestJS consumer repo
jobs:
  validate:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-validate-static.yml@main

  stack:
    uses: sca-templates/CI-CD-Templates/.github/workflows/stack-nest.yml@main
    with:
      node-version: "22"
      working-directory: "services/api"
```

All three templates use the **same fixed commands** (`npm ci`, `npm run lint`, `npm run format:check`, `npm run test:ci`, `npm run build`) toggled by booleans. There are no free-form command inputs.

Available inputs:

| Input | Default | Description |
|---|---|---|
| `node-version` | `22` | Node.js version |
| `working-directory` | `.` | Directory containing `package.json` (monorepos) |
| `run-lint` | `true` | Run `npm run lint` |
| `run-format` | node-ts: `false`; nest: `true` | Run `npm run format:check` |
| `run-test` | `true` | Run `npm run test:ci` |
| `run-build` | node-ts/nest: `true` | Run `npm run build` |
| `run-publish` | `false` | Build and push a Docker image to GHCR |
| `image` | *(required to publish)* | Image name without tag (e.g. `ghcr.io/sca-templates/sca-api`) |
| `publish-tag` | `sha-<commit>` | Image tag to publish |
| `dockerfile` | `Dockerfile` | Path to the Dockerfile |
| `context` | `.` | Docker build context |
| `platforms` | `linux/amd64` | Comma-separated build platforms |

> **Migration:** `stack-node.yml` was replaced by `stack-node-js.yml` and `stack-node-ts.yml`. Custom `*-command` inputs are gone; consumers must use the standard scripts listed above and toggle steps with the boolean inputs.

Publishing images to GHCR requires the **calling workflow** to grant `packages: write` in its top-level `permissions` (the reusable workflow cannot exceed it), plus the consumer repo to have `GITHUB_TOKEN` with `packages: write`. Typical release-driven wiring after the tag is created:

```yaml
# .github/workflows/build.yml in a consumer repo
on:
  push:
    tags: ["v*"]

permissions:
  contents: read
  packages: write
  id-token: write

jobs:
  publish:
    uses: sca-templates/CI-CD-Templates/.github/workflows/stack-nest.yml@main
    with:
      image: ghcr.io/sca-templates/sca-api
      publish-tag: ${{ github.ref_name }}
      run-publish: true
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
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-gitops-promote.yml@main
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
uses: sca-templates/CI-CD-Templates/.github/workflows/shared-validate-static.yml@v1
```

Or pin to a SHA for maximum safety:

```yaml
uses: sca-templates/CI-CD-Templates/.github/workflows/shared-validate-static.yml@a1b2c3d
```

## Secrets

Most workflows accept `secrets: inherit` for internal repos. See
[secrets.md](secrets.md) for the release automation secrets and where to
configure them. For least-privilege, map explicitly:

```yaml
jobs:
  release:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-release-flow.yml@main
    secrets:
      APP_ID: ${{ secrets.APP_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

Required secrets and where to configure them: see [secrets.md](secrets.md).

The GitHub App used for promotion must be installed on both the service repository (read: release PR gate) and `infra-kubernetes` (write: image tag bumps).
