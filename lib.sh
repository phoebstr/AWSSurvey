#!/usr/bin/env bash
# Shared helpers for the AWS inventory scripts.
# Source this from the per-service scripts; do not execute directly.

set -euo pipefail

# Region/profile come from the environment so every script honors the same config.
# Override per-invocation:  AWS_PROFILE=prod AWS_REGION=us-west-2 ./ecs.sh
: "${AWS_REGION:=${AWS_DEFAULT_REGION:-us-east-1}}"
export AWS_REGION AWS_DEFAULT_REGION="$AWS_REGION"

# All scripts emit either a human table (default) or JSON (OUTPUT=json).
# In json mode stdout is pure JSON Lines: one {"section","items"} object per
# section, so `OUTPUT=json ./all.sh > inv.json` is parseable with `jq -s`.
: "${OUTPUT:=table}"

aws_q() {
  # Thin wrapper so every call shares region and fails loudly on bad creds.
  aws --region "$AWS_REGION" --output json "$@"
}

# Banners/notes are diagnostics, not data — keep them off stdout so json mode
# stays pure and the redirected file is valid.
hr()  { printf '\n=== %s ===\n' "$1" >&2; }
note() { printf '  %s\n' "$1" >&2; }

# render SECTION
# Reads a JSON array of uniform objects on stdin and writes it to stdout as
# either a column-aligned table (OUTPUT=table) or one tagged JSON object
# (OUTPUT=json). Every section pipes through here, so OUTPUT is honored once,
# consistently, instead of being re-implemented per block.
render() {
  local section="$1"
  if [ "$OUTPUT" = json ]; then
    jq -c --arg s "$section" '{section:$s, items:.}'
  else
    # Header from the first object's keys; every row stringified to align.
    jq -r 'if length==0 then empty else
             (.[0]|keys_unsorted) as $h
             | ([$h] + [.[] | [ $h[] as $k | (.[$k]|tostring) ]])[] | @tsv
           end' | column -t -s$'\t'
  fi
}

require_jq() {
  command -v jq >/dev/null 2>&1 || {
    echo "ERROR: jq is required (brew install jq)" >&2
    exit 1
  }
}

# Confirm credentials work before a script fans out dozens of calls.
# One STS round-trip returns both Account and Arn (run via all.sh this saves
# one call per script).
preflight() {
  local ident account arn
  ident=$(aws_q sts get-caller-identity 2>/dev/null) || {
    echo "ERROR: AWS credentials not valid for profile '${AWS_PROFILE:-default}'." >&2
    echo "       Run 'aws sso login' or set AWS_PROFILE." >&2
    exit 1
  }
  account=$(echo "$ident" | jq -r '.Account')
  arn=$(echo "$ident" | jq -r '.Arn')
  note "account=$account region=$AWS_REGION identity=$arn"
}
