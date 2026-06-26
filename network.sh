#!/usr/bin/env bash
# Networking inventory: VPCs, subnets, security groups, NAT/IGW, Elastic IPs.
source "$(dirname "$0")/lib.sh"
require_jq
preflight

hr "VPCs"
aws_q ec2 describe-vpcs \
| jq '[.Vpcs[] | {
      VPC_ID:.VpcId, CIDR:.CidrBlock, DEFAULT:.IsDefault,
      NAME:((.Tags//[])|map(select(.Key=="Name"))|.[0].Value // "-")
    }]' \
| render "VPCs"

hr "Subnets"
# sort_by inside jq so ordering never disturbs the header (render derives the
# header from object keys, not from a row in the data stream).
aws_q ec2 describe-subnets \
| jq '[.Subnets[] | {
      SUBNET_ID:.SubnetId, VPC_ID:.VpcId, AZ:.AvailabilityZone, CIDR:.CidrBlock,
      FREE_IPS:.AvailableIpAddressCount, PUBLIC:.MapPublicIpOnLaunch,
      NAME:((.Tags//[])|map(select(.Key=="Name"))|.[0].Value // "-")
    }] | sort_by(.VPC_ID)' \
| render "Subnets"

hr "Security groups"
aws_q ec2 describe-security-groups \
| jq '[.SecurityGroups[] | {
      GROUP_ID:.GroupId, NAME:.GroupName, VPC_ID:(.VpcId//"-"),
      INGRESS:(.IpPermissions|length), EGRESS:(.IpPermissionsEgress|length)
    }]' \
| render "Security groups"

hr "NAT gateways"
aws_q ec2 describe-nat-gateways \
| jq '[.NatGateways[] | {
      NAT_ID:.NatGatewayId, STATE:.State, SUBNET:.SubnetId, VPC:.VpcId,
      PUBLIC_IP:((.NatGatewayAddresses//[])|.[0].PublicIp // "-")
    }]' \
| render "NAT gateways"

hr "Internet gateways"
aws_q ec2 describe-internet-gateways \
| jq '[.InternetGateways[] | {
      IGW_ID:.InternetGatewayId,
      ATTACHED_VPC:((.Attachments//[])|.[0].VpcId // "-")
    }]' \
| render "Internet gateways"

hr "Elastic IPs"
aws_q ec2 describe-addresses \
| jq '[.Addresses[] | {
      PUBLIC_IP:.PublicIp, ASSOC_ID:(.AssociationId//"UNATTACHED"),
      INSTANCE:(.InstanceId//"-"),
      NAME:((.Tags//[])|map(select(.Key=="Name"))|.[0].Value // "-")
    }]' \
| render "Elastic IPs"
