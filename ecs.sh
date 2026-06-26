#!/usr/bin/env bash
# ECS inventory: clusters, services, and task-definition families.
source "$(dirname "$0")/lib.sh"
require_jq
preflight

hr "ECS clusters"
cluster_arns=$(aws_q ecs list-clusters | jq -r '.clusterArns[]')
if [ -n "$cluster_arns" ]; then
  # shellcheck disable=SC2086
  aws_q ecs describe-clusters --clusters $cluster_arns \
  | jq '[.clusters[] | {
        CLUSTER:.clusterName, STATUS:.status, SERVICES:.activeServicesCount,
        RUNNING_TASKS:.runningTasksCount, PENDING_TASKS:.pendingTasksCount
      }]'
else
  echo '[]'
fi | render "ECS clusters"

hr "ECS services"
for c in $cluster_arns; do
  svc_arns=$(aws_q ecs list-services --cluster "$c" | jq -r '.serviceArns[]')
  [ -z "$svc_arns" ] && continue
  # describe-services caps at 10 ARNs per call; chunk to stay under the limit.
  echo "$svc_arns" | xargs -n10 | while read -r chunk; do
    # shellcheck disable=SC2086
    aws_q ecs describe-services --cluster "$c" --services $chunk
  done
done | jq -s '[.[].services[] | {
      CLUSTER:(.clusterArn|sub(".*/";"")), SERVICE:.serviceName, STATUS:.status,
      DESIRED:.desiredCount, RUNNING:.runningCount, LAUNCH_TYPE:(.launchType//"-")
    }] | sort_by(.CLUSTER, .SERVICE)' \
| render "ECS services"

hr "ECS task definition families"
aws_q ecs list-task-definition-families --status ACTIVE \
| jq '[.families[] | {FAMILY:.}]' \
| render "ECS task definition families"
