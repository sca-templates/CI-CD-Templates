# Secrets for release automation

The release and GitOps promotion templates authenticate as the org-owned
`sca-bot-release` GitHub App instead of the default `GITHUB_TOKEN`. Resources
opened with a plain `GITHUB_TOKEN` do not trigger workflow runs, so the release
PR created by release-please would never run its required checks and could not
merge. `sca-bot-release` (a GitHub App) exists to mint a per-run installation
token. See the same rationale documented in `infra-kubernetes`
[docs/secrets.md](https://raw.githubusercontent.com/sca-templates/infra-kubernetes/main/docs/secrets.md).

## The `sca-bot-release` GitHub App

`sca-bot-release` is a GitHub App owned by the `sca-templates` organization. It
must be **installed on every consumer repository** that calls
`shared-release-flow.yml`, and on `infra-kubernetes` when using
`shared-gitops-promote.yml`. Installation is org-wide ("All repositories") or
per-repository.

## Secrets

Consumers store these as **GitHub Actions secrets** (repository or organization
level). Plaintext never touches git, the API, or the runner: GitHub encrypts
each value at rest (libsodium sealed box) and injects it only as
`${{ secrets.<NAME> }}`.

| Secret | Required | Purpose |
| --- | --- | --- |
| `APP_ID` | yes | `sca-bot-release` GitHub App ID |
| `APP_PRIVATE_KEY` | yes | App private key (PEM; newlines allowed, base64 single-line accepted) |
| `RELEASE_GPG_PRIVATE_KEY` | no | Release-bot GPG key armor; when set, release tags are signed and re-pushed |

Without `APP_ID` and `APP_PRIVATE_KEY` the calling workflow fails at startup:
`shared-release-flow.yml` declares both as `required` on `workflow_call`, so
GitHub refuses to run with `Secret APP_ID is required, but not provided while
calling.`

## Where to configure

- **Organization level (recommended).** The templates are consumed by many
  repos, so organization secrets on `sca-templates` make these available to
  every repo via `secrets: inherit` with no per-repo setup. Trade-off: any repo
  in the organization can read them.
- **Repository level.** Set only on the repos that call
  `shared-release-flow.yml`, for a smaller blast radius.

## Passing them to the workflow

`self-release.yml` (this repository) calls the shared flow with
`secrets: inherit`. Consumers do the same, or map explicitly for least
privilege:

```yaml
jobs:
  release:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-release-flow.yml@main
    secrets:
      APP_ID: ${{ secrets.APP_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

## How the token is used

Inside `shared-release-flow.yml`, the `mint-app-token` composite action
(`.github/actions/mint-app-token`) exchanges `APP_ID` + `APP_PRIVATE_KEY` for a
short-lived installation token, which release-please uses for the release PR
and tag. When `RELEASE_GPG_PRIVATE_KEY` is set, the tag is re-signed with that
key; otherwise the tag is left unsigned with a warning. See
[workflows.md](workflows.md) for the flow catalog and [usage.md](usage.md) for
consumption examples.

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
