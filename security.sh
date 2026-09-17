#!/usr/bin/env bash
# Security posture sweep: what's actively alerting, not just what's configured.
# Unlike misc.sh (which lists GuardDuty *detectors* and *all* CloudWatch alarms),
# this pulls the findings/alerts an operator needs to triage:
#   - GuardDuty findings (active threats), highest severity first
#   - Security Hub AWS Foundational Security Best Practices — failed controls
#   - Route53 health checks + status, and CloudWatch alarms in a bad state
#
# Usage mirrors the other scripts:
#   ./security.sh                       # default profile, us-east-1, tables
#   AWS_PROFILE=prod ./security.sh
#   OUTPUT=json ./security.sh > sec.json
source "$(dirname "$0")/lib.sh"
require_jq
preflight

# --- GuardDuty findings -------------------------------------------------------
# list-detectors -> per detector, list-findings (server-side sorted by severity
# desc) -> get-findings hydrates the details. Cap to the top 50 per detector so
# a noisy account doesn't fan out into thousands of API calls.
hr "GuardDuty findings (active)"
for id in $(aws_q guardduty list-detectors | jq -r '.DetectorIds[]'); do
  ids=$(aws_q guardduty list-findings \
          --detector-id "$id" \
          --finding-criteria '{"Criterion":{"service.archived":{"Eq":["false"]}}}' \
          --sort-criteria '{"AttributeName":"severity","OrderBy":"DESC"}' \
          --max-items 50 \
        | jq -r '.FindingIds[]?')
  [ -n "$ids" ] || continue
  # get-findings takes up to 50 ids at once.
  aws_q guardduty get-findings --detector-id "$id" --finding-ids $ids \
  | jq '.Findings[]'
done | jq -s '[.[] | {
      SEVERITY:(.Severity|tostring), TYPE:.Type,
      RESOURCE:(.Resource.ResourceType//"-"),
      COUNT:(.Service.Count//1),
      REGION:(.Region//"-"),
      UPDATED:(.UpdatedAt//"-"), TITLE:(.Title//"-")
    }] | sort_by(.SEVERITY) | reverse' \
| render "GuardDuty findings"

# --- Security Hub: AWS Foundational Security Best Practices -------------------
# Filter to the FSBP standard (GeneratorId prefix) and only ACTIVE + FAILED
# controls that still need attention (workflow NEW/NOTIFIED). Paginate cap keeps
# this bounded on accounts with large backlogs.
hr "Security Hub — AWS Foundational (failed controls)"
aws_q securityhub get-findings \
  --filters '{
      "GeneratorId":[{"Value":"aws-foundational-security-best-practices","Comparison":"PREFIX"}],
      "RecordState":[{"Value":"ACTIVE","Comparison":"EQUALS"}],
      "ComplianceStatus":[{"Value":"FAILED","Comparison":"EQUALS"}],
      "WorkflowStatus":[{"Value":"NEW","Comparison":"EQUALS"},{"Value":"NOTIFIED","Comparison":"EQUALS"}]
    }' \
  --max-items 200 \
  2>/dev/null \
| jq '[(.Findings//[])[] | {
      SEVERITY:(.Severity.Label//"-"),
      CONTROL:(.ProductFields."StandardsControlArn"//.GeneratorId|tostring|sub(".*/";"")),
      TITLE:.Title,
      RESOURCE:((.Resources//[])[0].Id//"-"),
      UPDATED:(.UpdatedAt//"-")
    }] | sort_by(
      {"CRITICAL":0,"HIGH":1,"MEDIUM":2,"LOW":3,"INFORMATIONAL":4}[.SEVERITY] // 5
    )' \
| render "Security Hub FSBP findings"

# --- Route53 health checks ----------------------------------------------------
# Config lists the checks; get-health-check-status returns the per-checker
# observations — collapse to healthy/unhealthy counts for a quick read.
hr "Route53 health checks"
for hc in $(aws_q route53 list-health-checks | jq -r '.HealthChecks[].Id'); do
  cfg=$(aws_q route53 list-health-checks | jq -c --arg id "$hc" '.HealthChecks[]|select(.Id==$id).HealthCheckConfig')
  aws_q route53 get-health-check-status --health-check-id "$hc" \
  | jq --arg id "$hc" --argjson cfg "$cfg" '{
        ID:$id,
        TYPE:($cfg.Type//"-"),
        TARGET:(($cfg.FullyQualifiedDomainName // $cfg.IPAddress // "-")
                 + (if $cfg.Port then ":"+($cfg.Port|tostring) else "" end)),
        HEALTHY:([.HealthCheckObservations[]?|select(.StatusReport.Status|test("Success"))]|length),
        UNHEALTHY:([.HealthCheckObservations[]?|select(.StatusReport.Status|test("Success")|not)]|length)
      }'
done | jq -s '.' \
| render "Route53 health checks"

# --- CloudWatch alarms in a non-OK state -------------------------------------
# describe-alarms takes one --state-value at a time; query ALARM and
# INSUFFICIENT_DATA and merge. (misc.sh shows the same set at inventory level;
# here it lives alongside the other health signals for triage.)
hr "CloudWatch alarms (ALARM / INSUFFICIENT_DATA)"
{ aws_q cloudwatch describe-alarms --state-value ALARM
  aws_q cloudwatch describe-alarms --state-value INSUFFICIENT_DATA; } \
| jq -s '[.[].MetricAlarms[] | {
      ALARM:.AlarmName, STATE:.StateValue,
      METRIC:(.MetricName//"-"), NAMESPACE:(.Namespace//"-"),
      SINCE:(.StateUpdatedTimestamp//"-")
    }] | sort_by(.STATE)' \
| render "CloudWatch alarms"
