data "aws_caller_identity" "current" {}

# Key policy: account root delegates to IAM. Services get access through IAM policies attached to their
# roles (see ecs_service) and through the explicit service principals below.
data "aws_iam_policy_document" "key" {
  statement {
    sid       = "EnableIamPolicies"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

# mc-data: RDS storage, Redis at rest, Secrets Manager, backups, and wrapping of the application's
# field-level data keys (Bible 12.1).
resource "aws_kms_key" "data" {
  description             = "${var.name_prefix} mc-data: databases, secrets, backups, field-level key wrapping"
  enable_key_rotation     = true
  deletion_window_in_days = var.deletion_window_days
  policy                  = data.aws_iam_policy_document.key.json
  tags                    = merge(var.tags, { Name = "${var.name_prefix}-mc-data" })
}

resource "aws_kms_alias" "data" {
  name          = "alias/${var.name_prefix}-mc-data"
  target_key_id = aws_kms_key.data.key_id
}

# mc-media: S3 media and export objects.
resource "aws_kms_key" "media" {
  description             = "${var.name_prefix} mc-media: S3 media and exports"
  enable_key_rotation     = true
  deletion_window_in_days = var.deletion_window_days
  policy                  = data.aws_iam_policy_document.key.json
  tags                    = merge(var.tags, { Name = "${var.name_prefix}-mc-media" })
}

resource "aws_kms_alias" "media" {
  name          = "alias/${var.name_prefix}-mc-media"
  target_key_id = aws_kms_key.media.key_id
}
