# Contributing Guide

Thank you for your interest in the ClaimOps Platform infrastructure project!

## What is This Project?

This is a **learning-focused infrastructure-as-code (IaC) project** for AWS using Terraform. It demonstrates:
- Best practices for cloud infrastructure
- Secure configuration with least privilege
- Cost-efficient Free Tier architecture
- Professional git workflow and documentation

**Status**: Educational (MVP complete, not production)

---

## Getting Started

### 1. Prerequisites
- Git (https://git-scm.com/)
- Terraform >= 1.0 (https://www.terraform.io/downloads)
- Basic shell/CLI knowledge
- Patience and curiosity

### 2. Clone the Repository
```bash
git clone https://github.com/SvillarroelZ/ClaimOps-Platform.git
cd ClaimOps-Platform
```

### 3. Explore the Code
```bash
# Read the main documentation
cat README.md

# Understand the architecture
cat docs/architecture.md

# Check the current improvements roadmap
cat docs/IMPROVEMENTS.md
```

---

## Development Workflow

### Branch Strategy

We use **feature branches** for all work:

```bash
# Update main branch
git checkout main
git pull origin main

# Create a feature branch
git checkout -b feature/your-feature-name

# IMPORTANT: Use descriptive names
# Good: feature/lambda-module, feature/vpc-security
# Bad: feature/fix, feature/test
```

### Commit Message Format

We use **conventional commits**:

```bash
git commit -m "type: description"
```

**Valid types**:
- `feat`: New feature (e.g., "feat: add Lambda module with stream processor")
- `fix`: Bug fix (e.g., "fix: correct DynamoDB validation error")
- `docs`: Documentation (e.g., "docs: add Windows CLI instructions")
- `chore`: Maintenance (e.g., "chore: update Terraform version requirement")
- `refactor`: Code reorganization (e.g., "refactor: extract S3 logging to submodule")
- `test`: Testing (e.g., "test: add terraform tests for IAM module")

**Rules**:
- ✓ Use lowercase
- ✓ Use present tense ("add" not "added")
- ✓ Keep to one line (max 50 chars)
- ✓ No emojis (not following Unicode bloat principle)
- ✓ No period at the end

**Bad commits**:
```
❌ "Adds new feature"
❌ "WIP: stuff"
❌ "fixed it"
❌ "feat: add lambda module for processing events and also fixed a bug with terraform validation"
```

### Code Style

#### Terraform Files
```bash
# Format all files
terraform fmt -recursive

# Validate syntax
terraform validate

# Both must pass before committing
```

#### File Organization
```
modules/
├── module_name/
│   ├── main.tf (main resource definitions)
│   ├── variables.tf (input variables)
│   ├── outputs.tf (output values)
│   └── README.md (optional, module documentation)
```

#### Naming Conventions
```hcl
# Variables: snake_case
variable "enable_encryption" { }

# Resources: descriptive names
resource "aws_s3_bucket" "main" { }

# Outputs: match variable names
output "bucket_name" { }

# Comments: clear intent
# Enable versioning for data protection (costs $0.23/GB-month)
enabled_versioning = true
```

---

## Making a Contribution

### Step 1: Choose an Improvement

Go to [docs/IMPROVEMENTS.md](./docs/IMPROVEMENTS.md) and pick one:

**Easy (30 min - 1 hour)**:
- Add `terraform.tfvars.example`
- Improve variable validation messages
- Add LICENSE file
- Update documentation for Windows

**Medium (2-4 hours)**:
- Add Lambda module
- Improve error messages
- Add monitoring example
- Create multi-environment setup

**Hard (4+ hours)**:
- Integration tests
- CI/CD pipeline
- Integration with claimsops-app
- Disaster recovery procedures

### Step 2: Create Feature Branch

```bash
git checkout main
git pull origin main
git checkout -b feature/your-feature-name

# Example:
# git checkout -b feature/add-tfvars-example
# git checkout -b feature/lambda-module
```

### Step 3: Make Changes

Edit files relevant to your improvement:

```bash
# Example for adding terraform.tfvars.example
cat > infra/terraform/terraform.tfvars.example << 'EOF'
# Example Terraform variables
aws_region            = "us-east-1"
project_name          = "claimsops"
environment           = "dev"
enable_versioning     = false
dynamodb_billing_mode = "PAY_PER_REQUEST"
EOF

# Validate your changes
terraform fmt -recursive
terraform validate
```

### Step 4: Test Your Code

```bash
# Terraform must pass these checks
terraform fmt -recursive
terraform validate

# Code review yourself
git diff

# Are there any secrets? (should be none)
grep -r "AKIAIOSFODNN7EXAMPLE" infra/

# Are there large files? (should be no .terraform/)
find . -size +10M
```

### Step 5: Commit Changes

```bash
# Stage your changes
git add infra/terraform/ docs/

# Commit with conventional format
git commit -m "feat: add terraform.tfvars.example for quick setup"

# Don't commit secrets or large files!
# If you did, revert immediately:
# git reset HEAD~1
# git reset -- <file>
```

### Step 6: Push to GitHub

```bash
git push origin feature/your-feature-name
```

GitHub will suggest creating a Pull Request. Click the link or:

```bash
open https://github.com/SvillarroelZ/ClaimOps-Platform/pull/new/feature/your-feature-name
```

### Step 7: Create Pull Request

**Pull Request Title**:
```
feat: add lambda module with DynamoDB stream processor
```

**Pull Request Description**:
```markdown
## What does this do?
Adds a Lambda function that processes DynamoDB stream events and logs them to CloudWatch.

## Why?
- Demonstrates serverless event processing
- Shows integration between AWS services
- Educational value for stream consumption patterns

## How to test?
1. Review the module code in `modules/lambda/`
2. Check that `terraform validate` passes
3. Review the example Lambda code in `modules/lambda/example_function/`

## Related to
Closes #12 (if applicable)
```

### Step 8: Code Review & Merge

A maintainer will:
- ✓ Review your code
- ✓ Check for security issues
- ✓ Verify documentation
- ✓ Request changes if needed
- ✓ Merge when ready

You can make changes by:
```bash
# Make requested changes
git add .
git commit -m "fix: correct variable naming in Lambda module"
git push origin feature/your-feature-name

# Your PR will auto-update
```

---

## Common Pitfalls to Avoid

### ❌ Mistake 1: Committing Secrets
```bash
# NEVER commit AWS credentials, API keys, etc.
# Wrong:
git add terraform.tfvars
git commit -m "feat: add variables"

# Right:
# Keep secrets in .env or environment variables
terraform apply -var="password=$PASSWORD"
```

### ❌ Mistake 2: Committing Large Files
```bash
# NEVER commit .terraform/ directory or 100MB+ files
# Wrong:
git add infra/terraform/.terraform/

# Right:
# .gitignore automatically ignores these
echo ".terraform/" >> .gitignore
```

### ❌ Mistake 3: Breaking main Branch
```bash
# Always merge from main first
git checkout main
git pull origin main
git checkout -b feature/new-feature

# Not:
# Creating feature from old commits
git checkout -b feature/new-feature  # without pulling main
```

### ❌ Mistake 4: Ignoring Code Style
```bash
# Wrong: Committing unformatted code
git add infra/terraform/main.tf
git commit -m "feat: add resource"

# Right: Always format first
terraform fmt -recursive
git add infra/terraform/main.tf
git commit -m "feat: add resource"
```

### ❌ Mistake 5: Vague Commit Messages
```bash
# Wrong:
git commit -m "updates"
git commit -m "fix stuff"

# Right:
git commit -m "feat: add DynamoDB stream configuration"
git commit -m "fix: correct IAM policy for Lambda execution"
```

---

## Testing Your Code (Before AWS Account)

### Terraform Syntax
```bash
cd infra/terraform
terraform fmt -check -recursive
terraform validate
```

### Code Review Yourself
```bash
# See all your changes
git diff

# Check against template:
# - All files named correctly?
# - All variables have descriptions?
# - All outputs documented?
# - Comments explain non-obvious logic?
```

### Security Check
```bash
# No AWS keys?
grep -r "AKIA" infra/
grep -r "aws_access_key" infra/

# No large binaries?
find . -size +10M -type f

# No passwords?
grep -r "password\|secret\|token" infra/ | grep -v "description"
```

---

## Documentation Standards

### For New Modules

Create `modules/your_module/README.md`:

```markdown
# Your Module Name

## Purpose
Brief description of what this module does.

## Resources Created
- aws_resource_type: Description
- aws_another_resource: Description

## Variables
- `var_name`: Description, type, default

## Outputs
- `output_name`: Description

## Usage Example
\`\`\`hcl
module "your_module" {
  source = "./modules/your_module"
  
  input_var = "value"
}
\`\`\`

## Cost Implications
Free / Paid tier friendly / Warning: adds $X/month
```

### For Improvements

Update [docs/IMPROVEMENTS.md](./docs/IMPROVEMENTS.md):

```markdown
#### Your_Improvement_Name
**Effort**: 2 hours  
**Impact**: High  
**Details**:
- What it does
- Why it matters
- Implementation approach

**Commit**: `intent: specific description`
```

---

## Getting Help

### Questions About Terraform?
- [Terraform Docs](https://www.terraform.io/docs)
- [AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- Ask in GitHub Issues

### Questions About the Project?
- Read [README.md](./README.md)
- Read [docs/architecture.md](./docs/architecture.md)
- Check [docs/IMPROVEMENTS.md](./docs/IMPROVEMENTS.md)
- Open a GitHub Discussion

### Found a Bug?
1. Create a GitHub Issue with:
   - Description of the problem
   - Steps to reproduce
   - What you expected
   - What actually happened
2. Label as `bug`

### Have a Suggestion?
1. Open a GitHub Discussion
2. Or create an Issue labeled `enhancement`

---

## Code of Conduct

We follow a simple principle: **Be respectful, assume good intent, help others learn**.

This is an educational project. Everyone is welcome to:
- Ask questions (no "stupid" questions!)
- Make mistakes (we learn from them)
- Suggest improvements
- Share knowledge

---

## Reviewing Other Contributions

If you're asked to review someone's pull request:

1. **Check Code Quality**
   - Does `terraform validate` pass?
   - Is code formatted with `terraform fmt`?
   - Are variables well-named?

2. **Check Documentation**
   - Are new features documented?
   - Are comments clear?
   - Is the PR description complete?

3. **Check Security**
   - No secrets committed?
   - No unnecessary permissions granted?
   - Are resources encrypted?

4. **Write Helpful Comments**
   ```
   ✓ Good: "Consider using PAY_PER_REQUEST for DynamoDB since billing is unpredictable. See docs/costs.md#dynamodb for details."
   ✗ Bad: "This is wrong."
   ```

---

## Project Philosophy

This project follows **Kaizen** (continuous improvement):

- **Small, incremental changes** rather than big rewrites
- **Learn from failures** (no perfect first commits)
- **Document everything** (future learners will thank you)
- **Simplicity first** (avoid over-engineering)
- **Free tier always** (never accidentally cause costs)

---

## Success Checklist

Before submitting your PR:

- [ ] Code passes `terraform fmt -recursive`
- [ ] Code passes `terraform validate`
- [ ] No secrets or large files committed
- [ ] Commit message follows conventional format
- [ ] Pull request description is clear
- [ ] Related documentation updated
- [ ] No warnings or errors in Git history

---

## What Happens Next

1. **PR Created** → Maintainer notified
2. **Code Review** → Feedback provided (usually within 48 hours)
3. **Revisions** → You make requested changes
4. **Approval** → Maintainer approves PR
5. **Merge** → Code merged to develop branch
6. **Release** → Periodic releases to main branch

Typical timeline: **1-7 days** depending on complexity

---

## Thank You!

Every contribution helps others learn infrastructure-as-code and best practices. Whether it's code, documentation, or ideas—your help is appreciated! 🙌

---

**Questions?** Open a GitHub Issue or Discussion.  
**Happy coding!**
