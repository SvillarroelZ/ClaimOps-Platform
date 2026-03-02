output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = var.enable_resources ? aws_s3_bucket.main[0].id : ""
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = var.enable_resources ? aws_s3_bucket.main[0].arn : ""
}

output "bucket_domain_name" {
  description = "Domain name of the bucket"
  value       = var.enable_resources ? aws_s3_bucket.main[0].bucket_regional_domain_name : ""
}
