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
