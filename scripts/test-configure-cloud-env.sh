#!/usr/bin/env bash
# Local smoke test for the configure-cloud-env composite action (no GitHub,
# no YAML, no secrets, no network). Runs configure-cloud-env.sh against a
# throwaway GITHUB_ENV.
#
#   ./scripts/test-configure-cloud-env.sh
#
# run_case <desc> <expected_rc> <inputs...> -- <expected_env...>
#   <inputs...>          NAME=value pairs fed to the script (env -i).
#   <expected_env...>    NAME=value pairs asserted in GITHUB_ENV afterwards;
#                        NAME= (empty value) asserts the name is ABSENT.
#                        In local mode AWS_* test defaults are written; in
#                        cloud mode the real creds are passed through.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION_SH="${HERE}/../.github/actions/configure-cloud-env/configure-cloud-env.sh"

[ -f "$ACTION_SH" ] || { echo "missing ${ACTION_SH}" >&2; exit 1; }

PASS=0
FAILED=0

msg_pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
msg_fail() { printf 'FAIL  %s\n' "$1"; FAILED=$((FAILED + 1)); }

# block_value <file> <name>: prints the value of the NAME<<_SCA_CLOUD_EOF
# block in <file>, nothing otherwise.
block_value() {
  local file="$1" name="$2" line
  while IFS= read -r line; do
    if [ "$line" = "${name}<<_SCA_CLOUD_EOF" ]; then
      IFS= read -r line || true
      printf '%s\n' "$line"
      return 0
    fi
  done < "$file"
  return 1
}

env_has() {
  local file="$1" name="$2" want="$3" got=""
  if got="$(block_value "$file" "$name")"; then
    [ "$got" = "$want" ]
  else
    return 1
  fi
}

run_case() {
  local desc="$1" expect_rc="$2"; shift 2
  local inputs=() expected=() phase="inputs" arg env_file rc bad=""

  for arg in "$@"; do
    if [ "$arg" = "--" ]; then phase="expected"; continue; fi
    case "$phase" in
      inputs) inputs+=("$arg") ;;
      expected) expected+=("$arg") ;;
    esac
  done

  env_file="$(mktemp)"
  rc=0
  set +e
  env -i PATH="$PATH" GITHUB_ENV="$env_file" "${inputs[@]}" bash "$ACTION_SH" >/dev/null 2>&1
  rc=$?
  set -e

  if [ "$rc" -ne "$expect_rc" ]; then
    msg_fail "${desc} (expected rc=${expect_rc}, got ${rc})"
    rm -f "$env_file"
    return
  fi

  if [ "$expect_rc" -ne 0 ]; then
    # Failure must leave GITHUB_ENV untouched.
    if [ -s "$env_file" ]; then
      msg_fail "${desc} (GITHUB_ENV not empty on failure)"
    else
      msg_pass "$desc"
    fi
    rm -f "$env_file"
    return
  fi

  local name want
  for arg in "${expected[@]}"; do
    name="${arg%%=*}"
    want="${arg#*=}"
    if [ -n "$want" ]; then
      if ! env_has "$env_file" "$name" "$want"; then
        bad="${bad} ${name}"
      fi
    else
      if env_has "$env_file" "$name" ""; then
        bad="${bad} ${name}(unexpected)"
      fi
    fi
  done

  if [ -n "$bad" ]; then
    msg_fail "${desc} (bad env entries:${bad})"
  else
    msg_pass "$desc"
  fi
  rm -f "$env_file"
}

# local / aws
run_case "local default (no inputs)" 0 -- \
  AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test \
  AWS_DEFAULT_REGION=us-east-1 AWS_ENDPOINT_URL=http://localhost:4566
run_case "local: custom region" 0 \
  CLOUD_REGION=eu-west-1 -- \
  AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test \
  AWS_DEFAULT_REGION=eu-west-1 AWS_ENDPOINT_URL=http://localhost:4566
run_case "local: custom endpoint" 0 \
  CLOUD_ENDPOINT_URL=http://localhost:8080 -- \
  AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test \
  AWS_DEFAULT_REGION=us-east-1 AWS_ENDPOINT_URL=http://localhost:8080
run_case "local: ignores supplied secrets" 0 \
  AWS_ACCESS_KEY_ID=AKIA999 AWS_SECRET_ACCESS_KEY=secret999 \
  CLOUD_MODE=local -- \
  AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test \
  AWS_DEFAULT_REGION=us-east-1 AWS_ENDPOINT_URL=http://localhost:4566

# cloud / aws
run_case "cloud: real creds, no endpoint" 0 \
  CLOUD_MODE=cloud CLOUD_REGION=us-west-2 \
  AWS_ACCESS_KEY_ID=AKIA123 AWS_SECRET_ACCESS_KEY=secret123 -- \
  AWS_ACCESS_KEY_ID=AKIA123 AWS_SECRET_ACCESS_KEY=secret123 \
  AWS_DEFAULT_REGION=us-west-2
run_case "cloud: real creds, with endpoint" 0 \
  CLOUD_MODE=cloud CLOUD_REGION=us-east-1 CLOUD_ENDPOINT_URL=https://s3.example.com \
  AWS_ACCESS_KEY_ID=AKIA456 AWS_SECRET_ACCESS_KEY=secret456 -- \
  AWS_ACCESS_KEY_ID=AKIA456 AWS_SECRET_ACCESS_KEY=secret456 \
  AWS_DEFAULT_REGION=us-east-1 AWS_ENDPOINT_URL=https://s3.example.com
run_case "cloud: missing secrets must fail" 1 \
  CLOUD_MODE=cloud CLOUD_REGION=us-east-1 -- \
  AWS_ACCESS_KEY_ID= AWS_SECRET_ACCESS_KEY=

# failure / injection cases (must fail, nothing written)
run_case "unsupported provider → fail" 1 \
  CLOUD_PROVIDER=gcp CLOUD_MODE=local -- \
  AWS_ACCESS_KEY_ID= AWS_SECRET_ACCESS_KEY= AWS_DEFAULT_REGION= AWS_ENDPOINT_URL=
run_case "invalid mode → fail" 1 \
  CLOUD_MODE=bogus -- \
  AWS_ACCESS_KEY_ID= AWS_SECRET_ACCESS_KEY= AWS_DEFAULT_REGION= AWS_ENDPOINT_URL=
run_case "newline in region → fail" 1 \
  CLOUD_REGION=$'us-east-1\nAWS_EVIL=1' -- \
  AWS_ACCESS_KEY_ID= AWS_SECRET_ACCESS_KEY= AWS_DEFAULT_REGION= AWS_ENDPOINT_URL=
run_case "newline in endpoint → fail" 1 \
  CLOUD_ENDPOINT_URL=$'http://x\nAWS_EVIL=1' -- \
  AWS_ACCESS_KEY_ID= AWS_SECRET_ACCESS_KEY= AWS_DEFAULT_REGION= AWS_ENDPOINT_URL=
run_case "newline in secret → fail" 1 \
  CLOUD_MODE=cloud AWS_ACCESS_KEY_ID=AKIA123 \
  AWS_SECRET_ACCESS_KEY=$'secret\nAWS_EVIL=1' -- \
  AWS_ACCESS_KEY_ID= AWS_SECRET_ACCESS_KEY= AWS_DEFAULT_REGION= AWS_ENDPOINT_URL=

printf '\n%d passed, %d failed\n' "$PASS" "$FAILED"
[ "$FAILED" -eq 0 ]
