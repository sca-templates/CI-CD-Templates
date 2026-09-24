# Environments

Local-first CI/CD for the `sca-templates` organization: every shared/stack
workflow runs against real AWS, cloud ArgoCD, and GitHub-hosted runners
**except** when the org/environment variables below hold their local values.
Flipping local → cloud is a **value change only** — no workflow or action code
changes.

There is no shared "configure env" action. Consumers wire the AWS environment
**by hand** in each job that touches AWS (two layers: job-level env + a local
emulator). The recipe is at [Layer 1: AWS environment](#layer-1-aws-environment).

## Variable / secret matrix

| Name | Type | Level | Local | Cloud | Consumers |
|---|---|---|---|---|---|
| `RUNS_ON` | variable | org | `self-hosted` | `ubuntu-latest` | all shared/stack workflows (`runs-on`) |
| `AWS_DEFAULT_REGION` | variable | org | `us-east-1` | `us-east-1` | jobs that touch AWS (`env:`) |
| `AWS_ENDPOINT_URL` | variable | org | `http://localhost:4566` | *(empty/unset)* | jobs that touch AWS (`env:`) |
| `AWS_ACCESS_KEY_ID` | secret | org & env | `test` | real key | jobs that touch AWS (`env:`) |
| `AWS_SECRET_ACCESS_KEY` | secret | org & env | `test` | real key | jobs that touch AWS (`env:`) |
| `ARGOCD_SERVER` | secret | env (`dev`, `qa`) | `https://127.0.0.1:8443` | cloud ArgoCD URL | `shared-service-promote.yml` |
| `ARGOCD_TOKEN` | secret | env (`dev`, `qa`) | local scoped token | cloud scoped token | `shared-service-promote.yml` |
| `CONTAINER_REGISTRY` | variable | org | `ghcr.io` | `ghcr.io` | stack publish jobs + `shared-service-promote.yml` |

> `ARGOCD_SERVER` may also be declared as a **variable**: the promote workflow
> uses `${{ secrets.ARGOCD_SERVER || vars.ARGOCD_SERVER }}`. When both the
> environment secret and the org variable exist, the environment secret wins.

## Layer 1: AWS environment

The cloud environment is **not** provisioned by a composite action. Each job
that touches AWS declares its `AWS_*` environment from the org/env variables and
secrets — the consumer maps them by hand, they are never injected implicitly:

```yaml
jobs:
  deploy:
    runs-on: ${{ vars.RUNS_ON || 'ubuntu-latest' }}
    env:
      AWS_DEFAULT_REGION: ${{ vars.AWS_DEFAULT_REGION || 'us-east-1' }}
      AWS_ENDPOINT_URL: ${{ vars.AWS_ENDPOINT_URL }}
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    steps:
      - run: aws sts get-caller-identity
```

Behavior derived entirely from the variable values:

- **local mode** (`AWS_ENDPOINT_URL` = `http://localhost:4566`): the SDK talks
  to the local emulator. Dummy keys (`test`/`test`) are always used so a
  misconfigured job can never touch real AWS.
- **cloud mode** (`AWS_ENDPOINT_URL` empty/unset): real service endpoints, real
  keys from the org/env secrets. `aws` resolves AWS against the standard
  endpoint chain.

## Layer 2: Local runtime

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

## Flip checklist (local → cloud)

1. Org variable `RUNS_ON` → `ubuntu-latest` (or delete it).
2. Org variable `AWS_ENDPOINT_URL` → unset/empty.
3. Replace org/env secrets `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` with the real keys.
4. Replace the `dev`/`qa` environment secrets `ARGOCD_SERVER` / `ARGOCD_TOKEN` with the cloud ArgoCD values.
5. No code changes required — the job-level `env:` mapping stays the same.

Flipping back (cloud → local) is the same list in reverse.
