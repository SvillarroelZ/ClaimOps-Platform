# Interview Preparation: Frequently Asked Questions

**Purpose**: Model answers for technical questions about ClaimOps-Platform infrastructure.
**Audience**: Technical manager, peer engineers, architects.
**Presentation Context**: Monday meeting explaining infrastructure decisions and architecture.

---

## Architecture & Design Decisions

### Q1: Why modular Terraform structure instead of monolithic?

**Model Answer**:
Modularity enables:
- **Reusability**: Each module (IAM, S3, DynamoDB) can be instantiated independently or combined
- **Testing**: Modules can be validated separately (`terraform validate`, `terraform plan`)
- **Maintainability**: Changes to DynamoDB don't risk breaking S3 configuration
- **Scaling**: If we add new resources (Lambda, SNS), we follow the same pattern
- **Team collaboration**: Different engineers can own different modules without merge conflicts

**Example**: The security team owns `modules/iam/`, the data team owns `modules/dynamodb/`, reducing bottlenecks.

---

### Q2: How does the safety guard (`enable_resources = false`) prevent production incidents?

**Model Answer**:
Every resource uses `count = var.enable_resources ? 1 : 0`, which means:

1. **Default behavior**: `enable_resources = false` → `terraform plan` shows "0 to add, 0 to change, 0 to destroy"
2. **Manual activation**: Only when explicitly setting `enable_resources = true` in tfvars do resources create
3. **Protection layer**: Prevents accidental `terraform apply` in CI/CD without explicit approval
4. **Review gate**: Encourages code review before activation (enables policy enforcement)

**Real scenario**: Junior engineer runs `terraform plan` locally → sees 0 changes → knows they're safe. When ready to deploy, they create an explicit PR with `enable_resources = true`.

---

### Q3: Why use `count` instead of Terraform `workspace` for this pattern?

**Model Answer**:
`count` is better for our use case because:
- **Explicit in code**: The guard is visible in every resource definition
- **No hidden state**: Workspaces can be accidentally switched
- **CI/CD friendly**: Pipeline variables (enable_resources=true/false) are easier to audit than workspace names
- **Disaster recovery**: If state is lost, code still enforces the pattern

**Trade-off acknowledged**: Workspaces would be simpler if we had multiple environments (dev/staging/prod), but our current need is safety, not multi-env management.

---

## Security & Compliance

### Q4: How does IAM role granularity reduce blast radius?

**Model Answer**:
The IAM role uses 5 statement blocks with ARN restrictions:

```
1. S3 list: arn:aws:s3:::claimsops-* (only matching buckets)
2. S3 objects: arn:aws:s3:::claimsops-*/* (only matching bucket contents)
3. DynamoDB: arn:aws:dynamodb:region:account:table/claimsops-* (only matching tables)
4. Lambda invoke: arn:aws:lambda:region:account:function:claimsops-* (only matching functions)
5. Logs: arn:aws:logs:region:account:log-group:/aws/lambda/* (scoped to Lambda logs)
```

**Blast radius reduction**:
- If credentials leak, attacker can only access `claimsops-*` resources, not entire AWS account
- Denies `PassRole` to other principals (only lambda.amazonaws.com can receive role)
- Cannot list/delete unrelated S3 buckets or DynamoDB tables

---

### Q5: Is AES256 encryption sufficient, or should we use KMS?

**Model Answer**:
**Short answer**: AES256 is sufficient for MVP, KMS is next phase.

**Justification**:
- **AES256**: AWS-managed keys, automatic rotation, free, suitable for non-regulatory workloads
- **KMS**: Customer-managed keys, audit trail, granular access control, required for PCI/HIPAA

**For ClaimOps (claims data)**:
- If handling PII/payment info → KMS required (compliance)
- If handling anonymized claims → AES256 acceptable
- **Recommendation**: Start with AES256, migrate to KMS if auditor requires fine-grained key management

**Trade-off**: Security vs. complexity. We can add KMS in Phase 2 without breaking current architecture (count guard prevents applying before decision is made).

---

## Scalability & Performance

### Q6: Why DynamoDB PAY_PER_REQUEST over provisioned mode?

**Model Answer**:
**PAY_PER_REQUEST advantage**:
- No capacity planning needed (unpredictable audit event volume)
- Auto-scales on-demand (if claims surge, no throttling)
- Pay only for what you use (cost aligns with usage)
- No "hot partition" risk if audit data has skewed access patterns

**Trade-off**:
- Slightly higher per-request cost at high volumes (1M+ requests/month)
- Provisioned mode cheaper for sustained, predictable loads

**Decision logic**: Audit events are sporadic (regulatory checks, dispute resolution), not continuous, so PAY_PER_REQUEST is cost-effective.

**Monitoring**: Could migrate to provisioned mode if CloudWatch metrics show sustained high request rate.

---

### Q7: How does DynamoDB Streams (`stream_enabled = true`) enable future features?

**Model Answer**:
**DynamoDB Streams** capture all changes (PutItem, UpdateItem, DeleteItem) and enable:

1. **Event processing**: Lambda functions trigger on audit changes → real-time notifications
2. **Data pipeline**: Stream to Kinesis Data Firehose → S3 for archive/analysis
3. **Search indexing**: Stream to Elasticsearch → searchable audit log UI
4. **Compliance**: Tamper detection (can't hide changes, stream is immutable for 24h)

**Current benefit**: Not enabled in terraform.tfvars yet, but infrastructure is ready. When business asks "show me who modified this claim", we can implement stream-to-Lambda without Terraform changes.

**Architecture maturity**: Streams add ~0 cost until actually consumed, so enabling in code is a best practice.

---

## Cost Management

### Q8: How do you ensure this stays within AWS Free Tier?

**Model Answer**:
Three layers of protection:

1. **Safety guard**: `enable_resources = false` (default) → $0 cost until activated
2. **Billing constraints in tfvars.example**:
   ```
   # S3: 5GB free (typical for audit archives)
   # DynamoDB: 25 RCU/WCU free with PAY_PER_REQUEST (not counted in free tier, but reasonable)
   # CloudWatch: 5 free logs, <2GB ingestion free
   ```
3. **Cost calculator in docs/costs.md**:
   - Baseline with sample data: ~$15/month
   - High volume scenario: ~$45/month
   - Both under typical AWS budgets for startups

**Monitoring**: CloudWatch Budgets alert at $50/month (2x max projection).

**Honest assessment**: This is not a "free forever" setup, but cost is predictable and low for an audit system.

---

## Disaster Recovery & Operational Risk

### Q9: What happens if terraform.tfstate is deleted?

**Model Answer**:
**Short answer**: We recover by re-importing.

**Scenario walkthrough**:
1. Someone deletes `.terraform/terraform.tfstate`
2. Next `terraform plan` shows "0 AWS resources to create" (Terraform thinks nothing exists)
3. **Recovery steps**:
   ```bash
   # Find resource IDs in AWS console
   terraform import module.iam.aws_iam_role.deployment_role claimsops-deployment-role
   terraform import module.s3.aws_s3_bucket.exports claimsops-exports-123456789
   # ... repeat for DynamoDB
   ```
4. Run `terraform plan` → "no changes" (state restored)

**Prevention**:
- `.gitignore` protects state from being committed (can't accidentally push secrets)
- Backup script (not yet implemented): could snapshot state file daily to S3
- **Next phase**: Migrate to S3 + DynamoDB backend with state locking

**Risk assessment**: Low probability (requires deliberate deletion), medium-high impact (1-2 hours to recover). Acceptable for MVP.

---

### Q10: How do you handle infrastructure drift (manual changes in AWS console)?

**Model Answer**:
**Current approach**:
```bash
terraform plan
# If manual changes exist, shows "refresh: X resources"
# If drift is acceptable, update .tfstate with terraform refresh
# If drift is problematic, taint resource and re-apply
terraform taint module.s3.aws_s3_bucket.exports
terraform apply  # Recreates S3 bucket from Terraform config
```

**Better approach (Phase 2)**:
- Implement GitOps: every AWS change comes through Terraform PR, never directly
- Use AWS Config or CloudFormation drift detection for automated alerts
- CI/CD pipeline prevents manual apply without PR review

**Current risk**: If someone manually deletes KMS key or enables public access in S3 console, Terraform doesn't auto-fix. **Mitigation**: Runbook documents this scenario with recovery steps.

---

## Microservices & System Design

### Q11: Does this architecture support a microservices approach?

**Model Answer**:
**Yes, with caveats**:

**Supports**:
- Each Lambda function gets its own IAM role (can be created with separate Terraform module)
- DynamoDB table design supports multiple services reading `claimsops-audit-events`
- S3 bucket with versioning supports claims document storage for multiple microservices

**Does NOT solve**:
- Service discovery (no service mesh)
- API Gateway not included (would need separate module)
- Event-driven communication (Streams ready, but SQS/Kinesis not provisioned)

**Recommendation**: 
This is "microservices-ready infrastructure": each service gets its own Lambda + dedicated IAM policy, but relies on shared S3/DynamoDB. For true service isolation, add:
- `modules/api-gateway/` (routing)
- `modules/sqs-queue/` (async communication)
- `modules/event-bridge/` (cross-service events)

---

### Q12: How does this support claims processing workflow (if applicable)?

**Model Answer**:
**Example workflow** (claims approval):
1. **Lambda Function 1** (ClaimsValidator): Read claim from DynamoDB, validate structure
   - Uses IAM role with DynamoDB read + S3 read for supporting docs
2. **Lambda Function 2** (ClaimsApprover): Write approval to audit table
   - Uses separate IAM role with DynamoDB write + CloudWatch Logs write
3. **DynamoDB Streams**: Capture approval event
   - S3 Exporter Lambda: Archive approved claims to S3
4. **S3**: Store claim documents + audit trail

**Architecture advantage**: Each Lambda has least-privilege IAM (can't read/write beyond its function), audit trail is immutable, separation of concerns.

**Data flow**:
```
Claim Input → Validator Lambda → DynamoDB (event store)
                                    ↓
                              Stream → Approver Lambda → DynamoDB (audit)
                                                          ↓
                                                   S3 (archive)
```

---

## Testing & Validation

### Q13: How do you validate this Terraform before applying?

**Model Answer**:
**Pre-apply validation chain**:
```bash
# 1. Syntax check
terraform validate

# 2. Format compliance
terraform fmt -check

# 3. Dry run
terraform plan -out=tfplan

# 4. Manual review
cat tfplan | grep -E "(+ create|~ modify|^Plan:)"

# 5. Cost estimate
terraform plan -json | jq '.resource_changes[] | select(.change.actions | any)'
```

**Current automation**: Not yet in CI/CD, but runbook documents these steps.

**Next phase**: GitHub Actions + Checkov (terraform security scanner) to auto-validate PR before merge.

---

## Comparison & Trade-offs

### Q14: Why Terraform over CloudFormation/CDK?

**Model Answer**:
| Criterion | Terraform | CloudFormation | CDK |
|-----------|-----------|-----------------|-----|
| Learning curve | Moderate | High (YAML) | High (Python/TS) |
| Cloud-agnostic | ✅ (can use GCP, Azure) | ❌ (AWS-only) | ❌ (CDK for AWS) |
| Module ecosystem | ✅ (Terraform Registry) | ⚠️ (CloudFormation modules) | ✅ (npm packages) |
| State management | Explicit | Hidden in CloudFormation | Hidden in CDK |
| Community | Large | Medium | Growing |

**Decision**: Terraform was chosen for modularity + multi-cloud optionality. If we need to provision same infrastructure in GCP later, Terraform modules can be adapted more easily.

**Honest assessment**: For AWS-only teams, CDK might be simpler. For multi-cloud, Terraform is safer.

---

### Q15: Why not use a managed service like Cognito/RDS instead?

**Model Answer**:
**ClaimOps Platform needs**:
- Flexible audit event schema (DynamoDB allows JSON)
- Automatic scaling (claims spikes during open enrollment)
- Cost-effective at low volume (PAY_PER_REQUEST)

**For comparison**:
| Feature | DynamoDB | RDS (PostgreSQL) | Managed AppSync |
|---------|----------|------------------|-----------------|
| Scaling | Auto (seconds) | Manual/Aurora auto | Managed |
| Cost at 100 requests/day | ~$10/mo | $50-200/mo | $20-50/mo |
| SQL support | NoSQL | ✅ | GraphQL |
| Audit-specific | Streams for events | ❌ | ❌ |

**Decision logic**: DynamoDB's event streaming is purpose-built for audit logs. RDS would require change capture code.

---

## Production Readiness

### Q16: What's NOT production-ready yet?

**Model Answer**:
**Current gaps**:
1. **Backups**: No automated S3 → Glacier lifecycle
2. **Alerts**: No CloudWatch alarms for DynamoDB throttling
3. **High availability**: Single-region only (no multi-region failover)
4. **Compliance**: No encryption key audit trail (would need KMS)
5. **Performance**: No CloudFront for S3 (exports are slow for large files)
6. **Observability**: No X-Ray tracing (Lambda network calls not traced)

**Path to production**:
```
Phase 1 (CURRENT): Core infrastructure + safety guard
Phase 2: Add KMS, CloudWatch Budgets, X-Ray
Phase 3: Multi-region setup, automated backups
Phase 4: Infrastructure-as-Code linting (Checkov, tflint)
Phase 5: GitOps pipeline (destroy old resources, enforce PR-based deployment)
```

---

## Open Questions (Be prepared for)

### Q17: "Can we terraform destroy without losing data?"

**Answer**: 
- S3: `aws_s3_bucket_versioning` retains versions (can recover deleted objects)
- DynamoDB: Backup happens before destroy (manual job, should be automated)
- **Recommendation**: Add `lifecycle { prevent_destroy = true }` to data modules

### Q18: "What's the blast radius if someone queries with wrong sort_key?"

**Answer**:
- DynamoDB Query API: `aws_dynamodb_table` uses `pk` (partition) + `sk` (sort), can't scan full table without secondary index
- Cost risk: Scan instead of Query = 1000x more ReadCapacityUnits
- **Mitigation**: CloudWatch alarm if RCU > threshold

### Q19: "How do we debug Terraform failures in production?"

**Answer**:
```
1. terraform show  # Current state
2. terraform refresh  # Sync with AWS
3. AWS Console: Verify IAM permissions
4. terraform validate -json  # Detailed error output
```

### Q20: "What if enable_resources variable leaks into production by accident?"

**Answer**:
- **Prevention**: tfvars.example has enable_resources=false, no secrets committed
- **Detection**: Pull request policy requires 2 approvals if enable_resources=true
- **Rollback**: terraform apply with enable_resources=false again

---

## Summary

**Key talking points for Monday**:
1. ✅ **Safety first**: enable_resources guard prevents accidents
2. ✅ **Security native**: IAM least privilege, encryption built-in
3. ✅ **Cost predictable**: Free Tier aligned, PAY_PER_REQUEST scales naturally
4. ✅ **Scalable design**: Streams + modular approach supports microservices
5. ✅ **Production-ready path**: Phase roadmap exists, gaps documented

**If challenged**:
- Have numbers ready: costs.md has 3 scenarios with exact estimates
- Have recovery steps: runbook.md covers disaster scenarios
- Have honest trade-offs: acknowledge limitations (state management, multi-region, compliance)

---

**Last updated**: March 2, 2026
**Next review**: Before production deployment
