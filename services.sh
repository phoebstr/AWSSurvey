#!/usr/bin/env bash
# Broader sweep of common services not covered elsewhere: ECR, DynamoDB,
# ElastiCache, SQS, SNS, Secrets Manager, ACM, CloudFront, KMS, EFS,
# Step Functions, API Gateway.
source "$(dirname "$0")/lib.sh"
require_jq
preflight

hr "ECR repositories"
aws_q ecr describe-repositories \
| jq '[.repositories[] | {
      REPO:.repositoryName, URI:.repositoryUri,
      TAG_MUTABILITY:.imageTagMutability,
      SCAN_ON_PUSH:(.imageScanningConfiguration.scanOnPush//false)
    }]' \
| render "ECR repositories"

hr "DynamoDB tables"
aws_q dynamodb list-tables \
| jq '[.TableNames[] | {TABLE:.}]' \
| render "DynamoDB tables"

hr "ElastiCache clusters"
aws_q elasticache describe-cache-clusters \
| jq '[.CacheClusters[] | {
      CLUSTER:.CacheClusterId, ENGINE:(.Engine+" "+(.EngineVersion//"")),
      NODE_TYPE:.CacheNodeType, STATUS:.CacheClusterStatus,
      NODES:(.NumCacheNodes//0)
    }]' \
| render "ElastiCache clusters"

hr "SQS queues"
aws_q sqs list-queues \
| jq '[(.QueueUrls//[])[] | {QUEUE:(.|sub(".*/";"")), URL:.}]' \
| render "SQS queues"

hr "SNS topics"
aws_q sns list-topics \
| jq '[(.Topics//[])[] | {TOPIC:(.TopicArn|sub(".*:";"")), ARN:.TopicArn}]' \
| render "SNS topics"

hr "Secrets Manager secrets"
aws_q secretsmanager list-secrets \
| jq '[(.SecretList//[])[] | {
      NAME:.Name, ROTATION:(.RotationEnabled//false),
      LAST_CHANGED:((.LastChangedDate//"-")|tostring)
    }]' \
| render "Secrets Manager secrets"

hr "ACM certificates"
aws_q acm list-certificates \
| jq '[(.CertificateSummaryList//[])[] | {
      DOMAIN:.DomainName, STATUS:(.Status//"-"), ARN:.CertificateArn
    }]' \
| render "ACM certificates"

hr "CloudFront distributions"
# CloudFront is global; this returns the same data from any region.
aws_q cloudfront list-distributions \
| jq '[(.DistributionList.Items//[])[] | {
      ID:.Id, DOMAIN:.DomainName, STATUS:.Status, ENABLED:.Enabled,
      ALIASES:((.Aliases.Items//[])|join(","))
    }]' \
| render "CloudFront distributions"

hr "KMS keys"
aws_q kms list-keys \
| jq '[(.Keys//[])[] | {KEY_ID:.KeyId, ARN:.KeyArn}]' \
| render "KMS keys"

hr "EFS file systems"
aws_q efs describe-file-systems \
| jq '[(.FileSystems//[])[] | {
      FS_ID:.FileSystemId, NAME:(.Name//"-"), STATE:.LifeCycleState,
      SIZE_BYTES:(.SizeInBytes.Value//0), MOUNT_TARGETS:(.NumberOfMountTargets//0)
    }]' \
| render "EFS file systems"

hr "Step Functions state machines"
aws_q stepfunctions list-state-machines \
| jq '[(.stateMachines//[])[] | {
      NAME:.name, TYPE:(.type//"-"), ARN:.stateMachineArn
    }]' \
| render "Step Functions state machines"

hr "API Gateway (HTTP/WebSocket v2)"
aws_q apigatewayv2 get-apis \
| jq '[(.Items//[])[] | {
      API:.Name, ID:.ApiId, PROTOCOL:.ProtocolType, ENDPOINT:(.ApiEndpoint//"-")
    }]' \
| render "API Gateway v2 APIs"

hr "API Gateway (REST v1)"
aws_q apigateway get-rest-apis \
| jq '[(.items//[])[] | {API:.name, ID:.id}]' \
| render "API Gateway REST APIs"
