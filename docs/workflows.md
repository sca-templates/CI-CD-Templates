# Shared Workflows

All shared workflows live flat in `.github/workflows/` (GitHub does not support subdirectories). Consumers call them via `uses:`.

## Catalog

| Workflow | File | Description |
|---|---|---|
| Static Validation | `shared-validate-static.yml` | Markdown, YAML, shell, actionlint |
| Security Scan | `shared-security-scan.yml` | gitleaks, osv-scanner, license check, SonarQube Cloud, Semgrep (OWASP), OWASP Dependency-Check |
| Release Flow | `shared-release-flow.yml` | release-please + signed tags + optional release-PR auto-merge |
| QA Lock Check | `shared-qa-lock-check.yml` | Block merges while release PR open |
| CodeQL | `shared-codeql.yml` | CodeQL static analysis (GitHub Actions) |
| Scorecard | `shared-scorecard.yml` | OpenSSF Scorecard supply-chain security |
| Service Promote | `shared-service-promote.yml` | Promote a selected branch/tag/commit to `deploy/<env>` (dev/qa) so ArgoCD tracks it; QA requires human approval |
| Adopt Prod | `shared-adopt-prod.yml` | Pin a release tag as the version running in prod (GitOps registry, PR or direct commit) |
| Enforce Latest | `shared-enforce-latest.yml` | Correct GitHub `latest` release to the version actually deployed in prod |
| Auto Label | `shared-auto-label.yml` | Assign labels to PRs from type, changed files, and stack (idempotent, add-only) |
| Changelog Notify | `shared-changelog-notify.yml` | Post release summaries to Slack or Discord; skips silently when no webhook |
| Stale Notify | `shared-stale-notify.yml` | Comment on inactive issues and PRs; never closes or labels them |
| Node.js | `stack-node-js.yml` | JavaScript/Express: install, lint, test; optional publish |
| Node TypeScript | `stack-node-ts.yml` | TypeScript: install, lint, test, build; optional publish |
| Nest | `stack-nest.yml` | NestJS: install, lint, format, test, build; optional publish |
| DAST (OWASP ZAP) | `shared-dast.yml` | OWASP ZAP baseline/full scan against a running service URL |

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

### Security Scan

The single entry point for every repo's security checks. All jobs are **on by
default** and **skip silently** when their required secret is missing (same
pattern as Changelog Notify), so a repo pulls the whole suite with one
`uses:` line and the jobs light up as the org configures its secrets.

| Job | Tool | Secret required | Behavior |
|---|---|---|---|
| Secrets | gitleaks | — | Fails on findings; SARIF to code scanning |
| Dependency Vulnerabilities | osv-scanner | — | Fails on findings |
| License | *todo* | — | Off by default (`license-check`) |
| SonarQube Cloud | sonarqube-scan-action | `SONAR_TOKEN` | SAST; skipped silently without the token |
| Semgrep (OWASP rules) | Semgrep CE | — | SAST, SARIF to code scanning; report-only unless `semgrep-fail-on` |
| Dependency Vulnerabilities (OWASP) | OWASP Dependency-Check | `NVD_API_KEY` | NVD/CPE SCA; fails on CVSS ≥ `fail-on-cvss`; skipped silently without the key |

All jobs are **100% free at the org scale** and upgrade to paid tiers without
changing the templates: SonarQube's free tier covers private code up to **50k
LOC** (public repos are unlimited), Semgrep CE is open source, and the NVD API
key is free from [NIST](https://nvd.nist.gov/developers/request-an-api-key).

SonarQube Cloud projects are auto-created on the first analysis from an
organization token. Set `SONAR_ORGANIZATION` (or `SONAR_PROJECT_KEY`) on the
caller to pin them, or commit a `sonar-project.properties` per repo.

```yaml
jobs:
  security:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-security-scan.yml@main
    with:
      sonar: true
      sonar-organization: sca-templates
      sonar-project-key: sca-api
      semgrep: true
      semgrep-config: "p/owasp-top-ten"
      semgrep-fail-on: true
      dependency-check: true
      fail-on-cvss: "7"
      suppression-file: ".dependency-check/suppressions.xml"
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      NVD_API_KEY: ${{ secrets.NVD_API_KEY }}
```

> **Callers must grant `security-events: write` at workflow level.** The
> `semgrep` and `dependency-check` jobs request it to upload SARIF results to
> code scanning, and GitHub validates reusable-workflow permissions statically
> against the caller's `permissions:` block. Callers without it fail before the
> workflow starts. The `sonarqube` job only needs `contents: read`.
>
> **Dependency-Check is the slowest job** (NVD data sync). Prefer running the
> security scan on `push` to `main` plus a schedule, or keep the fast gates
> (gitleaks + osv-scanner) on every PR and run the full scan on the
> schedule.

Inputs:

| Input | Default | Description |
|---|---|---|
| `gitleaks` | `true` | Run gitleaks secret scanning |
| `osv-scan` | `true` | Run osv-scanner dependency scan |
| `license-check` | `false` | Run the (not yet implemented) license check |
| `license-allowed` | `MIT,Apache-2.0,ISC,BSD-2-Clause,BSD-3-Clause` | Allowed SPDX licenses |
| `sonar` | `true` | Run SonarQube Cloud SAST |
| `sonar-organization` | `""` | SonarQube Cloud organization key (else `sonar-project.properties`) |
| `sonar-project-key` | `""` | SonarQube project key (else `sonar-project.properties`) |
| `semgrep` | `true` | Run Semgrep static analysis |
| `semgrep-config` | `p/ci` | Semgrep rules: `p/ci`, `p/owasp-top-ten`, `p/secrets`, or a local path |
| `semgrep-fail-on` | `false` | Fail the job on Semgrep findings (report-only by default) |
| `dependency-check` | `true` | Run OWASP Dependency-Check |
| `fail-on-cvss` | `7` | Fail Dependency-Check on findings with CVSS ≥ this score |
| `suppression-file` | `""` | Path to a Dependency-Check suppression XML |

Secrets: `SONAR_TOKEN`, `NVD_API_KEY` (both optional, see
[secrets.md](secrets.md)).

### DAST (OWASP ZAP)

For **services** with a running URL (staging/dev), not for library repos. Run it
on a schedule, not as a PR gate. When `target-url` is empty every job is
skipped (used by the repo's own `self-dast.yml`).

```yaml
# .github/workflows/dast.yml in a service repo
name: DAST

on:
  schedule:
    - cron: "0 8 * * 1"
  workflow_dispatch:

permissions:
  contents: read
  security-events: write

jobs:
  dast:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-dast.yml@main
    with:
      target-url: https://qa.example.com
      scan-type: baseline # or full
      fail-on-alerts: false
```

SARIF is uploaded to code scanning with category `dast-zap`; the HTML report is
attached as the `zap-reports` artifact.

**Note on SonarQube PR decoration:** SonarQube Cloud reports the PR quality
gate through its own GitHub integration (SonarQube app or checks). The
workflow only needs `contents: read`; no looser permissions are required.

> **Callers must grant `pull-requests: write` at workflow level.** The nested
> `auto-merge` job requests it, and GitHub validates reusable-workflow
> permissions **statically** against the caller's `permissions:` block — a
> caller that only grants `contents: read` fails before the workflow starts,
> even if `auto-merge-release-pr` is left `false`. The auto-merge itself is
> executed with the release bot token, so the write scope only widens the
> caller's `GITHUB_TOKEN` for PR operations.

### Service Promote (ArgoCD sync)

Syncs the service's `dev` or `qa` ArgoCD Application to a selected revision via
the ArgoCD API — no git refs, no force-push, no PR. Applications track `main`
(see the infra registry) and the sync points the environment at the commit
whose head you select. Implements the trunk-based model documented in
[service-release-model.md](service-release-model.md).

Select the branch, tag or commit you want everyone to test in dev/qa, run the
workflow, and that revision becomes the environment. The `revision` input is a
plain string, so consumers usually expose a `branch` input on
`workflow_dispatch`:

```yaml
# .github/workflows/promote.yml in the service repo
name: Promote

on:
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [dev, qa]
      branch:
        description: Branch or tag to deploy
        type: string
        default: main
      service:
        required: true

jobs:
  promote:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-service-promote.yml@main
    with:
      environment: ${{ inputs.environment }}
      revision: ${{ inputs.branch }}
      service: ${{ inputs.service }}
    secrets: inherit
```

The workflow resolves the revision to its commit (branch head, else annotated
or lightweight tag via `git ls-remote`), logs it, and runs the
`argocd-app-sync` action (`argocd app sync <app> --revision <commit> [--prune]`).
The app defaults to `<service>-<environment>`; pass `app` to override. The
`prune` input defaults to `true`, except for `qa` where it defaults to `false`
(ADR-003: qa is synced without pruning). The
sync reads `ARGOCD_SERVER` / `ARGOCD_TOKEN` secrets: store them at repository
level and pass them explicitly, or scope them to the `dev`/`qa` GitHub
Environments and use `secrets: inherit` (the job targets that environment, so
the environment secrets are resolved there).

`run-publish: true` additionally builds and pushes the `sha-<commit>` image to
GHCR (exact `stack-nest.yml` publish pattern, `packages: write` on the job).
`dry-run: true` reports the revision/app without syncing and skips publishing.

> **Callers must grant `packages: write` at workflow level.** The nested
> `publish` job requests it, and GitHub validates reusable-workflow permissions
> **statically** against the caller's `permissions:` block — a caller that only
> grants `contents: read` fails before the workflow starts, even in
> `dry-run: true`.
>
> **Tokens are scoped ArgoCD API users, not cluster credentials.** Create a
> restricted role in ArgoCD (RBAC: `sync`/`get` on `<service>-dev` and
> `<service>-qa`) and issue a token for it; the Action only ever speaks to the
> ArgoCD server, so no kubeconfig is needed in CI. See
> [service-release-model.md](service-release-model.md).

#### QA approval (not a PR)

A real (non-`dry-run`) promote to `qa` runs against the GitHub `qa`
Environment. Configure **Required reviewers** on it (Settings → Environments →
`qa`, up to 6 people/teams): the run pauses at the `promote` job with
"Waiting for approval", and the sync only runs after one reviewer approves in
the Actions UI. Dev promotes never wait.

- The environment and its reviewers are **per consumer repo**; the template only
  references `qa` by name. Repos that leave the environment without reviewers
  (or let it auto-create) keep the old no-approval behavior.
- Required reviewers are only available for **public** repos on Free/Pro/Team
  plans; **private** repos need an Enterprise Cloud plan.
- A QA promote holds the `service+qa` concurrency lock while waiting for
  approval, so subsequent QA promotes queue instead of racing.
- Note: because the approval gates the whole `promote` job, a `dry-run` to `qa`
  also requires approval (use `dev` for free dry-runs).

### Adopt Prod (version pin)

Pins a release tag as the version running in prod inside the GitOps registry
(`argocd/services-prod.yaml` by default) via a pull request
`adopt/<service>-<tag>` or a direct commit. The tag must already exist in the
service repo (`gh release view`), unless `skip-tag-check: true`.

The registry is an `ApplicationSet` shaped as a `list` generator, so the pin is
read and written at the service's **element**:
`.spec.generators[0].list.elements[] | select(.name == "<service>") | .version`.
Pass `yq-expression` / `set-expression` to override for a different schema. The
workflow fails fast when the service is not registered in the list yet.

```yaml
jobs:
  adopt:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-adopt-prod.yml@main
    with:
      service: sca-api
      release-tag: v1.2.3
    secrets: inherit
```

The prod pin is the single source of truth `shared-enforce-latest.yml` reads
back from. In the per-service flow this is wired through
[docs/examples/deploy-prod.yml](examples/deploy-prod.yml) (`action: adopt`).

### Enforce Latest (latest = reality)

Reads the version pinned in the GitOps registry (or an explicit
`release-tag`), validates it is semver, harmonizes the release list
(pre-releases for every full release newer than the deployed tag, restore
of older ones), and marks the deployed tag as GitHub `latest`. `dry-run: true`
reports without mutating. By default the pin is read from the service's
`ApplicationSet` element in the registry
(`.spec.generators[0].list.elements[] | select(.name == "<service>") | .version`).

```yaml
jobs:
  enforce:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-enforce-latest.yml@main
    with:
      service: sca-api
    secrets: inherit
```

Outputs: `release-tag`, `changed`, `current-latest`.

In the per-service flow this runs **after** the prod `Sync` has applied the
version, via [docs/examples/deploy-prod.yml](examples/deploy-prod.yml)
(`action: mark-latest`). See [service-release-model.md](service-release-model.md)
for the full deployment contract and the bots involved.

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
