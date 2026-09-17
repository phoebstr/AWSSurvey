#!/usr/bin/env bash
# List every subnet whose CIDR falls inside the 10.0.0.0/8 private range,
# grouped by VPC. Handy for auditing RFC-1918 address usage / overlap.
#
# By default only public subnets (MapPublicIpOnLaunch=true) are returned; pass
# --all (or SHOW_ALL=1) to include private (false) subnets too.
#
# Usage:
#   ./subnets-10.sh                       # default profile, us-east-1, public only
#   ./subnets-10.sh --all                 # include private (PUBLIC=false) subnets
#   AWS_PROFILE=prod ./subnets-10.sh
#   AWS_REGION=us-west-2 ./subnets-10.sh
#   CIDR_PREFIX=10.1. ./subnets-10.sh     # narrow to a sub-range prefix
#   OUTPUT=json ./subnets-10.sh > tens.json
source "$(dirname "$0")/lib.sh"

: "${SHOW_ALL:=0}"
case "${1:-}" in
  -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --all|-a) SHOW_ALL=1 ;;
esac

require_jq
preflight

# A subnet is "in the 10 range" when its CIDR's first octet is 10 (10.0.0.0/8).
# CIDR_PREFIX lets an operator narrow the match, e.g. "10.1." for one /16.
: "${CIDR_PREFIX:=10.}"

if [ "$SHOW_ALL" = 1 ]; then
  hr "Subnets in 10.0.0.0/8 (prefix=$CIDR_PREFIX, public + private)"
else
  hr "Subnets in 10.0.0.0/8 (prefix=$CIDR_PREFIX, public only — pass --all for both)"
fi

aws_q ec2 describe-subnets \
| jq --arg p "$CIDR_PREFIX" --argjson all "$SHOW_ALL" '
    [ .Subnets[]
      | select(.CidrBlock | startswith($p))
      # default: only public subnets; --all keeps both true and false.
      | select($all == 1 or .MapPublicIpOnLaunch == true)
      | {SUBNET_ID:.SubnetId, VPC_ID:.VpcId, AZ:.AvailabilityZone,
         CIDR:.CidrBlock, FREE_IPS:.AvailableIpAddressCount,
         PUBLIC:.MapPublicIpOnLaunch,
         NAME:((.Tags//[])|map(select(.Key=="Name"))|.[0].Value // "-")} ]
    | sort_by(.VPC_ID, .CIDR)' \
| render "10.x subnets"
