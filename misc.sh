#!/usr/bin/env bash
# Quick survey of the other commonly-running services: RDS, Lambda, ELB/ALB, ASGs,
# plus storage/DNS/search/security globals (S3, Route53, OpenSearch, GuardDuty, CloudWatch).
source "$(dirname "$0")/lib.sh"
require_jq
preflight

hr "RDS instances"
aws_q rds describe-db-instances \
| jq '[.DBInstances[] | {
      IDENTIFIER:.DBInstanceIdentifier, ENGINE:(.Engine+" "+.EngineVersion),
      CLASS:.DBInstanceClass, STATUS:.DBInstanceStatus, MULTI_AZ:.MultiAZ,
      ENDPOINT:(.Endpoint.Address//"-")
    }]' \
| render "RDS instances"

hr "RDS / Aurora clusters"
aws_q rds describe-db-clusters \
| jq '[.DBClusters[] | {
      CLUSTER:.DBClusterIdentifier, ENGINE:(.Engine+" "+(.EngineVersion//"")),
      STATUS:.Status, MEMBERS:(.DBClusterMembers|length)
    }]' \
| render "RDS / Aurora clusters"

hr "Redshift clusters"
aws_q redshift describe-clusters \
| jq '[.Clusters[] | {
      CLUSTER:.ClusterIdentifier, NODE_TYPE:.NodeType, NODES:.NumberOfNodes,
      STATUS:.ClusterStatus, DB:(.DBName//"-"),
      ENDPOINT:(.Endpoint.Address//"-")
    }]' \
| render "Redshift clusters"

hr "DocumentDB clusters"
# docdb shares the RDS-style API but its endpoint filters to the DocumentDB engine.
aws_q docdb describe-db-clusters \
| jq '[.DBClusters[] | {
      CLUSTER:.DBClusterIdentifier, ENGINE:(.Engine+" "+(.EngineVersion//"")),
      STATUS:.Status, MEMBERS:(.DBClusterMembers|length),
      ENDPOINT:(.Endpoint//"-")
    }]' \
| render "DocumentDB clusters"

hr "Neptune clusters"
aws_q neptune describe-db-clusters \
| jq '[.DBClusters[] | {
      CLUSTER:.DBClusterIdentifier, ENGINE:(.Engine+" "+(.EngineVersion//"")),
      STATUS:.Status, MEMBERS:(.DBClusterMembers|length),
      ENDPOINT:(.Endpoint//"-")
    }]' \
| render "Neptune clusters"

hr "RDS proxies"
aws_q rds describe-db-proxies \
| jq '[(.DBProxies//[])[] | {
      PROXY:.DBProxyName, ENGINE_FAMILY:.EngineFamily, STATUS:.Status,
      ENDPOINT:(.Endpoint//"-")
    }]' \
| render "RDS proxies"

hr "Load balancers (ALB/NLB)"
aws_q elbv2 describe-load-balancers \
| jq '[.LoadBalancers[] | {
      NAME:.LoadBalancerName, TYPE:.Type, SCHEME:.Scheme,
      STATE:.State.Code, DNS:.DNSName
    }]' \
| render "Load balancers"

hr "Lambda functions"
aws_q lambda list-functions \
| jq '[.Functions[] | {
      NAME:.FunctionName, RUNTIME:(.Runtime//"container"),
      MEMORY:.MemorySize, LAST_MODIFIED:.LastModified
    }]' \
| render "Lambda functions"

hr "Auto Scaling groups"
aws_q autoscaling describe-auto-scaling-groups \
| jq '[.AutoScalingGroups[] | {
      NAME:.AutoScalingGroupName, MIN:.MinSize, MAX:.MaxSize,
      DESIRED:.DesiredCapacity,
      IN_SERVICE:([.Instances[]|select(.LifecycleState=="InService")]|length)
    }]' \
| render "Auto Scaling groups"

hr "S3 buckets"
# Buckets are global; CreationDate is the only field list-buckets returns.
aws_q s3api list-buckets \
| jq '[.Buckets[] | {BUCKET:.Name, CREATED:.CreationDate}]' \
| render "S3 buckets"

hr "Route53 hosted zones"
aws_q route53 list-hosted-zones \
| jq '[.HostedZones[] | {
      ZONE:.Name, ID:(.Id|sub("/hostedzone/";"")),
      PRIVATE:.Config.PrivateZone, RECORDS:.ResourceRecordSetCount
    }]' \
| render "Route53 hosted zones"

hr "OpenSearch domains"
# list-domain-names is cheap; describe each for endpoint + status.
for d in $(aws_q opensearch list-domain-names | jq -r '.DomainNames[].DomainName'); do
  aws_q opensearch describe-domain --domain-name "$d"
done | jq -s '[.[].DomainStatus | {
      DOMAIN:.DomainName, VERSION:(.EngineVersion//"-"),
      INSTANCES:(.ClusterConfig.InstanceCount//0),
      STATUS:(if .Processing then "processing" else "active" end),
      ENDPOINT:(.Endpoint // .Endpoints.vpc // "-")
    }]' \
| render "OpenSearch domains"

hr "GuardDuty detectors"
for id in $(aws_q guardduty list-detectors | jq -r '.DetectorIds[]'); do
  aws_q guardduty get-detector --detector-id "$id" \
  | jq --arg id "$id" '{DETECTOR_ID:$id, STATUS:.Status, FREQUENCY:.FindingPublishingFrequency}'
done | jq -s '.' \
| render "GuardDuty detectors"

hr "CloudWatch alarms (ALARM / INSUFFICIENT_DATA)"
# describe-alarms takes a single --state-value, so query both and merge.
{ aws_q cloudwatch describe-alarms --state-value ALARM
  aws_q cloudwatch describe-alarms --state-value INSUFFICIENT_DATA; } \
| jq -s '[.[].MetricAlarms[] | {
      ALARM:.AlarmName, STATE:.StateValue, METRIC:(.MetricName//"-"),
      NAMESPACE:(.Namespace//"-")
    }]' \
| render "CloudWatch alarms"
