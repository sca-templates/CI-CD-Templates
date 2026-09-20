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
| dev | `deploy/dev` branch ref in the service repo, force-pushed by the deploy bot |
| qa | `deploy/qa` branch ref in the service repo, force-pushed by the deploy bot |
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

A reconcile loop lives in `infra-kubernetes`:

- runs on a cron (~10–15 min) **and** after each merged `chore(services)` PR;
- queries the ArgoCD state for each service Application (must be `Synced` &
  `Healthy` before the version is considered "running");
- calls `shared-enforce-latest.yml` with `tag-source: explicit` and the tag it
  observed (`release-tag`), or `tag-source: registry` to read the pin.

Optional fast-path: on `release published`, the loop re-marks `latest` to the
current prod pin without waiting for the next cron tick.

## Workflows and roles

| Workflow | Role |
|---|---|
| [`shared-service-promote.yml`](workflows.md) | moves `deploy/<env>` to a commit — the dev/qa promotion |
| [`shared-adopt-prod.yml`](workflows.md) | pins the release tag as the prod version in the GitOps registry |
| [`shared-enforce-latest.yml`](workflows.md) | corrects GitHub `latest` to the deployed version (with `harmonize-releases`) |
| [`shared-release-flow.yml`](workflows.md) | release-please + signed tags; optional `auto-merge-release-pr` |

Consumer wiring: [usage.md](usage.md).

## Ruleset

[`service-deploy-refs.json`](../.github/rulesets/service-deploy-refs.json)
protects `refs/heads/deploy/**` from deletion and non-fast-forward while
bypassing those rules for the `sca-deploy-bot` app (`bypass_mode: always`,
`actor_type: Integration`). It must have **higher precedence** than
`allowed-branches-only.json` (create it after) so the bot's force-push is
allowed. Details: [rulesets.md](rulesets.md).

## Registry schema

The prod registry file is `argocd/services-prod.yaml` (configurable via
`registry-path`). The lookup key defaults to the service name with a tolerant
fallback chain — `.svc.version → .applications.svc.version →
.services.svc.version` — all expressions configurable via `yq-expression` /
`set-expression`. If the real schema differs, pass the correct expression
instead of editing the templates.

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
