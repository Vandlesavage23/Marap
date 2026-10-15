#!/usr/bin/env bash
# Create the Terraform remote-state S3 bucket and DynamoDB lock table (once per AWS account).
# Usage: AWS_REGION=af-south-1 ./bootstrap-state.sh <state-bucket-name> <lock-table-name>
# Run with admin credentials of the target account. Idempotent. NOT yet run against any account.
set -euo pipefail

BUCKET="${1:?state bucket name required}"
TABLE="${2:?lock table name required}"
REGION="${AWS_REGION:-af-south-1}"

if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "bucket $BUCKET exists"
else
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
    --create-bucket-configuration "LocationConstraint=$REGION"
fi

aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$BUCKET" --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'
aws s3api put-bucket-policy --bucket "$BUCKET" --policy "$(cat <<POLICY
{"Version":"2012-10-17","Statement":[{"Sid":"DenyInsecureTransport","Effect":"Deny","Principal":"*",
"Action":"s3:*","Resource":["arn:aws:s3:::$BUCKET","arn:aws:s3:::$BUCKET/*"],
"Condition":{"Bool":{"aws:SecureTransport":"false"}}}]}
POLICY
)"

if aws dynamodb describe-table --table-name "$TABLE" --region "$REGION" >/dev/null 2>&1; then
  echo "table $TABLE exists"
else
  aws dynamodb create-table --table-name "$TABLE" --region "$REGION" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --sse-specification Enabled=true
  aws dynamodb wait table-exists --table-name "$TABLE" --region "$REGION"
fi

echo "State backend ready. Init each environment with:"
echo "  terraform init -backend-config=bucket=$BUCKET -backend-config=dynamodb_table=$TABLE -backend-config=region=$REGION"
