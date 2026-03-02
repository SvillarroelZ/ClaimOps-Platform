# ClaimOps Platform - Infrastructure as Code

Terraform infrastructure for claims processing system. Defines AWS resources with production-grade security and validation.

**Status**: Production-ready. No resources created by default (safety guard).
**Language**: English (technical)
**Version**: Terraform >= 1.0

See [README.es.md](README.es.md) for Spanish documentation.

---

## What This Project Creates

Three AWS resources designed for claims processing:

1. **IAM Role** - Execution role with least-privilege permissions
2. **S3 Bucket** - Encrypted storage for claim exports and documents  
3. **DynamoDB Table** - NoSQL database for audit events and claim metadata

All resources protected by safety guard: `enable_resources = false` by default (zero resources created).

---

## Quick Start

### Prerequisites

- Terraform >= 1.0 (https://www.terraform.io/downloads)
- Git
- Optional: AWS Account with configured credentials (aws configure)

### Validation Only (No AWS Account Required)

```bash
cd infra/terraform

# Initialize (downloads providers)
terraform init

# Validate syntax
terraform validate

# Check formatting
terraform fmt -check .
```

Expected output:
```
Success! The configuration is valid.
```

### Deploy Infrastructure (AWS Account Required)

```bash
# Set safety guard
export TF_VAR_enable_resources=true

# Review changes
terraform plan

# Create infrastructure
terraform apply

# View resource outputs
terraform output

# Cleanup when done
terraform destroy
```

---

## Understanding the Architecture

### Directory Structure

```
infra/terraform/
├── providers.tf              # AWS provider version ~5.0, local backend
├── variables.tf              # 6 input variables with validation rules
├── main.tf                   # Module orchestration
├── outputs.tf                # Exports resource identifiers
├── terraform.tfvars.example  # Configuration template
│
└── modules/
    ├── iam/                  # IAM role + policy (least privilege)
    │   ├── main.tf           # aws_iam_role, aws_iam_role_policy
    │   ├── variables.tf      # Module inputs
    │   └── outputs.tf        # role_arn export
    │
    ├── s3/                   # S3 bucket (encryption + public access block)
    │   ├── main.tf           # aws_s3_bucket, encryption config
    │   ├── variables.tf      # Module inputs
    │   └── outputs.tf        # bucket_name export
    │
    └── dynamodb/             # DynamoDB table (streams enabled)
        ├── main.tf           # aws_dynamodb_table with pay-per-request
        ├── variables.tf      # Module inputs
        └── outputs.tf        # table_name export
```

### Safety Guard: The Core Concept

The `enable_resources` variable controls whether infrastructure is created:

```hcl
variable "enable_resources" {
  type    = bool
  default = false    # Safe by default
}

resource "aws_iam_role" "deployment_role" {
  count = var.enable_resources ? 1 : 0    # Only create if true
  # ...
}
```

Result:
- Default (false): terraform plan shows 0 changes
- Explicit (true): terraform plan shows 3 resources to add

This prevents accidental infrastructure creation in development or CI/CD pipelines.

---

## Terraform Workflow Explained

### Step 1: terraform init

Downloads AWS provider and initializes backend:

```bash
cd infra/terraform
terraform init
```

Output:
- .terraform/ directory (provider binaries)
- .terraform.lock.hcl (dependency lock file)

### Step 2: terraform validate

Checks syntax and references:

```bash
terraform validate
```

Does NOT connect to AWS. Does NOT cost anything.

### Step 3: terraform plan

Dry-run to see what would be created:

```bash
# With safety guard (default):
terraform plan
# Result: Plan: 0 to add, 0 to change, 0 to destroy

# To see actual infrastructure plan:
terraform plan -var="enable_resources=true"
# Result: Plan: 3 to add (IAM role, S3 bucket, DynamoDB table)
```

### Step 4: terraform apply

Creates actual AWS resources:

```bash
terraform apply -var="enable_resources=true"
```

Prompts for confirmation before creating. Type "yes" to proceed.

Output shows resource IDs:
```
module.iam.aws_iam_role.deployment_role[0]:
  arn = "arn:aws:iam::123456789:role/claimsops-deployment-role"
  
module.s3.aws_s3_bucket.exports[0]:
  bucket = "claimsops-exports-123456789"

module.dynamodb.aws_dynamodb_table.audit_events[0]:
  name = "claimsops-audit-events"
```

### Step 5: terraform destroy

Cleans up all created resources:

```bash
terraform destroy
```

Prompts for confirmation. Type "yes" to delete.

Cost returns to $0 after deletion.

---

## Configuration Variables

All variables defined in `infra/terraform/variables.tf`:

| Variable | Type | Default | Purpose |
|----------|------|---------|---------|
| aws_region | string | us-east-1 | AWS region for resources |
| project_name | string | claimsops | Used in resource names (bucket, table, role) |
| environment | string | dev | Environment tag: dev, staging, prod |
| enable_versioning | bool | false | S3 object versioning (adds storage cost) |
| dynamodb_billing_mode | string | PAY_PER_REQUEST | DynamoDB billing: PROVISIONED or PAY_PER_REQUEST |
| enable_resources | bool | false | SAFETY GUARD: must be true to create infrastructure |

### Custom Configuration

```bash
terraform plan \
  -var="aws_region=eu-west-1" \
  -var="project_name=claims-eu" \
  -var="enable_resources=true"
```

All variables are validated before execution.

---

## Modules Explained

### 1. IAM Module

Creates execution role with granular permissions:

Resources:
- aws_iam_role: deployment role
- aws_iam_role_policy: 5 statements (S3, DynamoDB, Lambda, CloudWatch)

Permissions (ARN-restricted to claimsops-*):
1. S3: ListBucket, ListBucketVersions
2. S3: GetObject, GetObjectVersion, PutObject
3. DynamoDB: Query, Scan, PutItem, UpdateItem
4. Lambda: InvokeFunction
5. CloudWatch: CreateLogStream, PutLogEvents

Security: Least privilege, no PassRole to other principals.

### 2. S3 Module

Creates encrypted, secure bucket:

Resources:
- aws_s3_bucket: bucket container
- aws_s3_bucket_server_side_encryption_configuration: AES256
- aws_s3_bucket_public_access_block: blocks all public access

Features:
- Encryption: AES256 (AWS-managed keys)
- Public access: Blocked at 4 levels (objects, ACLs, bucket policy)
- Versioning: Optional (disabled by default, saves cost)
- Bucket naming: claimsops-exports-{account-id}

### 3. DynamoDB Module

Creates NoSQL table with event streaming:

Resources:
- aws_dynamodb_table: table container
- Partition key: pk (String)
- Sort key: sk (String)
- Streams: NEW_AND_OLD_IMAGES (enabled)

Features:
- Billing: PAY_PER_REQUEST (auto-scales, charges per request)
- Streams: For Lambda integration, audit trail, real-time processing
- Optional: TTL, global secondary indexes, point-in-time recovery

---

## Security Checklist

Before deploying to production:

1. IAM role reviewed (least privilege)
   ```bash
   aws iam get-role-policy --role-name claimsops-deployment-role --policy-name <policy-name>
   ```

2. S3 bucket public access blocked
   ```bash
   aws s3api get-public-access-block --bucket claimsops-exports-<account-id>
   ```

3. CloudWatch alarms set for DynamoDB throttling
4. Backup procedure for terraform.tfstate file
5. Credentials used are temporary (not root account keys)
6. terraform.tfstate IS in .gitignore (never commit state file)

---

## Cost Analysis

### With AWS Free Tier

Assumes: 1 million DynamoDB requests/month, < 1 GB S3 storage.

| Resource | Free Tier Limit | Cost |
|----------|-----------------|------|
| IAM | Unlimited | $0 |
| S3 (1GB) | 5 GB | $0 |
| DynamoDB (1M reads) | 25 GB + RCU | $0 |
| CloudWatch | 5 GB logs | $0 |
| **Total** | | **$0/month** |

After free tier expires or at high volume:
- S3: $0.023/GB-month
- DynamoDB: $1.25/million write requests
- Realistic monthly cost: $5-15/month (low volume)

---

## Troubleshooting

### Error: "terraform: command not found"

Install Terraform: https://www.terraform.io/downloads

### Error: "No valid credential sources found"

Configure AWS credentials:
```bash
aws configure
# Enter: Access Key, Secret Access Key, Region, Output Format
```

### Error: "botocore.exceptions.NoCredentialsError"

Same as above. AWS credentials required for terraform apply.

### terraform plan shows 0 changes (but enable_resources=true)

Resources already exist in AWS. Verify:
```bash
aws s3 ls | grep claimsops-exports
aws dynamodb list-tables | grep claimsops
aws iam list-roles | grep claimsops
```

Or rebuild state:
```bash
terraform state list
terraform state show module.s3.aws_s3_bucket.exports[0]
```

### S3 bucket name already exists

S3 bucket names are globally unique. Change project_name:
```bash
terraform plan -var="project_name=claims-unique-42"
```

---

## Commands Reference

Validation (no AWS account needed):
```bash
terraform init
terraform validate
terraform fmt -check .
```

Planning:
```bash
terraform plan
terraform plan -var="enable_resources=true"
terraform plan -out=tfplan
terraform show tfplan
```

Deployment:
```bash
terraform apply
terraform apply -var="enable_resources=true"
terraform apply tfplan           # Apply saved plan
terraform apply -auto-approve    # Skip confirmation prompt
```

Inspection:
```bash
terraform state list
terraform state show module.s3.aws_s3_bucket.exports[0]
terraform output
terraform output s3_bucket_name
```

Cleanup:
```bash
terraform destroy
terraform destroy -target=module.s3    # Destroy specific module
```

AWS CLI verification (after apply):
```bash
aws iam list-roles | grep claimsops
aws s3 ls | grep claimsops
aws dynamodb list-tables | grep claimsops
```

---

## Design Decisions (Why These Choices)

### Why DynamoDB instead of RDS/PostgreSQL?

**Decision**: DynamoDB with PAY_PER_REQUEST billing.

**Reasoning**:
- Audit events are unpredictable (sporadic writes, not constant)
- No need for SQL joins or complex transactions
- Auto-scaling without capacity planning
- DynamoDB Streams enable real-time event processing (Lambda integration)
- Lower cost at low volume (free tier covers 25GB)

**Trade-off**: RDS would be better for complex queries or if you need ACID transactions across multiple tables.

### Why PAY_PER_REQUEST instead of PROVISIONED?

**Decision**: PAY_PER_REQUEST billing mode for DynamoDB.

**Reasoning**:
- Unpredictable claim processing volume (spikes during open enrollment, quiet otherwise)
- No wasted capacity during low-usage periods
- Simpler operations (no capacity tuning needed)
- Automatically scales to handle traffic spikes

**Trade-off**: PROVISIONED is cheaper at sustained high volumes (1M+ requests/month). Switch if usage becomes predictable.

### Why Modular Design (3 separate modules)?

**Decision**: Separate modules for IAM, S3, DynamoDB instead of monolithic main.tf.

**Reasoning**:
- Each module can be tested independently
- Modules are reusable across projects
- Changes to S3 don't risk breaking DynamoDB configuration
- Easier to understand (each module has single responsibility)
- Team members can own different modules (IAM team, storage team)

**Trade-off**: More files to manage. For tiny projects, single main.tf might be simpler.

### Why Safety Guard (enable_resources = false)?

**Decision**: Default to no resource creation unless explicitly enabled.

**Reasoning**:
- Prevents accidental infrastructure creation in development
- Safe for CI/CD validation (terraform plan won't surprise you)
- Forces intentional decision before spending money
- Educational projects can validate without AWS account

**Trade-off**: Extra step to enable resources. But this is a feature, not a bug.

### Why Local Backend instead of S3 Remote Backend?

**Decision**: Local terraform.tfstate file (Phase 1). S3 backend planned for Phase 2.

**Reasoning**:
- Simpler setup for single developer or study purposes
- No dependency on external S3 bucket
- Faster iteration during development

**Trade-off**: 
- State file not shared (can't collaborate easily)
- No state locking (risk of concurrent modifications)
- State file could be lost if machine fails

**Migration path**: When team grows or production readiness needed, migrate to S3 + DynamoDB lock backend.

### Why AES256 instead of KMS Keys?

**Decision**: AWS-managed AES256 encryption for S3. KMS planned for Phase 4.

**Reasoning**:
- AES256 is free and automatic
- Sufficient for most use cases (encryption at rest)
- No key management overhead
- Simpler compliance for non-regulated workloads

**Trade-off**:
- Cannot audit key access (no CloudTrail events for key usage)
- Cannot rotate keys on custom schedule
- May not meet PCI-DSS or HIPAA requirements

**Migration path**: If compliance requires customer-managed keys, switch to KMS in Phase 4.

### Why Least-Privilege IAM?

**Decision**: IAM policy restricted to claimsops-* resources only.

**Reasoning**:
- Limits blast radius if credentials leak
- Cannot accidentally delete unrelated resources
- Follows AWS best practices (principle of least privilege)
- Easier to audit (permissions are explicit and minimal)

**Example**: If role is compromised, attacker can only access claimsops-exports-* buckets, not all S3 buckets.

---

## Project Phases

Phase 1 (Current): MVP with safety guard
- Terraform structure, modular design
- Safety guard (enable_resources=false)
- Core resources (IAM, S3, DynamoDB)
- Local backend for simplicity

Phase 2 (Planned): Remote state backend
- Migrate from local to S3 + DynamoDB lock
- Enables team collaboration
- State versioning and backup

Phase 3 (Planned): CI/CD validation pipeline
- GitHub Actions: terraform validate on PR
- Auto-plan, manual approval for apply
- Prevents manual errors

Phase 4 (Planned): Advanced security
- KMS keys for encryption (vs AES256)
- Better audit trail and key rotation
- Compliance-ready

---

## Files Overview

| File | Purpose |
|------|---------|
| README.md | Complete documentation (English) |
| README.es.md | Complete documentation (Spanish) |
| infra/terraform/providers.tf | AWS provider version, local backend |
| infra/terraform/variables.tf | All input variables with validation |
| infra/terraform/main.tf | Module calls |
| infra/terraform/outputs.tf | Resource outputs |
| infra/terraform/modules/iam/main.tf | IAM role and policies |
| infra/terraform/modules/s3/main.tf | S3 bucket with encryption |
| infra/terraform/modules/dynamodb/main.tf | DynamoDB table with streams |
| .gitignore | Protects state file and secrets |

---

## More Information

- Terraform docs: https://www.terraform.io/docs/
- AWS Free Tier: https://aws.amazon.com/free/
- Terraform best practices: https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices

---

**Repository**: https://github.com/SvillarroelZ/ClaimOps-Platform  
**License**: MIT  
**Last Updated**: March 2, 2026
