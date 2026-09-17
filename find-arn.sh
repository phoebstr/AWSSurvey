#!/usr/bin/env bash
# Find/inspect resources in the account by ARN or free-text search.
#
# Usage:
#   ./find-arn.sh <term>                 # search by name/type/service fragment
#   ./find-arn.sh arn:aws:ecs:...        # inspect a specific ARN (describe it)
#   AWS_PROFILE=prod ./find-arn.sh badges
#   OUTPUT=json ./find-arn.sh ecs > hits.json
#
# Search strategy (best-effort, degrades gracefully):
#   1. If the term looks like an ARN, parse it and describe the resource
#      directly via the owning service.
#   2. Otherwise, try Resource Explorer (if an aggregator index exists), then
#      fall back to the Resource Groups Tagging API to enumerate + grep.
source "$(dirname "$0")/lib.sh"

usage() {
  sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && usage 0
[ $# -eq 0 ] && { echo "ERROR: a search term or ARN is required" >&2; usage 1 >&2; }

require_jq
preflight

TERM="$1"

# --- Case 1: caller handed us an ARN → describe the concrete resource. --------
if [[ "$TERM" == arn:aws:* ]]; then
  # arn:aws:<service>:<region>:<account>:<resource-type>/<id>  (or ...:<id>)
  IFS=':' read -r _arn _partition service region account rest <<<"$TERM"
  # rest may be "type/id", "type:id", or just "id" depending on the service.
  rtype="${rest%%[:/]*}"
  rid="${rest#*[:/]}"
  note "parsed ARN: service=$service region=${region:-<global>} type=$rtype id=$rid"

  # region can differ from AWS_REGION for the ARN we were given; honor the ARN.
  R="${region:-$AWS_REGION}"

  hr "Describe $service:$rtype"
  case "$service" in
    ecs)
      # arn:aws:ecs:...:service/<cluster>/<name>  or  task-definition/<name>:<rev>
      if [ "$rtype" = "service" ]; then
        cluster="${rid%%/*}"; svc="${rid#*/}"
        aws --region "$R" --output json ecs describe-services \
          --cluster "$cluster" --services "$svc" \
        | jq '[.services[] | {NAME:.serviceName, CLUSTER:(.clusterArn|split("/")|last),
              STATUS:.status, DESIRED:.desiredCount, RUNNING:.runningCount}]' \
        | render "ECS service"
      else
        aws --region "$R" --output json ecs describe-task-definition \
          --task-definition "$rid" | jq '.taskDefinition | {FAMILY:.family, REVISION:.revision, ARN:.taskDefinitionArn}' \
        | jq -s '.' | render "ECS $rtype"
      fi
      ;;
    secretsmanager)
      aws --region "$R" --output json secretsmanager describe-secret --secret-id "$TERM" \
      | jq '[{NAME:.Name, ARN:.ARN, LAST_CHANGED:(.LastChangedDate//"-"|tostring)}]' \
      | render "Secret"
      ;;
    iam)
      # IAM is global; type is role/user/policy.
      case "$rtype" in
        role) aws --output json iam get-role --role-name "$rid" | jq '[.Role|{NAME:.RoleName, ARN:.Arn, CREATED:(.CreateDate|tostring)}]' | render "IAM role" ;;
        user) aws --output json iam get-user --user-name "$rid" | jq '[.User|{NAME:.UserName, ARN:.Arn}]' | render "IAM user" ;;
        policy) aws --output json iam get-policy --policy-arn "$TERM" | jq '[.Policy|{NAME:.PolicyName, ARN:.Arn, ATTACHED:.AttachmentCount}]' | render "IAM policy" ;;
        *) note "no describe handler for iam:$rtype — showing tags"; TERM="$TERM"; ;;
      esac
      ;;
    s3)
      aws --region "$R" --output json s3api get-bucket-location --bucket "$rtype" \
      | jq --arg b "$rtype" '[{BUCKET:$b, REGION:(.LocationConstraint//"us-east-1")}]' \
      | render "S3 bucket"
      ;;
    cloudformation)
      aws --region "$R" --output json cloudformation describe-stacks --stack-name "$rid" \
      | jq '[.Stacks[] | {NAME:.StackName, STATUS:.StackStatus, UPDATED:(.LastUpdatedTime//.CreationTime|tostring)}]' \
      | render "CloudFormation stack"
      ;;
    *)
      note "no service-specific describe for '$service' — falling back to tag lookup"
      aws --region "$R" --output json resourcegroupstaggingapi get-resources \
        --resource-arn-list "$TERM" 2>/dev/null \
      | jq '[.ResourceTagMappingList[] | {ARN:.ResourceARN,
            TAGS:((.Tags//[])|map("\(.Key)=\(.Value)")|join(","))}]' \
      | render "Tagged resource" \
      || note "no tag data for $TERM"
      ;;
  esac
  exit 0
fi

# --- Case 2: free-text search across the account. -----------------------------
# Try Resource Explorer first (only works if a default view/index exists).
if aws_q resource-explorer-2 get-default-view >/dev/null 2>&1; then
  hr "Resource Explorer search: $TERM"
  aws_q resource-explorer-2 search --query-string "$TERM" \
  | jq '[.Resources[] | {ARN:.Arn, TYPE:.ResourceType, REGION:.Region, SERVICE:.Service}]' \
  | render "Resource Explorer"
  exit 0
fi

note "Resource Explorer not enabled — using Resource Groups Tagging API"
hr "Tagging API search: $TERM"
# Enumerate all taggable resources, then filter ARN + tag values for the term.
aws_q resourcegroupstaggingapi get-resources \
| jq --arg t "$TERM" '
    [ .ResourceTagMappingList[]
      | select( (.ResourceARN | ascii_downcase | contains($t | ascii_downcase))
             or ( (.Tags//[]) | any(.Value | ascii_downcase | contains($t | ascii_downcase)) ) )
      | {ARN:.ResourceARN,
         TAGS:((.Tags//[])|map("\(.Key)=\(.Value)")|join(","))} ]' \
| render "Tagging API"
