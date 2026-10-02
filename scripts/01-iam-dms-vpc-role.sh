#!/usr/bin/env bash
# One-time: DMS needs the dms-vpc-role to manage ENIs when you use the CLI/API.
# The console creates it automatically; skip this if it already exists.
set -euo pipefail
source "$(dirname "$0")/00-env.sh"

if aws iam get-role --role-name dms-vpc-role >/dev/null 2>&1; then
  echo "dms-vpc-role already exists"; exit 0
fi

aws iam create-role --role-name dms-vpc-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{"Effect": "Allow",
                   "Principal": {"Service": "dms.amazonaws.com"},
                   "Action": "sts:AssumeRole"}]
  }'

aws iam attach-role-policy --role-name dms-vpc-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole

echo "Created dms-vpc-role. Wait ~10 seconds for IAM to propagate."
