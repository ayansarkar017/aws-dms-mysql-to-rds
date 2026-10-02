#!/usr/bin/env bash
# Shows task status, per-table statistics and recent CDC latency.
set -euo pipefail
DIR="$(dirname "$0")"
source "$DIR/00-env.sh"
TASK_ARN=$(cat "$DIR/.task_arn")

echo "== Task status =="
aws dms describe-replication-tasks --region "$AWS_REGION" \
  --filters Name=replication-task-arn,Values="$TASK_ARN" \
  --query 'ReplicationTasks[0].[Status,ReplicationTaskStats.FullLoadProgressPercent,StopReason]' \
  --output table

echo "== Table statistics =="
aws dms describe-table-statistics --region "$AWS_REGION" \
  --replication-task-arn "$TASK_ARN" \
  --query 'TableStatistics[].[SchemaName,TableName,FullLoadRows,Inserts,Updates,Deletes,ValidationState]' \
  --output table

# CloudWatch dimensions need the resource IDs (last part of each ARN)
RI_ID=$(aws dms describe-replication-instances --region "$AWS_REGION" \
  --filters Name=replication-instance-arn,Values="$(cat "$DIR/.ri_arn")" \
  --query 'ReplicationInstances[0].ReplicationInstanceIdentifier' --output text)
TASK_RES_ID="${TASK_ARN##*:}"

START=$(date -u -d '-15 minutes' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-15M +%Y-%m-%dT%H:%M:%SZ)
END=$(date -u +%Y-%m-%dT%H:%M:%SZ)

for METRIC in CDCLatencySource CDCLatencyTarget; do
  echo "== $METRIC (seconds, last 15 min) =="
  aws cloudwatch get-metric-statistics --region "$AWS_REGION" \
    --namespace AWS/DMS --metric-name "$METRIC" \
    --dimensions Name=ReplicationInstanceIdentifier,Value="$RI_ID" Name=ReplicationTaskIdentifier,Value="$TASK_RES_ID" \
    --start-time "$START" --end-time "$END" --period 60 --statistics Maximum \
    --query 'sort_by(Datapoints,&Timestamp)[-5:].[Timestamp,Maximum]' --output table
done
