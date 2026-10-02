#!/usr/bin/env bash
# Creates and starts a full load + CDC replication task.
set -euo pipefail
DIR="$(dirname "$0")"
source "$DIR/00-env.sh"
ROOT="$DIR/.."

TASK_ARN=$(aws dms create-replication-task \
  --region "$AWS_REGION" \
  --replication-task-identifier "${PREFIX}-full-load-cdc" \
  --replication-instance-arn "$(cat "$DIR/.ri_arn")" \
  --source-endpoint-arn "$(cat "$DIR/.src_arn")" \
  --target-endpoint-arn "$(cat "$DIR/.tgt_arn")" \
  --migration-type full-load-and-cdc \
  --table-mappings "file://$ROOT/dms/table-mappings.json" \
  --replication-task-settings "file://$ROOT/dms/task-settings.json" \
  --query 'ReplicationTask.ReplicationTaskArn' --output text)

echo "$TASK_ARN" > "$DIR/.task_arn"

aws dms wait replication-task-ready --region "$AWS_REGION" \
  --filters Name=replication-task-arn,Values="$TASK_ARN"

aws dms start-replication-task --region "$AWS_REGION" \
  --replication-task-arn "$TASK_ARN" \
  --start-replication-task-type start-replication >/dev/null

echo "Task started: $TASK_ARN"
echo "Monitor with scripts/06-monitor.sh"
