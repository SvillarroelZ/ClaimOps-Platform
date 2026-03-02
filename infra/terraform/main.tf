/*
  ClaimOps Platform - Infrastructure as Code
  
  This Terraform configuration deploys the foundational AWS infrastructure
  for the ClaimOps platform, with a focus on Free Tier compatibility and
  minimal costs while maintaining enterprise-grade security practices.
  
  Infrastructure modules:
  - IAM: Least privilege access control
  - S3: Secure object storage
  - DynamoDB: Scalable database
  - Lambda: Serverless compute (optional)
  
  Free Tier guardrails are enforced in variables.tf and module configurations.
*/

module "iam" {
  source = "./modules/iam"

  role_name    = "${var.project_name}-deployment-role"
  project_name = var.project_name
  environment  = var.environment
}

module "s3" {
  source = "./modules/s3"

  project_name        = var.project_name
  environment         = var.environment
  enable_versioning   = var.enable_versioning
  block_public_access = true
  enable_encryption   = true
}
