# Shared Workflows

All shared workflows live flat in `.github/workflows/` (GitHub does not support subdirectories). Consumers call them via `uses:`.

## Catalog

| Workflow | File | Description |
|---|---|---|
| Security Scan | `shared-security-scan.yml` | gitleaks secret scanning + osv-scanner dependency vulnerabilities + optional checkov IaC scan |
| Validate | `shared-validate.yml` | Repository hygiene: markdownlint + link check, yamllint + `bash -n`, actionlint |
| Release Flow | `shared-release-flow.yml` | release-please + signed tags + optional release-PR auto-merge + `latest` hold policy |
| QA Lock Check | `shared-qa-lock-check.yml` | Block merges while release PR open (bot PRs exempt) |
| CodeQL | `shared-codeql.yml` | CodeQL static analysis (GitHub Actions) |
| Service Promote | `shared-service-promote.yml` | Sync the service's dev/qa ArgoCD Application to a selected branch/tag/commit via the ArgoCD API — no PR and no `deploy/*` ref; QA pauses for human approval when Required reviewers are configured |
| Adopt Prod | `shared-adopt-prod.yml` | Pin a release tag as the version running in prod (GitOps registry, PR or direct commit) |
| Enforce Latest | `shared-enforce-latest.yml` | Correct GitHub `latest` release to the version actually deployed in prod (optional signed-tag check and forward-only guard) |
| Auto Label | `shared-auto-label.yml` | Assign labels to PRs from type, changed files, and stack (idempotent, add-only) |
| Changelog Notify | `shared-changelog-notify.yml` | Post release summaries to Slack or Discord; skips silently when no webhook |
| Node.js | `stack-node-js.yml` | JavaScript/Express: install, lint, test; optional publish |
| Node TypeScript | `stack-node-ts.yml` | TypeScript: install, lint, test, build; optional publish |
| Nest | `stack-nest.yml` | NestJS: install, lint, format, test, build; optional publish |
| NPM Publish | `stack-npm-publish.yml` | Publish a package to npm from a tag (pnpm or npm), with tag↔manifest version check and dry-run |

### Composite actions

| Action | File | Description |
|---|---|---|
| Setup Node project | `setup-node-project` | Install the package manager (npm or pnpm), set up Node.js and install dependencies — the single setup step every `stack-*` job uses |

> **Local linting vs CI:** `shared-validate.yml` ships markdown, YAML, shell and
> actionlint checks for consumers that want them in CI; the same checks also run
> here as **pre-commit** hooks. This repo enforces its own structure invariants
> via `scripts/test-templates.sh` (pre-commit hook `template-structure`) — see
> `.pre-commit-config.yaml`.

## Usage

```yaml
jobs:
  security:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-security-scan.yml@main

  release:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-release-flow.yml@main
    secrets:
      APP_ID: ${{ secrets.APP_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

> **Callers must grant `pull-requests: write` at workflow level.** The nested
> `auto-merge` job requests it, and GitHub validates reusable-workflow
> permissions **statically** against the caller's `permissions:` block — a
> caller that only grants `contents: read` fails before the workflow starts,
> even if `auto-merge-release-pr` is left `false`. The auto-merge itself is
> executed with the release bot token, so the write scope only widens the
> caller's `GITHUB_TOKEN` for PR operations.

### Security Scan

The single entry point for every repo's security checks. Fast, no-secret jobs
that can gate every PR:

| Job | Tool | Behavior |
|---|---|---|
| Secrets | gitleaks | Fails on findings; SARIF to code scanning (non-PR events only) |
| Dependency Vulnerabilities | osv-scanner | Fails on findings |
| IaC posture | checkov | Optional (`iac: true`); fails on findings, honors a baseline file |

Dependency advisory PRs are left to **Dependabot** (native, zero Actions
minutes). SAST surfaces that used to live here (SonarQube, Semgrep,
Dependency-Check) were retired as redundant with CodeQL.

```yaml
jobs:
  security:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-security-scan.yml@main
    with:
      gitleaks: true
      osv-scan: true
      iac: true
      iac-framework: kubernetes
```

Inputs:

| Input | Default | Description |
|---|---|---|
| `gitleaks` | `true` | Run gitleaks secret scanning |
| `osv-scan` | `true` | Run osv-scanner dependency scan |
| `iac` | `false` | Run checkov infrastructure-as-code scan |
| `iac-framework` | `kubernetes` | checkov `--framework` value (`kubernetes`, `terraform`, …) |
| `iac-directory` | `.` | Directory scanned by checkov |
| `iac-baseline` | `.github/checkov-baseline.json` | Baseline file, applied only when present |
| `iac-requirements` | `.github/requirements.txt` | Hash-pinned requirements file used to install checkov |

### Validate (repository hygiene)

Repository-hygiene checks that were previously duplicated in each consumer's
`validate` workflow. Three independent, opt-in jobs:

| Job | Tools | Default |
|---|---|---|
| Markdown | `markdownlint-cli2` + `markdown-link-check` | `markdown: true`, `markdown-links: true` |
| YAML and Shell | `yamllint` + `bash -n` | `yaml: true` |
| Workflow lint | `actionlint` | `actionlint: true` |

```yaml
jobs:
  validate:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-validate.yml@main
    with:
      markdown-link-paths: "README.md docs"
      shell-glob: "bootstrap/*.sh"
```

Inputs: `markdown`, `markdown-glob`, `markdown-links`, `markdown-link-config`,
`markdown-link-paths`, `yaml`, `yaml-config`, `yaml-requirements`, `shell-glob`,
`actionlint`, `node-version`. `yamllint` is installed from a hash-pinned
requirements file (`--require-hashes`), so the consumer ships
`.github/requirements-yamllint.txt`. Technology-specific manifest validation
(kubeconform, helm template/lint, kube-linter) is deliberately **not** part of
this reusable — it stays in the consumer.

### Release Flow (`latest` policy)

release-please opens a release PR and, on merge, creates the tag and GitHub
Release; `sign-tag` re-signs the tag with the release-bot GPG key. Two optional
policies:

- `latest-policy: claim` (default) — the new release claims GitHub `latest`, as
  release-please does today.
- `latest-policy: hold` — the workflow publishes the release but restores the
  previous `latest` pointer, so only a separate promote workflow (e.g.
  `shared-adopt-prod` + `shared-enforce-latest`) ever moves it forward. Enabling
  `hold` requires a release-bot public key in the caller repo (`latest-gpg-key`,
  default `.github/release-bot-gpg.pub`); the tag signature is verified before
  the pointer is touched.

Because `make_latest=false` stores no pointer (the API falls back to the newest
release), `hold` publishes the release and then re-asserts the previous pointer
with a single PATCH, and reads the result back. A re-run is safe: the snapshot
excludes the tag this push cut.

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
    secrets:
      ARGOCD_SERVER: ${{ secrets.ARGOCD_SERVER }}
      ARGOCD_TOKEN: ${{ secrets.ARGOCD_TOKEN }}
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

Optional hardening: `verify-signed-tag: true` imports the release-bot GPG public
key (`gpg-public-key`, default `.github/release-bot-gpg.pub`) and runs
`git tag -v` on the deployed tag before promoting it; `forward-only: true`
refuses to move `latest` backwards when the current `latest` is newer than the
deployed tag.

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

### Stack workflows

Technology-specific workflows for application repos. Consumers call them together with the shared ones:

```yaml
jobs:
  security:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-security-scan.yml@main

  test:
    uses: sca-templates/CI-CD-Templates/.github/workflows/stack-nest.yml@main
    with:
      node-version: "22"
```

`stack-node-js.yml` covers plain JavaScript and Express; `stack-node-ts.yml` adds a build step for TypeScript projects; `stack-nest.yml` adds formatter and build checks for NestJS. The three use the **same fixed project scripts** (`npm run lint`, `npm run format:check`, `npm run test:ci`, `npm run build`) toggled by booleans — there are no free-form `*-command` inputs. All accept `working-directory` for monorepos and an optional `publish` job (`run-publish`, `image`, `publish-tag`) that builds and pushes the Docker image to GHCR.

#### Package manager

Each job delegates toolchain setup and dependency installation to the
[`setup-node-project`](#composite-actions) composite action, selected by the
`package-manager` input (`npm`, the default, or `pnpm`):

| `package-manager` | Installed | Dependencies |
|---|---|---|
| `npm` (default) | `actions/setup-node` | `npm ci` |
| `pnpm` | `pnpm/action-setup` + `actions/setup-node` | `pnpm install --frozen-lockfile` |

```yaml
jobs:
  test:
    uses: sca-templates/CI-CD-Templates/.github/workflows/stack-node-ts.yml@main
    with:
      package-manager: pnpm
      pnpm-version: "10.18.0"
```

The **script commands stay `npm run …`** in both cases: they resolve binaries
from `node_modules/.bin`, which pnpm populates just as npm does, so a pnpm
project needs no `package.json` changes. What the input changes is which
package manager installs the tree and which lockfile is enforced — a pnpm
project's `pnpm-lock.yaml` is what `--frozen-lockfile` checks.

> **`pnpm-version` is not read from `package.json`.** `pnpm/action-setup` v6 can
> omit its `version` only when `packageManager` declares pnpm v11 or newer;
> below that the version must be explicit. Pass it explicitly (or keep the
> default in sync with your `packageManager` field) rather than letting CI and
> developer machines drift.

Both package managers must have their lockfile at the **repository root** —
that is where `actions/setup-node` looks for the dependency hash, and it is
where npm and pnpm workspaces keep it. A sub-directory lockfile in a
non-workspace layout is not supported.

> **Migration:** `stack-node.yml` was replaced by `stack-node-js.yml` and `stack-node-ts.yml`. If you called `stack-node` with custom `*-command` inputs, switch to the matching template and align your `package.json` scripts with the fixed commands above.

### NPM Publish

Publishes a package to npm from a tag. A reusable workflow cannot itself trigger
on `release` / `workflow_dispatch`, so the consumer keeps a thin caller that
maps the event and passes `tag` / `dry-run`:

```yaml
# .github/workflows/publish.yml in the consumer repo
on:
  release:
    types: [published]
  workflow_dispatch:
    inputs:
      tag:
        type: string
      dry-run:
        type: boolean
        default: false

jobs:
  publish:
    uses: sca-templates/CI-CD-Templates/.github/workflows/stack-npm-publish.yml@main
    with:
      tag: ${{ inputs.tag || github.event.release.tag_name }}
      dry-run: ${{ inputs.dry-run || false }}
    secrets:
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

The job resolves the tag (input, else the release event), checks it out at that
ref, installs with the selected `package-manager` (`pnpm`/`npm`), verifies the
tag matches the `package.json` version (`verify-tag-version`, default `true`),
and publishes with `--access`. `dry-run: true` builds the tarball without
contacting npm's write API, and an empty `NPM_TOKEN` **fails fast** with an
explicit message rather than surfacing as a 401 mid-publish. Publishes share a
single `npm-publish` concurrency group, so two never overlap on one runner.

Inputs: `tag`, `dry-run`, `node-version`, `package-manager`, `pnpm-version`,
`working-directory`, `registry-url`, `access`, `verify-tag-version`.

## Adding a new technology

1. Create `stack-<tech>-*.yml` in `.github/workflows/`
2. Add composite actions under `.github/actions/<tech>/`
3. Add rulesets under `.github/rulesets/<tech>-*.json`
4. Update this file, `docs/INDEX.md`, and `README.md`

## Cross-repository reuse (concurrency)

Reusable workflows (`shared-*`, `stack-*`) must be callable from other repositories. A dispatch failure that completes instantly with **zero jobs** and the message "This run likely failed because of a workflow file issue." (no check run, no log) is the signature of the **concurrency group collision**: the caller and the called workflow declare the **same** top-level `concurrency.group` (e.g. `auto-label-${{ github.head_ref || github.ref }}` on both sides). GitHub rejects the re-entrant group at dispatch.

Rule: a reusable workflow's `concurrency.group` must be distinct from caller conventions — prefix it (`shared-auto-label-…`) or drop `concurrency` from the called workflow entirely.

Composites under `.github/actions/` serve two callers. In-repo, a shared or stack workflow reaches one by relative path (`uses: ./.github/actions/setup-node-project`) so it travels with the ref the caller pinned. From outside, a consumer's own workflow uses the fully-qualified path at a pinned SHA — see [docs/usage.md](usage.md#referencing-composite-actions).
