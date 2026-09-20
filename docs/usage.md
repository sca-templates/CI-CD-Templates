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
  - name: Mint bot token
    id: app-token
    uses: sca-templates/CI-CD-Templates/.github/actions/mint-app-token@main
    with:
      client-id: ${{ secrets.APP_ID }}
      private-key: ${{ secrets.APP_PRIVATE_KEY }}

  - name: Inspect the deployment state with the bot token
    env:
      GH_TOKEN: ${{ steps.app-token.outputs.token }}
    run: gh api "/repos/${{ github.repository }}/rulesets" --jq '.[].name'
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

## Deploying a service (deploy model)

Deployments follow a trunk-based model with ArgoCD/GitOps — there is no release
PR for deployments. The full contract is in
[service-release-model.md](service-release-model.md); the short version:

- **dev / qa** — a commit is promoted by force-pushing the `deploy/dev` or
  `deploy/qa` branch ref of the **service repo**. ArgoCD Applications track
  those refs, so the ref move is the deployment:
  `shared-service-promote.yml`.
- **prod** — a release tag `vX.Y.Z` is pinned in the GitOps registry
  (`argocd/services-prod.yaml` in `infra-kubernetes`) through a
  `chore(services): …` pull request: `shared-adopt-prod.yml`. A human approves
  and merges; ArgoCD syncs `prod` in the manual sync window (ADR-003).
- **latest** — GitHub `latest` is a marker of reality: the exact version
  running in prod. A reconcile loop in `infra-kubernetes` reads the ArgoCD
  state and calls `shared-enforce-latest.yml` (or the optional fast-path on
  `release published`).

Two org bot apps split the planes:

| Bot | Plane | Used by |
|---|---|---|
| `sca-bot-release` | release (tags, release PRs, GPG) | `shared-release-flow.yml` |
| `sca-deploy-bot` | deploy (deploy refs, prod pins, latest marker) | `shared-service-promote.yml`, `shared-adopt-prod.yml`, `shared-enforce-latest.yml` |

```yaml
# .github/workflows/promote.yml in the service repo
name: Promote

on:
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [dev, qa]
      service:
        required: true
        type: string

jobs:
  promote:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-service-promote.yml@main
    with:
      environment: ${{ inputs.environment }}
      service: ${{ inputs.service }}
    secrets: inherit
```

For prod the reconciler (or a human) calls `shared-adopt-prod.yml` with the
release tag and `shared-enforce-latest.yml` to keep `latest` truthful. See
[service-release-model.md](service-release-model.md) for wiring, roles, inputs
and the migration from the retired `shared-gitops-promote.yml`.

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

The GitHub Apps must be installed on the repositories they act on: `sca-bot-release` on every repo that calls `shared-release-flow.yml`; `sca-deploy-bot` on the service repos **and** `infra-kubernetes` (deploy refs and prod pins). See [secrets.md](secrets.md).
