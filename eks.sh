#!/usr/bin/env bash
# EKS inventory: clusters, managed node groups, and Fargate profiles.
source "$(dirname "$0")/lib.sh"
require_jq
preflight

clusters=$(aws_q eks list-clusters | jq -r '.clusters[]')

hr "EKS clusters"
for c in $clusters; do aws_q eks describe-cluster --name "$c"; done \
| jq -s '[.[].cluster | {
      NAME:.name, VERSION:.version, STATUS:.status,
      PLATFORM:(.platformVersion//"-"), ENDPOINT:(.endpoint//"-")
    }]' \
| render "EKS clusters"

hr "EKS node groups"
for c in $clusters; do
  for ng in $(aws_q eks list-nodegroups --cluster-name "$c" | jq -r '.nodegroups[]'); do
    aws_q eks describe-nodegroup --cluster-name "$c" --nodegroup-name "$ng"
  done
done | jq -s '[.[].nodegroup | {
      CLUSTER:.clusterName, NODEGROUP:.nodegroupName, STATUS:.status,
      INSTANCE_TYPES:((.instanceTypes//[])|join(",")),
      DESIRED:(.scalingConfig.desiredSize//0),
      MIN:(.scalingConfig.minSize//0), MAX:(.scalingConfig.maxSize//0)
    }]' \
| render "EKS node groups"

hr "EKS Fargate profiles"
for c in $clusters; do
  for fp in $(aws_q eks list-fargate-profiles --cluster-name "$c" | jq -r '.fargateProfileNames[]'); do
    aws_q eks describe-fargate-profile --cluster-name "$c" --fargate-profile-name "$fp"
  done
done | jq -s '[.[].fargateProfile | {
      CLUSTER:.clusterName, PROFILE:.fargateProfileName, STATUS:.status
    }]' \
| render "EKS Fargate profiles"
