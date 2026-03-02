variable "aws_region" {
  description = "AWS region where resources will be created. Free tier friendly: us-east-1, us-west-2, eu-west-1"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d+$", var.aws_region))
    error_message = "Invalid AWS region format. Examples: us-east-1, us-west-2, eu-west-1"
  }
}

variable "project_name" {
  description = "Project name for resource naming and tagging. Used in bucket name, table name, role name"
  type        = string
  default     = "claimsops"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,30}$", var.project_name))
    error_message = "Project name must: (1) start with lowercase letter, (2) contain only lowercase letters, numbers, hyphens, (3) be max 31 characters. Received: '${var.project_name}'"
  }
}

variable "environment" {
  description = "Environment classification: 'dev' (development), 'staging' (pre-production), 'prod' (production)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be exactly: 'dev', 'staging', or 'prod'. Received: '${var.environment}'"
  }
}

variable "enable_versioning" {
  description = "Enable S3 object versioning. WARNING: Adds $0.23/GB-month cost for old versions. Disabled for free tier optimization"
  type        = bool
  default     = false
}

variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode. PAY_PER_REQUEST (recommended for free tier): pay per request. PROVISIONED: pay by capacity"
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PROVISIONED", "PAY_PER_REQUEST"], var.dynamodb_billing_mode)
    error_message = "DynamoDB billing mode must be 'PROVISIONED' or 'PAY_PER_REQUEST'. Received: '${var.dynamodb_billing_mode}'"
  }
}
