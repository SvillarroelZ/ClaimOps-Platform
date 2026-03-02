# Infrastructure Architecture and State Management

## Overview

This document explains the complete infrastructure architecture, how Terraform state is managed, and why terraform.tfstate is not visible in the repository.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    ClaimOps Platform                         │
│                   Terraform Infrastructure                   │
└─────────────────────────────────────────────────────────────┘

                        ┌────────────────┐
                        │   AWS Account  │
                        │   (when ready) │
                        └────────────────┘
                              │
                ┌─────────────┼─────────────┐
                │             │             │
          ┌─────▼──┐    ┌──────▼──┐   ┌───▼────┐
          │  IAM   │    │    S3   │   │DynamoDB│
          │  Role  │    │  Bucket │   │ Table  │
          └────────┘    └─────────┘   └────────┘
                │             │             │
                └─────────────┼─────────────┘
                              │
                    ┌─────────▼─────────┐
                    │   ClaimOps App    │
                    │   Assumes Role    │
                    │  Stores Data      │
                    │  Logs Events      │
                    └───────────────────┘
```

---

## Directory Structure Explained

```
ClaimOps-Platform/
│
├── .gitignore                   ← Prevents accidentally committing sensitive files
│                                  Includes: terraform.tfstate, .terraform/
│
├── README.md                    ← Primary documentation (English)
├── README.es.md                 ← Spanish translation
│
├── infra/terraform/             ← Core infrastructure code
│   │
│   ├── providers.tf             ← AWS provider configuration
│   │   Purpose: Define AWS region, authentication method
│   │   Contains: AWS provider block, backend configuration
│   │
│   ├── variables.tf             ← Input variables for configuration
│   │   Purpose: Accept user input with validation
│   │   Variables:
│   │     ├── aws_region: Which AWS region to use
│   │     ├── project_name: Name for resources (claimsops)
│   │     ├── environment: dev/staging/prod
│   │     ├── enable_resources: SAFETY GUARD (true/false)
│   │     └── enable_versioning: S3 versioning (true/false)
│   │
│   ├── main.tf                  ← Module orchestration
│   │   Purpose: Call modules and pass variables
│   │   Consists of:
│   │     ├── module "iam" (deployment role)
│   │     ├── module "s3" (export bucket)
│   │     └── module "dynamodb" (events table)
│   │
│   ├── outputs.tf               ← Values exported from root module
│   │   Purpose: Pass resource names/ARNs to applications
│   │   Outputs:
│   │     ├── s3_bucket_name: For app to reference
│   │     ├── dynamodb_table_name: For app to reference
│   │     ├── iam_role_arn: For app to assume
│   │     └── enable_resources: Shows current safety state
│   │
│   ├── terraform.tfvars.example ← Configuration template
│   │   Purpose: Show users what variables to set
│   │   Note: User copies to terraform.tfvars (not in Git)
│   │
│   └── modules/                 ← Reusable components
│       │
│       ├── iam/                 ← Identity and Access Management
│       │   ├── main.tf
│       │   │   Contains:
│       │   │     ├── aws_iam_role: Deployment role
│       │   │     └── aws_iam_role_policy: Granular permissions
│       │   │       Permissions allow:
│       │   │       ├── S3: Create, delete, encrypt, read, write
│       │   │       ├── DynamoDB: CRUD operations on tables
│       │   │       └── Lambda: Create and manage functions
│       │   │       Permissions deny (by omission):
│       │   │       ├── RDS (too expensive)
│       │   │       ├── NAT Gateway (too expensive)
│       │   │       └── ECS (too expensive)
│       │   │
│       │   ├── variables.tf
│       │   │   Input variables:
│       │   │     ├── role_name: Name of the role
│       │   │     ├── project_name: For resource naming
│       │   │     └── environment: For tags
│       │   │
│       │   └── outputs.tf
│       │       Exports:
│       │         └── role_arn: So app can assume the role
│       │
│       ├── s3/                  ← Object Storage
│       │   ├── main.tf
│       │   │   Creates:
│       │   │     ├── aws_s3_bucket: Named claimsops-exports-{ACCOUNT_ID}
│       │   │     ├── aws_s3_bucket_versioning: Optional, disabled by default
│       │   │     ├── aws_s3_bucket_server_side_encryption: AES256 (free)
│       │   │     └── aws_s3_bucket_public_access_block: Fully blocked
│       │   │   Why these resources:
│       │   │     ├── Bucket: Required for object storage
│       │   │     ├── Encryption: Protects data at rest
│       │   │     ├── Versioning: Optional, costs money, disabled by default
│       │   │     └── Public access block: Prevents accidental exposure
│       │   │
│       │   ├── variables.tf
│       │   │   Input variables:
│       │   │     ├── project_name: For bucket naming
│       │   │     ├── environment: For tags
│       │   │     ├── enable_versioning: User can enable/disable
│       │   │     └── block_public_access: Force enabled
│       │   │
│       │   └── outputs.tf
│       │       Exports:
│       │         ├── bucket_name: For app to reference
│       │         └── bucket_arn: For IAM policies
│       │
│       └── dynamodb/            ← NoSQL Database
│           ├── main.tf
│           │   Creates:
│           │     ├── aws_dynamodb_table: Named claimsops-audit-events
│           │     │   ├── partition_key: pk (String type)
│           │     │   ├── sort_key: sk (String type)
│           │     │   ├── billing_mode: PAY_PER_REQUEST (events-driven)
│           │     │   └── stream_enabled: true (for Lambda processing)
│           │     │
│           │     Why this design:
│           │       ├── Partition key (pk): Unique identifier for event
│           │       ├── Sort key (sk): Event timestamp for ordering
│           │       ├── PAY_PER_REQUEST: Charged per request, not reserved capacity
│           │       │   Better for unpredictable audit traffic
│           │       │   Free tier: 25 GB + 25 RCU/WCU included
│           │       └── Streams: Enable Lambda to process events in real-time
│           │
│           │   Optional features (disabled by default):
│           │     ├── TTL: Auto-delete old audit logs
│           │     └── PITR: Point-in-time recovery for compliance
│           │
│           ├── variables.tf
│           │   Input variables:
│           │     ├── table_name: Custom name (default: claimsops-audit-events)
│           │     ├── environment: For tags
│           │     ├── billing_mode: PROVISIONED or PAY_PER_REQUEST
│           │     └── partition_key: Partition key attribute name
│           │
│           └── outputs.tf
│               Exports:
│                 ├── table_name: For app to reference
│                 ├── table_arn: For IAM policies
│                 └── stream_arn: For Lambda to read events
│
├── docs/                        ← Supporting documentation
│   ├── runbook.md               ← Deployment guide (step-by-step)
│   ├── architecture.md          ← System design explanation
│   ├── costs.md                 ← Cost analysis and optimization
│   └── IMPROVEMENTS.md          ← Future enhancement roadmap
│
└── (No terraform.tfstate)       ← Explained below


```

---

## Why terraform.tfstate is Not Visible

### What is terraform.tfstate?

`terraform.tfstate` is a JSON file that Terraform creates after running `terraform apply`. It contains:
- Mapping between your HCL code and actual AWS resource IDs
- Current state of every resource (attributes, values)
- Metadata about the infrastructure

**Example terraform.tfstate content:**
```json
{
  "version": 4,
  "terraform_version": "1.7.0",
  "serial": 5,
  "lineage": "abc-123",
  "outputs": {
    "s3_bucket_name": {
      "value": "claimsops-exports-123456789012"
    }
  },
  "resources": [
    {
      "type": "aws_s3_bucket",
      "name": "main",
      "instances": [
        {
          "attributes": {
            "id": "claimsops-exports-123456789012",
            "arn": "arn:aws:s3:::claimsops-exports-123456789012"
          }
        }
      ]
    }
  ]
}
```

### Why It's Not in Git

**Security Reasons:**
- terraform.tfstate contains sensitive data (AWS account ID, resource details)
- If someone gains access to your Git repo, they can read the state file
- They could learn structure of your infrastructure
- In some cases, it may contain secrets (passwords, API keys)

**Practical Reasons:**
- terraform.tfstate is environment-specific (different per deployment)
- It changes with every `terraform apply` (high Git churn)
- It should be managed separately from code
- For teams, use Terraform Cloud or S3 remote state, not Git

**Version Control Reason:**
- `terraform.tfstate` is not source code; it is generated output
- Like `*.o` files in C or `__pycache__` in Python, it should be ignored

### When Does terraform.tfstate Get Created?

```
Step 1: terraform init
  └─ Initializes directory, downloads providers
  └─ NO state file created

Step 2: terraform plan
  └─ Reads code, queries AWS API (if credentials exist)
  └─ Shows what WILL happen
  └─ NO state file created

Step 3: terraform apply
  └─ Creates/updates/deletes AWS resources
  └─ Terraform creates terraform.tfstate file
  └─ State file is stored LOCALLY (because backend = "local")

Step 4: terraform destroy
  └─ Deletes AWS resources
  └─ Updates terraform.tfstate
  └─ State file still exists (shows: no resources)
```

### Current State of this Project

```
Current Situation:
├─ enable_resources = false (default)
├─ terraform apply HAS NEVER BEEN RUN
├─ Therefore: terraform.tfstate DOES NOT EXIST
└─ When user sets enable_resources = true and runs apply:
   └─ terraform.tfstate will be created
   └─ It will be ignored by .gitignore (protected)
```

---

## State Management Strategy

### Local State (Current Approach)

**Configuration in providers.tf:**
```hcl
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
```

**How it works:**
- State file stored in current directory
- Only user with file access can read it
- Good for: Single developer, study projects, simple environments

**Limitations:**
- Cannot be shared between team members
- No locking (two people can apply simultaneously, causing conflicts)
- No backup/recovery mechanism
- No audit trail

**When to use:**
- Development environment (local testing)
- Solo projects
- Learning Terraform

---

### Remote State (For Future - When Team Collaboration Needed)

When this project scales to team collaboration, migrate to remote state:

**Option 1: Terraform Cloud (Recommended for beginners)**
```hcl
terraform {
  cloud {
    organization = "your-org"
    workspaces {
      name = "claimsops-dev"
    }
  }
}
```

Benefits:
- Secure remote storage (encrypted)
- Automatic state locking (prevents conflicts)
- State history and recovery
- Free tier available
- Web interface for viewing state

**Option 2: S3 Backend (Recommended for AWS-heavy projects)**
```hcl
terraform {
  backend "s3" {
    bucket         = "claimsops-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
  }
}
```

Benefits:
- Uses AWS services you already have
- State locked via DynamoDB
- Low-cost remote storage
- Organization-owned (vs. third-party)

**Option 3: Other Backends**
- Terraform Enterprise (self-hosted)
- Azure Blob Storage
- Google Cloud Storage

---

## .gitignore Strategy

### What Goes in .gitignore

```
# Terraform State (CRITICAL - Never commit)
terraform.tfstate
terraform.tfstate.*
*.tfstate

# Terraform Directories (large binary files)
.terraform/
.terraform.lock.hcl

# Local Variable Overrides (user-specific)
terraform.tfvars
override.tf

# Plan Files
*.tfplan
tfplan

# Sensitive Files
*.pem
*.key
.env
.env.local
```

### What Gets Committed

```
Source Code:
├─ *.tf files              (infra/terraform/*.tf)
├─ variables.tf            (input definitions)
├─ outputs.tf              (output definitions)
├─ README.md               (documentation)
└─ .gitignore              (protection rules)

Templates:
├─ terraform.tfvars.example      (sample configuration)
└─ docs/                          (guides)
```

### What Never Gets Committed

```
Generated Files:
├─ terraform.tfstate              (state history)
├─ terraform.tfstate.backup       (backup copy)
├─ .terraform/                    (provider binaries, 600+ MB)
├─ .terraform.lock.hcl            (lock file)
└─ .terraform.tfvars              (actual values with secrets)
```

---

## Workflow: From Code to Deployed Infrastructure

### Phase 1: Development (Your Current Phase)

```
┌─ User: Read documentation
├─ User: Clone repository
├─ User: Examine *.tf files
├─ User: Verify with terraform validate
└─ Result: No resources created (enable_resources=false)

Git State:
  ├─ .git/                (repository history)
  ├─ *.tf files          (in Git)
  └─ terraform.tfstate   (NOT created, not needed)
```

### Phase 2: Deployment (When Ready)

```
┌─ User: aws configure
│        (provide credentials)
│
├─ User: Edit terraform.tfvars
│        set: enable_resources = true
│
├─ User: terraform init
│        (downloads providers, validates)
│
├─ User: terraform plan
│        (preview changes)
│
├─ User: terraform apply
│        ============================================
│        At this point: terraform.tfstate CREATED
│        ============================================
│        ├─ Creates aws_iam_role (claimsops-app-executor)
│        ├─ Creates aws_s3_bucket (claimsops-exports-{ID})
│        └─ Creates aws_dynamodb_table (claimsops-audit-events)
│
└─ Result: Infrastructure deployed in AWS

Git State:
  ├─ *.tf files            (unchanged in Git)
  ├─ terraform.tfstate     (created locally, GITIGNORED)
  └─ .terraform/           (downloaded, GITIGNORED)
```

### Phase 3: Maintenance (Ongoing)

```
User changes code (e.g., S3 versioning):

┌─ Edit: infra/terraform/terraform.tfvars
│        set: enable_versioning = true
│
├─ Command: terraform plan
│           Shows: S3 bucket versioning will be enabled
│
├─ Command: terraform apply
│           Executes the change
│           terraform.tfstate automatically updates
│
└─ Result: Infrastructure modified in AWS
           terraform.tfstate updated
           Git repository unchanged (only code changes)
```

---

## Safety Mechanisms in Place

### Mechanism 1: enable_resources Variable

Located: `infra/terraform/variables.tf`

```hcl
variable "enable_resources" {
  description = "Safety guard to prevent accidental resource creation"
  type        = bool
  default     = false  # ← CRITICAL: Default is false
}
```

Every resource uses:
```hcl
count = var.enable_resources ? 1 : 0
```

Effect:
- When false: count evaluates to 0, resource not created
- When true: count evaluates to 1, resource created
- terraform plan shows "0 to add" when false

### Mechanism 2: .gitignore Protection

Located: `.gitignore`

Prevents accidental commit of:
- terraform.tfstate (state files)
- .terraform/ (provider binaries)
- terraform.tfvars (actual configuration with secrets)

### Mechanism 3: Terraform Validation

Command: `terraform validate`

Checks:
- Syntax errors
- Resource type validity
- Variable references
- Module structure
- No AWS credentials needed

### Mechanism 4: Variable Validation

Located: `infra/terraform/variables.tf`

Examples:
```hcl
variable "aws_region" {
  validation {
    condition = can(regex("^[a-z]{2}-[a-z]+-\\d+$", var.aws_region))
    error_message = "Invalid region format. Examples: us-east-1, us-west-2"
  }
}

variable "environment" {
  validation {
    condition = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Must be dev, staging, or prod"
  }
}
```

---

## Summary

| Item | Purpose | Status |
|------|---------|--------|
| `.gitignore` | Protect state files | Implemented |
| `enable_resources` | Prevent accidental creation | Implemented |
| `terraform.tfstate` | Track deployed infrastructure | Does not exist (by design) |
| `providers.tf` | Define AWS backend | Implemented (local state) |
| Module isolation | Separate IAM, S3, DynamoDB | Implemented |
| Documentation | Explain architecture | Implemented |

**Result**: Safe, documented, version-controlled infrastructure code ready for deployment when user has AWS account.

---

**Document Version**: 1.0  
**Last Updated**: March 2, 2026  
**Purpose**: Explain infrastructure state management and architecture  
**Audience**: Developers, DevOps engineers, students
