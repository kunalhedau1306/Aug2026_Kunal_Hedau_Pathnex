#!/bin/bash

export PS4='[ec2-user@ip-172-31-1-189 ~]$ '

set -x

echo "========================================================"
echo "Terraform Practice - Day 20"
echo "Environment: Amazon EC2 - Amazon Linux"
echo "========================================================"

echo
echo "=============================="
echo "Topic: Terraform Version"
echo "=============================="

terraform version

echo
echo "=============================="
echo "Topic: Current Directory"
echo "=============================="

pwd
ls -la

echo
echo "=============================="
echo "Topic: Terraform Initialization"
echo "=============================="

# Run from a directory containing Terraform *.tf files
terraform init

echo
echo "=============================="
echo "Topic: Terraform Formatting"
echo "=============================="

terraform fmt
terraform fmt -check

echo
echo "=============================="
echo "Topic: Terraform Validation"
echo "=============================="

terraform validate

echo
echo "=============================="
echo "Topic: Terraform Providers"
echo "=============================="

terraform providers

echo
echo "=============================="
echo "Topic: Terraform Plan"
echo "=============================="

terraform plan

echo
echo "=============================="
echo "Topic: Save Terraform Plan"
echo "=============================="

terraform plan -out=tfplan

echo
echo "=============================="
echo "Topic: Show Saved Plan"
echo "=============================="

terraform show tfplan

echo
echo "=============================="
echo "Topic: Terraform Apply"
echo "=============================="

echo "Run manually when ready:"
echo "terraform apply"

echo
echo "Or apply the saved plan:"
echo "terraform apply tfplan"

echo
echo "=============================="
echo "Topic: Terraform Outputs"
echo "=============================="

terraform output

echo
echo "=============================="
echo "Topic: Terraform State"
echo "=============================="

terraform state list

echo
echo "=============================="
echo "Topic: Terraform Show"
echo "=============================="

terraform show

echo
echo "=============================="
echo "Topic: Terraform Graph"
echo "=============================="

terraform graph

echo
echo "=============================="
echo "Topic: Terraform Workspace"
echo "=============================="

terraform workspace list
terraform workspace show

echo
echo "Practice manually:"
echo "terraform workspace new dev"
echo "terraform workspace select dev"
echo "terraform workspace list"

echo
echo "=============================="
echo "Topic: AWS Authentication"
echo "=============================="

aws sts get-caller-identity

echo
echo "=============================="
echo "Topic: Terraform State Resource"
echo "=============================="

echo "Use the actual address returned by:"
echo "terraform state list"

echo
echo "Example:"
echo "terraform state show aws_instance.web"

echo
echo "=============================="
echo "Topic: Terraform Import"
echo "=============================="

echo "Practice with an existing resource only:"
echo "terraform import aws_instance.web i-xxxxxxxxxxxxxxxxx"

echo
echo "=============================="
echo "Topic: Terraform Variable File"
echo "=============================="

echo "Example:"
echo "terraform plan -var-file=dev.tfvars"

echo
echo "=============================="
echo "Topic: Terraform Destroy"
echo "=============================="

echo "WARNING: This can destroy Terraform-managed infrastructure."

echo
echo "Run manually only when ready:"
echo "terraform destroy"

echo
echo "=============================="
echo "Topic: Important Terraform Concepts"
echo "=============================="

echo "Provider  = Connects Terraform to a platform/API"
echo "Resource  = Infrastructure object managed by Terraform"
echo "Variable  = Input to configuration"
echo "Output    = Value returned by configuration"
echo "State     = Terraform record of managed infrastructure"
echo "Module    = Reusable Terraform configuration"
echo "Plan      = Preview proposed changes"
echo "Apply     = Apply infrastructure changes"
echo "Destroy   = Remove managed infrastructure"
echo "Drift     = Difference between desired and actual state"

echo
echo "========================================================"
echo "Day 20 Terraform Practice Completed"
echo "========================================================"
