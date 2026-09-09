# Reusable Workflows

All reusable workflows live flat in `.github/workflows/` (GitHub does not support subdirectories).

## Global

| Workflow | File | Description |
|---|---|---|
| Static Validation | `reusable_validate-static.yml` | Markdown, YAML, shell linting |
| Security Validation | `reusable_validate-security.yml` | Secret scanning, license compliance |

## Node.js

| Workflow | File | Description |
|---|---|---|
| Node.js CI | `reusable_nodejs-ci.yml` | Lint + typecheck + test |
| Node.js Release | `reusable_nodejs-release.yml` | release-please + changelog |

## Self-tests

| Workflow | File | Description |
|---|---|---|
| Test: Static Validation | `test_validate-static.yml` | Self-test for static validation |
| Test: Node.js CI | `test_nodejs-ci.yml` | Self-test for Node.js CI |

## Adding a new technology

1. Create `reusable_<tech>-ci.yml` and `reusable_<tech>-release.yml` in `.github/workflows/`
2. Create `test_<tech>-ci.yml` to self-test
3. Add composite actions under `.github/actions/<tech>/`
4. Add a ruleset under `.github/rulesets/<tech>-*.json`
5. Update this file and `docs/INDEX.md`
