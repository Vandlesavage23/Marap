data "aws_caller_identity" "current" {}

locals {
  suffix = data.aws_caller_identity.current.account_id
  names = {
    media_private   = "${var.name_prefix}-${local.suffix}-media-private"
    exports_private = "${var.name_prefix}-${local.suffix}-exports-private"
    static_public   = "${var.name_prefix}-${local.suffix}-static-public"
  }
  private_buckets = {
    media_private   = aws_s3_bucket.media_private.id
    exports_private = aws_s3_bucket.exports_private.id
  }
}

# ------------------------------------------------------------------ media-private
resource "aws_s3_bucket" "media_private" {
  bucket        = local.names.media_private
  force_destroy = var.force_destroy
  tags          = merge(var.tags, { Name = local.names.media_private, Purpose = "media-private" })
}

# ------------------------------------------------------------------ exports-private
resource "aws_s3_bucket" "exports_private" {
  bucket        = local.names.exports_private
  force_destroy = var.force_destroy
  tags          = merge(var.tags, { Name = local.names.exports_private, Purpose = "exports-private" })
}

# Settings common to both private buckets. for_each keys are static; the bucket ids are only values.
resource "aws_s3_bucket_public_access_block" "private" {
  for_each = local.private_buckets

  bucket                  = each.value
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "private" {
  for_each = local.private_buckets

  bucket = each.value
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "private" {
  for_each = local.private_buckets

  bucket = each.value
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "private" {
  for_each = local.private_buckets

  bucket = each.value
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.media_kms_key_arn
    }
    bucket_key_enabled = true
  }
}

data "aws_iam_policy_document" "private_tls_only" {
  for_each = {
    media_private   = aws_s3_bucket.media_private.arn
    exports_private = aws_s3_bucket.exports_private.arn
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [each.value, "${each.value}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "private" {
  for_each = local.private_buckets

  bucket = each.value
  policy = data.aws_iam_policy_document.private_tls_only[each.key].json

  depends_on = [aws_s3_bucket_public_access_block.private]
}

resource "aws_s3_bucket_lifecycle_configuration" "media_private" {
  bucket = aws_s3_bucket.media_private.id

  rule {
    id     = "abort-incomplete-uploads-and-expire-old-versions"
    status = "Enabled"
    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 3
    }
    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiry_days
    }
    expiration {
      expired_object_delete_marker = true
    }
  }

  depends_on = [aws_s3_bucket_versioning.private]
}

resource "aws_s3_bucket_lifecycle_configuration" "exports_private" {
  bucket = aws_s3_bucket.exports_private.id

  rule {
    id     = "expire-exports"
    status = "Enabled"
    filter {}

    expiration {
      days = var.exports_expiry_days
    }
    noncurrent_version_expiration {
      noncurrent_days = 1
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 3
    }
  }

  depends_on = [aws_s3_bucket_versioning.private]
}

# ------------------------------------------------------------------ static-public
# Public-read assets only (web checkout CSS/JS, legal pages). Never user content. SSE-S3 because anonymous
# readers cannot use a KMS-encrypted object. Prefer fronting with a CDN later.
resource "aws_s3_bucket" "static_public" {
  bucket        = local.names.static_public
  force_destroy = var.force_destroy
  tags          = merge(var.tags, { Name = local.names.static_public, Purpose = "static-public" })
}

resource "aws_s3_bucket_ownership_controls" "static_public" {
  bucket = aws_s3_bucket.static_public.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "static_public" {
  bucket                  = aws_s3_bucket.static_public.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_server_side_encryption_configuration" "static_public" {
  bucket = aws_s3_bucket.static_public.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "static_public" {
  statement {
    sid       = "PublicReadObjects"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.static_public.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.static_public.arn, "${aws_s3_bucket.static_public.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "static_public" {
  bucket = aws_s3_bucket.static_public.id
  policy = data.aws_iam_policy_document.static_public.json

  depends_on = [aws_s3_bucket_public_access_block.static_public]
}

resource "aws_s3_bucket_cors_configuration" "static_public" {
  count  = length(var.static_cors_origins) > 0 ? 1 : 0
  bucket = aws_s3_bucket.static_public.id

  cors_rule {
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = var.static_cors_origins
    allowed_headers = ["*"]
    max_age_seconds = 3600
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "static_public" {
  bucket = aws_s3_bucket.static_public.id

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"
    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 3
    }
  }
}
