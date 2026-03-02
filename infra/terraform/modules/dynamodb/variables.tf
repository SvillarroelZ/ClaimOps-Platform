variable "table_name" {
  description = "Name of the DynamoDB table"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Project name for table naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "partition_key" {
  description = "Partition key attribute"
  type        = string
  default     = "pk"
}

variable "sort_key" {
  description = "Sort key attribute (optional)"
  type        = string
  default     = "sk"
}

variable "billing_mode" {
  description = "Billing mode for DynamoDB table (PAY_PER_REQUEST is free tier friendly)"
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = can(regex("^(PROVISIONED|PAY_PER_REQUEST)$", var.billing_mode))
    error_message = "Billing mode must be PROVISIONED or PAY_PER_REQUEST."
  }
}

variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery"
  type        = bool
  default     = false
}

variable "enable_ttl" {
  description = "Enable TTL for automatic item expiration"
  type        = bool
  default     = false
}

variable "ttl_attribute" {
  description = "Name of the TTL attribute"
  type        = string
  default     = "ttl"
}

variable "enable_resources" {
  description = "Safety guard to prevent resource creation. Set to true to actually create resources"
  type        = bool
  default     = false
}
