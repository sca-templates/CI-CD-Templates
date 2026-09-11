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
