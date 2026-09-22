# Secrets for release and deploy automation

Release and deploy automation authenticate as org-owned GitHub Apps instead of
the default `GITHUB_TOKEN`. Resources created with a plain `GITHUB_TOKEN` do not
trigger workflow runs, so the release PR created by release-please would never
run its required checks and could not merge. The org uses two GitHub Apps, one
per plane (see [service-release-model.md](service-release-model.md)):

| GitHub App | Plane | Used by |
|---|---|---|
| `sca-bot-release` | release (release PRs, signed tags, GPG) | `shared-release-flow.yml` |
| `sca-deploy-bot` | deploy (prod pins, latest marker) | `shared-adopt-prod.yml`, `shared-enforce-latest.yml` |

## Installations

- **`sca-bot-release`** must be installed on every consumer repo that calls
  `shared-release-flow.yml`.
- **`sca-deploy-bot`** must be installed on `sca-templates/infra-kubernetes`
  (`contents: write`, `pull-requests: write` for the `chore(services)` PRs).

Dev/qa deployment does **not** use a GitHub App: it is an ArgoCD Application
sync with a scoped ArgoCD API token, so service repos need no bot installation
for `shared-service-promote.yml`. `sca-deploy-bot` never needs cluster access —
it only pins versions and opens/merges PRs.

## Secrets

Consumers store these as **GitHub Actions secrets** (repository or organization
level). Plaintext never touches git, the API, or the runner: GitHub encrypts
each value at rest (libsodium sealed box) and injects it only as
`${{ secrets.<NAME> }}`.

### Release plane (`sca-bot-release`)

| Secret | Required | Purpose |
| --- | --- | --- |
| `APP_ID` | yes | `sca-bot-release` GitHub App ID |
| `APP_PRIVATE_KEY` | yes | Release-bot App private key (PEM; newlines allowed, base64 single-line accepted) |
| `RELEASE_GPG_PRIVATE_KEY` | no | Release-bot GPG key armor; when set, release tags are signed and re-pushed |

### Deploy plane — ArgoCD sync (`shared-service-promote.yml`)

Dev/qa deployment syncs the ArgoCD Application through the ArgoCD API. Every
consumer that promotes stores `ARGOCD_SERVER` / `ARGOCD_TOKEN` as
**repository or organization** secrets and passes them explicitly (recommended,
least-setup), or scopes them to the `dev`/`qa` GitHub Environments and calls
with `secrets: inherit` — the reusable `promote` job declares the environment,
so environment secrets are resolved there.

| Secret | Required | Purpose |
| --- | --- | --- |
| `ARGOCD_SERVER` | yes | ArgoCD API server URL (e.g. `https://argocd.example.com`) |
| `ARGOCD_TOKEN` | yes | ArgoCD API token for a **scoped role** (`sync`/`get` on the service's `<service>-dev` and `<service>-qa` Applications only) |

The token is created in ArgoCD (Settings → Users/Projects → Roles → New token),
restricted with RBAC so it cannot touch other projects or environments. No
kubeconfig or cluster credential is ever stored in CI.

### Deploy plane — bot (`sca-deploy-bot`)

Used by the prod pin/latest reconcile flows.

| Secret | Required | Purpose |
| --- | --- | --- |
| `DEPLOY_APP_ID` | yes | `sca-deploy-bot` GitHub App ID |
| `DEPLOY_APP_PRIVATE_KEY` | yes | Deploy-bot App private key (PEM) |

### Security scanning

Consumed by `shared-security-scan.yml`. The two jobs (gitleaks, osv-scanner)
are **secret-free** — no configuration is needed and nothing skips silently.

Dependency advisory PRs are left to Dependabot, which needs no secrets either.

The deploy bot secrets are named with the `*_DEPLOY` suffix (recommended) so they
**do not collide** with the release-bot `APP_ID`/`APP_PRIVATE_KEY` on repos that
run both planes. The prod workflows declare their inputs as
`APP_ID`/`APP_PRIVATE_KEY`; map them at the call site:

```yaml
jobs:
  adopt:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-adopt-prod.yml@main
    with:
      service: sca-api
      release-tag: v1.2.3
    secrets:
      APP_ID: ${{ secrets.DEPLOY_APP_ID }}
      APP_PRIVATE_KEY: ${{ secrets.DEPLOY_APP_PRIVATE_KEY }}
```

## Where to configure

- **Organization level (recommended).** The templates are consumed by many
  repos, so organization secrets on `sca-templates` make these available to
  every repo via `secrets: inherit` with no per-repo setup. Trade-off: any repo
  in the organization can read them.
- **Repository level.** Set only on the repos that run the plane, for a smaller
  blast radius.

## Passing them to the workflow

`self-*.yml` workflows (this repository) call the shared flows with
`secrets: inherit`. Consumers do the same, or map explicitly for least
privilege (see the deploy-plane example above and the release-plane mapping in
[usage.md](usage.md)).

## How the tokens are used

Inside each shared workflow, the `mint-app-token` composite action
(`.github/actions/mint-app-token`) exchanges `APP_ID` + `APP_PRIVATE_KEY` for a
short-lived installation token scoped to the target repositories:

- `shared-service-promote.yml` — syncs the dev/qa ArgoCD Application to the
  selected revision via the ArgoCD API (`ARGOCD_SERVER` / `ARGOCD_TOKEN`); no
  GitHub App involved.
- `shared-adopt-prod.yml` — verifies the release tag, clones `infra-kubernetes`,
  pins the version, and commits directly or opens `adopt/<service>-<tag>` PRs.
- `shared-enforce-latest.yml` — reads the prod pin, harmonizes the release list
  and marks the deployed tag as `latest`.
- `shared-release-flow.yml` — drives release-please (release PR + tag); when
  `RELEASE_GPG_PRIVATE_KEY` is set, the tag is re-signed with that key.

See [workflows.md](workflows.md) for the flow catalog and [usage.md](usage.md)
for consumption examples.

## Signed release tags and the trust anchor

When `RELEASE_GPG_PRIVATE_KEY` is set, `shared-release-flow.yml` re-signs the
release tag with the release-bot GPG key before pushing. Release tags are
**not** marked `Verified` in the GitHub UI: the signing identity is the
`sca-bot-release` GitHub App, and GitHub only displays the badge for signatures
tied to a registered **user account**. The signature is still cryptographically
valid and verifiable locally.

The org's signing keys live in **this repository** at
[`.github/release-bot-gpg.pub`](../.github/release-bot-gpg.pub) as the canonical
trust anchor. It holds two keys:

| Key | Fingerprint | Status |
| --- | --- | --- |
| Current release bot | `93390743AFE58FF566BC29D4D0EC17FC76E3C4BA` | signs release tags from now on |
| Legacy release bot | `E272B06540C49A7EF2AA22A22D7114035EB46A21` | `infra-kubernetes` `v0.1.0`; kept so historical tags stay verifiable |

Verification (no GitHub account required):

```bash
curl -fsSL https://raw.githubusercontent.com/sca-templates/CI-CD-Templates/main/.github/release-bot-gpg.pub \
  | gpg --import
git tag -v <tag>
```

`gpg --import` runs once per trust anchor per machine; `git tag -v` then prints
`Good signature`. Consumer repositories reference the canonical file by URL (as
above) instead of copying it, keeping a single source of truth for the org's
signing keys.
