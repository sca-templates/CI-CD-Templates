---
description: Quick lint check — YAML and markdown validation only.
agent: build
---

# Check

Run quick lint checks:

1. `yamllint .github/` — YAML files valid
2. `npx markdownlint-cli2 "**/*.md"` — Markdown clean

Report failures and fix in place. This is the fast path — no structural
deep-check, just syntax validation.
