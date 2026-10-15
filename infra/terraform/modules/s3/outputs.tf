output "media_private_bucket" {
  value = aws_s3_bucket.media_private.id
}

output "media_private_arn" {
  value = aws_s3_bucket.media_private.arn
}

output "exports_private_bucket" {
  value = aws_s3_bucket.exports_private.id
}

output "exports_private_arn" {
  value = aws_s3_bucket.exports_private.arn
}

output "static_public_bucket" {
  value = aws_s3_bucket.static_public.id
}

output "static_public_arn" {
  value = aws_s3_bucket.static_public.arn
}
