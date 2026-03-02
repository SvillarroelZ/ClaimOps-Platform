output "table_name" {
  description = "Name of the DynamoDB table"
  value       = var.enable_resources ? aws_dynamodb_table.main[0].name : ""
}

output "table_arn" {
  description = "ARN of the DynamoDB table"
  value       = var.enable_resources ? aws_dynamodb_table.main[0].arn : ""
}

output "table_stream_arn" {
  description = "Stream ARN of the DynamoDB table"
  value       = var.enable_resources ? aws_dynamodb_table.main[0].stream_arn : ""
}
