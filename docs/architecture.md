# ClaimOps Platform - Architecture Documentation

## System Overview

ClaimOps Platform Infrastructure provides the AWS foundation for the ClaimOps application, a claims processing system. The infrastructure consists of three core components: **IAM** (identity and access), **S3** (object storage), and **DynamoDB** (NoSQL database).

### Design Principles

1. **Security First**: Least privilege access, encryption at rest, public access blocking
2. **Cost Optimization**: Free Tier friendly, pay-per-use billing, no unnecessary resources
3. **Study-Focused**: Safe mode by default, validate without AWS account
4. **Modular**: Each AWS service in dedicated module for maintainability
5. **Immutable Infrastructure**: Terraform manages all resources declaratively

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         AWS Account (Free Tier)                      │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                     Identity & Access (IAM)                     │ │
│  │                                                                 │ │
│  │  ┌──────────────────────────────────────────────────────────┐ │ │
│  │  │  IAM Role: claimsops-app-executor                        │ │ │
│  │  │  - AssumeRole: Account root only                         │ │ │
│  │  │  - Least privilege policies                              │ │ │
│  │  │  - S3: crud on claimsops-* buckets                       │ │ │
│  │  │  - DynamoDB: crud on claimsops-* tables                  │ │ │
│  │  │  - Lambda: manage claimsops-* functions (future)         │ │ │
│  │  │  - CloudWatch: write logs to claimsops-* groups          │ │ │
│  │  └──────────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                     Storage Layer (S3)                          │ │
│  │                                                                 │ │
│  │  ┌──────────────────────────────────────────────────────────┐ │ │
│  │  │  S3 Bucket: claimsops-exports-{account-id}               │ │ │
│  │  │  - Purpose: Claim documents, reports, exports            │ │ │
│  │  │  - Encryption: AES256 (AWS-managed keys)                 │ │ │
│  │  │  - Public Access: Blocked at 4 levels                    │ │ │
│  │  │  - Versioning: Disabled (cost optimization)              │ │ │
│  │  │  - Tagging: Project, Environment, ManagedBy              │ │ │
│  │  │                                                           │ │ │
│  │  │  Objects:                                                 │ │ │
│  │  │  ├─ exports/claims/2026/claim-12345.pdf                  │ │ │
│  │  │  ├─ exports/reports/monthly-summary.csv                  │ │ │
│  │  │  └─ documents/supporting-docs/receipt.jpg                │ │ │
│  │  └──────────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                 ▲                                    │
│                                 │ writes exports                     │
│                                 │                                    │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                    Database Layer (DynamoDB)                    │ │
│  │                                                                 │ │
│  │  ┌──────────────────────────────────────────────────────────┐ │ │
│  │  │  DynamoDB Table: claimsops-audit-events                  │ │ │
│  │  │  - Purpose: Audit trail, claim metadata                  │ │ │
│  │  │  - Billing: PAY_PER_REQUEST (free tier friendly)         │ │ │
│  │  │  - Keys: pk (partition), sk (sort)                       │ │ │
│  │  │  - Streams: Enabled (for Lambda triggers)                │ │ │
│  │  │  - Encryption: Automatic (AWS-managed)                   │ │ │
│  │  │                                                           │ │ │
│  │  │  Schema Design:                                           │ │ │
│  │  │  pk: CLAIM#{claimId} | AUDIT#{timestamp}                 │ │ │
│  │  │  sk: METADATA | EVENT#{eventType}                        │ │ │
│  │  │  attributes: userId, action, timestamp, details          │ │ │
│  │  └──────────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                 ▲                                    │
│                                 │ writes audit events                │
│                                 │                                    │
└─────────────────────────────────┼────────────────────────────────────┘
                                  │
                         ┌────────┴────────┐
                         │                 │
                      ┌──▼──────────────────▼──┐
                      │  ClaimOps Application  │
                      │  (Separate Repository) │
                      │                         │
                      │  - API Endpoints        │
                      │  - Business Logic       │
                      │  - Assumes IAM role     │
                      │  - Writes to S3         │
                      │  - Writes to DynamoDB   │
                      └─────────────────────────┘
```

---

## Component Details

### 1. IAM Module

**Purpose**: Provide least privilege access for application to interact with AWS services.

**Resources**:
- `aws_iam_role.deployment_role`: Role that application assumes
- `aws_iam_role_policy.deployment_policy`: Inline policy with specific permissions

**Key Features**:
- ✅ **AssumeRole Trust**: Only account root (prevents external access)
- ✅ **Resource Restrictions**: Only `claimsops-*` prefixed resources
- ✅ **No Admin Access**: Cannot modify IAM, create expensive services
- ✅ **PassRole Limited**: Can only pass role to Lambda (not other services)

**Security Guardrails**:
```hcl
# Cannot create these expensive services
❌ RDS (database) - $15+/month
❌ NAT Gateway - $32+/month  
❌ ECS/EKS (containers) - $73+/month
❌ Load Balancers - $16+/month
```

**Terraform Code Structure**:
```hcl
resource "aws_iam_role" "deployment_role" {
  count = var.enable_resources ? 1 : 0  # ← Safety guard
  name  = var.role_name
  # ... trust policy
}
```

---

### 2. S3 Module

**Purpose**: Store claim documents, reports, and exports securely.

**Resources**:
- `aws_s3_bucket.main`: Primary bucket for all objects
- `aws_s3_bucket_versioning.main`: Versioning configuration (disabled for cost)
- `aws_s3_bucket_server_side_encryption_configuration.main`: AES256 encryption
- `aws_s3_bucket_public_access_block.main`: Block all public access

**Bucket Naming Convention**:
```
claimsops-exports-{AWS_ACCOUNT_ID}

Example: claimsops-exports-123456789012
```

**Why include account ID?**
- S3 bucket names are globally unique across ALL AWS accounts
- Including account ID prevents naming conflicts
- Makes bucket ownership clear

**Object Organization**:
```
claimsops-exports-123456789012/
├── exports/
│   ├── claims/
│   │   ├── 2026/
│   │   │   ├── 01/
│   │   │   │   └── claim-12345.pdf
│   │   │   └── 02/
│   │   └── 2027/
│   └── reports/
│       ├── daily/
│       ├── weekly/
│       └── monthly/
└── documents/
    ├── supporting-docs/
    └── attachments/
```

**Security Features**:
```hcl
# Encryption (AES256)
- Server-side encryption enabled by default
- No additional cost
- AWS-managed keys (no KMS needed)

# Public Access Blocking (4 levels)
- block_public_acls       = true  # Block new public ACLs
- block_public_policy     = true  # Block new public bucket policies
- ignore_public_acls      = true  # Ignore existing public ACLs
- restrict_public_buckets = true  # Restrict if bucket has public policy
```

---

### 3. DynamoDB Module

**Purpose**: Store audit events and claim metadata in NoSQL format.

**Resources**:
- `aws_dynamodb_table.main`: Table with partition and sort keys

**Table Name**:
```
claimsops-audit-events
```

**Key Schema**:
```
Partition Key (pk): String - Entity identifier
Sort Key (sk): String - Event/metadata type

Example records:

1. Claim metadata:
   pk = "CLAIM#12345"
   sk = "METADATA"
   attributes: { claimAmount, status, createdAt, ... }

2. Audit event:
   pk = "AUDIT#2026-03-02T10:30:00Z"
   sk = "EVENT#CLAIM_CREATED"
   attributes: { userId, action, ipAddress, ... }

3. User action:
   pk = "USER#john.doe@example.com"
   sk = "EVENT#LOGIN"
   attributes: { timestamp, device, location, ... }
```

**Billing Mode**: `PAY_PER_REQUEST`

**Why?**
- ✅ Free tier includes 25 RCU and 25 WCU
- ✅ No upfront capacity planning needed
- ✅ Automatically scales with usage
- ✅ Only pay for actual requests
- ✅ Ideal for unpredictable workloads

**Streams**: Enabled

**Why?**
- ✅ Capture real-time changes for processing
- ✅ Trigger Lambda functions (future enhancement)
- ✅ Build event-driven architectures
- ✅ No additional cost

---

## Data Flow

### Write Flow (Application → Infrastructure)

```
1. Application submits claim
   │
   ▼
2. App assumes IAM role (claimsops-app-executor)
   │
   ▼
3. App uploads document to S3
   │  PUT /exports/claims/2026/claim-12345.pdf
   │  Response: 200 OK, ETag
   │
   ▼
4. App writes audit event to DynamoDB
   │  PutItem: { pk: "AUDIT#timestamp", sk: "EVENT#UPLOAD", ... }
   │  Response: 200 OK
   │
   ▼
5. DynamoDB stream triggers (future: Lambda notification)
```

### Read Flow (Application ← Infrastructure)

```
1. Application requests claim history
   │
   ▼
2. App assumes IAM role
   │
   ▼
3. App queries DynamoDB for audit events
   │  Query: pk = "CLAIM#12345"
   │  Response: List of events
   │
   ▼
4. App retrieves document from S3
   │  GET /exports/claims/2026/claim-12345.pdf
   │  Response: PDF file
   │
   ▼
5. App returns data to user
```

---

## Security Architecture

### Defense in Depth

```
Layer 1: IAM (Identity)
- Role-based access control
- Least privilege policies
- No hardcoded credentials

Layer 2: Network (Implicit)
- S3: HTTPS-only access
- DynamoDB: AWS backbone network
- VPC: Not needed for serverless architecture

Layer 3: Encryption
- S3: AES256 at rest, TLS in transit
- DynamoDB: AWS-managed encryption at rest, TLS in transit

Layer 4: Access Control
- S3: Bucket policies (future), no public access
- DynamoDB: IAM-based access only

Layer 5: Audit
- CloudTrail: API call logging (recommended, not implemented)
- DynamoDB: Application-level audit trail
```

### Threat Model

| Threat | Mitigation | Status |
|--------|------------|--------|
| **Unauthorized S3 Access** | Public access blocked, IAM-only | ✅ Implemented |
| **Data Breach** | Encryption at rest and in transit | ✅ Implemented |
| **Privilege Escalation** | Least privilege IAM, no PassRole to admin | ✅ Implemented |
| **Cost Overrun** | Free tier limits, PAY_PER_REQUEST billing | ✅ Implemented |
| **Accidental Deletion** | Versioning (optional, disabled for cost) | ⚠️ Optional |
| **Service Disruption** | Multi-AZ (DynamoDB default), S3 replicated | ✅ AWS Default |

---

## Scaling Considerations

### Current Architecture (MVP)

- **S3**: Auto-scales to exabytes
- **DynamoDB**: Auto-scales with PAY_PER_REQUEST
- **IAM**: No scaling limits

**Supports**:
- Up to 5 GB S3 storage (free tier)
- Up to 25 GB DynamoDB storage (free tier)
- Millions of requests per month (free tier)

### Future Enhancements

**When to consider**:

1. **Multi-Region** (災害 Recovery)
   - When: Critical uptime required (99.99%+)
   - How: S3 Cross-Region Replication, DynamoDB Global Tables
   - Cost impact: +50-100%

2. **CloudFront CDN** (Performance)
   - When: Users across multiple continents
   - How: CloudFront in front of S3
   - Cost impact: +$5-20/month

3. **Lambda Integration** (Event Processing)
   - When: Need real-time notifications, data transformations
   - How: DynamoDB Streams → Lambda → SNS
   - Cost impact: +$0.20/million invocations

4. **Monitoring** (Observability)
   - When: Production deployment
   - How: CloudWatch Alarms, X-Ray tracing
   - Cost impact: +$5-10/month

---

## High Availability

### Current Design

| Service | Availability | RPO | RTO |
|---------|-------------|-----|-----|
| **S3** | 99.99% (multi-AZ default) | N/A (no data loss) | Immediate |
| **DynamoDB** | 99.99% (multi-AZ default) | N/A (no data loss) | Immediate |
| **IAM** | 99.99% (global service) | N/A | Immediate |

**RPO** = Recovery Point Objective (max acceptable data loss)  
**RTO** = Recovery Time Objective (max acceptable downtime)

### Limitations

- ❌ Single region (us-east-1)
- ❌ No automated backups (optional feature)
- ❌ No disaster recovery plan
- ❌ No multi-region failover

**Acceptable for**: Development, staging, low-criticality workloads  
**NOT acceptable for**: High-availability production systems

---

## Cost Architecture

### Design for Cost Optimization

1. **Free Tier First**: All resources fit within free tier
2. **No Provisioned Capacity**: Use PAY_PER_REQUEST (pay per use)
3. **No Versioning**: Disabled to avoid duplicate storage costs
4. **Minimal IAM**: Single role, no extra users/groups
5. **No Expensive Services**: No RDS, NAT, ECS, Load Balancers

### Monthly Cost Breakdown (Free Tier)

```
IAM Role:                  $0.00  (unlimited)
S3 Storage (< 5 GB):       $0.00  (covered by free tier)
S3 Requests:               $0.00  (up to 2000 PUT, 20000 GET)
DynamoDB Storage (< 25 GB): $0.00  (covered by free tier)
DynamoDB Requests:         $0.00  (up to 25 RCU/WCU)
───────────────────────────────────
Total:                     $0.00/month
```

See [docs/costs.md](costs.md) for detailed analysis.

---

## Design Decisions

### Why NoSQL (DynamoDB) vs SQL (RDS)?

**Chose DynamoDB because**:
✅ Free tier: 25 GB vs RDS (none)  
✅ Serverless: No server maintenance  
✅ Scalability: Auto-scales with demand  
✅ Cost: $0/month vs RDS $15+/month  

**Trade-offs**:
❌ No SQL queries (learn NoSQL patterns)  
❌ No JOIN operations (denormalize data)  
❌ Limited transactions (need DynamoDB Transactions API)  

**When to consider RDS**:
- Complex relational queries needed
- Existing SQL application
- Team expertise in SQL
- Budget allows $15+/month

### Why Backend Local vs Remote (S3/Terraform Cloud)?

**Chose local because**:
✅ Study-focused: No shared state needed  
✅ Simple: No extra configuration  
✅ Free: No Terraform Cloud costs  
✅ Fast: No network latency  

**Trade-offs**:
❌ No collaboration (single developer)  
❌ No state locking (risk of conflicts)  
❌ No state backup (manual backups needed)  

**When to consider remote backend**:
- Team collaboration required
- CI/CD pipeline deployed
- State history needed
- State locking required

### Why Least Privilege IAM?

**Security principle**: Grant minimum permissions necessary.

**Benefits**:
✅ Limits blast radius if credentials compromised  
✅ Prevents accidental resource creation  
✅ Enforces separation of concerns  
✅ Audit-friendly (clear permission boundaries)  

**Example**: If app credentials leaked:
- ✅ Attacker can: Access claimsops-* resources
- ❌ Attacker cannot: Create RDS, modify IAM, access other accounts

---

## Future Architecture Enhancements

See [docs/IMPROVEMENTS.md](IMPROVEMENTS.md) for roadmap.

**Priority improvements**:

1. **Lambda Integration** (Week 2-3)
   - DynamoDB streams → Lambda → process events
   - Example: Send notification when claim submitted

2. **CloudWatch Monitoring** (Month 2)
   - Alarms for S3 usage, DynamoDB throttling
   - Dashboards for resource utilization

3. **Multi-Environment** (Month 2)
   - Separate dev/staging/prod environments
   - Environment-specific configurations

4. **Disaster Recovery** (Month 3+)
   - S3 Cross-Region Replication
   - DynamoDB Global Tables
   - Automated backups

---

## Related Documentation

- 📖 [Runbook](runbook.md) - Deployment procedures
- 📖 [Costs](costs.md) - Cost analysis and optimization
- 📖 [README](../README.md) - Project overview
- 📖 [IMPROVEMENTS](IMPROVEMENTS.md) - Future enhancements

---

**Last Updated**: March 2, 2026  
**Architecture Version**: 1.0.0  
**Terraform Version**: >= 1.7.0
