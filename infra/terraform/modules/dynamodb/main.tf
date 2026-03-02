resource "aws_dynamodb_table" "main" {
  count = var.enable_resources ? 1 : 0

  name           = var.table_name != "" ? var.table_name : "${var.project_name}-audit-events"
  billing_mode   = var.billing_mode
  hash_key       = var.partition_key
  range_key      = var.sort_key
  stream_enabled = true

  attribute {
    name = var.partition_key
    type = "S"
  }

  attribute {
    name = var.sort_key
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  dynamic "ttl" {
    for_each = var.enable_ttl ? [1] : []
    content {
      attribute_name = var.ttl_attribute
      enabled        = true
    }
  }

  tags = {
    Name        = var.project_name
    Environment = var.environment
  }
}
