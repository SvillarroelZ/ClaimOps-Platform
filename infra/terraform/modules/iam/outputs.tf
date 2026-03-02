output "deployment_role_arn" {
  description = "ARN of the deployment IAM role"
  value       = aws_iam_role.deployment_role.arn
}

output "deployment_role_name" {
  description = "Name of the deployment IAM role"
  value       = aws_iam_role.deployment_role.name
}

output "account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}
