#!/usr/bin/env bash
# Deletes the lab resources created by these scripts. Irreversible.
set -euo pipefail
DIR="$(dirname "$0")"
source "$DIR/00-env.sh"

read -r -p "Delete the DMS task, endpoints, replication instance AND RDS instance ${RDS_ID}? Type yes: " OK
[ "$OK" = "yes" ] || { echo "Aborted."; exit 1; }

if [ -f "$DIR/.task_arn" ]; then
  TASK_ARN=$(cat "$DIR/.task_arn")
  aws dms stop-replication-task --region "$AWS_REGION" --replication-task-arn "$TASK_ARN" >/dev/null 2>&1 || true
  aws dms wait replication-task-stopped --region "$AWS_REGION" --filters Name=replication-task-arn,Values="$TASK_ARN" || true
  aws dms delete-replication-task --region "$AWS_REGION" --replication-task-arn "$TASK_ARN" >/dev/null
  aws dms wait replication-task-deleted --region "$AWS_REGION" --filters Name=replication-task-arn,Values="$TASK_ARN" || true
fi

for F in .src_arn .tgt_arn; do
  [ -f "$DIR/$F" ] && aws dms delete-endpoint --region "$AWS_REGION" --endpoint-arn "$(cat "$DIR/$F")" >/dev/null
done

if [ -f "$DIR/.ri_arn" ]; then
  RI_ARN=$(cat "$DIR/.ri_arn")
  aws dms delete-replication-instance --region "$AWS_REGION" --replication-instance-arn "$RI_ARN" >/dev/null
  aws dms wait replication-instance-deleted --region "$AWS_REGION" --filters Name=replication-instance-arn,Values="$RI_ARN" || true
fi
aws dms delete-replication-subnet-group --region "$AWS_REGION" \
  --replication-subnet-group-identifier "${PREFIX}-dms-subnets" || true

aws rds delete-db-instance --region "$AWS_REGION" --db-instance-identifier "$RDS_ID" \
  --skip-final-snapshot --delete-automated-backups >/dev/null
aws rds wait db-instance-deleted --region "$AWS_REGION" --db-instance-identifier "$RDS_ID"
aws rds delete-db-subnet-group --region "$AWS_REGION" --db-subnet-group-name "${PREFIX}-db-subnets"

rm -f "$DIR"/.ri_arn "$DIR"/.src_arn "$DIR"/.tgt_arn "$DIR"/.task_arn
echo "Cleanup complete. NAT gateways and the VPC are not touched by this script."
