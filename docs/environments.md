# Environments

Local-first CI/CD for the `sca-templates` organization: every shared/stack
workflow runs against real AWS, cloud ArgoCD, and GitHub-hosted runners
**except** when the org/environment variables below hold their local values.
Flipping local → cloud is a **value change only** — no workflow or action code
changes.

## Variable / secret matrix

| Name | Type | Level | Local | Cloud | Consumers |
|---|---|---|---|---|---|
| `RUNS_ON` | variable | org | `self-hosted` | `ubuntu-latest` | all shared/stack workflows (`runs-on`) |
| `AWS_MODE` | variable | org & env | `local` | `cloud` | `configure-aws-env` action |
| `AWS_ENDPOINT_URL` | variable | org | `http://localhost:4566` | *(empty/unset)* | `configure-aws-env` action |
| `AWS_DEFAULT_REGION` | variable | org | `us-east-1` | `us-east-1` | `configure-aws-env` action |
| `AWS_ACCESS_KEY_ID` | secret | org & env | `test` | real key | `configure-aws-env` action |
| `AWS_SECRET_ACCESS_KEY` | secret | org & env | `test` | real key | `configure-aws-env` action |
| `ARGOCD_SERVER` | secret | env (`dev`, `qa`) | `https://127.0.0.1:8443` | cloud ArgoCD URL | `shared-service-promote.yml` |
| `ARGOCD_TOKEN` | secret | env (`dev`, `qa`) | local scoped token | cloud scoped token | `shared-service-promote.yml` |
| `CONTAINER_REGISTRY` | variable | org | `ghcr.io` | `ghcr.io` | stack publish jobs + `shared-service-promote.yml` |

> `ARGOCD_SERVER` may also be declared as a **variable**: the promote workflow
> uses `${{ secrets.ARGOCD_SERVER || vars.ARGOCD_SERVER }}`. When both the
> environment secret and the org variable exist, the environment secret wins.

## How it works

- Every `runs-on: ubuntu-latest` in the shared and stack workflows became
  `runs-on: ${{ vars.RUNS_ON || 'ubuntu-latest' }}`. When the variable is unset
  or equals `ubuntu-latest`, GitHub-hosted runners are used; when it equals a
  local label (`self-hosted`), the self-hosted runner handles the jobs.
- The `configure-aws-env` composite action
  (`sca-templates/CI-CD-Templates/.github/actions/configure-aws-env`) expands
  the AWS environment before any AWS-touching step:
  - **local mode**: `AWS_ACCESS_KEY_ID=test`, `AWS_SECRET_ACCESS_KEY=test`,
    `AWS_DEFAULT_REGION` (default `us-east-1`),
    `AWS_ENDPOINT_URL` (default `http://localhost:4566`).
    Dummy keys are always used so a misconfigured job can never touch real AWS.
  - **cloud mode**: real `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` from the
    org/env secrets; `AWS_ENDPOINT_URL` is exported only when non-empty (empty
    means real AWS service endpoints).

Consumers invoke it as the first step of any AWS-touching job:

```yaml
steps:
  - uses: sca-templates/CI-CD-Templates/.github/actions/configure-aws-env@main
```

## Flip checklist (local → cloud)

1. Org variable `RUNS_ON` → `ubuntu-latest` (or delete it).
2. Org variable `AWS_MODE` → `cloud`.
3. Org variable `AWS_ENDPOINT_URL` → unset/empty.
4. Replace org/env secrets `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` with the real keys.
5. Replace the `dev`/`qa` environment secrets `ARGOCD_SERVER` / `ARGOCD_TOKEN` with the cloud ArgoCD values.
6. No code changes required.

Flipping back (cloud → local) is the same list in reverse.

## Local runtime

- **AWS emulation**: [Floci](https://floci.io) —
  `floci start --persist "$HOME/floci-data" --detach`, endpoint
  `http://localhost:4566`; a local LocalStack at the same port is a drop-in
  backup (same dummy credentials scheme).
- **ArgoCD**: local mirror at `https://127.0.0.1:8443`
  (`kubectl port-forward svc/argocd-server 8443:443`), accessed with a scoped
  token for role `cicd-local` on project `default`.
- **Runner**: self-hosted runner `debian-kind` (labels `self-hosted`, `Linux`,
  `X64`, `kind`), registered at org level and managed as a systemd user unit.
- **On/off button**: `~/bin/local-infra status|up|down|logs` (runner + Floci by
  default; `--all` also starts the kind clusters and the ArgoCD port-forward).
