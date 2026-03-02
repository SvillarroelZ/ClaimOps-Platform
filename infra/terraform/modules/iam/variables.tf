variable "role_name" {
  description = "Name of the IAM role for ClaimOps deployment"
  type        = string
  default     = "claimsops-deployment-role"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "enable_resources" {
  description = "Safety guard to prevent resource creation. Set to true to actually create resources"
  type        = bool
  default     = false
}
