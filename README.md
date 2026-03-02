# ClaimOps Platform - Infrastructure as Code

**[English](#english) | [Español](README.es.md)**

<a name="english"></a>

## Overview

ClaimOps Platform Infrastructure is a **study-focused Terraform project** that defines AWS infrastructure for the ClaimOps application (claims processing system). This project demonstrates professional IaC practices with a critical safety feature: **no resources are created by default**.

### Key Features

- ✅ **Study Mode**: Validate and learn without requiring AWS account
- ✅ **Safety Guard**: `enable_resources = false` by default (zero resources created)
- ✅ **Free Tier Optimized**: When deployed, stays within AWS Free Tier limits
- ✅ **Production-Grade Security**: Least privilege IAM, encryption, public access blocking
- ✅ **Modular Design**: Clean separation of IAM, S3, and DynamoDB resources

### What This Project Defines

| Resource | Purpose | Business Use Case |
|----------|---------|-------------------|
| **IAM Role** | `claimsops-app-executor` | Minimal permissions for app to access S3 and DynamoDB |
| **S3 Bucket** | `claimsops-exports-{account-id}` | Store claim reports, documents, and exports |
| **DynamoDB Table** | `claimsops-audit-events` | Track audit events, claim metadata (NoSQL) |

---

## Quick Start

### Prerequisites

- Terraform >= 1.7.0 ([Download](https://www.terraform.io/downloads))
- Git
- **(Optional)** AWS Account with configured credentials

### Installation

```bash
# Clone repository
git clone https://github.com/SvillarroelZ/ClaimOps-Platform.git
cd ClaimOps-Platform/infra/terraform

# Initialize Terraform (downloads providers and modules)
terraform init

# Validate configuration (NO AWS account needed)
terraform validate
```

### Study Mode (No AWS Required)

```bash
# Format code
terraform fmt -recursive

# Validate syntax
terraform validate

# See what WOULD be created (requires AWS credentials)
terraform plan

# Result: "0 to add, 0 to change, 0 to destroy" 
# Because enable_resources = false by default
```

### Deploy Mode (AWS Account Required)

⚠️ **WARNING**: This creates real AWS resources and may incur costs

```bash
# 1. Configure AWS credentials
aws configure

# 2. Create terraform.tfvars
cp terraform.tfvars.example terraform.tfvars

# 3. Edit terraform.tfvars and set:
#    enable_resources = true  ← CRITICAL STEP

# 4. Review plan
terraform plan

# 5. Deploy infrastructure
terraform apply

# 6. View outputs
terraform output

# 7. When done, destroy resources
terraform destroy
```

---

## Project Structure

```
infra/terraform/
├── providers.tf          # AWS provider and backend configuration
├── variables.tf          # Input variables with validations
├── main.tf               # Module orchestration
├── outputs.tf            # Resource exports
├── terraform.tfvars.example  # Configuration template
│
└── modules/
    ├── iam/              # IAM role for application access
    │   ├── main.tf       # Role and policies
    │   ├── variables.tf  # IAM module inputs
    │   └── outputs.tf    # Role ARN export
    │
    ├── s3/               # S3 bucket for exports
    │   ├── main.tf       # Bucket with encryption
    │   ├── variables.tf  # S3 module inputs
    │   └── outputs.tf    # Bucket name/ARN export
    │
    └── dynamodb/         # DynamoDB for audit events
        ├── main.tf       # Table with streams
        ├── variables.tf  # DynamoDB module inputs
        └── outputs.tf    # Table name/ARN export
```

---

## Safety Guard Explained

### Why `enable_resources` Exists

This project is designed for **study and validation** without requiring an AWS account. The `enable_resources` variable protects against accidental resource creation:

```hcl
# In variables.tf
variable "enable_resources" {
  description = "Safety guard to prevent resource creation"
  type        = bool
  default     = false  # ← NO resources created by default
}

# In every module (IAM, S3, DynamoDB)
resource "aws_iam_role" "example" {
  count = var.enable_resources ? 1 : 0  # ← Only creates if true
  # ...
}
```

### Behavior

| `enable_resources` | `terraform plan` | `terraform apply` | Result |
|--------------------|------------------|-------------------|--------|
| `false` (default) | Shows 0 resources | Creates nothing | **Safe for study** |
| `true` | Shows 3-5 resources | Creates real AWS resources | **Requires AWS account** |

---

## Configuration Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `aws_region` | string | `us-east-1` | AWS region (free tier friendly) |
| `project_name` | string | `claimsops` | Project name for resource naming |
| `environment` | string | `dev` | Environment: dev, staging, prod |
| `enable_versioning` | bool | `false` | S3 versioning (adds cost) |
| `dynamodb_billing_mode` | string | `PAY_PER_REQUEST` | DynamoDB billing mode |
| **`enable_resources`** | **bool** | **`false`** | **Critical safety guard** |

For detailed configuration examples, see [`terraform.tfvars.example`](infra/terraform/terraform.tfvars.example).

---

## Security Features

### IAM Least Privilege

The `claimsops-app-executor` role has **minimal permissions**:

✅ **Allowed**:
- S3: Create/read/write to `claimsops-*` buckets only
- DynamoDB: CRUD operations on `claimsops-*` tables only
- Lambda: Manage `claimsops-*` functions (optional)
- CloudWatch: Create logs for `claimsops-*` log groups

❌ **Denied** (by omission):
- RDS, ECS, EKS (expensive services)
- IAM modifications
- NAT Gateway creation
- Cross-account access

### S3 Security

- ✅ AES256 encryption at rest (AWS-managed keys)
- ✅ Public access blocked at 4 levels
- ✅ Versioning disabled by default (cost optimization)
- ✅ Bucket name includes account ID (unique across AWS)

### DynamoDB Security

- ✅ Encryption at rest (automatic)
- ✅ Encryption in transit (HTTPS)
- ✅ PAY_PER_REQUEST billing (no wasted capacity)
- ✅ Streams enabled for event processing

---

## Cost Estimation

### Free Tier (First 12 Months)

| Resource | Free Tier Limit | Expected Usage | Cost |
|----------|-----------------|----------------|------|
| S3 | 5 GB storage | < 1 GB | **$0/month** |
| DynamoDB | 25 GB + 25 RCU/WCU | < 1 GB | **$0/month** |
| IAM Role | Unlimited | 1 role | **$0/month** |
| **Total** | | | **$0/month** |

### Beyond Free Tier

- S3: $0.023/GB-month
- DynamoDB: $1.25/million write requests
- Total (low usage): **$5-10/month**

For detailed cost analysis, see [`docs/costs.md`](docs/costs.md).

---

## Documentation

- 📖 [Architecture](docs/architecture.md) - System design and diagrams
- 📖 [Runbook](docs/runbook.md) - Step-by-step deployment guide
- 📖 [Costs](docs/costs.md) - Detailed cost analysis and optimization
- 📖 [CONTRIBUTING](CONTRIBUTING.md) - How to contribute
- 📖 [IMPROVEMENTS](docs/IMPROVEMENTS.md) - Kaizen roadmap

---

## Common Operations

### Initialize (First Time)

```bash
cd infra/terraform
terraform init
```

### Validate Configuration

```bash
terraform fmt -check -recursive  # Check formatting
terraform validate                # Validate syntax
```

### Plan Changes

```bash
# Dry-run (shows what would be created)
terraform plan

# Save plan to file
terraform plan -out=tfplan
```

### Apply Changes

```bash
# Deploy with confirmation
terraform apply

# Deploy without confirmation (careful!)
terraform apply -auto-approve
```

### Destroy Resources

```bash
# Remove all created resources
terraform destroy

# Destroy specific resource
terraform destroy -target=module.s3
```

### View Outputs

```bash
# Show all outputs
terraform output

# Show specific output
terraform output s3_bucket_name
```

---

## Troubleshooting

### "Error: No valid credential sources found"

**Cause**: AWS credentials not configured  
**Solution**: 
```bash
aws configure
# Enter: Access Key ID, Secret Access Key, Region
```

### "terraform: command not found"

**Cause**: Terraform not installed  
**Solution**: [Download Terraform](https://www.terraform.io/downloads)

### "Error: Module not installed"

**Cause**: Modules not initialized  
**Solution**: 
```bash
terraform init
```

### "0 resources to add" but I want to deploy

**Cause**: `enable_resources = false` (safety guard active)  
**Solution**: 
```hcl
# In terraform.tfvars
enable_resources = true
```

---

## Relationship to ClaimOps-App

This infrastructure project (`ClaimOps-Platform`) supports the application code (`ClaimOps-App`):

| Platform (Infrastructure) | App (Application) |
|---------------------------|-------------------|
| Defines **what** resources exist | Uses resources to **process claims** |
| IAM role for access control | Assumes role to access S3/DynamoDB |
| S3 bucket for document storage | Uploads claim documents |
| DynamoDB table for audit log | Writes audit events |

**Important**: These are **separate Git repositories**. Do not mix application code with infrastructure code.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Git workflow
- Branching strategy
- Commit conventions
- Code review process

---

## License

This project is educational and study-focused. See LICENSE file for details.

---

## Support

- 📧 Issues: [GitHub Issues](https://github.com/SvillarroelZ/ClaimOps-Platform/issues)
- 📖 Docs: See `docs/` directory
- 💬 Questions: Open a discussion on GitHub

---

**Built with ❤️ for learning Infrastructure as Code**

---

**[⬆ Back to top](#claimops-platform---infrastructure-as-code)**
