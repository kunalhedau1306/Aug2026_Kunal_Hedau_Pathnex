#!/bin/bash

export PS4='[ec2-user@ip-172-31-1-189 ~]$ '

set -x

echo "========================================================"
echo "Terraform Practice - Day 21"
echo "Date: 21-Aug-2026"
echo "Environment: Amazon EC2 - Amazon Linux"
echo "========================================================"

echo
echo "========================================================"
echo "Topic 1: Terraform Modules"
echo "========================================================"

echo
echo "=============================="
echo "What is a Terraform Module?"
echo "=============================="

echo "A Terraform module is a reusable collection of Terraform"
echo "configuration files."
echo
echo "Every Terraform configuration is itself a module."
echo
echo "Root Module  = Terraform files in the current directory"
echo "Child Module = Module called by another module"

echo
echo "=============================="
echo "Recommended Module Structure"
echo "=============================="

echo "Example structure:"
echo
echo "terraform-project/"
echo "|-- main.tf"
echo "|-- variables.tf"
echo "|-- outputs.tf"
echo "|-- versions.tf"
echo "|-- terraform.tfvars"
echo "|"
echo "|-- modules/"
echo "    |-- ec2/"
echo "        |-- main.tf"
echo "        |-- variables.tf"
echo "        |-- outputs.tf"

echo
echo "=============================="
echo "Create Module Directory"
echo "=============================="

echo "Practice manually:"
echo
echo "mkdir -p modules/ec2"
echo "touch modules/ec2/main.tf"
echo "touch modules/ec2/variables.tf"
echo "touch modules/ec2/outputs.tf"

echo
echo "=============================="
echo "Example EC2 Module"
echo "=============================="

echo
echo "modules/ec2/main.tf"
echo
cat <<'EOF'
resource "aws_instance" "this" {
  ami           = var.ami_id
  instance_type = var.instance_type

  tags = {
    Name = var.instance_name
  }
}
EOF

echo
echo "modules/ec2/variables.tf"
echo
cat <<'EOF'
variable "ami_id" {
  description = "AMI ID for EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "instance_name" {
  description = "EC2 instance name"
  type        = string
}
EOF

echo
echo "modules/ec2/outputs.tf"
echo
cat <<'EOF'
output "instance_id" {
  value = aws_instance.this.id
}

output "private_ip" {
  value = aws_instance.this.private_ip
}
EOF

echo
echo "=============================="
echo "Calling a Child Module"
echo "=============================="

echo
echo "Example root main.tf:"
echo
cat <<'EOF'
module "web_server" {
  source = "./modules/ec2"

  ami_id        = "ami-xxxxxxxxxxxxxxxxx"
  instance_type = "t3.micro"
  instance_name = "day21-web-server"
}
EOF

echo
echo "=============================="
echo "Module Outputs"
echo "=============================="

echo
cat <<'EOF'
output "web_instance_id" {
  value = module.web_server.instance_id
}

output "web_private_ip" {
  value = module.web_server.private_ip
}
EOF

echo
echo "=============================="
echo "Initialize Modules"
echo "=============================="

echo "terraform init"

echo
echo "Modules are downloaded/initialized during terraform init."

echo
echo "=============================="
echo "Terraform Get"
echo "=============================="

terraform get

echo
echo "To update already downloaded modules:"
echo "terraform get -update"

echo
echo "=============================="
echo "Validate Module Configuration"
echo "=============================="

terraform validate

echo
echo "=============================="
echo "Plan Module Resources"
echo "=============================="

terraform plan

echo
echo "========================================================"
echo "Topic 2: Terraform Remote Backends"
echo "========================================================"

echo
echo "=============================="
echo "What is a Terraform Backend?"
echo "=============================="

echo "Terraform backend determines where Terraform stores its"
echo "state and how Terraform performs state operations."

echo
echo "Local Backend:"
echo "terraform.tfstate stored on local filesystem"

echo
echo "Remote Backend:"
echo "terraform.tfstate stored in remote/shared storage"

echo
echo "Benefits:"
echo "- Centralized state"
echo "- Team collaboration"
echo "- Reduced risk of losing state"
echo "- Better security"
echo "- State locking support depending on backend"
echo "- Easier CI/CD integration"

echo
echo "=============================="
echo "Local Terraform State"
echo "=============================="

ls -l terraform.tfstate 2>/dev/null || true

echo
echo "Current backend initialization information:"
terraform version

echo
echo "=============================="
echo "Example AWS S3 Remote Backend"
echo "=============================="

cat <<'EOF'
terraform {
  backend "s3" {
    bucket = "kunal-terraform-state"
    key    = "day21/terraform.tfstate"
    region = "eu-west-1"

    encrypt = true
  }
}
EOF

echo
echo "IMPORTANT:"
echo "The S3 bucket must already exist before Terraform can use it"
echo "as a backend."

echo
echo "=============================="
echo "Backend Initialization"
echo "=============================="

echo "After adding or modifying backend configuration:"
echo
echo "terraform init"

echo
echo "If backend configuration changes:"
echo
echo "terraform init -reconfigure"

echo
echo "=============================="
echo "Migrate Existing State"
echo "=============================="

echo "To migrate an existing local state to a configured backend:"
echo
echo "terraform init -migrate-state"

echo
echo "Terraform will ask for confirmation before migrating state."

echo
echo "=============================="
echo "Backend Configuration File"
echo "=============================="

echo "Instead of hardcoding backend values, you can use:"
echo
echo "backend.hcl"

cat <<'EOF'
bucket = "kunal-terraform-state"
key    = "day21/terraform.tfstate"
region = "eu-west-1"
EOF

echo
echo "Then initialize using:"
echo
echo "terraform init -backend-config=backend.hcl"

echo
echo "=============================="
echo "Inspect Terraform State"
echo "=============================="

terraform state list

echo
echo "Pull current state:"
echo
echo "terraform state pull"

echo
echo "DO NOT manually modify remote Terraform state unless"
echo "you fully understand the consequences."

echo
echo "========================================================"
echo "Topic 3: Terraform Lifecycle - CPIR"
echo "========================================================"

echo
echo "Lifecycle rules control how Terraform creates, updates,"
echo "replaces, and destroys resources."

echo
echo "CPIR:"
echo "C = create_before_destroy"
echo "P = prevent_destroy"
echo "I = ignore_changes"
echo "R = replace_triggered_by"

echo
echo "--------------------------------------------------------"
echo "C - create_before_destroy"
echo "--------------------------------------------------------"

echo
echo "Normally Terraform may destroy an existing resource before"
echo "creating its replacement."

echo
echo "create_before_destroy creates the replacement first."

cat <<'EOF'
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  lifecycle {
    create_before_destroy = true
  }
}
EOF

echo
echo "Useful for:"
echo "- Reducing downtime"
echo "- Load-balanced application servers"
echo "- Resources where parallel replacement is possible"

echo
echo "--------------------------------------------------------"
echo "P - prevent_destroy"
echo "--------------------------------------------------------"

echo
echo "Protects important Terraform-managed resources from"
echo "accidental destruction."

cat <<'EOF'
resource "aws_instance" "critical_server" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  lifecycle {
    prevent_destroy = true
  }
}
EOF

echo
echo "Terraform will reject a plan that attempts to destroy"
echo "this resource."

echo
echo "Typical use cases:"
echo "- Production databases"
echo "- Critical infrastructure"
echo "- Important storage resources"

echo
echo "WARNING:"
echo "Removing the resource block from configuration can still"
echo "require careful state/configuration handling."

echo
echo "--------------------------------------------------------"
echo "I - ignore_changes"
echo "--------------------------------------------------------"

echo
echo "Terraform ignores changes to selected resource attributes."

cat <<'EOF'
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  tags = {
    Name = "day21-server"
  }

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}
EOF

echo
echo "Useful when:"
echo "- Another system updates specific attributes"
echo "- External automation manages selected values"
echo "- You intentionally do not want Terraform correcting them"

echo
echo "Ignore specific tag example:"

cat <<'EOF'
lifecycle {
  ignore_changes = [
    tags["LastPatched"]
  ]
}
EOF

echo
echo "Avoid excessive ignore_changes because it can hide"
echo "configuration drift."

echo
echo "--------------------------------------------------------"
echo "R - replace_triggered_by"
echo "--------------------------------------------------------"

echo
echo "Forces Terraform to replace a resource when another"
echo "resource or attribute changes."

cat <<'EOF'
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  lifecycle {
    replace_triggered_by = [
      aws_security_group.web.id
    ]
  }
}
EOF

echo
echo "Example concept:"
echo
echo "Security Group changes"
echo "        |"
echo "        v"
echo "Terraform replaces EC2 resource"

echo
echo "=============================="
echo "Combined Lifecycle Example"
echo "=============================="

cat <<'EOF'
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
EOF

echo
echo "========================================================"
echo "Topic 4: Terraform Best Practices"
echo "========================================================"

echo
echo "=============================="
echo "1. Format Terraform Code"
echo "=============================="

terraform fmt

echo
echo "Check formatting without changing files:"
terraform fmt -check

echo
echo "=============================="
echo "2. Validate Terraform Code"
echo "=============================="

terraform validate

echo
echo "=============================="
echo "3. Always Review Terraform Plan"
echo "=============================="

echo "terraform plan"

echo
echo "Never blindly run terraform apply in important environments."

echo
echo "=============================="
echo "4. Save Plan for Controlled Apply"
echo "=============================="

echo "terraform plan -out=tfplan"
echo "terraform show tfplan"
echo "terraform apply tfplan"

echo
echo "This ensures the reviewed plan is the one being applied."

echo
echo "=============================="
echo "5. Use Variables"
echo "=============================="

cat <<'EOF'
variable "environment" {
  description = "Deployment environment"
  type        = string
}
EOF

echo
echo "Avoid hardcoding environment-specific values."

echo
echo "=============================="
echo "6. Add Variable Validation"
echo "=============================="

cat <<'EOF'
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
EOF

echo
echo "=============================="
echo "7. Use Meaningful Resource Names"
echo "=============================="

echo "Good:"
echo 'resource "aws_instance" "web_server" {}'

echo
echo "Avoid:"
echo 'resource "aws_instance" "server1" {}'

echo
echo "=============================="
echo "8. Add Descriptions to Variables"
echo "=============================="

cat <<'EOF'
variable "instance_type" {
  description = "EC2 instance type used for application servers"
  type        = string
  default     = "t3.micro"
}
EOF

echo
echo "=============================="
echo "9. Specify Provider Versions"
echo "=============================="

cat <<'EOF'
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
EOF

echo
echo "Avoid uncontrolled provider upgrades."

echo
echo "=============================="
echo "10. Commit Terraform Lock File"
echo "=============================="

echo ".terraform.lock.hcl should normally be committed to Git."

echo
echo "It helps ensure consistent provider versions."

echo
echo "=============================="
echo "11. Do Not Commit Terraform State"
echo "=============================="

echo "Add to .gitignore:"

cat <<'EOF'
.terraform/
*.tfstate
*.tfstate.*
tfplan
crash.log
EOF

echo
echo "Terraform state can contain sensitive information."

echo
echo "=============================="
echo "12. Do Not Store Secrets in Terraform Files"
echo "=============================="

echo "Avoid:"
echo
echo 'db_password = "MyPassword123"'

echo
echo "Prefer:"
echo "- Secret management systems"
echo "- Environment variables"
echo "- CI/CD secret stores"
echo "- AWS Secrets Manager"
echo "- HashiCorp Vault"

echo
echo "=============================="
echo "13. Mark Sensitive Variables"
echo "=============================="

cat <<'EOF'
variable "db_password" {
  type      = string
  sensitive = true
}
EOF

echo
echo "NOTE:"
echo "sensitive = true hides normal CLI display but does not"
echo "remove the value from Terraform state."

echo
echo "=============================="
echo "14. Use Remote State"
echo "=============================="

echo "For team environments:"
echo "- Store state remotely"
echo "- Enable encryption"
echo "- Restrict IAM permissions"
echo "- Enable state locking where supported"
echo "- Enable bucket versioning/backups where appropriate"

echo
echo "=============================="
echo "15. Reuse Infrastructure With Modules"
echo "=============================="

echo "Example:"
echo
echo "modules/"
echo "|-- ec2/"
echo "|-- vpc/"
echo "|-- security-group/"
echo "|-- database/"

echo
echo "Avoid copying and pasting the same Terraform code."

echo
echo "=============================="
echo "16. Separate Environments"
echo "=============================="

echo "Example:"
echo
echo "environments/"
echo "|-- dev/"
echo "|-- acc/"
echo "|-- prd/"

echo
echo "Each environment can use separate:"
echo "- State"
echo "- Variables"
echo "- Credentials"
echo "- Resource sizing"

echo
echo "=============================="
echo "17. Tag AWS Resources"
echo "=============================="

cat <<'EOF'
tags = {
  Environment = var.environment
  Application = "TerraformPractice"
  ManagedBy   = "Terraform"
  Owner       = "TAM"
}
EOF

echo
echo "=============================="
echo "18. Use Data Sources"
echo "=============================="

echo "Avoid hardcoding values that can be discovered."

cat <<'EOF'
data "aws_availability_zones" "available" {
  state = "available"
}
EOF

echo
echo "=============================="
echo "19. Review State Before State Operations"
echo "=============================="

terraform state list

echo
echo "Useful commands:"
echo "terraform state show <resource>"
echo "terraform state mv <source> <destination>"
echo "terraform state rm <resource>"
echo "terraform state pull"

echo
echo "State commands can have major consequences."
echo "Take backups and understand the action first."

echo
echo "=============================="
echo "20. Use CI/CD Checks"
echo "=============================="

echo "Recommended automated checks:"
echo
echo "terraform fmt -check"
echo "terraform init"
echo "terraform validate"
echo "terraform plan"

echo
echo "Production apply should normally require approval."

echo
echo "========================================================"
echo "Day 21 Useful Terraform Commands"
echo "========================================================"

echo
echo "terraform init"
echo "terraform init -reconfigure"
echo "terraform init -migrate-state"
echo "terraform get"
echo "terraform get -update"
echo "terraform fmt"
echo "terraform fmt -check"
echo "terraform validate"
echo "terraform plan"
echo "terraform plan -out=tfplan"
echo "terraform show tfplan"
echo "terraform apply tfplan"
echo "terraform state list"
echo "terraform state show RESOURCE"
echo "terraform state pull"
echo "terraform output"
echo "terraform providers"

echo
echo "========================================================"
echo "Day 21 Revision"
echo "========================================================"

echo
echo "Terraform Module:"
echo "Reusable Terraform configuration."

echo
echo "Root Module:"
echo "Configuration from which Terraform is executed."

echo
echo "Child Module:"
echo "Reusable module called by another Terraform module."

echo
echo "Backend:"
echo "Defines where Terraform state is stored."

echo
echo "Remote Backend:"
echo "Stores Terraform state in remote/shared infrastructure."

echo
echo "CPIR Lifecycle:"
echo "C = create_before_destroy"
echo "P = prevent_destroy"
echo "I = ignore_changes"
echo "R = replace_triggered_by"

echo
echo "Terraform Best Practices:"
echo "- Use modules"
echo "- Use remote state"
echo "- Protect state"
echo "- Pin provider versions"
echo "- Use variables"
echo "- Validate variables"
echo "- Avoid hardcoded secrets"
echo "- Review plans before apply"
echo "- Commit .terraform.lock.hcl"
echo "- Do not commit state files"
echo "- Tag infrastructure"
echo "- Separate environments"
echo "- Use CI/CD validation"

echo
echo "========================================================"
echo "AWS Authentication Check"
echo "========================================================"

aws sts get-caller-identity

echo
echo "========================================================"
echo "Day 21 Terraform Practice Completed"
echo "Topics Covered:"
echo "1. Terraform Modules"
echo "2. Terraform Remote Backends"
echo "3. Terraform Lifecycle - CPIR"
echo "4. Terraform Best Practices"
echo "========================================================"
