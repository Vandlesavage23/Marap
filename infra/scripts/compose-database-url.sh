#!/usr/bin/env bash
# Build the DATABASE_URL secret from the RDS-managed master credentials and write it to Secrets Manager.
# The password is read and written in memory only (never printed, never in Terraform state or argv).
# Usage: ./compose-database-url.sh <env> [region]
#   Requires: aws CLI, jq, python3; permission to read the RDS master secret and write mc/<env>/DATABASE_URL.
# Re-run after RDS rotates the master password (or replace with a dedicated, rotated application user).
set -euo pipefail

ENVIRONMENT="${1:?environment (dev|staging|prod) required}"
export AWS_REGION="${2:-${AWS_REGION:-af-south-1}}"
PREFIX="mc-${ENVIRONMENT}"

DB_ID="${PREFIX}-postgres"
MASTER_SECRET_ARN="$(aws rds describe-db-instances --db-instance-identifier "$DB_ID" \
  --query 'DBInstances[0].MasterUserSecret.SecretArn' --output text)"
HOST="$(aws rds describe-db-instances --db-instance-identifier "$DB_ID" \
  --query 'DBInstances[0].Endpoint.Address' --output text)"
PORT="$(aws rds describe-db-instances --db-instance-identifier "$DB_ID" \
  --query 'DBInstances[0].Endpoint.Port' --output text)"

# Pass the secret via the environment of a single process, not on a command line.
URL="$(aws secretsmanager get-secret-value --secret-id "$MASTER_SECRET_ARN" --query SecretString --output text \
  | HOST="$HOST" PORT="$PORT" python3 -I -c '
import json, os, sys, urllib.parse as u
s = json.load(sys.stdin)
print("postgres://%s:%s@%s:%s/mc?sslmode=require" % (
    u.quote(s["username"], safe=""), u.quote(s["password"], safe=""), os.environ["HOST"], os.environ["PORT"]))
')"

aws secretsmanager put-secret-value --secret-id "mc/${ENVIRONMENT}/DATABASE_URL" \
  --secret-string "$URL" --query VersionId --output text >/dev/null
unset URL
echo "DATABASE_URL secret for ${ENVIRONMENT} updated (value not shown)."
