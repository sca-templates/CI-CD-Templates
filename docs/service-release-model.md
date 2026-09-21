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

The deploy model is trunk-based: there is **no release PR** for deployments.
`main` is always releasable; environments advance by moving refs and pins.

## The contract

| Aspect | Mechanism |
|---|---|
| dev | selected branch/tag/commit, force-pushed by the deploy bot to `deploy/dev` in the service repo (no approval) |
| qa | selected branch/tag/commit, force-pushed by the deploy bot to `deploy/qa`; a real promote runs against the `qa` GitHub Environment and waits for a **human approval** (Required reviewers) before the ref moves — no PR involved |
| prod | immutable, signed `vX.Y.Z` tag (from `shared-release-flow.yml`) pinned in `argocd/services-prod.yaml` of `sca-templates/infra-kubernetes` |
| prod apply | PR `chore(services): …` **or** direct commit; human approves/merges; ArgoCD syncs `prod` in the manual sync window (ADR-003) |
| container images | always tagged `sha-<commit>`, never `latest` |
| GitHub `latest` | corrected to the version running in `prod` |

ArgoCD Applications track the `deploy/dev` and `deploy/qa` refs directly. A
detailed doctree lives in [sca-docs](https://github.com/sca-templates/sca-docs).

## Two bots, two planes

| Bot | Plane | Repos it touches | Cluster access |
|---|---|---|---|
| `sca-bot-release` | release: release PRs, signed tags, GPG | every consumer repo | no |
| `sca-deploy-bot` | deploy: `deploy/*` refs, `chore(services)` pins, `latest` marker | service repos + `infra-kubernetes` | no |

Secrets and scopes: [secrets.md](secrets.md). Neither bot ever touches the
cluster; ArgoCD is the only component with access.

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
| [`shared-service-promote.yml`](workflows.md) | moves `deploy/<env>` to a commit — the dev/qa promotion |
| [`shared-adopt-prod.yml`](workflows.md) | pins the release tag as the prod version in the GitOps registry |
| [`shared-enforce-latest.yml`](workflows.md) | corrects GitHub `latest` to the deployed version (with `harmonize-releases`) |
| [`shared-release-flow.yml`](workflows.md) | release-please + signed tags; optional `auto-merge-release-pr` |

Consumer wiring: [usage.md](usage.md).

## Dev/QA promotion

Dev and QA share one environment each: whoever promotes last decides what
everyone tests there. `shared-service-promote.yml` takes a `ref` (branch or tag,
resolved to its head commit) — or an explicit `commit` — and force-pushes it to
`deploy/dev` or `deploy/qa`:

- **dev**: promotes immediately.
- **qa**: a real promote runs against the repo's `qa` GitHub Environment. If the
  repo configures **Required reviewers** on it, the run pauses ("Waiting for
  approval") until one reviewer approves in the Actions UI — the approval is a
  human gate, not a PR. Without reviewers configured the old no-approval
  behavior is kept. `dry-run` never waits.

Dev/QA have no release PR: they take any commit, not only `vX.Y.Z` tags.

## Ruleset

[`service-deploy-refs.json`](../.github/rulesets/service-deploy-refs.json)
protects `refs/heads/deploy/**` from deletion and non-fast-forward while
bypassing those rules for the `sca-deploy-bot` app (`bypass_mode: always`,
`actor_type: Integration`). It must have **higher precedence** than
`allowed-branches-only.json` (create it after) so the bot's force-push is
allowed. Details: [rulesets.md](rulesets.md).

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
3. Add the `Service Deploy Refs` ruleset and set the `sca-deploy-bot` App ID in
   `bypass_actors`; remove the old GitOps rules unless still needed.
4. Configure the deploy-plane secrets ([secrets.md](secrets.md)).
5. Point the reconciler in `infra-kubernetes` at
   `shared-adopt-prod.yml` / `shared-enforce-latest.yml`, delete the
   `image.tag` schema usage, and drop `gitops-bump-image` references (the
   action is removed from this repo).
