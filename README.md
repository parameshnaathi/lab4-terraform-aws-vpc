# Lab 4 - AWS VPC Networking with Terraform

## Objective

Rebuild the AWS networking architecture created manually in Lab 3 using Terraform and reusable modules.

This lab focuses on:

- Terraform project structure
- Bootstrap configuration
- Remote state using S3
- Reusable network and security modules
- Environment-specific configuration
- VPC, subnets, route tables, Internet Gateway, NAT Gateway
- Security groups
- S3 Gateway Endpoint
- Terraform plan/apply workflow
- State management
- Drift detection
- Resource validation
- Safe cleanup

---

# Quick Command Reference

| Category | Command | Use | Simple Example |
|---|---|---|---|
| Terraform | `terraform version` | Check Terraform version | `terraform version` |
| AWS | `aws sts get-caller-identity` | Verify AWS identity | `aws sts get-caller-identity` |
| Terraform | `terraform init` | Initialize backend/providers/modules | `terraform init` |
| Terraform | `terraform init -reconfigure` | Reinitialize backend configuration | `terraform init -reconfigure` |
| Terraform | `terraform fmt` | Format Terraform files | `terraform fmt -recursive` |
| Terraform | `terraform validate` | Validate Terraform configuration | `terraform validate` |
| Terraform | `terraform plan` | Preview changes | `terraform plan` |
| Terraform | `terraform plan -refresh-only` | Detect external infrastructure changes | `terraform plan -refresh-only` |
| Terraform | `terraform apply` | Apply infrastructure changes | `terraform apply` |
| Terraform | `terraform destroy` | Destroy managed infrastructure | `terraform destroy` |
| Terraform | `terraform output` | Display root-module outputs | `terraform output` |
| Terraform | `terraform state list` | List managed state resources | `terraform state list` |
| Terraform | `terraform state show` | Inspect one state resource | `terraform state show module.network.aws_vpc.this` |
| Terraform | `terraform providers` | Show provider/module dependencies | `terraform providers` |
| Terraform | `terraform graph` | Show dependency graph | `terraform graph` |
| Terraform | `terraform import` | Import existing AWS resource | `terraform import aws_vpc.legacy vpc-xxxx` |
| AWS CLI | `aws ec2 describe-vpcs` | Verify VPC | `aws ec2 describe-vpcs --vpc-ids <vpc-id>` |
| AWS CLI | `aws ec2 describe-subnets` | Verify subnets | `aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>"` |

---

# Architecture

Lab 4 rebuilds the same network created manually in Lab 3, but now the entire architecture is defined as code.

```text
                           Internet
                              |
                       Internet Gateway
                              |
                 +------------+------------+
                 |                         |
             Public-A                  Public-B
           10.20.1.0/24              10.20.2.0/24
                 |
             NAT Gateway
                 |
          +------+------+
          |             |
       App-A           App-B
   10.20.11.0/24   10.20.12.0/24
          |             |
          +------+------+
                 |
          +------+------+
          |             |
        DB-A           DB-B
   10.20.21.0/24   10.20.22.0/24
```

VPC:

```text
10.20.0.0/16
```

The network is separated into three tiers:

```text
Public Tier
    |
Application Tier
    |
Database Tier
```

The main purpose of each tier is:

```text
Public Subnets
    -> Internet-facing infrastructure

Application Subnets
    -> Private workloads with outbound internet through NAT

Database Subnets
    -> Isolated workloads without direct internet routing
```

---

# Repository Structure

```text
lab4-terraform-aws-vpc/
│
├── bootstrap/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars
│
├── modules/
│   │
│   ├── network/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── security/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── environments/
│   └── dev/
│       ├── backend.tf
│       ├── main.tf
│       ├── providers.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       └── outputs.tf
│
├── .gitignore
└── README.md
```

The main relationship is:

```text
bootstrap/
    |
    | creates
    v
Terraform S3 State Bucket
    |
    | used by
    v
environments/dev/
    |
    | calls
    +--------------------------+
    |                          |
    v                          v
modules/network/          modules/security/
    |                          |
    v                          v
AWS Networking            AWS Security Groups
```

---

# Terraform Folder Responsibilities

## bootstrap/

Creates infrastructure Terraform itself needs before the main environment can use remote state.

```text
Local bootstrap Terraform
        |
        v
Create S3 state bucket
        |
        v
Main Terraform environment can use S3 backend
```

The bootstrap folder is a separate Terraform root module.

## modules/network/

Reusable child module responsible for AWS networking.

It creates:

```text
VPC
Subnets
Internet Gateway
Elastic IP
NAT Gateway
Route Tables
Routes
Route Table Associations
S3 Gateway Endpoint
```

## modules/security/

Reusable child module responsible for security groups.

It creates:

```text
Public Security Group
Application Security Group
Database Security Group
```

## environments/dev/

Main development environment root module.

It:

```text
Configures AWS Provider
        |
Reads dev values
        |
Uses S3 remote backend
        |
Calls network module
        |
Receives network outputs
        |
Calls security module
        |
Creates development environment
```

---

# Terraform File Responsibilities

Inside a Terraform module:

```text
variables.tf = INPUT
main.tf      = CREATE / CONFIGURE
outputs.tf   = OUTPUT
```

Example:

```text
variables.tf
    |
    | vpc_cidr
    v
main.tf
    |
    | creates VPC
    v
outputs.tf
    |
    | outputs vpc_id
    v
another module can use the VPC ID
```

Terraform reads all `.tf` files in the same directory as one module.

---

# Step 1 - Verify Terraform and AWS Access

```powershell
terraform version
aws sts get-caller-identity
```

Optional region configuration:

```powershell
$env:AWS_REGION="ap-south-1"
$env:AWS_DEFAULT_REGION="ap-south-1"
```

---

# Step 2 - Bootstrap Terraform State Bucket

Go to:

```powershell
cd bootstrap
```

## bootstrap/variables.tf

```hcl
variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket used for Terraform state"
  type        = string
}
```

## bootstrap/main.tf

```hcl
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  force_destroy = true

  tags = {
    Name        = var.state_bucket_name
    Environment = "lab"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

This creates:

```text
S3 State Bucket
    |
    +-- Versioning
    +-- Encryption
    +-- Public Access Block
```

## bootstrap/outputs.tf

```hcl
output "state_bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket
}
```

## bootstrap/terraform.tfvars

```hcl
region            = "ap-south-1"
state_bucket_name = "paramesh-arrise-tfstate-12345"
```

Using `terraform.tfvars` prevents Terraform from prompting for the bucket name every time.

If Terraform displays:

```text
var.state_bucket_name
Enter a value:
```

enter the actual bucket name, not `yes`.

---

# Step 3 - Initialize Bootstrap

```powershell
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
terraform output
```

---

# Step 4 - Network Module

The network module builds the AWS networking foundation.

## Why These Resources Are Required

```text
VPC
    = Network boundary

Subnet
    = Network segment

Route Table
    = Traffic direction

Internet Gateway
    = VPC internet connectivity

NAT Gateway
    = Outbound internet for private workloads

Security Group
    = Traffic permission

VPC Endpoint
    = Private access to AWS services
```

Each Terraform resource represents one AWS networking component.

---

# VPC

```hcl
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
}
```

The VPC defines the network boundary:

```text
10.20.0.0/16
```

---

# Subnets

Two Availability Zones and three tiers create six subnets:

```text
AZ-A                    AZ-B

Public-A                Public-B
App-A                   App-B
DB-A                    DB-B
```

Public:

```text
10.20.1.0/24
10.20.2.0/24
```

Application:

```text
10.20.11.0/24
10.20.12.0/24
```

Database:

```text
10.20.21.0/24
10.20.22.0/24
```

---

# Internet Gateway

The Internet Gateway connects the VPC to the internet.

```text
Public Route Table
0.0.0.0/0 -> Internet Gateway
```

Creating an Internet Gateway alone does not make a subnet public.

---

# Route Tables and Associations

A route table determines where traffic should go.

```text
Public:
0.0.0.0/0 -> IGW

Application:
0.0.0.0/0 -> NAT

Database:
No internet default route
```

Route-table associations determine which subnet uses which route table.

```text
Public-A -> Public Route Table
Public-B -> Public Route Table

App-A -> App Route Table
App-B -> App Route Table

DB-A -> DB Route Table
DB-B -> DB Route Table
```

---

# Elastic IP and NAT Gateway

Private application workloads should not require public IP addresses.

Their outbound internet path is:

```text
Private Application
        |
        v
App Route Table
        |
        v
NAT Gateway
        |
        v
Elastic IP
        |
        v
Public Subnet
        |
        v
Internet Gateway
        |
        v
Internet
```

Common uses include package downloads, OS updates, external APIs, and registry access.

---

# Database Route Table

The database route table intentionally has no default internet route.

```text
10.20.0.0/16 -> local
```

There is no:

```text
0.0.0.0/0
```

This keeps the database tier isolated from direct internet routing.

---

# S3 Gateway Endpoint

The S3 Gateway Endpoint allows private resources to reach S3 without using the NAT Gateway.

```text
App Subnet
    |
S3 Gateway Endpoint
    |
Amazon S3
```

---

# Step 5 - Network Module Variables and Outputs

Inputs:

```hcl
variable "name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "app_subnet_cidrs" {
  type = list(string)
}

variable "db_subnet_cidrs" {
  type = list(string)
}

variable "enable_nat_gateway" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
```

Important outputs:

```hcl
output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "app_subnet_ids" {
  value = aws_subnet.app[*].id
}

output "db_subnet_ids" {
  value = aws_subnet.db[*].id
}
```

---

# Step 6 - Security Module

The security module creates tier-specific security groups.

```text
Public SG
    |
    | TCP 8080
    v
Application SG
    |
    | TCP 5432
    v
Database SG
```

The security module receives the VPC ID from the network module.

```text
Network Module
     |
     v
output vpc_id
     |
     v
Dev Root Module
     |
     v
Security Module
```

## security/variables.tf

```hcl
variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
```

If the caller passes:

```hcl
name   = "arrise-dev"
vpc_id = module.network.vpc_id
tags   = local.common_tags
```

the child module must declare matching variables.

Otherwise Terraform reports:

```text
Unsupported argument
```

---

# Step 7 - Development Environment

Go to:

```powershell
cd environments\dev
```

This is the development root module.

## backend.tf

```hcl
terraform {
  backend "s3" {
    bucket       = "paramesh-arrise-tfstate-12345"
    key          = "arrise/dev/network/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

Important:

```text
Bootstrap creates the bucket.
Dev uses the bucket.
Dev does not manage the bucket.
```

## providers.tf

```hcl
provider "aws" {
  region = var.region
}
```

## terraform.tfvars

```hcl
region      = "ap-south-1"
environment = "dev"

vpc_cidr = "10.20.0.0/16"

availability_zones = [
  "ap-south-1a",
  "ap-south-1b"
]

public_subnet_cidrs = [
  "10.20.1.0/24",
  "10.20.2.0/24"
]

app_subnet_cidrs = [
  "10.20.11.0/24",
  "10.20.12.0/24"
]

db_subnet_cidrs = [
  "10.20.21.0/24",
  "10.20.22.0/24"
]
```

Flow:

```text
terraform.tfvars
       |
       v
dev variables.tf
       |
       v
dev main.tf
       |
       v
module variables
       |
       v
AWS resources
```

---

# Step 8 - Call the Network Module

```hcl
module "network" {
  source = "../../modules/network"

  name = "arrise-${var.environment}"

  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
  app_subnet_cidrs    = var.app_subnet_cidrs
  db_subnet_cidrs     = var.db_subnet_cidrs
  enable_nat_gateway  = true

  tags = local.common_tags
}
```

---

# Step 9 - Call the Security Module

```hcl
module "security" {
  source = "../../modules/security"

  name   = "arrise-${var.environment}"
  vpc_id = module.network.vpc_id
  tags   = local.common_tags
}
```

Terraform infers the dependency from:

```hcl
vpc_id = module.network.vpc_id
```

---

# Step 10 - Initialize, Format and Validate

```powershell
terraform init
terraform fmt -recursive
terraform validate
```

If backend configuration changed:

```powershell
terraform init -reconfigure
```

Expected validation:

```text
Success! The configuration is valid.
```

---

# Step 11 - Terraform Plan and Apply

```powershell
terraform plan
```

Common plan symbols:

```text
+    create
~    update in-place
-    destroy
-/+  destroy and then create replacement
```

Review the plan before applying.

Then:

```powershell
terraform apply
```

Only enter:

```text
yes
```

when Terraform asks for apply confirmation.

---

# Step 12 - Validate State

```powershell
terraform state list
```

Example:

```text
module.network.aws_vpc.this
module.network.aws_subnet.public[0]
module.network.aws_subnet.public[1]
module.network.aws_subnet.app[0]
module.network.aws_subnet.app[1]
module.network.aws_nat_gateway.this[0]
module.security.aws_security_group.app
module.security.aws_security_group.db
```

Inspect a resource:

```powershell
terraform state show module.network.aws_vpc.this
```

---

# Step 13 - Outputs

```powershell
terraform output
```

Typical outputs:

```text
vpc_id
public_subnet_ids
app_subnet_ids
db_subnet_ids
nat_gateway_id
app_security_group_id
db_security_group_id
```

---

# Step 14 - Terraform State Ownership

This lab contains two independent root modules.

```text
bootstrap/
    |
    | State A
    v
S3 State Bucket


environments/dev/
    |
    | State B
    v
VPC
Subnets
NAT
Routes
Security Groups
```

Terraform only detects drift for resources managed by the current state.

---

# Step 15 - Drift Detection

Example: manually change the bootstrap S3 bucket tag:

```text
ManagedBy = Terraform
```

to:

```text
ManagedBy = Terraform-dev
```

Run from:

```text
bootstrap/
```

```powershell
terraform plan
```

Terraform should detect:

```text
ManagedBy = Terraform-dev -> Terraform
```

Running the same plan from `environments/dev` will not detect the bucket drift because the development state does not own that bucket.

---

# Refresh-Only Plan

```powershell
terraform plan -refresh-only
```

Use this to inspect changes that occurred outside Terraform.

---

# Unexpected Replacement

If Terraform shows:

```text
-/+ destroy and then create replacement
```

inspect the cause before applying.

Example:

```text
bucket = "paramesh-arrise-tfstate-12345" -> "yes"
```

This indicates an incorrect input value.

Correct the variable and generate a new plan.

---

# Step 16 - count vs for_each

This lab uses `count` for simple lists.

```hcl
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)
}
```

State addresses:

```text
aws_subnet.public[0]
aws_subnet.public[1]
```

`for_each` can be used when stable logical keys are preferred.

```text
aws_subnet.public["public-a"]
aws_subnet.public["public-b"]
```

---

# Step 17 - Import Existing Infrastructure

Example:

```powershell
terraform import aws_vpc.legacy vpc-0123456789
```

Then:

```powershell
terraform plan
```

Reconcile Terraform configuration with the imported resource.

---

# Step 18 - .gitignore

```gitignore
.terraform/
*.tfstate
*.tfstate.*
*.tfplan
crash.log
crash.*.log

*.auto.tfvars
*.auto.tfvars.json

!.terraform.lock.hcl
```

Do not commit local Terraform state files.

---

# Main Traffic Paths

## Public Internet Traffic

```text
Internet
   |
Internet Gateway
   |
Public Route Table
   |
Public Subnet
```

## Private Application to Internet

```text
Application
    |
App Security Group
    |
App Subnet
    |
App Route Table
    |
NAT Gateway
    |
Elastic IP
    |
Public Route Table
    |
Internet Gateway
    |
Internet
```

## Application to Database

```text
Application
    |
App Security Group
    |
VPC Local Route
    |
DB Subnet
    |
DB Security Group
    |
Database
```

## Application to S3

```text
Application
    |
App Route Table
    |
S3 Gateway Endpoint
    |
Amazon S3
```

---

# Network Troubleshooting Flow

```text
Application / Process
        |
        v
Destination IP / DNS
        |
        v
Source Subnet
        |
        v
Route Table
        |
        v
Security Group
        |
        v
Network ACL
        |
        v
NAT / IGW / VPC Endpoint
        |
        v
Destination Security
        |
        v
VPC Flow Logs
```

---

# Cleanup

Destroy the development environment before destroying the bootstrap resources.

From:

```text
environments/dev/
```

run:

```powershell
terraform plan -destroy
terraform destroy
```

This removes the environment resources, including the NAT Gateway.

The NAT Gateway is billable while provisioned, so clean it up after the lab.

After the development environment is destroyed:

```powershell
cd ..\..\bootstrap
terraform destroy
```

Only destroy the bootstrap bucket after confirming no environment still depends on it.

---
