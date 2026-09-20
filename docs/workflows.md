# Shared Workflows

All shared workflows live flat in `.github/workflows/` (GitHub does not support subdirectories). Consumers call them via `uses:`.

## Catalog

| Workflow | File | Description |
|---|---|---|
| Static Validation | `shared-validate-static.yml` | Markdown, YAML, shell, actionlint |
| Security Scan | `shared-security-scan.yml` | gitleaks, osv-scanner, license check |
| Release Flow | `shared-release-flow.yml` | release-please + signed tags + optional release-PR auto-merge |
| QA Lock Check | `shared-qa-lock-check.yml` | Block merges while release PR open |
| CodeQL | `shared-codeql.yml` | CodeQL static analysis (GitHub Actions) |
| Scorecard | `shared-scorecard.yml` | OpenSSF Scorecard supply-chain security |
| Service Promote | `shared-service-promote.yml` | Move `deploy/<env>` refs (dev/qa) so ArgoCD tracks the promoted commit |
| Adopt Prod | `shared-adopt-prod.yml` | Pin a release tag as the version running in prod (GitOps registry, PR or direct commit) |
| Enforce Latest | `shared-enforce-latest.yml` | Correct GitHub `latest` release to the version actually deployed in prod |
| Auto Label | `shared-auto-label.yml` | Assign labels to PRs from type, changed files, and stack (idempotent, add-only) |
| Changelog Notify | `shared-changelog-notify.yml` | Post release summaries to Slack or Discord; skips silently when no webhook |
| Stale Notify | `shared-stale-notify.yml` | Comment on inactive issues and PRs; never closes or labels them |
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

### Service Promote (dev/qa refs)

Moves the `deploy/dev` or `deploy/qa` branch ref of the service repo to a target
commit (`--force` by the deploy bot). ArgoCD Applications point at these refs,
so the ref move is the promotion. Implements the trunk-based model documented in
[service-release-model.md](service-release-model.md).

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

jobs:
  promote:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-service-promote.yml@main
    with:
      environment: ${{ inputs.environment }}
      service: ${{ inputs.service }}
    secrets: inherit
```

`run-publish: true` additionally builds and pushes the `sha-<commit>` image to
GHCR (exact `stack-nest.yml` publish pattern, `packages: write` on the job).
`dry-run: true` reports the ref move without pushing.

### Adopt Prod (version pin)

Pins a release tag as the version running in prod inside the GitOps registry
(`argocd/services-prod.yaml` by default) via a pull request
`adopt/<service>-<tag>` or a direct commit. The tag must already exist in the
service repo (`gh release view`), unless `skip-tag-check: true`.

```yaml
jobs:
  adopt:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-adopt-prod.yml@main
    with:
      service: sca-api
      release-tag: v1.2.3
    secrets: inherit
```

The prod pin is the single source of truth the reconcile loop reads back from.

### Enforce Latest (latest = reality)

Reads the version pinned in the GitOps registry (or an explicit
`release-tag`), validates it is semver, harmonizes the release list
(pre-releases for every full release newer than the deployed tag, restore
of older ones), and marks the deployed tag as GitHub `latest`. `dry-run: true`
reports without mutating.

```yaml
jobs:
  enforce:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-enforce-latest.yml@main
    with:
      service: sca-api
    secrets: inherit
```

Outputs: `release-tag`, `changed`, `current-latest`.

See [service-release-model.md](service-release-model.md) for the full
deployment contract, the bots involved, and the reconciliation loop.

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

### Changelog Notify

Posts the release notes summary to Slack or Discord whenever a release is
published. When the `WEBHOOK_URL` secret is not configured the notification is
**silently skipped** — the workflow succeeds without warnings or failures.

```yaml
# .github/workflows/release-notify.yml in a consumer repo
name: Release Notify

on:
  release:
    types: [published]

jobs:
  notify:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-changelog-notify.yml@main
    with:
      platform: slack
      summary-lines: 7
    secrets:
      WEBHOOK_URL: ${{ secrets.WEBHOOK_URL }}
```

Full reference: [docs/automations.md](automations.md).

### Stale Notify

Comments on issues and pull requests that have been inactive for longer than a
threshold. It **never closes, deletes, or labels** anything — it only posts a
reminder (once, or twice when `remind-again` is on). Runs on a schedule.

```yaml
# .github/workflows/stale.yml in a consumer repo
name: Stale

on:
  schedule:
    - cron: "0 7 * * 1"

permissions:
  contents: read
  issues: write
  pull-requests: write

jobs:
  stale:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-stale-notify.yml@main
    with:
      issues-days: 30
      prs-days: 21
      remind-again: true
```

Full reference: [docs/automations.md](automations.md).

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
