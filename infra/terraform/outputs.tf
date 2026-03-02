output "aws_region" {
  description = "The AWS region being used"
  value       = var.aws_region
}

output "project_name" {
  description = "The project name"
  value       = var.project_name
}

output "environment" {
  description = "The environment name"
  value       = var.environment
}

output "enable_resources" {
  description = "Whether resource creation is enabled (safety guard)"
  value       = var.enable_resources
}

output "deployment_role_arn" {
  description = "ARN of the deployment IAM role"
  value       = module.iam.deployment_role_arn
}

output "deployment_role_name" {
  description = "Name of the deployment IAM role"
  value       = module.iam.deployment_role_name
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = module.iam.account_id
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket (for claim exports)"
  value       = module.s3.bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = module.s3.bucket_arn
}

output "s3_bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = module.s3.bucket_domain_name
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table (for audit events)"
  value       = module.dynamodb.table_name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = module.dynamodb.table_arn
}

output "dynamodb_table_stream_arn" {
  description = "Stream ARN of the DynamoDB table"
  value       = module.dynamodb.table_stream_arn
}
