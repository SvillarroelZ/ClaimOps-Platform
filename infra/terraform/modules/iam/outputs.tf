output "deployment_role_arn" {
  description = "ARN of the deployment IAM role"
  value       = var.enable_resources ? aws_iam_role.deployment_role[0].arn : ""
}

output "deployment_role_name" {
  description = "Name of the deployment IAM role"
  value       = var.enable_resources ? aws_iam_role.deployment_role[0].name : ""
}

output "account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}
