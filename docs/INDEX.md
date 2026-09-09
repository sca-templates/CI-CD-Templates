# CI-CD-Templates — Documentation

Centralized CI/CD templates for the `sca-templates` organization.

## Contents

- [Workflows](workflows.md) — Reusable workflow catalog
- [Rulesets](rulesets.md) — GitHub Rulesets catalog
- [Usage](usage.md) — How to consume these templates from consumer repos

## Quick start

```yaml
# In your repo's .github/workflows/ci.yml
jobs:
  lint:
    uses: sca-templates/cicd-templates/.github/workflows/reusable_validate-static.yml@main
  security:
    uses: sca-templates/cicd-templates/.github/workflows/reusable_validate-security.yml@main
```
