#!/usr/bin/env bash
# Apply the repository rulesets from .github/rulesets/*.json to a repository
# using the GitHub CLI. Idempotent: existing rulesets are updated in place.
#
# The JSON files are API exports and contain response-only fields (`id`,
# `source`, ...); this script normalizes them into create/update payloads and
# keeps required status checks as {context} objects (the API rejects plain
# context strings).
#
# Usage:
#   gh auth login   # requires admin on the target repository
#   ./scripts/setup-rulesets.sh [owner/repo]   # defaults to this repository
set -euo pipefail

REPO="${1:-sca-templates/CI-CD-Templates}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RULESETS="$ROOT/.github/rulesets"

if ! command -v gh >/dev/null 2>&1; then
  echo "error: GitHub CLI (gh) not found; install it and run 'gh auth login'" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "error: gh is not authenticated; run 'gh auth login'" >&2
  exit 1
fi

existing_rulesets="$(gh api "/repos/${REPO}/rulesets" --jq '.[] | "\(.id)\t\(.name)"' 2>/dev/null || true)"

for payload in "$RULESETS"/*.json; do
  name="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["name"])' "$payload")"
  body="$(mktemp)"
  python3 - "$payload" >"$body" <<'EOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
for key in ("id", "source", "source_type", "url", "node_id", "created_at", "updated_at"):
    data.pop(key, None)
for rule in data.get("rules", []):
    if rule.get("type") != "required_status_checks":
        continue
    checks = rule.setdefault("parameters", {}).get("required_status_checks", [])
    rule["parameters"]["required_status_checks"] = [
        {"context": c} if isinstance(c, str) else {"context": c["context"]} for c in checks
    ]
json.dump(data, sys.stdout)
EOF

  id="$(printf '%s\n' "$existing_rulesets" | awk -F'\t' -v n="$name" '$2==n{print $1; exit}')"
  if [ -n "$id" ]; then
    echo "updating ruleset '$name' ($id) in $REPO"
    gh api --method PUT "/repos/${REPO}/rulesets/${id}" --input "$body" >/dev/null
  else
    echo "creating ruleset '$name' in $REPO"
    gh api --method POST "/repos/${REPO}/rulesets" --input "$body" >/dev/null
  fi
  rm -f "$body"
done

echo "done: rulesets applied to $REPO"
