output "data_key_arn" {
  value = aws_kms_key.data.arn
}

output "data_key_id" {
  value = aws_kms_key.data.key_id
}

output "media_key_arn" {
  value = aws_kms_key.media.arn
}

output "media_key_id" {
  value = aws_kms_key.media.key_id
}
