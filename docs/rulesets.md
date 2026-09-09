# Rulesets

GitHub Rulesets in JSON format, exportable via the GitHub API.

## Global

| Ruleset | File | Target | Description |
|---|---|---|---|
| Main Protected | `global-main.json` | `main` branch | Require review, squash merge, no force-push |
| Branch Naming | `global-pr-branch-naming.json` | All branches | Enforce `feat/**`, `fix/**`, `chore/**` pattern |

## Node.js

| Ruleset | File | Target | Description |
|---|---|---|---|
| PR Quality | `nodejs-pr-quality.json` | `main` branch | Require lint + typecheck + test CI checks |

## Applying rulesets

### Via API

```bash
curl -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/{owner}/{repo}/rulesets \
  -d @.github/rulesets/global-main.json
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
