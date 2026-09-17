#!/usr/bin/env bash
# Run the full inventory across every service group.
#
# Usage:
#   ./all.sh                          # default profile, us-east-1, tables
#   AWS_PROFILE=prod ./all.sh         # pick a profile
#   AWS_REGION=us-west-2 ./all.sh     # pick a region
#   OUTPUT=json ./all.sh > inv.json   # JSON Lines — parse with: jq -s . inv.json
#
# In json mode stdout is pure data (banners/notes go to stderr), so the
# redirected file is valid: one {"section","items"} object per section.
set -euo pipefail
here="$(dirname "$0")"

for s in ec2 ecs network eks iam misc services security ai; do
  "$here/$s.sh"
done
