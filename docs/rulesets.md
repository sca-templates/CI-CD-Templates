# Rulesets

GitHub Rulesets in JSON format, exportable via the GitHub API.

## Global

| Ruleset | File | Target | Description |
|---|---|---|---|
| Main Protected | `main-protected.json` | default branch | Require review, squash merge, status checks, no force-push |
| Branch Naming | `allowed-branches-only.json` | All other branches | Enforce `feat/**`, `fix/**`, `chore/**` naming pattern |
| Service Deploy Refs | `service-deploy-refs.json` | `refs/heads/deploy/**` | Protect `deploy/*` refs from deletion and non-fast-forward, bypassed by the `sca-deploy-bot` app |

## Node.js

| Ruleset | File | Target | Description |
|---|---|---|---|
| PR Quality | `nodejs-pr-quality.json` | `main` branch | Require lint + typecheck + test CI checks |

## Required status checks for reusable workflows

When a required status check covers a job that **calls a reusable workflow**
(`uses:`), GitHub reports the check with a prefixed name:

```text
<job name> / <reusable job name>
```

The ruleset must use that exact prefixed name, otherwise the check stays
"Expected — Waiting for status to be reported" forever, even after the job
passes. Example — `self-validate.yml` calls `shared-validate-static.yml`
as job `Validate`:

| Reported check name | Ruleset context required |
|---|---|
| `Validate / Markdown` | `Validate / Markdown` |
| `Validate / YAML and Shell` | `Validate / YAML and Shell` |
| `Validate / Analyze (GitHub Actions)` | `Validate / Analyze (GitHub Actions)` |

For a direct (non-reusable) job, use the bare job name.

## Deployment refs bypass

`service-deploy-refs.json` protects the `deploy/*` refs from deletion and
non-fast-forward pushes while still allowing the `sca-deploy-bot` GitHub App to
force-push them. The ruleset is stored in **normalized form** (no `id`/`source`
fields) and carries the bypass in `bypass_actors`:

```json
{
  "actor_id": 0,
  "actor_type": "Integration",
  "bypass_mode": "always"
}
```

`actor_type: "Integration"` identifies a GitHub App. `actor_id` must be the
**App ID** of `sca-deploy-bot`; the file ships with the placeholder `0` —
replace it with the real App ID before applying, and keep it in sync with the
deploy-bot registration.

### Precedence

Bypass on a ruleset does **not** bypass other rulesets that also apply to the
same ref. `service-deploy-refs.json` only talks about `deploy/*`, which matches
`allowed-branches-only.json` (all branches). To let the bot force-push despite
the branch-naming ruleset, `service-deploy-refs` must have **higher precedence**
than `allowed-branches-only` — create it **after** `allowed-branches-only` (the
API orders rulesets by `created_at`; later = higher precedence). Both rulesets
then apply, and the bot's bypass on `service-deploy-refs` covers the
force-push.

## Applying rulesets

### Via the setup script

`scripts/setup-rulesets.sh` normalizes the exported JSON (drops response-only
fields like `id`/`source`, normalizes status checks to `{context}` objects) and
creates or updates every `.github/rulesets/*.json` in the target repository:

```bash
gh auth login && ./scripts/setup-rulesets.sh sca-templates/CI-CD-Templates
```

### Via API

Create:

```bash
curl -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/{owner}/{repo}/rulesets \
  -d @.github/rulesets/main-protected.json
```

Update an existing ruleset (replace `{id}`):

```bash
curl -X PUT \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/{owner}/{repo}/rulesets/{id} \
  -d @.github/rulesets/main-protected.json
```

### Via Terraform

```hcl
resource "github_repository_ruleset" "main" {
  repository = "my-repo"
  name       = "global-main"
  target     = "branch"
  # ... import from JSON
}
```
