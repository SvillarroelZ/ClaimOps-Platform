resource "aws_s3_bucket" "main" {
  count = var.enable_resources ? 1 : 0

  bucket = var.bucket_name != "" ? var.bucket_name : "${var.project_name}-exports-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = var.project_name
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "main" {
  count  = var.enable_resources ? 1 : 0
  bucket = aws_s3_bucket.main[0].id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  count  = var.enable_resources ? 1 : 0
  bucket = aws_s3_bucket.main[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "main" {
  count = var.block_public_access && var.enable_resources ? 1 : 0

  bucket = aws_s3_bucket.main[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_caller_identity" "current" {}
