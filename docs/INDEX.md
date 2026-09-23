# CI-CD-Templates — Documentation

Centralized CI/CD templates for the `sca-templates` organization.

## Contents

- [Workflows](workflows.md) — Reusable workflow catalog
- [Rulesets](rulesets.md) — GitHub Rulesets catalog
- [Secrets](secrets.md) — Release and deploy automation secrets for consumers
- [Environments](environments.md) — Local-first variables/secrets matrix and the local↔cloud flip
- [Automations](automations.md) — Labeling and release automations
- [Automations](automations.md) — Labeling and release automations
- [Usage](usage.md) — How to consume these templates from consumer repos
- [Service release model](service-release-model.md) — Deploy contract: ArgoCD dev/qa syncs, prod pins, `latest` marker, reconciliation

## Quick start

```yaml
# In your repo's .github/workflows/ci.yml
jobs:
  security:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-security-scan.yml@main
  release:
    uses: sca-templates/CI-CD-Templates/.github/workflows/shared-release-flow.yml@main
    secrets: inherit
```
