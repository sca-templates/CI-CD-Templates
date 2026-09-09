# CI-CD-Templates

Centralized, reusable CI/CD templates for the [sca-templates](https://github.com/sca-templates) organization. Global and technology-specific workflows, composite actions, and GitHub Rulesets.

## What's inside

```
.github/
├── workflows/        # Reusable workflows (workflow_call)
├── actions/          # Composite actions
├── rulesets/         # GitHub Rulesets (JSON, API-exportable)
├── ISSUE_TEMPLATE/   # Issue templates
├── PULL_REQUEST_TEMPLATE.md
├── CODEOWNERS
└── dependabot.yml
```

## Available templates

### Global

| Type | Name | File |
|---|---|---|
| Workflow | Static Validation | `reusable_validate-static.yml` |
| Workflow | Security Validation | `reusable_validate-security.yml` |
| Ruleset | Main Protected | `global-main.json` |
| Ruleset | Branch Naming | `global-pr-branch-naming.json` |

### Node.js

| Type | Name | File |
|---|---|---|
| Workflow | Node.js CI | `reusable_nodejs-ci.yml` |
| Workflow | Node.js Release | `reusable_nodejs-release.yml` |
| Action | Setup Node.js | `actions/setup-nodejs/` |
| Action | Run Linters | `actions/run-linters/` |
| Action | Security Scan | `actions/security-scan/` |
| Ruleset | PR Quality | `nodejs-pr-quality.json` |

## Quick start

```yaml
# .github/workflows/ci.yml in your repo
jobs:
  validate:
    uses: sca-templates/cicd-templates/.github/workflows/reusable_validate-static.yml@main
  security:
    uses: sca-templates/cicd-templates/.github/workflows/reusable_validate-security.yml@main
  nodejs:
    uses: sca-templates/cicd-templates/.github/workflows/reusable_nodejs-ci.yml@main
    with:
      node-version: "20"
```

See [docs/usage.md](docs/usage.md) for full reference.

## Adding a new technology

1. Add workflows: `.github/workflows/reusable_<tech>-*.yml`
2. Add actions: `.github/actions/<tech>/action.yml`
3. Add rulesets: `.github/rulesets/<tech>-*.json`
4. Add issue templates: `.github/ISSUE_TEMPLATE/` (tech-specific)
5. Self-test: `.github/workflows/test_<tech>-*.yml`
6. Update docs

## Documentation

- [Documentation index](docs/INDEX.md)
- [Workflows catalog](docs/workflows.md)
- [Rulesets catalog](docs/rulesets.md)
- [Usage guide](docs/usage.md)

## License

MIT
