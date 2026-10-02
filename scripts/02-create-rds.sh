#!/usr/bin/env bash
# Creates the DB subnet group (both private DB subnets) and the target RDS MySQL instance.
set -euo pipefail
source "$(dirname "$0")/00-env.sh"

aws rds create-db-subnet-group \
  --region "$AWS_REGION" \
  --db-subnet-group-name "${PREFIX}-db-subnets" \
  --db-subnet-group-description "Private DB subnets for ${RDS_ID}" \
  --subnet-ids "$SUBNET_PRIVATE_A_DB" "$SUBNET_PRIVATE_B_DB"

MULTI_AZ_FLAG="--no-multi-az"
[ "$RDS_MULTI_AZ" = "true" ] && MULTI_AZ_FLAG="--multi-az"

# --manage-master-user-password stores the admin password in Secrets Manager
aws rds create-db-instance \
  --region "$AWS_REGION" \
  --db-instance-identifier "$RDS_ID" \
  --engine mysql \
  --engine-version "$RDS_ENGINE_VERSION" \
  --db-instance-class "$RDS_CLASS" \
  --allocated-storage "$RDS_STORAGE_GB" \
  --storage-type gp3 \
  --master-username "$TARGET_USER" \
  --manage-master-user-password \
  --db-subnet-group-name "${PREFIX}-db-subnets" \
  --vpc-security-group-ids "$RDS_SG_ID" \
  --no-publicly-accessible \
  --backup-retention-period 7 \
  --storage-encrypted \
  $MULTI_AZ_FLAG

echo "Waiting for ${RDS_ID} to become available (10-20 min)..."
aws rds wait db-instance-available --region "$AWS_REGION" --db-instance-identifier "$RDS_ID"

aws rds describe-db-instances --region "$AWS_REGION" --db-instance-identifier "$RDS_ID" \
  --query 'DBInstances[0].[Endpoint.Address,MasterUserSecret.SecretArn]' --output text

echo "Next: create the schema on the target (no secondary indexes/FKs yet)."
