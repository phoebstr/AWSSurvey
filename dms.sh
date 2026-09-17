#!/usr/bin/env bash
# AWS Database Migration Service (DMS) inventory: replication instances,
# endpoints, classic replication tasks, serverless replication configs +
# their status, subnet groups, certificates, and event subscriptions.
source "$(dirname "$0")/lib.sh"
require_jq
preflight

hr "DMS replication instances"
aws_q dms describe-replication-instances \
| jq '[(.ReplicationInstances//[])[] | {
      IDENTIFIER:.ReplicationInstanceIdentifier,
      CLASS:.ReplicationInstanceClass,
      ENGINE:(.EngineVersion//"-"),
      STATUS:.ReplicationInstanceStatus,
      MULTI_AZ:(.MultiAZ//false),
      PUBLIC:(.PubliclyAccessible//false),
      STORAGE_GB:(.AllocatedStorage//0),
      AZ:(.AvailabilityZone//"-"),
      ARN:.ReplicationInstanceArn
    }]' \
| render "DMS replication instances"

hr "DMS endpoints"
aws_q dms describe-endpoints \
| jq '[(.Endpoints//[])[] | {
      ENDPOINT_ID:.EndpointIdentifier,
      TYPE:.EndpointType,
      ENGINE:(.EngineName//"-"),
      STATUS:(.Status//"-"),
      SERVER:(.ServerName//"-"),
      PORT:(.Port//"-"),
      DATABASE:(.DatabaseName//"-"),
      SSL:(.SslMode//"-"),
      ARN:.EndpointArn
    }]' \
| render "DMS endpoints"

hr "DMS replication tasks"
aws_q dms describe-replication-tasks \
| jq '[(.ReplicationTasks//[])[] | {
      TASK_ID:.ReplicationTaskIdentifier,
      MIGRATION_TYPE:(.MigrationType//"-"),
      STATUS:(.Status//"-"),
      PROGRESS_PCT:(.ReplicationTaskStats.FullLoadProgressPercent//0),
      TABLES_LOADED:(.ReplicationTaskStats.TablesLoaded//0),
      TABLES_ERRORED:(.ReplicationTaskStats.TablesErrored//0),
      LAST_FAILURE:(.LastFailureMessage//"-"),
      ARN:.ReplicationTaskArn
    }]' \
| render "DMS replication tasks"

hr "DMS serverless replication configs"
aws_q dms describe-replication-configs \
| jq '[(.ReplicationConfigs//[])[] | {
      CONFIG_ID:.ReplicationConfigIdentifier,
      MIGRATION_TYPE:(.ReplicationType//"-"),
      ARN:.ReplicationConfigArn
    }]' \
| render "DMS serverless replication configs"

hr "DMS serverless replications (status)"
aws_q dms describe-replications \
| jq '[(.Replications//[])[] | {
      CONFIG_ID:.ReplicationConfigIdentifier,
      TYPE:(.ReplicationType//"-"),
      STATUS:(.Status//"-"),
      LAST_FAILURE:(.FailureMessages//[]|join("; ")|if .=="" then "-" else . end),
      ARN:.ReplicationConfigArn
    }]' \
| render "DMS serverless replications"

hr "DMS replication subnet groups"
aws_q dms describe-replication-subnet-groups \
| jq '[(.ReplicationSubnetGroups//[])[] | {
      GROUP_ID:.ReplicationSubnetGroupIdentifier,
      VPC:(.VpcId//"-"),
      STATUS:(.SubnetGroupStatus//"-"),
      SUBNETS:((.Subnets//[])|map(.SubnetIdentifier)|join(","))
    }]' \
| render "DMS replication subnet groups"

hr "DMS certificates"
aws_q dms describe-certificates \
| jq '[(.Certificates//[])[] | {
      CERT_ID:.CertificateIdentifier,
      VALID_FROM:((.ValidFromDate//"-")|tostring),
      VALID_TO:((.ValidToDate//"-")|tostring),
      ARN:.CertificateArn
    }]' \
| render "DMS certificates"

hr "DMS event subscriptions"
aws_q dms describe-event-subscriptions \
| jq '[(.EventSubscriptionsList//[])[] | {
      NAME:.CustSubscriptionId,
      SOURCE_TYPE:(.SourceType//"-"),
      SNS_TOPIC:(.SnsTopicArn//"-"),
      STATUS:(.Status//"-"),
      ENABLED:(.Enabled//false)
    }]' \
| render "DMS event subscriptions"
