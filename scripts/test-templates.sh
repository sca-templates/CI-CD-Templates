#!/usr/bin/env bash
# Template library structural invariants, run locally via pre-commit
# (.pre-commit-config.yaml, hook: template-structure).
#
# Keeps the catalog self-consistent: reusable workflows are flat, prefixed,
# self-tested, catalogued in docs, and free of mutable/unpinned references and
# run-step expression interpolation.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WF="$ROOT/.github/workflows"
DOCS="$ROOT/docs/workflows.md"

fail=0

fail_msg() {
  echo "FAIL: $1"
  fail=1
}

# Reusable workflows are flat in .github/workflows (GitHub constraint).
if [ -n "$(find "$WF" -mindepth 2 -name '*.yml' -print -quit)" ]; then
  fail_msg "reusable workflows must be flat in .github/workflows"
fi

# Every shared-* and stack-* workflow has a workflow_call trigger and is listed
# in the workflows catalog.
for f in "$WF"/shared-*.yml "$WF"/stack-*.yml; do
  [ -e "$f" ] || continue
  name="$(basename "$f")"
  grep -q "^  workflow_call:" "$f" || fail_msg "$name lacks a workflow_call trigger"
  grep -qF "$name" "$DOCS" || fail_msg "$name is missing from docs/workflows.md"
done

# Each shared-* workflow has a self-* workflow that calls it.
for f in "$WF"/shared-*.yml; do
  name="$(basename "$f")"
  grep -rqF "workflows/$name" "$WF"/self-*.yml || fail_msg "$name has no self-* workflow calling it"
done

# No mutable action references: @latest, or self-refs not pinned to a full SHA.
if grep -rn "uses:.*@latest" "$WF" >/dev/null 2>&1; then
  fail_msg "found @latest action references"
fi
while IFS= read -r ref; do
  [ -n "$ref" ] || continue
  sha="${ref##*@}"
  if [ "${#sha}" -ne 40 ] || ! printf '%s' "$sha" | grep -qE '^[0-9a-f]{40}$'; then
    fail_msg "unpinned self-reference: ${ref}"
  fi
done < <(grep -rhoE 'CI-CD-Templates/\.github/(actions|workflows)/[^@[:space:]]+@[0-9a-zA-Z._/-]+' "$WF" || true)

# No run-step that starts with an interpolated expression (command injection).
if grep -rnE '^[[:space:]]*run:[[:space:]]*[$][{]{' "$WF" >/dev/null 2>&1; then
  fail_msg "run steps must not interpolate expressions as commands"
fi

# No free-form command inputs (same injection surface).
if grep -rnE '^[[:space:]]+[a-z0-9-]+-command:[[:space:]]*$' "$WF"/shared-*.yml "$WF"/stack-*.yml >/dev/null 2>&1; then
  fail_msg "free-form *-command inputs are not allowed (code injection surface)"
fi

# Composite actions declare the composite runner.
for d in "$ROOT"/.github/actions/*/; do
  [ -d "$d" ] || continue
  if [ -f "$d/action.yml" ]; then
    grep -q "using: composite" "$d/action.yml" || fail_msg "$d/action.yml must use 'using: composite'"
  elif [ -n "$(ls -A "$d")" ]; then
    fail_msg "$d contains files but no action.yml"
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "Template structure check failed."
  exit 1
fi
echo "Template structure check passed."
