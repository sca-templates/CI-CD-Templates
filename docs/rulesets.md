# Rulesets

GitHub Rulesets in JSON format, exportable via the GitHub API.

## Global

| Ruleset | File | Target | Description |
|---|---|---|---|
| Main Protected | `main-protected.json` | default branch | Require review, squash merge, status checks, no force-push |
| Branch Naming | `allowed-branches-only.json` | All other branches | Enforce `feat/**`, `fix/**`, `chore/**` naming pattern |

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

## Applying rulesets

### Via the setup script

`scripts/setup-rulesets.sh` normalizes the exported JSON (drops response-only
fields like `id`/`source`, collapses status checks to plain contexts) and
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
