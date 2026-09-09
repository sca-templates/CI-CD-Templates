# Usage

How to consume CI-CD templates from this repository.

## Referencing reusable workflows

```yaml
# .github/workflows/ci.yml in consumer repo
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  validate:
    uses: sca-templates/cicd-templates/.github/workflows/reusable_validate-static.yml@main
    with:
      markdown-lint: true
      yaml-lint: true

  security:
    uses: sca-templates/cicd-templates/.github/workflows/reusable_validate-security.yml@main

  nodejs:
    uses: sca-templates/cicd-templates/.github/workflows/reusable_nodejs-ci.yml@main
    with:
      node-version: "20"
      package-manager: "npm"
    secrets: inherit
```

## Referencing composite actions

```yaml
# Inside a job step
steps:
  - uses: sca-templates/cicd-templates/.github/actions/setup-nodejs@main
    with:
      node-version: "20"
      package-manager: "pnpm"
```

## Applying rulesets

See [rulesets.md](rulesets.md) for API and Terraform examples.

## Versioning

Pin to a major version tag for auto-patches:
```yaml
uses: sca-templates/cicd-templates/.github/workflows/reusable_validate-static.yml@v1
```

Or pin to a SHA for maximum safety:
```yaml
uses: sca-templates/cicd-templates/.github/workflows/reusable_validate-static.yml@a1b2c3d
```

## Secrets

Most workflows accept `secrets: inherit` for internal repos. For least-privilege, map explicitly:

```yaml
jobs:
  release:
    uses: sca-templates/cicd-templates/.github/workflows/reusable_nodejs-release.yml@main
    secrets:
      RELEASE_BOT_TOKEN: ${{ secrets.RELEASE_BOT_TOKEN }}
```
