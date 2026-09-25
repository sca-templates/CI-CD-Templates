# Environments

Local-first CI/CD for the `sca-templates` organization: every shared/stack
workflow runs against a **cloud provider** (provider of the client's choice),
cloud ArgoCD, and GitHub-hosted runners **except** when the org/environment
variables below hold their local values. Flipping local → cloud is a **value
change only** — no workflow or action code changes. The template is
**provider-agnostic**: the same variables and secrets work for any cloud, and
nothing references a specific vendor by name.

There is no shared "configure env" action. Consumers wire the cloud environment
**by hand** in each job that talks to a provider (two layers: job-level env + a
local emulator). The recipe is at
[Layer 1: Cloud credentials and endpoint](#layer-1-cloud-credentials-and-endpoint).

## Variable / secret matrix

| Name | Type | Level | Local | Cloud | Consumers |
|---|---|---|---|---|---|
| `RUNS_ON` | variable | org | `self-hosted` | `ubuntu-latest` | all shared/stack workflows (`runs-on`) |
| `CLOUD_REGION` | variable | org | `us-east-1` | `us-east-1` | jobs that talk to a cloud provider (`env:`) |
| `CLOUD_ENDPOINT_URL` | variable | org | `http://localhost:4566` | *(empty/unset)* | jobs that talk to a cloud provider (`env:`) |
| `CLOUD_ACCESS_KEY_ID` | secret | org & env | `test` | real credential | jobs that talk to a cloud provider (`env:`) |
| `CLOUD_SECRET_ACCESS_KEY` | secret | org & env | `test` | real credential | jobs that talk to a cloud provider (`env:`) |
| `ARGOCD_SERVER` | secret | env (`dev`, `qa`) | `https://127.0.0.1:8443` | cloud ArgoCD URL | `shared-service-promote.yml` |
| `ARGOCD_TOKEN` | secret | env (`dev`, `qa`) | local scoped token | cloud scoped token | `shared-service-promote.yml` |
| `CONTAINER_REGISTRY` | variable | org | `ghcr.io` | `ghcr.io` | stack publish jobs + `shared-service-promote.yml` |

> `ARGOCD_SERVER` may also be declared as a **variable**: the promote workflow
> uses `${{ secrets.ARGOCD_SERVER || vars.ARGOCD_SERVER }}`. When both the
> environment secret and the org variable exist, the environment secret wins.
>
> The `CLOUD_*` names are the template's contract. Nothing in the template is
> tied to a specific provider; only the **values** change between local and
> cloud.

## Layer 1: Cloud credentials and endpoint

The cloud environment is **not** provisioned by a composite action. Each job
that talks to a provider declares its environment from the org/env variables and
secrets — the consumer maps them by hand, they are never injected implicitly:

```yaml
jobs:
  deploy:
    runs-on: ${{ vars.RUNS_ON || 'ubuntu-latest' }}
    env:
      CLOUD_REGION: ${{ vars.CLOUD_REGION || 'us-east-1' }}
      CLOUD_ENDPOINT_URL: ${{ vars.CLOUD_ENDPOINT_URL }}
      CLOUD_ACCESS_KEY_ID: ${{ secrets.CLOUD_ACCESS_KEY_ID }}
      CLOUD_SECRET_ACCESS_KEY: ${{ secrets.CLOUD_SECRET_ACCESS_KEY }}
    steps:
      - run: ./deploy.sh
```

Bridging to a provider's SDK is **consumer-side**. For example, the AWS SDK and
CLI expect `AWS_*` names, so export them from the generic ones before invoking
tools: `AWS_DEFAULT_REGION="${CLOUD_REGION}"`,
`AWS_ENDPOINT_URL="${CLOUD_ENDPOINT_URL}"`,
`AWS_ACCESS_KEY_ID="${CLOUD_ACCESS_KEY_ID}"`,
`AWS_SECRET_ACCESS_KEY="${CLOUD_SECRET_ACCESS_KEY}"`. Another provider needs a
different mapping; the template itself never changes.

Behavior derived entirely from the variable values:

- **local mode** (`CLOUD_ENDPOINT_URL` = `http://localhost:4566`): tools talk
  to the local emulator. Dummy credentials (`test`/`test`) are always used so a
  misconfigured job can never touch a real provider.
- **cloud mode** (`CLOUD_ENDPOINT_URL` empty/unset): real service endpoints,
  real credentials from the org/env secrets.

## Layer 2: Local runtime

- **Cloud emulation**: [Floci](https://floci.io) —
  `floci start --persist "$HOME/floci-data" --detach`, endpoint
  `http://localhost:4566` (S3/similar-compatible); a local LocalStack at the
  same port is a drop-in backup (same dummy credential scheme).
- **ArgoCD**: local mirror at `https://127.0.0.1:8443`
  (`kubectl port-forward svc/argocd-server 8443:443`), accessed with a scoped
  token for role `cicd-local` on project `default`.
- **Runner**: self-hosted runner `debian-kind` (labels `self-hosted`, `Linux`,
  `X64`, `kind`), registered at org level and managed as a systemd user unit.
- **On/off button**: `~/bin/local-infra status|up|down|logs` (runner + Floci by
  default; `--all` also starts the kind clusters and the ArgoCD port-forward).

## Flip checklist (local → cloud)

1. Org variable `RUNS_ON` → `ubuntu-latest` (or delete it).
2. Org variable `CLOUD_ENDPOINT_URL` → unset/empty.
3. Replace org/env secrets `CLOUD_ACCESS_KEY_ID` / `CLOUD_SECRET_ACCESS_KEY` with the real credentials.
4. Replace the `dev`/`qa` environment secrets `ARGOCD_SERVER` / `ARGOCD_TOKEN` with the cloud ArgoCD values.
5. No code changes required — the job-level `env:` mapping stays the same.

Flipping back (cloud → local) is the same list in reverse.