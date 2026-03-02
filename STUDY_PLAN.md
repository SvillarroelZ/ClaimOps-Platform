# Study Plan: What to Review Before Monday Presentation

**Objective**: Internalize key concepts so you can explain them naturally without reading notes.
**Timeline**: Today (Sunday) - review in priority order.
**Audience**: Yourself (internal study), but organized for external communication later.
**Format**: Critical to non-critical, by impact on conversation.

---

## CRITICAL (Read first, ~45 minutes)

### 1. README.md - Skim for "why this exists"
**File**: [README.md](README.md)
**Why**: This is what your manager will see first.
**What to absorb**:
- Project name: ClaimOps-Platform
- One-line: "Infrastructure-as-Code for claims audit system"
- Quick start command chain (terraform validate → plan → apply)
- Free Tier alignment statement

**Key quote to remember**: "All resources protected by enable_resources safety guard"

**Time**: 5 min

---

### 2. EXECUTIVE_BRIEFING.md - Full read
**File**: [EXECUTIVE_BRIEFING.md](EXECUTIVE_BRIEFING.md)
**Why**: This is your manager's language. Internalize the business framing.
**What to memorize**:
- **Problem statement**: Why claims systems need audit trails
- **Solution architecture**: 3-module approach (IAM, S3, DynamoDB)
- **Business value**: Which benefits matter to CFO (cost), CTO (scalability), compliance officer (audit trail)
- **Risk mitigation**: How enable_resources guard prevents production incidents

**Key phrase to use**: "This infrastructure is production-ready but safe-by-default"

**Time**: 15 min

---

### 3. TECHNICAL_DEFENSE.md - Full read
**File**: [TECHNICAL_DEFENSE.md](TECHNICAL_DEFENSE.md)
**Why**: This is your peer engineers' language. Be ready for architectural questions.
**What to memorize**:
- **Terraform flow**: How count guard works (count = var.enable_resources ? 1 : 0)
- **IAM permission model**: 5 statement blocks with ARN restrictions
- **DynamoDB streaming**: Why it's enabled for future Lambda integration
- **State management**: Why terraform.tfstate is not in Git + how to recover if deleted

**Key phrase to use**: "The safety guard is explicit in every resource, not hidden in code"

**Time**: 20 min

---

### 4. infra/terraform/variables.tf - Study the enable_resources definition
**File**: [infra/terraform/variables.tf](infra/terraform/variables.tf)
**Why**: This variable is the heart of your safety architecture.
**What to understand**:
```hcl
variable "enable_resources" {
  description = "SAFETY GUARD: Set to false to prevent resource creation..."
  type        = bool
  default     = false
  # Above: default is false = safe default
}
```
**Why this matters**: Even if someone runs `terraform apply` without setting this variable, resources won't create.

**Test yourself**: "What happens if someone forgets to set enable_resources?" → Answer: "Nothing. It defaults to false, so terraform plan shows 0 changes."

**Time**: 5 min

---

## HIGH PRIORITY (Read next, ~60 minutes)

### 5. INTERVIEW_PREP_FAQ.md - Questions 1-10
**File**: [INTERVIEW_PREP_FAQ.md](INTERVIEW_PREP_FAQ.md)
**Why**: These are the exact questions your manager/peers will ask.
**Strategy**: Read the Q&A pairs, close the file, then explain each answer out loud.
**Questions to master** (in order):
1. "Why modular Terraform?" → Know the 4 benefits (reusability, testing, maintainability, scaling)
2. "How does the safety guard work?" → Describe the count logic without reading
3. "Why count vs. workspaces?" → Know the trade-offs
4. "How does IAM granularity reduce risk?" → Be able to point to 5 statements
5. "AES256 vs KMS?" → Know when to upgrade (PII/payment data triggers KMS)
6. "Why DynamoDB PAY_PER_REQUEST?" → Explain the sporadic audit workload
7. "DynamoDB Streams use cases?" → Know 4 examples (events, pipeline, search, compliance)
8. "How stay in Free Tier?" → Cite the 3-layer protection
9. "What if terraform.tfstate is deleted?" → Walk through recovery (terraform import)
10. "How handle infrastructure drift?" → Know the terraform refresh → taint → apply flow

**Practice technique**: Read Q1-Q5, close the file, explain to a rubber duck. Repeat for Q6-Q10.

**Time**: 45 min reading + 15 min practicing aloud

---

### 6. docs/architecture.md - Sections: Overview + Diagram + Terraform Flow
**File**: [docs/architecture.md](docs/architecture.md)
**Why**: Visual understanding of how modules connect.
**What to focus on**:
- ASCII diagram showing 3 modules + flow
- Why DynamoDB streams to S3 (audit archive)
- Why IAM role is separate module (can be reused for Lambda functions)

**Skip**: Cost analysis section (not needed for Monday)

**Time**: 15 min

---

## MEDIUM PRIORITY (Reference if asked, ~30 minutes)

### 7. INTERVIEW_PREP_FAQ.md - Questions 11-20
**File**: [INTERVIEW_PREP_FAQ.md](INTERVIEW_PREP_FAQ.md)
**Why**: Deeper questions if presentation goes technical.
**Questions to skim**:
11. Microservices support? → Know the "microservices-ready" framing
12. Claims workflow integration? → Lambda + DynamoDB + S3 data flow
13. Validation chain? → terraform validate → fmt → plan
14. Why Terraform vs CFN/CDK? → Know the comparison table
15. Why DynamoDB vs RDS? → Understand event streaming advantage
16. What's not production-ready? → Have the 5-phase roadmap memorized

**Strategy**: These are "if asked" questions. Understand them, but don't memorize word-for-word.

**Time**: 20 min skimming

---

### 8. docs/costs.md - Sections: Free Tier Alignment + 3 Scenarios
**File**: [docs/costs.md](docs/costs.md)
**Why**: If asked about budget, cite actual numbers.
**What to memorize**:
- Baseline: ~$15/month with sample data
- High volume: ~$45/month (reasonable)
- Monitoring: CloudWatch Budgets set to $50/month

**Key phrase**: "We're well within AWS Free Tier limits, and scaling is cost-predictable"

**Time**: 10 min

---

## LOW PRIORITY (Skim if time permits, ~20 minutes)

### 9. docs/runbook.md - Skim: "Deployment Steps" section
**File**: [docs/runbook.md](docs/runbook.md)
**Why**: If asked "how do you deploy?", have a mental model.
**What to know**:
- Step 1: terraform validate (syntax check)
- Step 2: terraform plan (review changes)
- Step 3: Review approval (enable_resources=true check)
- Step 4: terraform apply

**You don't need to memorize exact CLI flags, just the logical flow.**

**Time**: 10 min

---

### 10. docs/STATE_MANAGEMENT.md - Skim: "First 50 lines + Recovery Scenarios"
**File**: [docs/STATE_MANAGEMENT.md](docs/STATE_MANAGEMENT.md)
**Why**: If asked "what if state is lost?" have a response.
**What to know**:
- terraform.tfstate is NOT in Git (.gitignore protects it)
- State contains sensitive data (passwords, keys) → must be protected
- Recovery: terraform import can rebuild state from actual AWS resources

**Time**: 10 min

---

## OPTIONAL (Reference material, don't memorize)

### Reference: REPOSITORY_ANALYSIS.md
**Use case**: If asked "what's in the repo?", point to this.
**Contains**: Complete inventory of all 13 .tf files, all documentation.

### Reference: PROJECT_SUMMARY.md  
**Use case**: If asked "give me the elevator pitch", reference this.
**Contains**: High-level overview suitable for CTO or product manager.

---

## Study Schedule (Suggested for Today)

### 60 minutes (Morning)
- [ ] README.md (5 min)
- [ ] EXECUTIVE_BRIEFING.md (15 min)
- [ ] TECHNICAL_DEFENSE.md (20 min)
- [ ] infra/terraform/variables.tf (5 min)
- [ ] Walk through enable_resources mentally (5 min)

**Checkpoint**: Can you explain the safety guard to a non-technical colleague?

### 60 minutes (Afternoon)
- [ ] INTERVIEW_PREP_FAQ.md Q1-Q10 (30 min reading)
- [ ] Practice Q1-Q5 aloud (15 min)
- [ ] Practice Q6-Q10 aloud (15 min)

**Checkpoint**: Can you answer any Q1-Q10 without looking at the file?

### 30 minutes (Evening)
- [ ] docs/architecture.md - Overview + Diagram (15 min)
- [ ] docs/costs.md - Free Tier + 3 scenarios (10 min)
- [ ] Skim INTERVIEW_PREP_FAQ.md Q11-Q20 (5 min)

**Checkpoint**: Can you draw the 3-module architecture from memory?

---

## Critical Concepts to Master (Test yourself)

### Concept 1: The Safety Guard Pattern
**Question**: How does `count = var.enable_resources ? 1 : 0` prevent production incidents?
**Answer template**:
- Default is false → no resources created
- Must explicitly set enable_resources=true → forces review
- Every resource uses same pattern → no exceptions

**Practice**: Explain this to someone who's never seen Terraform.

---

### Concept 2: IAM Least Privilege
**Question**: Why is the IAM role split into 5 statements instead of one?
**Answer template**:
- Each statement grants specific permission (S3 list, S3 get-object, DynamoDB write, etc.)
- ARN restrictions (claimsops-*) limit damage if role is compromised
- If one permission is overly broad, audit catches it

**Practice**: Point out which statement handles what (without looking at code).

---

### Concept 3: DynamoDB vs. Relational Database Trade-off
**Question**: Why DynamoDB instead of PostgreSQL?
**Answer template**:
- DynamoDB: Automatically scales, pays per request, Streams for events
- PostgreSQL: Requires capacity planning, cheaper at high volume, SQL queries
- For audit system: Events are sporadic, not predictable → DynamoDB better

**Practice**: Defend the choice to a database engineer.

---

### Concept 4: State Management Risk
**Question**: What could go wrong with terraform.tfstate?
**Answer template**:
- State file contains secrets (passwords, API keys)
- If leaked (Git commit), attacker has AWS creds
- Must be in .gitignore and protected
- If lost, can recover via `terraform import` (slow but possible)

**Practice**: Explain why .terraform.tfstate is NOT committed to Git.

---

### Concept 5: Scaling the Architecture
**Question**: How do you add Lambda functions to this infrastructure?
**Answer template**:
- Create new module: `modules/lambda/main.tf`
- Each Lambda gets own IAM role (grant specific permissions)
- Role uses `assume_role_policy` trusting lambda.amazonaws.com
- Use DynamoDB + S3 from shared infrastructure

**Practice**: Sketch the module addition on paper.

---

## Knowledge Check (Right Before Monday)

**Do this 30 minutes before your presentation**:

1. Close all files. Answer these without looking:
   - [ ] What's the default value of enable_resources? (Answer: false)
   - [ ] Why use DynamoDB Streams? (Answer: Event processing, Lambda triggers, audit archive)
   - [ ] How recover if terraform.tfstate deleted? (Answer: terraform import)
   - [ ] What's the AWS Free Tier alignment cost? (Answer: $15-45/month)
   - [ ] What prevents manual drift? (Answer: Nothing yet—Phase 2 adds CloudFormation DMP)

2. Recite the 5-statement IAM blocks without looking:
   - [ ] S3 list-buckets
   - [ ] S3 get-object
   - [ ] DynamoDB query/scan
   - [ ] Lambda invoke (invoke only, not create)
   - [ ] CloudWatch Logs write

3. Walk through the 4-phase plan:
   - [ ] Phase 0: Safety guard (current)
   - [ ] Phase 1: Production readiness (KMS, CloudWatch)
   - [ ] Phase 2: Compliance (audit trail, key rotation)
   - [ ] Phase 3: Scale (multi-region, backup)

---

## Pro Tips for Monday

### Tips for Explaining Terraform Code
- **Don't read the code**: Explain the concept, then show the code as proof
  - ✅ "The safety guard checks if resources should exist before creating..."
  - ❌ "Look, here's line 27, it says count equals..."
  
### Tips for Handling "I Don't Know" Questions
- **Honest deflection**: "That's a great question. Let me check the runbook and send you the answer."
- **Don't improvise or guess** about AWS billing, permissions, or security

### Tips for Demonstrating Credibility
- **Cite documents**: "As the economics analysis shows in docs/costs.md..."
- **Reference decisions**: "We explicitly chose DynamoDB for this reason..."
- **Acknowledge gaps**: "This is Phase 0. Phase 2 adds KMS encryption keys."

### Tips for Managing Time
- **Have a timer**: 30-min presentation = ~6 minutes per major topic
- **Prepare 3-minute summary**: "If we only have 10 min, here's the core story..."
- **Know your Q&A depth**: Basic vs. advanced answers for each question

---

## Confidence Builders

### What You Know (Be proud of this)
- ✅ Modular Terraform architecture (3 modules, reusable pattern)
- ✅ Security from ground up (IAM least privilege, encryption)
- ✅ Cost-conscious design (Free Tier alignment, PAY_PER_REQUEST)
- ✅ Scalability path (Streams, Lambda integration, multi-region ready)
- ✅ Production-safe (enable_resources guard, state protection, recovery steps)

### What You Don't Know Yet (That's OK)
- ❌ Advanced Terraform state backends (S3 + DynamoDB locking)
- ❌ Multi-region disaster recovery (stretch goal)
- ❌ Full CI/CD pipeline automation (Phase 2)
- ❌ All AWS security certifications (not your job today)

**Remember**: You're explaining infrastructure decisions you've made, not defending AWS's entire platform.

---

## Quick Reference (Bookmark this section)

### The 3-Module Architecture
```
IAM Module
  └─ Deployment role with 5-statement policy

S3 Module
  └─ Exports bucket with encryption + versioning

DynamoDB Module
  └─ Audit table with streams enabled

All protected by count = var.enable_resources ? 1 : 0
```

### The Safety Guard Logic
```
IF enable_resources == true
  → terraform plan shows resources to create
  ELSE
  → terraform plan shows "no changes"
```

### The Cost Summary
```
Baseline (sample data): ~$15/month
High volume (1M events): ~$45/month
Free Tier limit: ~$25/month
Monitoring threshold: $50/month (CloudWatch Budget)
```

### The 4-Step Deployment Flow
```
1. terraform validate  (syntax check)
2. terraform plan      (review changes + enable_resources check)
3. Review approval     (someone reviews the plan)
4. terraform apply     (create resources if enable_resources=true)
```

### The 5-Statement IAM Policy
```
1. S3 ListBucket         (claimsops-*)
2. S3 GetObject          (claimsops-*/*)
3. DynamoDB Query        (claimsops-audit-events)
4. Lambda Invoke         (claimsops-*, deny PassRole)
5. CloudWatch Logs Write (for Lambda execution logs)
```

---

## Last Minute Checklist (90 minutes before)

- [ ] Print EXECUTIVE_BRIEFING.md (have it on your desk)
- [ ] Print INTERVIEW_PREP_FAQ.md Q1-Q10 (reference during Q&A)
- [ ] Open docs/costs.md in a browser tab (for cost questions)
- [ ] Have terraform validate output ready (proof that code works)
- [ ] Have git log showing commits (proof of methodology)
- [ ] Wear something that makes you feel confident 😊

---

## What Now?

**Today's study flow**:
```
Start with CRITICAL section (45 min)
  ↓ (Take 10-min break)
Start with HIGH PRIORITY section (60 min)
  ↓ (Take 15-min break)
Start with MEDIUM PRIORITY section (30 min)
  ↓
Do the Knowledge Check (30 min before presentation)
```

**Total time**: ~2.5-3 hours spread throughout the day.

**Success metric**: You can explain any concept to a peer without reading the file.

---

**Last updated**: March 2, 2026
**Ready by**: March 2 20:00 (Monday presentation time TBD)
