# AWS Costs Analysis - ClaimOps Platform

## Table of Contents

1. [Overview](#overview)
2. [Free Tier Details](#free-tier-details)
3. [Resource-by-Resource Cost](#resource-by-resource-cost)
4. [Scenario Analysis](#scenario-analysis)
5. [Cost Optimization Tips](#cost-optimization-tips)
6. [Monitoring Costs](#monitoring-costs)

---

## Overview

ClaimOps Platform infrastructure is **designed to be free** within AWS Free Tier limits. This document provides detailed cost estimation and helps you understand cost implications of different configurations.

**Key Principle**: `enable_resources = false` (default) means **zero costs** because no resources are created.

When `enable_resources = true`, costs depend on actual usage and configuration.

---

## Free Tier Details

AWS offers a **12-month Free Tier** for new accounts:

| Service | Free Tier Offer | Duration |
|---------|---|---|
| S3 | 5 GB storage | 12 months |
| DynamoDB | 25 GB storage + 25 RCU/WCU | 12 months |
| IAM | Unlimited | Always free |
| CloudWatch | 10 GB logs ingestion | 12 months |

**Total Value**: ~$50-100/month of free resources

---

## Resource-by-Resource Cost

### 1. IAM Role - ALWAYS FREE

**Cost**: $0/month

```hcl
# cost_breakdown.tf
# IAM roles and policies are always free, regardless of number
resource "aws_iam_role" "deployment_role" {
  count = var.enable_resources ? 1 : 0
  # Cost: $0
}
```

**Why free?**
- AWS charges for API calls, not for IAM definitions
- You only pay for what the role does (S3 API, DynamoDB)
- 1000s of organizations use IAM role without charges

---

### 2. S3 Bucket - FREE (Basic Usage)

**Free Tier**: 5 GB storage + 20,000 GET requests + 2,000 PUT requests/month

**Pricing** (per GB per month):
- Storage: $0.023/GB (*after 5 GB free*)
- GET requests: $0/10,000 (*after 20,000 free*)
- PUT requests: $0.005/1,000 (*after 2,000 free*)
- Data transfer out: $0.09/GB (*after 1 GB free*)

**Typical Usage Scenarios**:

| Scenario | Storage | Requests | Cost |
|----------|---------|----------|------|
| **Minimal** (study mode) | 0 GB | 100/month | **$0** ✅ |
| **Development** | 500 MB | 10,000/month | **$0** ✅ |
| **Light production** | 2 GB | 100,000/month | **$0** ✅ |
| **Moderate** | 5 GB | 500,000/month | **$11.50** |
| **Heavy** | 10 GB | 2M/month | **$23** |

**Cost Formula**:
```
Cost = (Storage - 5) * $0.023 + (Requests - 20,000) * $0/10,000 + Data_Transfer * $0.09
```

**Example**:
```
Have: 3 GB storage, 50,000 PUT requests/month
Calculation:
- Storage: 3 GB < 5 GB free → $0
- Requests: 50,000 puts = 50 * $0.005 per 1,000 → $0.25
- Total: $0.25/month ✅ WITHIN FREE TIER
```

---

### 3. DynamoDB - FREE (On-Demand Mode)

**Free Tier**: 25 GB storage + 25 write/read capacity units per second

**Pricing** (on-demand):
- Write: $1.25 per million requests
- Read: $0.25 per million requests
- Storage: $0.25/GB (*after 25 GB free*)

**Typical Usage Scenarios**:

| Scenario | Writes | Reads | Storage | Cost |
|----------|--------|-------|---------|------|
| **Study** | 100/day | 100/day | 100 MB | **$0** ✅ |
| **Dev testing** | 1,000/day | 5,000/day | 1 GB | **$0** ✅ |
| **Light audit log** | 10,000/day | 50,000/day | 5 GB | **$0** ✅ |
| **Moderate traffic** | 100,000/day | 500,000/day | 20 GB | **$0** ✅ |
| **Heavy traffic** | 1M+/day | 5M+/day | 50 GB | **$5-20** |

**Cost Formula**:
```
Cost = (Writes / 1,000,000) * $1.25 + (Reads / 1,000,000) * $0.25 + (Storage - 25) * $0.25
```

**Example**:
```
Audit events: 100,000 writes/month, 500,000 reads/month, 10 GB storage

Calculation:
- Writes: 100,000 / 1M * $1.25 = $0.125
- Reads: 500,000 / 1M * $0.25 = $0.125
- Storage: 10 GB < 25 GB free → $0
- Total: $0.25/month ✅ WITHIN FREE TIER
```

**Why PAY_PER_REQUEST (On-Demand)?**
- ✅ No capacity management
- ✅ Scales automatically
- ✅ Fair pricing for variable workloads
- ✅ Best for apps with unpredictable traffic

**Alternative (PROVISIONED mode)**:
```
If you choose PROVISIONED:
- Read: $0.00013 per RCU-hour
- Write: $0.00065 per WCU-hour
- Minimum: 4 RCU + 4 WCU = ~$20/month
- ❌ Not recommended for our use case
```

---

## Scenario Analysis

### Scenario 1: Study Mode (enable_resources = false)

```hcl
variable "enable_resources" {
  default = false  # ← Safety mode
}
```

**Result**: 
```
All resources: 0 (count = 0)
Monthly Cost: $0
AWS Bill: $0
Status: ✅ "No charges"
```

---

### Scenario 2: Development (Light Usage)

**Configuration**:
```hcl
enable_resources = true
aws_region = "us-east-1"
environment = "dev"
enable_versioning = false        # Keep disabled
dynamodb_billing_mode = "PAY_PER_REQUEST"
```

**Projected Usage** (typical dev/test):
- S3: 500 MB, 5,000 requests/month
- DynamoDB: 1 GB, 50,000 writes, 100,000 reads/month
- IAM: 1 role (constant)

**Cost Calculation**:
```
IAM:       $0 (always free)
S3:        $0 (within free tier)
DynamoDB:  $0.08 (100K writes + reads within free)
CloudWatch: $0 (minimal logs)
──────────────────
TOTAL:     $0.08/month ✅
```

---

### Scenario 3: Small Production (Moderate Usage)

**Configuration**:
```hcl
enable_resources = true
environment = "prod"
enable_versioning = true       # Enable for safety
dynamodb_billing_mode = "PAY_PER_REQUEST"
```

**Projected Usage** (small SaaS):
- S3: 5 GB, 100,000 requests/month
- DynamoDB: 10 GB, 1M writes, 5M reads/month
- IAM: 2 roles

**Cost Calculation**:
```
IAM:       $0.00 (always free)
S3:        $0.50 (small request charges)
DynamoDB:  $1.50 (1M writes + 5M reads = $1.25 + $1.25)
CloudWatch: $2.00 (logging)
──────────────────
TOTAL:     $4.00/month ✅ Still very cheap
```

---

### Scenario 4: Why NOT Other Services

**❌ DO NOT USE: RDS (Relational Database)**

```
RDS costs:
- Minimum instance: db.t3.micro = $30-50/month
- Storage: $0.20/GB (beyond free)
- Backups: $0.095/GB
- Even with free tier, it's expensive

Why we chosen DynamoDB instead:
✅ Cheaper ($0-5 vs $30+)
✅ No server management
✅ Scales automatically
✅ Better for event/audit logs
```

**❌ DO NOT USE: NAT Gateway**

```
NAT Gateway cost:
- Fixed: $32/month
- Data: $0.045/GB
- Total: Minimum $32/month even if unused

Lesson: Minimize data transfer out of VPC
```

**❌ DO NOT USE: ECS/EKS**

```
ECS costs:
- EC2 instance: $20-100/month
- Or Fargate: $0.04790 per CPU-hour ($35+/month)

Better alternatives:
✅ Lambda: $0.20 per million requests (FREE for 1M/month)
✅ Step Functions: Complex workflows
✅ AppSync: GraphQL APIs
```

---

## Cost Optimization Tips

### Tip 1: Keep enable_resources = false by Default

```hcl
variable "enable_resources" {
  description = "Create resources only when needed"
  type        = bool
  default     = false  # ← Keep this
}
```

**Impact**: Saves 100% of infrastructure costs during development.

---

### Tip 2: Disable S3 Versioning

```hcl
variable "enable_versioning" {
  description = "S3 versioning costs: $0.23/GB-month for old versions"
  type        = bool
  default     = false  # ← Keep disabled unless needed
}
```

**Cost Impact**:
- With versioning: 10 versions of 1 GB file = $0.23/month (for storage alone)
- Without: $0/month
- **Savings**: $0.23/month per GB

---

### Tip 3: Use DynamoDB On-Demand (PAY_PER_REQUEST)

```hcl
variable "dynamodb_billing_mode" {
  default = "PAY_PER_REQUEST"  # ← Better than PROVISIONED
}
```

**Cost Comparison** (for variable traffic):
| Billing Mode | Min Cost | Scales | Best For |
|---|---|---|---|
| PROVISIONED | ~$20/month | Manual | Predictable traffic |
| PAY_PER_REQUEST | $0.50+ | Automatic | Variable traffic |

**Our Choice**: PAY_PER_REQUEST (saves money on low traffic)

---

### Tip 4: Delete Resources When Not Using

```bash
# When you're done testing:
terraform destroy

# Cost after destroy:
# IAM: $0 (roles deleted)
# S3: $0 (bucket deleted)
# DynamoDB: $0 (table deleted)
# Total: $0
```

---

### Tip 5: Use Free Tier Region (us-east-1)

```hcl
variable "aws_region" {
  default = "us-east-1"  # Free tier available
}
```

**Why us-east-1?**
- Most free tier resources available
- Cheapest pricing
- Best for US-based apps

**Other free tier regions**:
- us-west-2 (all services)
- eu-west-1 (select services)

---

### Tip 6: Monitor with AWS Cost Explorer

```bash
# View costs in AWS Console:
AWS Console → Billing & Cost Management → Cost Explorer

# Or via AWS CLI:
aws ce get-cost-and-usage \
  --time-period Start=2024-03-01,End=2024-03-31 \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

---

## Billing Scenarios by Month

### Month 1-12 (Free Tier Eligible)

```
Enable Resources: false
Expected Cost: $0

Enable Resources: true, Light Usage:
Expected Cost: $0-5

Calculation:
- IAM: $0 (always free)
- S3: $0 (5 GB free, typical under <100K requests)
- DynamoDB: $0-2 (Free tier + minimal on-demand)
- Total: $0-2/month ✅
```

### Month 13+ (Free Tier Expires)

```
Light Usage:
- IAM: $0
- S3: $2-5 (depends on storage/requests)
- DynamoDB: $2-5 (depends on traffic)
- Total: $4-10/month ✅

Moderate Usage:
- IAM: $0
- S3: $5-10
- DynamoDB: $5-15
- Total: $10-25/month

Heavy Usage:
- IAM: $0
- S3: $20+
- DynamoDB: $20+
- Total: $40+/month
```

---

## Alert: Potential Over-Budget Scenarios

### ⚠️ Accidental enable_resources = true During Free Tier

```
Risk: Someone sets enable_resources = true, forgets about it
Cost: Depends on traffic, but could be $20-100/month

Prevention:
✅ Code review before merge
✅ Use terraform plan (review before apply)
✅ Set AWS budget alert
✅ Read-only access for junior developers
```

### ⚠️ Enable Versioning Without Monitoring

```
S3 versioning cost:
- 100 versions * 1 GB = $23/month (just for storage)
- If you also have requests: +$5-10/month

Prevention:
✅ Keep enable_versioning = false
✅ Enable versioning explicitly (not default)  
✅ Use AWS S3 lifecycle policies to clean old versions
```

### ⚠️ DynamoDB Provisioned Mode (Wrong Choice)

```
Cost if you chose PROVISIONED instead of PAY_PER_REQUEST:
- Minimum 4 RCU + 4 WCU = $20-30/month (even if unused!)

Why we avoid it:
✅ Our traffic is variable (development/testing)
✅ On-demand scales with real usage
✅ Saves $15-20/month compared to provisioned
```

---

## Cost Calculator

Use this template to estimate YOUR costs:

```hcl
# terraform/cost_estimation.tf (not applied, just for reference)

# INPUT: Your expected monthly usage
locals {
  # S3 Estimates
  s3_storage_gb = 2                    # How much will you store?
  s3_get_requests = 50000              # Read requests/month?
  s3_put_requests = 10000              # Write requests/month?
  
  # DynamoDB Estimates
  dynamo_writes_daily = 5000           # Write requests/day?
  dynamo_reads_daily = 20000           # Read requests/day?
  dynamo_storage_gb = 5                # Storage size?
  
  # CALCULATIONS
  s3_storage_cost = max(0, (local.s3_storage_gb - 5) * 0.023)
  s3_requests_cost = (local.s3_get_requests / 10000 - 2) * 0 + 
                     (local.s3_put_requests / 1000 - 2) * 0.005
  
  dynamo_writes_monthly = local.dynamo_writes_daily * 30
  dynamo_reads_monthly = local.dynamo_reads_daily * 30
  dynamo_write_cost = max(0, (local.dynamo_writes_monthly / 1000000 - 25) * 1.25)
  dynamo_read_cost = max(0, (local.dynamo_reads_monthly / 1000000 - 25) * 0.25)
  dynamo_storage_cost = max(0, (local.dynamo_storage_gb - 25) * 0.25)
  
  # TOTAL
  estimated_monthly = local.s3_storage_cost + 
                      local.s3_requests_cost +
                      local.dynamo_write_cost +
                      local.dynamo_read_cost +
                      local.dynamo_storage_cost
}

output "estimated_monthly_cost" {
  value = local.estimated_monthly
}
```

---

## AWS Free Tier Limitations

**Important**: AWS Free Tier has limitations:

1. **Duration**: 12 months (from first use of service)
2. **Account**: Only 1 per AWS account
3. **Per Service**: If you exceed free tier on ONE service, you pay for all overage
4. **Services**: Not all services have free tier

**Free Tier Services We Use**:
- ✅ S3: 5 GB + requests
- ✅ DynamoDB: 25 GB + capacity
- ✅ IAM: Always free (unlimited)
- ✅ CloudWatch: 10 GB logs per month

**Services NOT in Free Tier** (avoid):
- ❌ RDS (minimum ~$30/month)
- ❌ NAT Gateway ($32/month)
- ❌ Elasticsearch ($56/month minimum)
- ❌ AppSync ($1.25 per million queries)

---

## Setting Up Billing Alerts

### Step 1: Enable Cost Anomaly Detection

```
AWS Console:
  → Billing & Cost Management
  → Cost Anomaly Detection
  → Create Detection Rule
  → Set threshold (e.g., $10/month)
```

### Step 2: Configure Budget Alert

```
AWS Console:
  → Billing & Cost Management
  → Budgets
  → Create Budget
  → Set limit (e.g., $25/month)
  → Add email notification when exceeded
```

### Step 3: Monitor with CLI

```bash
# Check current month's cost
aws ce get-cost-and-usage \
  --time-period Start=2024-03-01,End=2024-03-31 \
  --granularity MONTHLY \
  --metrics BlendedCost
```

---

## Cost Optimization Checklist

```
Before Deploying (enable_resources = true):
☑ Review terraform plan (see what will be created)
☑ Estimate cost using calculator above
☑ Set AWS budget alert to $25/month
☑ Enable cost anomaly detection
☑ Have read the cost documentation (this file)
☑ Understand destroy process

After Deploying:
☑ Check AWS Billing Dashboard daily (first week)
☑ Review actual costs vs estimate
☑ Adjust resources if costs exceed estimate
☑ When done testing, run terraform destroy
☑ Verify resources deleted in AWS Console

Before Any Cost Surprises:
☑ Keep enable_resources = false by default
☑ Use version control (reverting is easy)
☑ Test in non-prod environment (dev)
☑ Have destroy process documented
```

---

## Summary

| Scenario | Monthly Cost | Who Should Use |
|----------|---|---|
| **Study Mode** (enable_resources=false) | **$0** | Everyone (safe) |
| **Development** (light usage) | **$0-5** | Developers testing |
| **Small SaaS** (moderate usage) | **$5-15** | MVP stage |
| **Growing SaaS** (heavy usage) | **$25-50** | Scaling phase |

**Key Takeaway**: 
> This infrastructure is designed to stay free during development and cost less than $5/month with light production usage.

---

**Last Updated**: March 2, 2024  
**Terraform Module**: >= 1.0  
**AWS Region**: us-east-1 (Free Tier)
