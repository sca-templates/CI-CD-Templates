# Shared Workflows

All shared workflows live flat in `.github/workflows/` (GitHub does not support subdirectories). Consumers call them via `uses:`.

## Catalog

| Workflow | File | Description |
|---|---|---|
| Static Validation | `shared-validate-static.yml` | Markdown, YAML, shell, actionlint |
| Security Scan | `shared-security-scan.yml` | gitleaks, osv-scanner, license check |
| Release Flow | `shared-release-flow.yml` | release-please + signed tags |
| QA Lock Check | `shared-qa-lock-check.yml` | Block merges while release PR open |
| CodeQL | `shared-codeql.yml` | CodeQL static analysis (GitHub Actions) |
| Scorecard | `shared-scorecard.yml` | OpenSSF Scorecard supply-chain security |
| GitOps Promote | `shared-gitops-promote.yml` | *Not yet implemented* |

## Usage

```yaml
jobs:
  validate:
    uses: sca-templates/cicd-templates/.github/workflows/shared-validate-static.yml@main
    with:
      markdown-lint: true
      yaml-lint: true
      actionlint: true

  security:
    uses: sca-templates/cicd-templates/.github/workflows/shared-security-scan.yml@main

  release:
    uses: sca-templates/cicd-templates/.github/workflows/shared-release-flow.yml@main
    secrets:
      RELEASE_BOT_TOKEN: ${{ secrets.RELEASE_BOT_TOKEN }}
      RELEASE_GPG_PRIVATE_KEY: ${{ secrets.RELEASE_GPG_PRIVATE_KEY }}
```

See [usage.md](usage.md) for full reference.

## Adding a new technology

1. Create `shared_<tech>-*.yml` in `.github/workflows/`
2. Add composite actions under `.github/actions/<tech>/`
3. Add rulesets under `.github/rulesets/<tech>-*.json`
4. Update this file, `docs/INDEX.md`, and `README.md`
