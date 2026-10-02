#!/usr/bin/env bash
# Creates the DMS replication subnet group and replication instance.
set -euo pipefail
source "$(dirname "$0")/00-env.sh"

aws dms create-replication-subnet-group \
  --region "$AWS_REGION" \
  --replication-subnet-group-identifier "${PREFIX}-dms-subnets" \
  --replication-subnet-group-description "Subnets for the DMS replication instance" \
  --subnet-ids "$DMS_SUBNET_A" "$DMS_SUBNET_B"

PUBLIC_FLAG="--no-publicly-accessible"
[ "$DMS_PUBLIC" = "true" ] && PUBLIC_FLAG="--publicly-accessible"

RI_ARN=$(aws dms create-replication-instance \
  --region "$AWS_REGION" \
  --replication-instance-identifier "${PREFIX}-ri" \
  --replication-instance-class "$DMS_INSTANCE_CLASS" \
  --allocated-storage "$DMS_STORAGE_GB" \
  --replication-subnet-group-identifier "${PREFIX}-dms-subnets" \
  --vpc-security-group-ids "$DMS_SG_ID" \
  $PUBLIC_FLAG \
  --query 'ReplicationInstance.ReplicationInstanceArn' --output text)

echo "Waiting for replication instance..."
aws dms wait replication-instance-available --region "$AWS_REGION" \
  --filters Name=replication-instance-arn,Values="$RI_ARN"

echo "$RI_ARN" > "$(dirname "$0")/.ri_arn"
echo "Replication instance ready: $RI_ARN"
