# Automations

Repository automations on top of the shared workflows: label management, stale
notifications, release notifications, and security dashboards. Consumed via
`uses:` like any shared workflow.

## Auto Label

Assigns labels to pull requests based on the PR metadata and changed files. The
labeling strategy is deterministic and coarse-grained by design — a single label
per category, add-only, never removing what a human already set.

Triggers: `pull_request` (opened, reopened, synchronize) plus a thin consumer
wrapper if manual runs are desired.

### What gets labeled

| Source | Rule | Label |
|---|---|---|
| Author | PR opened by `dependabot[bot]` | `dependencies` |
| Title | `feat` / `fix` / `bug` / `docs` / `ci` / `refactor` / `perf` / `security` / `chore(deps)` / `build` prefix | mapping below |
| Title | contains `security`, `CVE`, `vulnerab` | `security` |
| Files | lockfiles (`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `poetry.lock`, `Pipfile.lock`, `go.sum`, `Cargo.lock`, `composer.lock`, `packages.lock.json`) | `dependencies` |
| Files | `.github/workflows/*`, `.github/actions/*` | `ci` |
| Files | `SECURITY.md`, `security/*` | `security` |
| Files | `README*`, `docs/*.md` | `documentation` |
| Files (opt-in) | stack manifests (`package.json`, `nest-cli.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `composer.json`, `*.csproj`, ...) | `node` / `nest` / `python` / `go` / `rust` / `php` / `dotnet` |

Title prefix mapping: `feat`→`feature`, `fix`→`bug`, `bug`→`bug`,
`docs`→`documentation`, `ci`→`ci`, `refactor`→`refactor`, `perf`→`enhancement`,
`security`→`security`, `chore(deps)`→`dependencies`, `build`→`ci`.

### Consumer wiring

```yaml
# .github/workflows/auto-label.yml in a consumer repo
name: Auto Label

on:
  pull_request:
    types: [opened, reopened, synchronize]

permissions:
  contents: read
  pull-requests: write
  issues: write

jobs:
  label:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-auto-label.yml@main
    with:
      type-labels: true
      stack-labels: true
      ensure-labels: true
```

### Inputs

| Input | Default | Description |
|---|---|---|
| `type-labels` | `true` | Assign labels from PR type (title prefix and keywords) |
| `stack-labels` | `false` | Assign stack labels from changed manifests |
| `ensure-labels` | `true` | Create the global label set (and any label to be added) if missing |
| `global-labels` | org default set | Space-separated labels to ensure exist (default: `bug feature security documentation dependencies ci refactor enhancement question wontfix duplicate invalid good first issue help wanted`) |

### Global label set

The default `ensure-labels` set is the organization-wide label catalog. It is
deliberately prefixless (no `type:`/`area:` prefixes):

`bug` `feature` `security` `documentation` `dependencies` `ci` `refactor`
`enhancement` `question` `wontfix` `duplicate` `invalid`
`good first issue` `help wanted`

### Backup / restore

To capture the current label list of a repo (e.g. before migrating repos to this
automation):

```bash
gh label list --repo <owner>/<repo> --limit 100 --json name --jq '.[].name' | paste -sd ' ' -
```

Pass the result via `with.global-labels` to make that repo self-healing.
