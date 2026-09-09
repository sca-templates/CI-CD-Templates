---
name: sca-docs
description: Enforce sca-docs conventions when writing or updating this repository's documentation (README.md, docs/, AGENTS.md). Use when the user asks to create, edit, or review documentation.
---

# sca-docs conventions

> Reference: <https://github.com/sca-templates/sca-docs>

## Rules (strict)

1. **English only** — all content, commit messages, PR descriptions.
2. **One fact, one place** — depth in this repo's `docs/`, pointers in READMEs.
   Never duplicate a fact across files.
3. **Source of truth = `docs/`.** The `docs/` directory is the catalog and usage
   guide. When adding or modifying templates, update the relevant doc in the
   same commit.
4. **Truth over aspiration** — never list a non-existent template as available.
   What is not in the docs does not exist.
5. **Reference-and-explain** — point at real files; do not copy whole workflow
   contents into docs (duplication causes drift). External links as raw URLs.
6. **Links** — relative markdown links between `docs/` files and to the repo root.
7. **Add new tech = update docs** — when adding a new technology category
   (e.g. `stack-go-*`), update `docs/workflows.md`, `docs/rulesets.md`,
   `docs/INDEX.md`, and `README.md` in the same commit.

## Definition of done

- [ ] Content in English
- [ ] No duplicated facts (cross-links instead)
- [ ] Docs updated when adding/modifying templates
- [ ] `markdownlint` passes on all `.md` files

## Fetch conventions

Consult sca-docs via raw URLs:
`https://raw.githubusercontent.com/sca-templates/sca-docs/main/<path>`
