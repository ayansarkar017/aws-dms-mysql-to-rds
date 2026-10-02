#!/usr/bin/env bash
# Creates source and target endpoints (credentials from Secrets Manager) and tests both.
set -euo pipefail
DIR="$(dirname "$0")"
source "$DIR/00-env.sh"
RI_ARN=$(cat "$DIR/.ri_arn")

TARGET_HOST=$(aws rds describe-db-instances --region "$AWS_REGION" \
  --db-instance-identifier "$RDS_ID" --query 'DBInstances[0].Endpoint.Address' --output text)

SRC_ARN=$(aws dms create-endpoint \
  --region "$AWS_REGION" \
  --endpoint-identifier "${PREFIX}-source" \
  --endpoint-type source \
  --engine-name mysql \
  --my-sql-settings "SecretsManagerSecretId=${SOURCE_PASSWORD_SECRET_ARN},SecretsManagerAccessRoleArn=${DMS_SECRETS_ROLE_ARN}" \
  --query 'Endpoint.EndpointArn' --output text)

TGT_ARN=$(aws dms create-endpoint \
  --region "$AWS_REGION" \
  --endpoint-identifier "${PREFIX}-target" \
  --endpoint-type target \
  --engine-name mysql \
  --my-sql-settings "SecretsManagerSecretId=${TARGET_PASSWORD_SECRET_ARN},SecretsManagerAccessRoleArn=${DMS_SECRETS_ROLE_ARN}" \
  --query 'Endpoint.EndpointArn' --output text)
# The source secret must contain host/port/username/password keys.
# With --manage-master-user-password the RDS secret holds only username/password:
# either create your own secret for the target with host and port, or use
# --server-name "$TARGET_HOST" --port 3306 --username ... --password ... instead.

echo "$SRC_ARN" > "$DIR/.src_arn"
echo "$TGT_ARN" > "$DIR/.tgt_arn"

for EP in "$SRC_ARN" "$TGT_ARN"; do
  aws dms test-connection --region "$AWS_REGION" \
    --replication-instance-arn "$RI_ARN" --endpoint-arn "$EP" >/dev/null
done

echo "Testing connections (about 1 minute)..."
sleep 60
aws dms describe-connections --region "$AWS_REGION" \
  --filters Name=replication-instance-arn,Values="$RI_ARN" \
  --query 'Connections[].[EndpointIdentifier,Status,LastFailureMessage]' --output table

echo "Target host for reference: $TARGET_HOST"
