#!/usr/bin/env bash
# Run the full inventory: EC2 + ECS + networking + RDS/Lambda/ELB/ASG + S3/Route53/OpenSearch/GuardDuty/CloudWatch.
#
# Usage:
#   ./all.sh                         # default profile, us-east-1, table output
#   AWS_PROFILE=prod ./all.sh        # pick a profile
#   AWS_REGION=us-west-2 ./all.sh    # pick a region
#   OUTPUT=json ./all.sh > inv.json  # machine-readable
set -euo pipefail
here="$(dirname "$0")"

for s in ec2 ecs network misc; do
  "$here/$s.sh"
done

