# ClaimOps Platform - Deployment Runbook

## Purpose

This runbook provides step-by-step instructions for deploying, validating, and managing the ClaimOps Platform infrastructure using Terraform. This guide is designed for both **study mode** (no AWS account) and **production deployment** (with AWS account).

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Study Mode Workflow](#study-mode-workflow)
4. [Production Deployment Workflow](#production-deployment-workflow)
5. [Verification Steps](#verification-steps)
6. [Rollback Procedures](#rollback-procedures)
7. [Troubleshooting](#troubleshooting)
8. [Maintenance Operations](#maintenance-operations)

---

## Prerequisites

### Required Tools

| Tool | Version | Purpose | Installation |
|------|---------|---------|--------------|
| **Terraform** | >= 1.7.0 | Infrastructure provisioning | [Download](https://www.terraform.io/downloads) |
| **Git** | >= 2.0 | Version control | [Download](https://git-scm.com/downloads) |
| **AWS CLI** | >= 2.0 (optional) | AWS resource verification | [Download](https://aws.amazon.com/cli/) |

### For Study Mode
- ✅ Terraform installed
- ✅ Git installed
- ❌ AWS account NOT required

### For Production Deployment
- ✅ Terraform installed
- ✅ Git installed
- ✅ AWS account with configured credentials
- ✅ IAM user with AdministratorAccess or equivalent permissions

---

## Environment Setup

### Step 1: Clone Repository

```bash
# Clone from GitHub
git clone https://github.com/SvillarroelZ/ClaimOps-Platform.git

# Navigate to Terraform directory
cd ClaimOps-Platform/infra/terraform

# Verify structure
ls -la
```

**Expected output**:
```
providers.tf
variables.tf
main.tf
outputs.tf
terraform.tfvars.example
modules/
```

### Step 2: Verify Terraform Installation

```bash
# Check Terraform version
terraform version

# Expected: Terraform v1.7.0 or later
```

### Step 3: Initialize Terraform

```bash
# Download providers and initialize modules
terraform init

# Expected output:
# "Terraform has been successfully initialized!"
```

**What this does**:
- Downloads AWS provider (~100 MB)
- Initializes local backend
- Validates module paths

---

## Study Mode Workflow

**Purpose**: Learn and validate Terraform without creating AWS resources.

### Step 1: Format Code

```bash
# Format all .tf files
terraform fmt -recursive

# Check formatting without modifying
terraform fmt -check -recursive
```

### Step 2: Validate Configuration

```bash
# Validate syntax and logic
terraform validate

# Expected: "Success! The configuration is valid."
```

### Step 3: Generate Plan (Without Credentials)

```bash
# Attempt to generate plan
terraform plan

# Expected result:
# - Shows outputs will be set
# - NO resources to create (0 to add)
# - Error about credentials (expected if not configured)
```

**Key observation**: Even without AWS credentials, Terraform validates the configuration is correct.

### Step 4: Review Configuration

```bash
# View variables
cat variables.tf | grep -A 5 "enable_resources"

# Expected: default = false

# View module structure
tree modules/ -L 2
```

---

## Production Deployment Workflow

**⚠️ WARNING**: This creates real AWS resources and may incur costs.

### Step 1: Configure AWS Credentials

#### Option A: AWS CLI

```bash
# Configure credentials interactively
aws configure

# Enter when prompted:
# AWS Access Key ID: [YOUR_ACCESS_KEY]
# AWS Secret Access Key: [YOUR_SECRET_KEY]
# Default region: us-east-1
# Default output format: json
```

#### Option B: Environment Variables

```bash
export AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="YOUR_SECRET_KEY"
export AWS_DEFAULT_REGION="us-east-1"
```

#### Verify Credentials

```bash
# Test AWS access
aws sts get-caller-identity

# Expected output: Account ID, User ARN
```

### Step 2: Create Configuration File

```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit configuration
nano terraform.tfvars
# OR
vim terraform.tfvars
```

**Critical changes in `terraform.tfvars`**:

```hcl
# Must set to true to create resources
enable_resources = true  ← CHANGE THIS

# Customize if needed
aws_region = "us-east-1"
project_name = "claimsops"
environment = "dev"
enable_versioning = false  # Keep false for cost optimization
dynamodb_billing_mode = "PAY_PER_REQUEST"  # Free tier friendly
```

### Step 3: Review Plan

```bash
# Generate execution plan
terraform plan

# Save plan to file for review
terraform plan -out=tfplan

# Review plan details
terraform show tfplan
```

**Verify plan shows**:
```
Plan: 5 to add, 0 to change, 0 to destroy

Resources to create:
- module.iam.aws_iam_role.deployment_role[0]
- module.iam.aws_iam_role_policy.deployment_policy[0]
- module.s3.aws_s3_bucket.main[0]
- module.s3.aws_s3_bucket_server_side_encryption_configuration.main[0]
- module.dynamodb.aws_dynamodb_table.main[0]
```

### Step 4: Apply Configuration

```bash
# Deploy with confirmation prompt
terraform apply

# Review changes, type "yes" when prompted
```

**OR** deploy without confirmation (use carefully):

```bash
terraform apply -auto-approve
```

**Expected duration**: 30-60 seconds

### Step 5: Verify Deployment

```bash
# View all outputs
terraform output

# View specific outputs
terraform output s3_bucket_name
terraform output dynamodb_table_name
terraform output deployment_role_arn
```

**Expected outputs**:
```hcl
aws_region = "us-east-1"
enable_resources = true
s3_bucket_name = "claimsops-exports-123456789012"
dynamodb_table_name = "claimsops-audit-events"
deployment_role_arn = "arn:aws:iam::123456789012:role/claimsops-app-executor"
```

---

## Verification Steps

### Verify IAM Role

```bash
# Using AWS CLI
aws iam get-role --role-name claimsops-app-executor

# Expected: Role exists with trust policy
```

### Verify S3 Bucket

```bash
# List buckets
aws s3 ls | grep claimsops

# Check bucket encryption
aws s3api get-bucket-encryption --bucket claimsops-exports-ACCOUNT_ID

# Check public access block
aws s3api get-public-access-block --bucket claimsops-exports-ACCOUNT_ID
```

**Expected**:
- Bucket exists
- Encryption enabled (AES256)
- All public access blocked

### Verify DynamoDB Table

```bash
# Describe table
aws dynamodb describe-table --table-name claimsops-audit-events

# Expected:
# - BillingMode: PAY_PER_REQUEST
# - Streams enabled
# - Keys: pk (partition), sk (sort)
```

### Verify Terraform State

```bash
# List resources in state
terraform state list

# Show specific resource
terraform state show module.s3.aws_s3_bucket.main[0]
```

---

## Rollback Procedures

### Emergency Rollback (Destroy All Resources)

```bash
# Destroy all created resources
terraform destroy

# Review destruction plan, type "yes" to confirm
```

**⚠️ WARNING**: This deletes ALL resources including data in S3 and DynamoDB.

### Destroy Specific Resource

```bash
# Destroy only S3 bucket
terraform destroy -target=module.s3

# Destroy only DynamoDB table
terraform destroy -target=module.dynamodb
```

### Restore from Backup (If Needed)

```bash
# If you have a state backup
cp terraform.tfstate.backup terraform.tfstate

# Re-import resources if needed
terraform import module.s3.aws_s3_bucket.main[0] claimsops-exports-ACCOUNT_ID
```

---

## Troubleshooting

### Issue: "Error: No valid credential sources found"

**Symptoms**:
```
Error: No valid credential sources found
  with provider["registry.terraform.io/hashicorp/aws"],
  on providers.tf line 16, in provider "aws":
```

**Cause**: AWS credentials not configured

**Solution**:
```bash
# Option 1: Configure via AWS CLI
aws configure

# Option 2: Set environment variables
export AWS_ACCESS_KEY_ID="YOUR_KEY"
export AWS_SECRET_ACCESS_KEY="YOUR_SECRET"
export AWS_DEFAULT_REGION="us-east-1"

# Option 3: Use AWS credentials file
# Create ~/.aws/credentials with:
[default]
aws_access_key_id = YOUR_KEY
aws_secret_access_key = YOUR_SECRET
```

### Issue: "Error 403: Access Denied"

**Symptoms**:
```
Error: error creating S3 bucket: AccessDenied
```

**Cause**: IAM user lacks sufficient permissions

**Solution**:
1. Attach `AdministratorAccess` policy to IAM user
2. Or create custom policy with required permissions:
   - `s3:*`
   - `dynamodb:*`
   - `iam:CreateRole`, `iam:AttachRolePolicy`

### Issue: "Bucket name already exists"

**Symptoms**:
```
Error: error creating S3 bucket: BucketAlreadyExists
```

**Cause**: S3 bucket names are globally unique

**Solution**:
```hcl
# In terraform.tfvars, override bucket name
# Add your unique suffix
s3_bucket_name = "claimsops-exports-yourcompany-12345"
```

### Issue: "Module not found"

**Symptoms**:
```
Error: Module not found
```

**Cause**: Modules not initialized

**Solution**:
```bash
terraform init
```

### Issue: "0 resources to add" but expected resources

**Symptoms**: Plan shows no resources to create

**Cause**: `enable_resources = false` (safety guard)

**Solution**:
```hcl
# In terraform.tfvars
enable_resources = true  ← Set to true
```

Then re-run:
```bash
terraform plan
```

---

## Maintenance Operations

### Update Infrastructure

```bash
# Make code changes
vim infra/terraform/variables.tf

# Format changes
terraform fmt -recursive

# Validate
terraform validate

# Review what would change
terraform plan

# Apply updates
terraform apply
```

### Refresh State

```bash
# Sync state with actual AWS resources
terraform refresh

# Or better: re-plan
terraform plan -refresh-only
```

### Backup State

```bash
# Manual backup
cp terraform.tfstate terraform.tfstate.backup-$(date +%Y%m%d)

# Verify backup
ls -lh terraform.tfstate*
```

### View Resource Details

```bash
# List all resources
terraform state list

# Show resource details
terraform state show module.s3.aws_s3_bucket.main[0]

# Show all outputs
terraform output
```

### Check Cost Estimate

```bash
# Using Infracost (if installed)
infracost breakdown --path .

# Or manually:
terraform plan -out=tfplan
terraform show -json tfplan > plan.json
```

---

## Safety Checklist

Before `terraform apply` in production:

- [ ] Reviewed `terraform plan` output
- [ ] Verified `enable_resources = true` in tfvars
- [ ] Confirmed AWS credentials are for correct account
- [ ] Backed up existing terraform.tfstate (if exists)
- [ ] Reviewed estimated costs
- [ ] Informed team of deployment
- [ ] Have rollback plan ready

---

## Next Steps

After successful deployment:

1. **Test Integration**: Connect ClaimOps-App to infrastructure
2. **Monitor Costs**: Check AWS Cost Explorer after 24 hours
3. **Enable Monitoring**: Set up CloudWatch alarms (future enhancement)
4. **Document**: Update runbook with any team-specific procedures

---

## Support

- 📖 See [Architecture](architecture.md) for system design
- 📖 See [Costs](costs.md) for detailed cost analysis
- 📧 Open issue on [GitHub](https://github.com/SvillarroelZ/ClaimOps-Platform/issues)

---

**Last Updated**: March 2, 2026  
**Version**: 1.0.0
