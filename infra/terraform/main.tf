/*
  ClaimOps Platform - Infrastructure as Code
  
  This Terraform configuration deploys the foundational AWS infrastructure
  for the ClaimOps platform, with a focus on Free Tier compatibility and
  minimal costs while maintaining enterprise-grade security practices.
  
  Infrastructure modules:
  - IAM: Least privilege access control for claimsops-app
  - S3: Secure storage for claim exports and documents
  - DynamoDB: Audit events and claim metadata (NoSQL)
  - Lambda: Serverless compute (optional)
  
  SAFETY GUARD: All resources protected by enable_resources variable.
  Default: enable_resources = false (no resources created on apply)
  
  Free Tier guardrails are enforced in variables.tf and module configurations.
*/

module "iam" {
  source = "./modules/iam"

  role_name        = "${var.project_name}-app-executor"
  project_name     = var.project_name
  environment      = var.environment
  enable_resources = var.enable_resources
}

module "s3" {
  source = "./modules/s3"

  project_name        = var.project_name
  environment         = var.environment
  enable_versioning   = var.enable_versioning
  block_public_access = true
  enable_encryption   = true
  enable_resources    = var.enable_resources
}

module "dynamodb" {
  source = "./modules/dynamodb"

  project_name                  = var.project_name
  environment                   = var.environment
  billing_mode                  = var.dynamodb_billing_mode
  enable_point_in_time_recovery = false
  enable_ttl                    = false
  enable_resources              = var.enable_resources
}
