# Service release and deploy model

The deployment contract for `sca-templates` service repositories, implemented
as shared workflows in this repository. It replaces the retired
`shared-gitops-promote.yml` / `.github/actions/gitops-bump-image/`.

## Principle: `latest` = reality

GitHub's `latest` release is treated as a **marker of reality**, not a release
history artifact. It must always point at the exact version running in `prod`.
release-please creates a release per merged bump; without intervention `latest`
would drift to whichever bumped last, so the deploy plane corrects it after
every prod change.

The deploy model is trunk-based: service repos keep **only `main`** and there
is **no release PR** for deployments. `main` is always releasable; environments
advance by syncing the ArgoCD Application and by pins.

## The contract

| Aspect | Mechanism |
|---|---|
| branches | only `main` exists in the service repos — no `deploy/dev`, `deploy/qa` or temporary branches |
| dev | `shared-service-promote.yml` syncs the service's `dev` ArgoCD Application to the selected branch/tag/commit via the ArgoCD API (no approval) |
| qa | same workflow, `qa` Application; a real promote runs against the `qa` GitHub Environment and waits for a **human approval** (Required reviewers) before the sync — no PR involved |
| prod | immutable, signed `vX.Y.Z` tag (from `shared-release-flow.yml`) pinned in `argocd/services-prod.yaml` of `sca-templates/infra-kubernetes` |
| prod apply | PR `chore(services): …` (the only PR in the model); human approves/merges; ArgoCD syncs `prod` in the manual sync window (ADR-003) |
| container images | always tagged `sha-<commit>`, never `latest` |
| GitHub `latest` | corrected to the version running in `prod` |

The dev and qa ArgoCD Applications point at `main` and are synced on demand;
the prod Application points at the pinned tag. A detailed doctree lives in
[sca-docs](https://github.com/sca-templates/sca-docs).

## Two bots, two planes

| Bot | Plane | Repos it touches | Cluster access |
|---|---|---|---|
| `sca-bot-release` | release: release PRs, signed tags, GPG | every consumer repo | no |
| `sca-deploy-bot` | deploy: `chore(services)` prod pins, `latest` marker | service repos + `infra-kubernetes` | no |

Secrets and scopes: [secrets.md](secrets.md). Neither bot ever touches the
cluster. Dev/qa deployments are executed by GitHub Actions **with a scoped
ArgoCD API token**: the runner calls the ArgoCD server directly, so no
cluster credentials ever reach the pipeline (`ARGOCD_SERVER` + `ARGOCD_TOKEN`,
scoped to `sync`/`get` on the service's dev/qa Applications).

## Orchestration

Prod promotion is **manual per service**: each service repo ships a small
`workflow_dispatch` wrapper (`docs/examples/deploy-prod.yml`) that calls the
shared workflows on demand. Two runs, in order:

1. **`action: adopt`** calls `shared-adopt-prod.yml` with the `release-tag`: it
   opens the `chore(services)` PR that pins the version in the GitOps registry.
2. **`action: mark-latest`** calls `shared-enforce-latest.yml` **after** the
   prod `Sync` succeeded (the app must be `Synced` & `Healthy` first); it marks
   the deployed tag as GitHub `latest`.

`shared-enforce-latest.yml` keeps `latest` truthful by re-reading the registry
pin on every call. A future optional fast-path on `release published` can
re-mark `latest` automatically; for now the marker moves only on the manual run.

## Workflows and roles

| Workflow | Role |
|---|---|
| [`shared-service-promote.yml`](workflows.md) | syncs the dev/qa ArgoCD Application to a selected revision — the dev/qa promotion |
| [`shared-adopt-prod.yml`](workflows.md) | pins the release tag as the prod version in the GitOps registry |
| [`shared-enforce-latest.yml`](workflows.md) | corrects GitHub `latest` to the deployed version (with `harmonize-releases`) |
| [`shared-release-flow.yml`](workflows.md) | release-please + signed tags; optional `auto-merge-release-pr` |

Consumer wiring: [usage.md](usage.md).

## Dev/QA promotion

Dev and QA share one environment each: whoever promotes last decides what
everyone tests there. `shared-service-promote.yml` takes a `revision` (branch
or tag, resolved to its head commit) — or an explicit commit — and syncs the
service's `dev` or `qa` ArgoCD Application to that commit:

- **dev**: the sync runs immediately (no approval).
- **qa**: a real promote runs against the repo's `qa` GitHub Environment. If the
  repo configures **Required reviewers** on it, the run pauses ("Waiting for
  approval") until one reviewer approves in the Actions UI — the approval is a
  human gate, not a PR. Without reviewers configured the old no-approval
  behavior is kept.

Dev/QA have no release PR: they take any commit, not only `vX.Y.Z` tags. The
Application name defaults to `<service>-<environment>`; pass `app` explicitly
when the infra registry names the Application differently.

## No deploy refs

There are no `deploy/*` refs and no ruleset protecting them: dev and qa are
Application syncs, not branch moves. That ruleset and the
`push-deploy-ref` action have been removed from this repository. Anything still
referencing `deploy/dev` or `deploy/qa` is stale and should be treated as a
migration artifact.

## Registry schema

The prod registry file is `argocd/services-prod.yaml` (configurable via
`registry-path`). It is an `ApplicationSet` whose `list` generator holds one
`element` per service, so `shared-adopt-prod.yml` /
`shared-enforce-latest.yml` default to that element lookup through yq `select`:

| Purpose | Default expression |
|---|---|
| Read the pinned version | `.spec.generators[0].list.elements[] \| select(.name == "<service>") \| .version` |
| Write the pinned version | same path (assign) |

Both expressions are configurable via `yq-expression` / `set-expression`, so
pass your own if a consumer's registry schema differs.
`shared-adopt-prod.yml` fails fast when `<service>` is not yet registered in
the list, and reuses an open `adopt/<service>-<tag>` PR when one exists.

## Migrating from `shared-gitops-promote.yml`

1. Replace the `deploy.yml` wrapper: call `shared-service-promote.yml` for
   dev/qa instead of `shared-gitops-promote.yml`.
2. Images keep `sha-<commit>` tags; the promote workflow can build them with
   `run-publish: true` or your existing tag-triggered publish job.
3. Configure the deploy-plane secrets ([secrets.md](secrets.md)):
   `ARGOCD_SERVER` and `ARGOCD_TOKEN` as repository/organization secrets, or
   scoped to the `dev`/`qa` GitHub Environments (with `secrets: inherit`).
4. Point the reconciler in `infra-kubernetes` at
   `shared-adopt-prod.yml` / `shared-enforce-latest.yml`, delete the
   `image.tag` schema usage, and drop `gitops-bump-image` references (the
   action is removed from this repo).
5. Drop any `deploy/*` refs and rulesets; delete the branches if an old model
   left them behind (only `main` should remain)
