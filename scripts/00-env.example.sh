#!/usr/bin/env bash
# Copy to 00-env.sh and fill in. Every script sources 00-env.sh.
# Do not commit 00-env.sh (it is in .gitignore).

export AWS_REGION="us-east-1"
export PREFIX="dms-lab"

# Network (TargetVPC)
export VPC_ID="vpc-xxxxxxxx"
export SUBNET_PRIVATE_A_DB="subnet-aaaaaaaa"
export SUBNET_PRIVATE_B_DB="subnet-bbbbbbbb"
# Subnets for the DMS replication instance (private recommended)
export DMS_SUBNET_A="subnet-cccccccc"
export DMS_SUBNET_B="subnet-dddddddd"
export DMS_SG_ID="sg-dms0000000"      # replication instance security group
export RDS_SG_ID="sg-rds0000000"      # allows 3306 from DMS_SG_ID

# Target RDS
export RDS_ID="database-1"
export RDS_ENGINE_VERSION="8.0.39"
export RDS_CLASS="db.t3.medium"
export RDS_STORAGE_GB="50"
export RDS_MULTI_AZ="false"           # set true before production cutover
export DB_NAME="your_database"
export TARGET_USER="admin"
export TARGET_PASSWORD_SECRET_ARN="arn:aws:secretsmanager:REGION:ACCOUNT:secret:target-db-XXXX"

# Source MySQL
export SOURCE_HOST="10.0.0.10"
export SOURCE_PORT="3306"
export SOURCE_USER="dms_user"
export SOURCE_PASSWORD_SECRET_ARN="arn:aws:secretsmanager:REGION:ACCOUNT:secret:source-db-XXXX"

# DMS
export DMS_INSTANCE_CLASS="dms.t3.medium"
export DMS_STORAGE_GB="50"
export DMS_PUBLIC="false"
# Role that lets DMS read the Secrets Manager secrets above
export DMS_SECRETS_ROLE_ARN="arn:aws:iam::ACCOUNT:role/dms-secrets-access"
