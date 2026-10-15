# Remote state: S3 bucket + DynamoDB lock table. Bucket and table names are NOT hard-coded: supply them
# with partial configuration at init time (they are created by infra/scripts/bootstrap-state.sh):
#
#   terraform init \
#     -backend-config="bucket=<state-bucket>" \
#     -backend-config="dynamodb_table=<lock-table>" \
#     -backend-config="region=<region>"
#
# or put the same keys in a (non-secret) backend.hcl and run `terraform init -backend-config=backend.hcl`.
terraform {
  backend "s3" {
    key     = "marriage-connect/prod/terraform.tfstate"
    encrypt = true
    # bucket, dynamodb_table, region: partial configuration (see above)
  }
}
