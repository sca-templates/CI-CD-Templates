#!/usr/bin/env bash
# Configure cloud environment.
#
# Inputs (set by action.yml from variables/secrets; nothing else is read or
# probed):
#   CLOUD_PROVIDER  aws (default)         provider driver
#   CLOUD_MODE      local (default) cloud mode
#   CLOUD_REGION    region (e.g. us-east-1)
#   CLOUD_ENDPOINT_URL  optional endpoint (emulation host in local mode)
#   AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY  (cloud mode only)
#
# Writes provider env vars to GITHUB_ENV via ONE function, emit(), which
# always uses the multiline heredoc form with a fixed delimiter. emit() is the
# only place that touches GITHUB_ENV, so the action cannot leak lines and can
# never be used to inject additional environment variables.
set -euo pipefail

PROVIDER="${CLOUD_PROVIDER:-aws}"
MODE="${CLOUD_MODE:-local}"
REGION="${CLOUD_REGION:-us-east-1}"
ENDPOINT="${CLOUD_ENDPOINT_URL:-}"
ACCESS_KEY="${AWS_ACCESS_KEY_ID:-}"
SECRET_KEY="${AWS_SECRET_ACCESS_KEY:-}"

if [ -z "${GITHUB_ENV:-}" ]; then
  echo "::error::GITHUB_ENV must be set (run through the composite action)" >&2
  exit 1
fi

DELIM='_SCA_CLOUD_EOF'

# validate <name> <value>: aborts before anything is written (so a failure is
# atomic and cannot leave a partial GITHUB_ENV nor inject a variable).
validate() {
  local name="$1" value="$2"
  case "${name}" in
    *[!A-Za-z0-9_]*|"")
      echo "::error::refusing to write invalid env name '${name}'" >&2
      exit 1
      ;;
  esac
  case "${value}" in
    *$'\n'*|*$'\r'*)
      echo "::error::refusing to write '${name}': value contains a newline" >&2
      exit 1
      ;;
    *"${DELIM}"*)
      echo "::error::refusing to write '${name}': value contains the delimiter" >&2
      exit 1
      ;;
  esac
}

# Phase 1 — validate.*: nothing is written yet ⟹ a validation failure never
# leaves a partial GITHUB_ENV and never creates a KEY=value one-liner.
pairs=()
collect() {
  validate "$1" "$2"
  pairs+=("$1" "$2")
}

case "${PROVIDER}" in
  aws)
    case "${MODE}" in
      local)
        collect AWS_ACCESS_KEY_ID "test"
        collect AWS_SECRET_ACCESS_KEY "test"
        collect AWS_DEFAULT_REGION "${REGION}"
        collect AWS_ENDPOINT_URL "${ENDPOINT:-http://localhost:4566}"
        ;;
      cloud)
        if [ -z "${ACCESS_KEY}" ] || [ -z "${SECRET_KEY}" ]; then
          echo "::error::cloud mode with provider 'aws' requires AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY secrets at org, environment or repo level." >&2
          exit 1
        fi
        collect AWS_ACCESS_KEY_ID "${ACCESS_KEY}"
        collect AWS_SECRET_ACCESS_KEY "${SECRET_KEY}"
        collect AWS_DEFAULT_REGION "${REGION}"
        if [ -n "${ENDPOINT}" ]; then
          collect AWS_ENDPOINT_URL "${ENDPOINT}"
        fi
        ;;
      *)
        echo "::error::CLOUD_MODE must be 'local' or 'cloud' (got '${MODE}')" >&2
        exit 1
        ;;
    esac
    ;;
  *)
    echo "::error::CLOUD_PROVIDER must be 'aws' for now (got '${PROVIDER}'); other providers are added as drivers." >&2
    exit 1
    ;;
esac

# Phase 2 — emit (only after all pairs validated).
emit() {
  local name="$1" value="$2"
  {
    printf '%s<<%s\n' "${name}" "${DELIM}"
    printf '%s\n' "${value}"
    printf '%s\n' "${DELIM}"
  } >> "${GITHUB_ENV}"
}

count=0
while [ "${count}" -lt "${#pairs[@]}" ]; do
  emit "${pairs[${count}]}" "${pairs[$((count + 1))]}"
  count=$((count + 2))
done
