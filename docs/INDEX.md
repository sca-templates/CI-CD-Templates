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
  validate:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-validate-static.yml@main
  security:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-security-scan.yml@main
```
