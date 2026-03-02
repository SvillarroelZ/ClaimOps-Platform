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
