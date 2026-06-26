#!/usr/bin/env bash
# AI/ML inventory: Bedrock (custom models, provisioned throughput, guardrails,
# agents, knowledge bases) plus SageMaker, Kendra, Comprehend, and Lex.
# Only account-provisioned resources are listed — stateless inference APIs
# (Rekognition, Textract, Polly, Translate) have nothing to enumerate.
#
# Several of these services are region-scoped and may not exist everywhere;
# run against the region where the workloads live (AWS_REGION=...).
source "$(dirname "$0")/lib.sh"
require_jq
preflight

hr "Bedrock custom models"
aws_q bedrock list-custom-models \
| jq '[(.modelSummaries//[])[] | {
      MODEL:.modelName, ARN:.modelArn, BASE:(.baseModelName//"-"),
      CREATED:(.creationTime//"-")
    }]' \
| render "Bedrock custom models"

hr "Bedrock provisioned throughput"
aws_q bedrock list-provisioned-model-throughputs \
| jq '[(.provisionedModelSummaries//[])[] | {
      NAME:.provisionedModelName, MODEL:(.modelArn|sub(".*/";"")),
      STATUS:.status, UNITS:(.modelUnits//0)
    }]' \
| render "Bedrock provisioned throughput"

hr "Bedrock guardrails"
aws_q bedrock list-guardrails \
| jq '[(.guardrails//[])[] | {
      NAME:.name, ID:.id, STATUS:.status, VERSION:(.version//"-")
    }]' \
| render "Bedrock guardrails"

hr "Bedrock agents"
aws_q bedrock-agent list-agents \
| jq '[(.agentSummaries//[])[] | {
      AGENT:.agentName, ID:.agentId, STATUS:.agentStatus,
      UPDATED:(.updatedAt//"-")
    }]' \
| render "Bedrock agents"

hr "Bedrock knowledge bases"
aws_q bedrock-agent list-knowledge-bases \
| jq '[(.knowledgeBaseSummaries//[])[] | {
      NAME:.name, ID:.knowledgeBaseId, STATUS:.status
    }]' \
| render "Bedrock knowledge bases"

hr "SageMaker endpoints"
aws_q sagemaker list-endpoints \
| jq '[(.Endpoints//[])[] | {
      ENDPOINT:.EndpointName, STATUS:.EndpointStatus, CREATED:.CreationTime
    }]' \
| render "SageMaker endpoints"

hr "SageMaker notebook instances"
aws_q sagemaker list-notebook-instances \
| jq '[(.NotebookInstances//[])[] | {
      NOTEBOOK:.NotebookInstanceName, STATUS:.NotebookInstanceStatus,
      INSTANCE_TYPE:(.InstanceType//"-")
    }]' \
| render "SageMaker notebook instances"

hr "SageMaker models"
aws_q sagemaker list-models \
| jq '[(.Models//[])[] | {MODEL:.ModelName, CREATED:.CreationTime}]' \
| render "SageMaker models"

hr "Kendra indexes"
aws_q kendra list-indices \
| jq '[(.IndexConfigurationSummaryItems//[])[] | {
      NAME:.Name, ID:.Id, EDITION:(.Edition//"-"), STATUS:.Status
    }]' \
| render "Kendra indexes"

hr "Comprehend endpoints"
aws_q comprehend list-endpoints \
| jq '[(.EndpointPropertiesList//[])[] | {
      ENDPOINT:(.EndpointArn|sub(".*/";"")), STATUS:.Status,
      MODEL:(.ModelArn|sub(".*/";""))
    }]' \
| render "Comprehend endpoints"

hr "Lex v2 bots"
aws_q lexv2-models list-bots \
| jq '[(.botSummaries//[])[] | {
      BOT:.botName, ID:.botId, STATUS:.botStatus
    }]' \
| render "Lex v2 bots"
