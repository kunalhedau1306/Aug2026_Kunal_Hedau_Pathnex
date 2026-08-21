# Terraform Practice – Day 21

**Date:** 21-Aug-2026  
**Topics Covered:**
1. Terraform Modules
2. Terraform Remote Backends
3. Terraform Lifecycle – CPIR
4. Terraform Best Practices

---

# 1. Terraform Modules

## 1.1 What is a Terraform Module?

A **Terraform module** is a collection of Terraform configuration files that are grouped together and used as a reusable unit.

Every Terraform configuration is technically a module.

There are two main types:

- **Root Module** – The Terraform configuration from which you run commands such as `terraform plan` and `terraform apply`.
- **Child Module** – A reusable Terraform module called from another module.

Example:

```text
terraform-project/
├── main.tf
├── variables.tf
├── outputs.tf
└── modules/
    └── ec2/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

The top-level directory is the **root module**.

The `modules/ec2` directory is a **child module**.

---

## 1.2 Why Use Modules?

Modules help to:

- Reuse Terraform code.
- Avoid duplicate configuration.
- Standardize infrastructure.
- Improve maintainability.
- Simplify large Terraform projects.
- Separate infrastructure into logical components.
- Make infrastructure easier to test and review.
- Enforce organizational standards.

For example, instead of defining an EC2 instance repeatedly in DEV, ACC, and PRD, you can create one reusable EC2 module.

---

## 1.3 Basic Module Structure

A common module contains:

```text
modules/ec2/
├── main.tf
├── variables.tf
├── outputs.tf
└── versions.tf
```

### main.tf

Contains Terraform resources.

```hcl
resource "aws_instance" "this" {
  ami           = var.ami_id
  instance_type = var.instance_type

  tags = {
    Name = var.instance_name
  }
}
```

### variables.tf

Defines inputs accepted by the module.

```hcl
variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "instance_name" {
  description = "Name assigned to the EC2 instance"
  type        = string
}
```

### outputs.tf

Defines values returned by the module.

```hcl
output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP address"
  value       = aws_instance.this.private_ip
}
```

---

## 1.4 Calling a Child Module

A module is called using a `module` block.

```hcl
module "web_server" {
  source = "./modules/ec2"

  ami_id        = "ami-xxxxxxxxxxxxxxxxx"
  instance_type = "t3.micro"
  instance_name = "day21-web-server"
}
```

Syntax:

```hcl
module "<MODULE_NAME>" {
  source = "<MODULE_SOURCE>"

  variable1 = value1
  variable2 = value2
}
```

---

## 1.5 Accessing Module Outputs

If the module exposes:

```hcl
output "instance_id" {
  value = aws_instance.this.id
}
```

The root module can access it using:

```hcl
module.web_server.instance_id
```

Example:

```hcl
output "web_instance_id" {
  value = module.web_server.instance_id
}
```

---

## 1.6 Module Sources

Terraform modules can come from several locations.

### Local directory

```hcl
module "web" {
  source = "./modules/ec2"
}
```

### Git repository

```hcl
module "web" {
  source = "git::https://github.com/example/terraform-modules.git//ec2"
}
```

### Terraform Registry

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "x.y.z"
}
```

### S3 or other supported sources

Terraform also supports remote package locations depending on the module source mechanism.

---

## 1.7 Module Versioning

For public or remote modules, versions should be controlled.

Example:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"
}
```

Pinning module versions prevents unexpected changes caused by automatic upgrades.

---

## 1.8 Terraform Commands for Modules

Initialize modules:

```bash
terraform init
```

Explicitly download modules:

```bash
terraform get
```

Update downloaded modules:

```bash
terraform get -update
```

Validate configuration:

```bash
terraform validate
```

Preview changes:

```bash
terraform plan
```

---

## 1.9 Module Best Practices

Recommended practices:

- Keep modules focused on one responsibility.
- Avoid very large modules.
- Use meaningful input variable names.
- Add descriptions to variables and outputs.
- Define variable types.
- Add validation where appropriate.
- Avoid hardcoded environment-specific values.
- Use version constraints.
- Document module usage.
- Avoid exposing unnecessary outputs.
- Keep modules reusable across environments.

---

# 2. Terraform Remote Backends

## 2.1 What is Terraform State?

Terraform stores information about managed infrastructure in a **state file**.

Default state filename:

```text
terraform.tfstate
```

Terraform state maps resources in your `.tf` configuration to real infrastructure.

Example:

```text
Terraform configuration
        |
        v
terraform.tfstate
        |
        v
AWS EC2 / VPC / Security Groups
```

---

## 2.2 What is a Backend?

A **backend** defines where Terraform stores state and how state operations are performed.

Terraform can use:

- Local backend
- Remote backend

---

## 2.3 Local Backend

By default, Terraform stores state locally.

Example:

```text
project/
├── main.tf
├── variables.tf
└── terraform.tfstate
```

Advantages:

- Simple.
- Easy for learning.
- No external infrastructure required.

Disadvantages:

- Poor for teams.
- State can be lost.
- Difficult to share.
- Potential concurrency problems.
- Harder to integrate safely with CI/CD.

---

## 2.4 Remote Backend

A remote backend stores Terraform state in remote/shared infrastructure.

For AWS environments, S3 is commonly used.

Benefits:

- Centralized state.
- Better collaboration.
- Improved durability.
- Easier CI/CD integration.
- Better access control.
- Encryption support.
- Versioning/backups.
- State locking support depending on backend configuration and Terraform version.

---

# 2.5 Example S3 Backend

Example `backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket = "kunal-terraform-state"
    key    = "day21/terraform.tfstate"
    region = "eu-west-1"

    encrypt = true
  }
}
```

Important:

The S3 bucket must already exist before Terraform initializes the backend.

Terraform cannot create its own backend bucket using the same configuration that depends on that backend.

A common approach is:

1. Bootstrap the S3 backend separately.
2. Configure the backend.
3. Run `terraform init`.
4. Migrate existing state if required.

---

## 2.6 Backend State Key

The `key` defines the location of the state object inside the bucket.

Example:

```hcl
key = "day21/terraform.tfstate"
```

Possible structure:

```text
s3://kunal-terraform-state/
├── dev/terraform.tfstate
├── acc/terraform.tfstate
└── prd/terraform.tfstate
```

Separate state files are recommended for independent environments.

---

## 2.7 Initialize a Backend

After configuring the backend:

```bash
terraform init
```

Terraform detects the backend configuration and initializes it.

---

## 2.8 Reconfigure a Backend

If backend configuration changes:

```bash
terraform init -reconfigure
```

This tells Terraform to disregard previously saved backend initialization information and initialize again using the current configuration.

---

## 2.9 Migrate Local State to Remote State

If you already have local state:

```bash
terraform init -migrate-state
```

Terraform can migrate state from the old backend to the new backend.

Always back up state before significant backend changes.

---

## 2.10 Partial Backend Configuration

Instead of putting all values directly in `backend.tf`, you can use a separate file.

`backend.tf`:

```hcl
terraform {
  backend "s3" {}
}
```

`backend.hcl`:

```hcl
bucket = "kunal-terraform-state"
key    = "day21/terraform.tfstate"
region = "eu-west-1"
```

Initialize with:

```bash
terraform init -backend-config=backend.hcl
```

This is useful for separating backend values by environment.

---

## 2.11 State Commands

List resources:

```bash
terraform state list
```

Show one resource:

```bash
terraform state show aws_instance.web
```

Pull state:

```bash
terraform state pull
```

Move a resource in state:

```bash
terraform state mv <source> <destination>
```

Remove resource from state:

```bash
terraform state rm <resource>
```

Important:

`terraform state rm` removes the resource from Terraform management but does not necessarily delete the real infrastructure.

State commands should be treated carefully.

---

## 2.12 Remote Backend Security Best Practices

For S3 state:

- Enable encryption.
- Enable S3 bucket versioning.
- Restrict IAM access.
- Block public access.
- Enable audit logging where required.
- Use separate state locations for environments.
- Protect state from accidental deletion.
- Avoid sharing state publicly.
- Treat state as sensitive data.
- Back up state appropriately.

Terraform state may contain passwords, IDs, endpoints, tokens, or other sensitive data depending on resources and providers.

---

# 3. Terraform Lifecycle – CPIR

Terraform supports a `lifecycle` block to control resource behavior.

A useful way to remember the main lifecycle options is:

```text
C = create_before_destroy
P = prevent_destroy
I = ignore_changes
R = replace_triggered_by
```

---

# 3.1 C – create_before_destroy

By default, when Terraform needs to replace a resource, it may destroy the old resource and then create a replacement.

With:

```hcl
lifecycle {
  create_before_destroy = true
}
```

Terraform attempts to create the replacement before destroying the original.

Example:

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  lifecycle {
    create_before_destroy = true
  }
}
```

### Use Cases

Useful for:

- Application servers.
- Load-balanced infrastructure.
- Resources where replacement should minimize downtime.
- Blue/green-style transitions.

### Important Limitation

The cloud provider must allow the old and new resources to exist at the same time.

For example, unique resource names can prevent simultaneous creation.

---

# 3.2 P – prevent_destroy

`prevent_destroy` protects a resource from accidental Terraform-driven destruction.

Example:

```hcl
resource "aws_db_instance" "production" {
  # configuration

  lifecycle {
    prevent_destroy = true
  }
}
```

If Terraform detects that this resource must be destroyed, it returns an error instead.

Useful for:

- Production databases.
- Critical storage.
- Important infrastructure.
- Resources that are difficult to recover.

### Important

`prevent_destroy` is not a complete backup or security solution.

It protects against Terraform plans that attempt destruction while the lifecycle setting is present.

You still need:

- Backups.
- Access controls.
- Change management.
- Resource-level cloud protections where applicable.

---

# 3.3 I – ignore_changes

`ignore_changes` tells Terraform not to reconcile changes to specific attributes after creation.

Example:

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  tags = {
    Name = "web-server"
  }

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}
```

Terraform will ignore changes to the configured `tags` attribute.

---

## Ignore a Specific Tag

```hcl
lifecycle {
  ignore_changes = [
    tags["LastPatched"]
  ]
}
```

This can be useful if another system updates only that tag.

Examples of external systems:

- Patch management.
- Security automation.
- Asset management.
- Cloud governance tooling.
- FinOps tooling.

### Risk

Overusing `ignore_changes` can hide real infrastructure drift.

Use it only when another system intentionally owns the specified attribute.

---

# 3.4 R – replace_triggered_by

`replace_triggered_by` tells Terraform to replace a resource when another managed resource or attribute changes.

Example:

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  lifecycle {
    replace_triggered_by = [
      aws_security_group.web.id
    ]
  }
}
```

Conceptually:

```text
Referenced resource changes
          |
          v
Terraform marks dependent resource
for replacement
```

Use this when a change elsewhere must result in a clean replacement rather than an in-place update.

---

# 3.5 CPIR Summary

| Letter | Lifecycle Rule | Purpose |
|---|---|---|
| C | `create_before_destroy` | Create replacement before destroying old resource |
| P | `prevent_destroy` | Block accidental destruction |
| I | `ignore_changes` | Ignore selected external changes |
| R | `replace_triggered_by` | Replace resource when another object changes |

---

# 3.6 Combined Lifecycle Example

```hcl
resource "aws_instance" "application" {
  ami           = var.ami_id
  instance_type = var.instance_type

  tags = {
    Name = "application-server"
  }

  lifecycle {
    create_before_destroy = true

    ignore_changes = [
      tags["LastPatched"]
    ]
  }
}
```

This configuration:

1. Attempts to create a replacement before destroying the old instance.
2. Ignores external updates to the `LastPatched` tag.

---

# 4. Terraform Best Practices

# 4.1 Use terraform fmt

Format Terraform code:

```bash
terraform fmt
```

Check formatting:

```bash
terraform fmt -check
```

Benefits:

- Consistent code style.
- Easier reviews.
- Cleaner Git differences.
- Better team collaboration.

---

# 4.2 Use terraform validate

Run:

```bash
terraform validate
```

This validates the syntax and internal consistency of Terraform configuration.

Recommended workflow:

```bash
terraform fmt -check
terraform init
terraform validate
terraform plan
```

---

# 4.3 Always Review terraform plan

Never apply changes blindly.

Run:

```bash
terraform plan
```

Review:

- Resources being created.
- Resources being modified.
- Resources being destroyed.
- Replacement operations.
- Unexpected drift.

---

# 4.4 Save Plans for Controlled Apply

Create saved plan:

```bash
terraform plan -out=tfplan
```

Review:

```bash
terraform show tfplan
```

Apply exactly that saved plan:

```bash
terraform apply tfplan
```

This can be useful in controlled deployment pipelines.

---

# 4.5 Use Variables

Avoid hardcoding values repeatedly.

Bad:

```hcl
instance_type = "t3.micro"
```

Better:

```hcl
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}
```

Then:

```hcl
instance_type = var.instance_type
```

---

# 4.6 Use Variable Types

Example:

```hcl
variable "instance_count" {
  type = number
}

variable "enable_monitoring" {
  type = bool
}

variable "allowed_ports" {
  type = list(number)
}
```

Types improve validation and readability.

---

# 4.7 Use Variable Validation

Example:

```hcl
variable "environment" {
  type = string

  validation {
    condition = contains(
      ["dev", "test", "acc", "prd"],
      var.environment
    )

    error_message = "Environment must be dev, test, acc, or prd."
  }
}
```

This prevents invalid input from reaching the provider.

---

# 4.8 Use Meaningful Resource Names

Good:

```hcl
resource "aws_instance" "web_server" {
}
```

Less useful:

```hcl
resource "aws_instance" "server1" {
}
```

Terraform resource names should communicate purpose.

---

# 4.9 Add Descriptions

Example:

```hcl
variable "instance_type" {
  description = "EC2 instance type used by the application servers"
  type        = string
}
```

Descriptions improve readability and make modules easier to consume.

---

# 4.10 Pin Terraform and Provider Versions

Example:

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

Benefits:

- Predictable behavior.
- Controlled upgrades.
- Easier troubleshooting.
- Reduced risk of provider-breaking changes.

---

# 4.11 Commit .terraform.lock.hcl

Terraform generates:

```text
.terraform.lock.hcl
```

This file records selected provider versions and checksums.

It should normally be committed to Git.

Benefits:

- Consistent provider versions.
- Reproducible deployments.
- Better team consistency.

---

# 4.12 Do Not Commit Terraform State

Do not commit:

```text
terraform.tfstate
terraform.tfstate.backup
```

State can contain sensitive values.

Example `.gitignore`:

```gitignore
.terraform/
*.tfstate
*.tfstate.*
tfplan
crash.log
*.tfplan
```

Do not blindly ignore `.terraform.lock.hcl`.

---

# 4.13 Do Not Hardcode Secrets

Bad:

```hcl
db_password = "MyPassword123"
```

Preferred approaches include:

- AWS Secrets Manager.
- HashiCorp Vault.
- CI/CD secret storage.
- Secure environment variables.
- Other approved secrets-management platforms.

---

# 4.14 Sensitive Variables

Example:

```hcl
variable "db_password" {
  type      = string
  sensitive = true
}
```

This reduces accidental CLI display.

Important:

`sensitive = true` does **not** guarantee that the value is absent from Terraform state.

Protect the state itself.

---

# 4.15 Use Remote State for Team Environments

For shared environments:

- Store state remotely.
- Encrypt state.
- Restrict access.
- Enable versioning.
- Use appropriate state locking.
- Maintain separate state boundaries.

Avoid sharing a local `terraform.tfstate` among team members manually.

---

# 4.16 Use Modules

Reusable infrastructure components can include:

```text
modules/
├── ec2/
├── vpc/
├── security-group/
├── load-balancer/
└── database/
```

Benefits:

- Consistency.
- Reduced duplication.
- Easier maintenance.
- Reusable standards.

---

# 4.17 Separate Environments

Example:

```text
environments/
├── dev/
├── acc/
└── prd/
```

Each environment should ideally have appropriate separation for:

- State.
- Variables.
- Credentials.
- Resource sizing.
- Backend configuration.
- Access control.

---

# 4.18 Use tfvars Appropriately

Example:

```text
dev.tfvars
acc.tfvars
prd.tfvars
```

Run:

```bash
terraform plan -var-file=dev.tfvars
```

Example `dev.tfvars`:

```hcl
environment   = "dev"
instance_type = "t3.micro"
```

Do not store secrets in committed `.tfvars` files.

---

# 4.19 Tag Cloud Resources

Example:

```hcl
tags = {
  Environment = var.environment
  Application = "TerraformPractice"
  ManagedBy   = "Terraform"
  Owner       = "TAM"
}
```

Tags help with:

- Cost allocation.
- Ownership.
- Environment identification.
- Automation.
- Governance.
- Incident response.

---

# 4.20 Use Data Sources Instead of Hardcoding

Example:

```hcl
data "aws_availability_zones" "available" {
  state = "available"
}
```

Data sources allow Terraform to query existing information.

Other examples:

- AMIs.
- VPCs.
- Subnets.
- Security groups.
- Route 53 zones.
- IAM information.

---

# 4.21 Keep Terraform Files Organized

Typical project structure:

```text
terraform-project/
├── backend.tf
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── providers.tf
├── terraform.tfvars
└── modules/
```

Possible responsibility:

| File | Purpose |
|---|---|
| `main.tf` | Main resources |
| `variables.tf` | Input variables |
| `outputs.tf` | Output values |
| `providers.tf` | Provider configuration |
| `versions.tf` | Terraform/provider version constraints |
| `backend.tf` | Backend configuration |
| `terraform.tfvars` | Variable values |

Terraform does not require these exact filenames, but the convention improves readability.

---

# 4.22 Avoid Manual Infrastructure Changes

If Terraform owns a resource, avoid changing it manually unless required.

Manual changes create **drift**.

Detect drift with:

```bash
terraform plan
```

Terraform compares:

```text
Configuration
     +
State
     +
Actual provider infrastructure
```

and identifies differences.

---

# 4.23 Understand Terraform Drift

Drift occurs when real infrastructure differs from the desired Terraform configuration.

Example:

Terraform:

```hcl
instance_type = "t3.micro"
```

Someone manually changes AWS to:

```text
t3.small
```

The next:

```bash
terraform plan
```

can identify the difference.

Terraform may propose returning the infrastructure to `t3.micro`.

---

# 4.24 Use State Commands Carefully

Useful commands:

```bash
terraform state list
terraform state show <resource>
terraform state pull
terraform state mv <source> <destination>
terraform state rm <resource>
```

Before state manipulation:

1. Understand the objective.
2. Back up state.
3. Check the resource address.
4. Review dependencies.
5. Perform the change.
6. Run `terraform plan`.

---

# 4.25 Use CI/CD Validation

Recommended pipeline stages:

```text
Git Commit
    |
    v
terraform fmt -check
    |
    v
terraform init
    |
    v
terraform validate
    |
    v
Security / Policy Checks
    |
    v
terraform plan
    |
    v
Review / Approval
    |
    v
terraform apply
```

Production changes should generally require suitable approval controls.

---

# 4.26 Use Least Privilege

Terraform AWS credentials should not automatically have unlimited permissions.

Follow least privilege:

- Grant only required IAM actions.
- Separate deployment roles by environment.
- Protect production roles.
- Avoid long-lived static credentials where possible.
- Use IAM roles for EC2 or CI/CD when appropriate.

---

# 4.27 Protect Production Infrastructure

Production environments may use:

- `prevent_destroy`.
- Cloud-native deletion protection.
- Approval workflows.
- Restricted IAM roles.
- Separate AWS accounts.
- Remote state.
- State versioning.
- Backups.
- Monitoring.
- Audit logging.

Do not rely on one Terraform lifecycle rule as the only protection.

---

# 4.28 Keep Terraform Code in Git

Infrastructure as Code should be version controlled.

Typical workflow:

```bash
git checkout -b Day21-21-Aug-2026
git add .
git commit -m "Add Day 21 Terraform modules and backend practice"
git push -u origin Day21-21-Aug-2026
```

Benefits:

- History.
- Peer review.
- Rollback capability.
- Auditability.
- Collaboration.

---

# 5. Suggested Day 21 Lab Structure

```text
Day21-21-Aug-2026/
├── README.md
├── day21-practice.sh
│
├── 01-modules/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       └── ec2/
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
│
├── 02-remote-backend/
│   ├── main.tf
│   ├── backend.tf
│   └── backend.hcl
│
├── 03-lifecycle-cpir/
│   ├── main.tf
│   └── variables.tf
│
└── 04-best-practices/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── providers.tf
    ├── versions.tf
    └── .gitignore
```

---

# 6. Important Terraform Commands

## Initialization

```bash
terraform init
```

Reinitialize backend:

```bash
terraform init -reconfigure
```

Migrate state:

```bash
terraform init -migrate-state
```

---

## Modules

```bash
terraform get
terraform get -update
```

---

## Formatting

```bash
terraform fmt
terraform fmt -check
terraform fmt -recursive
```

---

## Validation

```bash
terraform validate
```

---

## Planning

```bash
terraform plan
```

Save plan:

```bash
terraform plan -out=tfplan
```

---

## Apply

```bash
terraform apply
```

Apply saved plan:

```bash
terraform apply tfplan
```

---

## State

```bash
terraform state list
terraform state show RESOURCE
terraform state pull
```

---

## Outputs

```bash
terraform output
```

Specific output:

```bash
terraform output <output_name>
```

---

## Providers

```bash
terraform providers
```

---

# 7. Quick Revision

## Terraform Module

A reusable collection of Terraform configuration.

```text
Root Module
    |
    +--> Child EC2 Module
    |
    +--> Child VPC Module
    |
    +--> Child Security Group Module
```

---

## Terraform Backend

Defines where Terraform stores state.

```text
Developer
    |
    v
Terraform
    |
    v
Remote Backend
    |
    v
terraform.tfstate
```

---

## CPIR

```text
C -> create_before_destroy
P -> prevent_destroy
I -> ignore_changes
R -> replace_triggered_by
```

### C

Create new resource before destroying old one.

### P

Prevent Terraform from destroying a protected resource.

### I

Ignore selected externally managed changes.

### R

Trigger resource replacement based on another change.

---

# 8. Interview / Revision Questions

1. What is a Terraform module?
2. What is the difference between a root module and child module?
3. Why should modules be used?
4. How do you call a local Terraform module?
5. How do you access a child module output?
6. What does `terraform get` do?
7. What is Terraform state?
8. Why should Terraform state normally not be committed to Git?
9. What is a Terraform backend?
10. What is the difference between local and remote state?
11. Why is remote state useful for teams?
12. How do you migrate state to a new backend?
13. What does `terraform init -reconfigure` do?
14. What is `create_before_destroy`?
15. When should `prevent_destroy` be used?
16. What are the risks of `ignore_changes`?
17. What does `replace_triggered_by` do?
18. What does CPIR stand for?
19. Why should provider versions be constrained?
20. Why should `.terraform.lock.hcl` be committed?
21. Why should secrets not be hardcoded?
22. What does `sensitive = true` actually protect?
23. What is Terraform drift?
24. How does `terraform plan` help detect drift?
25. Why are separate state files useful for DEV, ACC, and PRD?
26. Why should `terraform fmt` and `terraform validate` run in CI/CD?
27. What is the purpose of a saved plan?
28. Why should state commands be used carefully?
29. What are the benefits of tagging resources?
30. Why should Terraform credentials follow least privilege?

---

# 9. Day 21 Key Takeaways

- Modules provide reusable infrastructure building blocks.
- Root modules call child modules.
- Inputs are defined using variables.
- Outputs expose values from modules.
- Module versions should be controlled.
- Terraform state is critical to resource management.
- Remote backends are preferred for team environments.
- S3 can be used to store Terraform state in AWS.
- State must be encrypted and access controlled.
- State may contain sensitive information.
- CPIR provides important Terraform lifecycle controls.
- `create_before_destroy` can reduce replacement downtime.
- `prevent_destroy` protects important resources.
- `ignore_changes` should be used selectively.
- `replace_triggered_by` can force dependent replacement.
- Terraform code should be formatted and validated.
- Always review plans before applying.
- Provider and module versions should be constrained.
- `.terraform.lock.hcl` should normally be committed.
- Terraform state files should not be committed.
- Secrets should not be hardcoded.
- Use remote state, modules, variables, tags, CI/CD, and least privilege for production-quality Terraform.

---

# 10. Day 21 Practice Workflow

```bash
terraform version

aws sts get-caller-identity

terraform init

terraform fmt -recursive

terraform fmt -check -recursive

terraform validate

terraform providers

terraform get

terraform plan

terraform plan -out=tfplan

terraform show tfplan

terraform state list

terraform output
```

Apply only when the plan has been reviewed:

```bash
terraform apply tfplan
```

Destroy only when intentionally cleaning up lab infrastructure:

```bash
terraform destroy
```

---

# End of Day 21 Notes

**Topics completed:**

- Terraform Modules
- Terraform Remote Backends
- Terraform Lifecycle – CPIR
- Terraform Best Practices

