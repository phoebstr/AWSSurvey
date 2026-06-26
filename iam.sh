#!/usr/bin/env bash
# IAM inventory (global): account summary, users, roles, groups, and
# customer-managed policies. Users are enriched with access-key and MFA counts
# so the table doubles as a quick security review.
source "$(dirname "$0")/lib.sh"
require_jq
preflight

hr "IAM account summary"
aws_q iam get-account-summary \
| jq '[.SummaryMap | to_entries[] | {METRIC:.key, VALUE:.value}] | sort_by(.METRIC)' \
| render "IAM account summary"

hr "IAM users"
# One list call, then per-user key/MFA lookups (these counts aren't in list-users).
aws_q iam list-users | jq -c '.Users[]' | while read -r user; do
  u=$(echo "$user" | jq -r '.UserName')
  keys=$(aws_q iam list-access-keys --user-name "$u" | jq '.AccessKeyMetadata|length')
  mfa=$(aws_q iam list-mfa-devices --user-name "$u" | jq '.MFADevices|length')
  echo "$user" | jq --argjson keys "$keys" --argjson mfa "$mfa" '{
      USER:.UserName, CREATED:.CreateDate, PW_LAST_USED:(.PasswordLastUsed//"-"),
      ACCESS_KEYS:$keys, MFA:$mfa
    }'
done | jq -s '. | sort_by(.USER)' \
| render "IAM users"

hr "IAM roles"
# Flag AWS service-linked roles (path /aws-service-role/) so the human ones stand out.
aws_q iam list-roles \
| jq '[.Roles[] | {
      ROLE:.RoleName, CREATED:.CreateDate,
      SERVICE_LINKED:(.Path | startswith("/aws-service-role/"))
    }] | sort_by(.SERVICE_LINKED, .ROLE)' \
| render "IAM roles"

hr "IAM groups"
aws_q iam list-groups \
| jq '[.Groups[] | {GROUP:.GroupName, CREATED:.CreateDate, PATH:.Path}]' \
| render "IAM groups"

hr "IAM customer-managed policies"
# --scope Local excludes the hundreds of AWS-managed policies.
aws_q iam list-policies --scope Local \
| jq '[.Policies[] | {
      POLICY:.PolicyName, ATTACHMENTS:.AttachmentCount, CREATED:.CreateDate
    }] | sort_by(-.ATTACHMENTS)' \
| render "IAM customer-managed policies"
