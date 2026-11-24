# Lab 5 - Terraform State, Drift and Safe Resource Management

## Objective

This lab focuses only on five Terraform concepts:

1. `terraform state list`
2. Drift detection
3. `moved` blocks
4. `prevent_destroy`
5. `removed` blocks and `terraform state rm`

The goal is to understand how Terraform tracks existing infrastructure and how to safely change or stop managing resources without accidentally recreating or deleting them.

This lab continues from the Terraform infrastructure created in Lab 4.

---

# Recommended Learning Order

Follow the concepts in this order:

```text
1. State List
      |
      v
Understand what Terraform manages

2. Drift
      |
      v
Understand differences between Terraform and AWS

3. Moved
      |
      v
Safely rename/refactor Terraform resources

4. Prevent Destroy
      |
      v
Protect critical resources from accidental deletion

5. Removed / State RM
      |
      v
Stop Terraform from managing a resource without deleting it
```

This order is important because each concept builds on the previous one.

---

# Quick Command Reference

| Concept | Command / Configuration | Purpose | Simple Example |
|---|---|---|---|
| State | `terraform state list` | List resources Terraform manages | `terraform state list` |
| State | `terraform state show` | Inspect one managed resource | `terraform state show module.network.aws_vpc.this` |
| Drift | `terraform plan` | Detect differences between code and AWS | `terraform plan` |
| Drift | `terraform plan -refresh-only` | Review external changes | `terraform plan -refresh-only` |
| Moved | `moved {}` | Rename Terraform resource address safely | `from = old` / `to = new` |
| Protection | `prevent_destroy = true` | Stop Terraform from destroying a critical resource | VPC lifecycle |
| Removed | `removed {}` | Stop managing resource without deleting it | `destroy = false` |
| State | `terraform state rm` | Manually remove resource from state | `terraform state rm <address>` |

---

# Lab Architecture

Lab 5 does not create a new AWS architecture.

It uses the same infrastructure created in Lab 4.

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
        DB-A           DB-B
   10.20.21.0/24   10.20.22.0/24
```

Lab 4 was about creating infrastructure.

Lab 5 is about safely managing existing Terraform infrastructure.

```text
Lab 4
    =
Create infrastructure

Lab 5
    =
Understand and safely operate Terraform state
```

---

# Repository

Continue using:

```text
lab4-terraform-aws-vpc/
│
├── bootstrap/
│
├── modules/
│   ├── network/
│   └── security/
│
└── environments/
    └── dev/
```

You do not need to create a new VPC or new Terraform project for this lab.

Run most Lab 5 commands from:

```text
lab4-terraform-aws-vpc/environments/dev/
```

---

# Step 1 - Start With a Clean Terraform Plan

Go to:

```powershell
cd C:\Users\PN017156\Downloads\Courses\DevOps-Projects\sre-devops-labs\lab4-terraform-aws-vpc\environments\dev
```

Run:

```powershell
terraform init
terraform validate
terraform plan
```

Before starting the exercises, you ideally want:

```text
No changes.

Your infrastructure matches the configuration.
```

This gives us a known-good starting point.

---

# Concept 1 - Terraform State List

## What Is Terraform State?

Terraform state keeps the relationship between:

```text
Terraform Resource Address
        |
        v
Actual AWS Resource
```

Example:

```text
module.network.aws_vpc.this
        |
        v
vpc-0123456789abcdef
```

Terraform uses this relationship to understand:

```text
"This VPC already exists.

I manage it.

I should update it instead of creating another VPC."
```

---

# Step 2 - List Managed Resources

Run:

```powershell
terraform state list
```

Example output:

```text
module.network.aws_eip.nat[0]
module.network.aws_internet_gateway.this
module.network.aws_nat_gateway.this[0]
module.network.aws_route.app_internet[0]
module.network.aws_route.public_internet
module.network.aws_route_table.app
module.network.aws_route_table.db
module.network.aws_route_table.public
module.network.aws_subnet.app[0]
module.network.aws_subnet.app[1]
module.network.aws_subnet.db[0]
module.network.aws_subnet.db[1]
module.network.aws_subnet.public[0]
module.network.aws_subnet.public[1]
module.network.aws_vpc.this
module.security.aws_security_group.app
module.security.aws_security_group.db
module.security.aws_security_group.public
```

The exact list may differ slightly depending on your Lab 4 configuration.

---

# How to Read a Terraform Address

Example:

```text
module.network.aws_subnet.app[0]
```

Break it into:

```text
module.network
    |
    v
network child module


aws_subnet
    |
    v
AWS resource type


app
    |
    v
Terraform resource name


[0]
    |
    v
First resource created using count
```

Another example:

```text
module.security.aws_security_group.db
```

means:

```text
security module
    |
    v
AWS Security Group
    |
    v
Terraform resource name = db
```

---

# Step 3 - Inspect One Resource

Run:

```powershell
terraform state show module.network.aws_vpc.this
```

Example information:

```text
cidr_block           = "10.20.0.0/16"
enable_dns_hostnames = true
enable_dns_support   = true
id                   = "vpc-..."
```

For an indexed subnet:

```powershell
terraform state show 'module.network.aws_subnet.app[0]'
```

Use `state show` when you want to understand exactly what Terraform currently knows about one resource.

---

# Key State Concept

Think of state as Terraform's inventory.

```text
Terraform Configuration
        |
        v
Terraform State
        |
        v
AWS Resources
```

If the resource is in state:

```text
Terraform manages it
```

If the resource is not in state:

```text
Terraform does not currently manage that object
```

This concept is important before learning drift, moved blocks, or state removal.

---

# Concept 2 - Terraform Drift

## What Is Drift?

Drift means the real AWS resource no longer matches the Terraform configuration because somebody or something changed it outside Terraform.

```text
Terraform Configuration
        |
        v
Desired State

        !=

AWS
        |
        v
Actual State

        =
      DRIFT
```

For this lab, use only the following two scenarios.

---

# Drift Scenario 1 - Manual Tag Change

Use the Terraform-managed VPC.

In AWS Console:

```text
VPC
  |
  v
Your Lab 4 VPC
  |
  v
Tags
```

Change:

```text
Owner = DevOps
```

to:

```text
Owner = Platform-Team
```

Now from:

```text
environments/dev/
```

run:

```powershell
terraform plan
```

Terraform should detect something similar to:

```text
~ "Owner" = "Platform-Team" -> "DevOps"
```

Meaning:

```text
AWS currently:
Owner = Platform-Team

Terraform wants:
Owner = DevOps
```

Restore it with:

```powershell
terraform apply
```

Then verify:

```powershell
terraform plan
```

Expected:

```text
No changes.
```

---

# Drift Scenario 2 - Manual Security Group Rule Change

Use the application security group created by Terraform.

In AWS Console:

```text
EC2
  |
  v
Security Groups
  |
  v
Application Security Group
```

Add a temporary inbound rule manually, for example:

```text
Type: Custom TCP
Port: 8080
Source: Your IP or another safe test source
```

Do not use broad production-style access such as `0.0.0.0/0` for this exercise.

Now run:

```powershell
terraform plan
```

Terraform should detect that AWS contains an inbound rule that is not present in Terraform configuration.

The key idea is:

```text
Terraform configuration
        |
        | expected SG rules
        v

AWS Security Group
        |
        | manually added rule
        v

Different
        |
        v
Drift detected
```

If the plan is safe, run:

```powershell
terraform apply
```

Terraform should remove the manually added rule and return the security group to the configuration defined in code.

Verify:

```powershell
terraform plan
```

Expected:

```text
No changes.
```

---

# Drift Commands to Remember

```powershell
terraform plan
```

Use to detect differences and see what Terraform wants to change.

```powershell
terraform plan -refresh-only
```

Use when you only want to inspect changes that happened outside Terraform.

---

# Drift Mental Model

```text
Manual AWS Change
      |
      v
AWS != Terraform
      |
      v
terraform plan
      |
      v
Drift detected
      |
      v
Review
      |
      v
terraform apply
      |
      v
AWS matches Terraform again
```

---

# Concept 3 - Terraform moved Block

## Why Do We Need moved?

Suppose we have this resource:

```hcl
resource "aws_security_group" "app" {
  ...
}
```

Terraform knows it using this address:

```text
module.security.aws_security_group.app
```

Now suppose we want a clearer name:

```hcl
resource "aws_security_group" "application" {
  ...
}
```

To a human, this looks like a simple rename.

But Terraform sees:

```text
Old address disappeared:

aws_security_group.app


New address appeared:

aws_security_group.application
```

Without additional information, Terraform may think:

```text
Destroy old resource
        +
Create new resource
```

That is not what we want.

The actual AWS Security Group should remain the same.

---

# Step 8 - Rename the Application Security Group

Open:

```text
modules/security/main.tf
```

Find:

```hcl
resource "aws_security_group" "app" {
```

Change it to:

```hcl
resource "aws_security_group" "application" {
```

Now update references.

For example, if the DB security group contains:

```hcl
security_groups = [aws_security_group.app.id]
```

change it to:

```hcl
security_groups = [aws_security_group.application.id]
```

Also check:

```text
modules/security/outputs.tf
```

If you have:

```hcl
output "app_security_group_id" {
  value = aws_security_group.app.id
}
```

change it to:

```hcl
output "app_security_group_id" {
  value = aws_security_group.application.id
}
```

---

# Step 9 - Add a moved Block

Inside the security module, add:

```hcl
moved {
  from = aws_security_group.app
  to   = aws_security_group.application
}
```

This tells Terraform:

```text
The old resource

aws_security_group.app

has not been deleted.

It is now known as

aws_security_group.application
```

---

# Step 10 - Validate the Move

Return to:

```text
environments/dev/
```

Run:

```powershell
terraform fmt -recursive
terraform validate
terraform plan
```

Terraform should understand:

```text
Old Terraform Address
        |
        v
aws_security_group.app

        |
      moved
        |

        v
aws_security_group.application
```

The AWS Security Group itself should not need to be recreated just because the Terraform name changed.

Apply the safe move:

```powershell
terraform apply
```

---

# Step 11 - Verify State After Move

Run:

```powershell
terraform state list
```

Before:

```text
module.security.aws_security_group.app
```

After:

```text
module.security.aws_security_group.application
```

The important idea:

```text
Terraform address changed
        |
        v
AWS resource stayed the same
```

---

# moved Mental Model

Without `moved`:

```text
Rename resource in code
        |
        v
Terraform may see
OLD resource removed
NEW resource added
        |
        v
Potential destroy/create
```

With `moved`:

```text
Rename resource in code
        |
        v
moved block
        |
        v
Terraform transfers state address
        |
        v
Same AWS resource remains
```

---

# Concept 4 - prevent_destroy

## Why Use prevent_destroy?

Some resources are dangerous to delete accidentally.

Examples:

```text
Production database
Critical VPC
Stateful storage
Shared infrastructure
```

Terraform supports a lifecycle rule:

```hcl
lifecycle {
  prevent_destroy = true
}
```

It acts as a Terraform-side protection against planned destruction.

---

# Step 12 - Protect the VPC

Open:

```text
modules/network/main.tf
```

Find:

```hcl
resource "aws_vpc" "this" {
```

Temporarily add:

```hcl
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  lifecycle {
    prevent_destroy = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-vpc"
    }
  )
}
```

---

# Step 13 - Test the Protection

From:

```text
environments/dev/
```

run:

```powershell
terraform plan -destroy
```

Terraform should stop the plan because the VPC is protected by:

```text
prevent_destroy = true
```

The idea is:

```text
Terraform wants:
Destroy VPC

        |
        v

lifecycle.prevent_destroy

        |
        v

BLOCK
```

---

# Important Limitation

`prevent_destroy` does not mean:

```text
The AWS resource can never be deleted
```

It means:

```text
Terraform will reject a destroy plan
while prevent_destroy is active
in the configuration
```

It is a Terraform guardrail.

---

# Step 14 - Remove the Temporary Guardrail

After testing, remove:

```hcl
lifecycle {
  prevent_destroy = true
}
```

Then:

```powershell
terraform fmt -recursive
terraform validate
terraform plan
```

The environment should return to normal.

We remove the guardrail in this lab because later cleanup may require:

```powershell
terraform destroy
```

---

# prevent_destroy Mental Model

```text
Critical Terraform Resource
        |
        v
prevent_destroy = true
        |
        v
Terraform destroy requested
        |
        v
BLOCKED
```

---

# Concept 5 - removed Block and terraform state rm

This concept answers an important question:

> How do I stop Terraform from managing a resource but keep the actual AWS resource?

That is different from destroy.

---

# Destroy vs Remove From State

## Terraform Destroy

```text
Terraform State
     X

AWS Resource
     X
```

Terraform stops managing the resource because the resource is actually deleted.

---

## Remove From Terraform Management

```text
Terraform State
     X

AWS Resource
     ✓
```

The AWS resource stays.

Terraform simply stops tracking it.

---

# Why Would We Do This?

Possible reasons include:

```text
Resource ownership moves to another Terraform project

Another team takes ownership

Resource is moving to another management system

Terraform configuration is being reorganized
```

For this lab, the goal is only to understand the behavior.

---

# Step 15 - Choose a Safe Lab Resource

Do not practice state removal on:

```text
VPC
NAT Gateway
Internet Gateway
Core route tables
```

because other resources depend on them.

Use a simple lab security group if available.

For example:

```text
module.security.aws_security_group.public
```

First verify it exists:

```powershell
terraform state list
```

---

# Option A - removed Block

The declarative method is a `removed` block.

Suppose the resource currently exists in configuration as:

```hcl
resource "aws_security_group" "public" {
  ...
}
```

To stop managing it without destroying it, the configuration can be changed to a `removed` block.

Concept:

```hcl
removed {
  from = aws_security_group.public

  lifecycle {
    destroy = false
  }
}
```

Because our security group is inside the security module, the `removed` block belongs in that module and refers to the local resource address.

The important line is:

```hcl
destroy = false
```

Meaning:

```text
Remove from Terraform management
        |
        v
Do NOT delete the AWS resource
```

---

# Step 16 - Plan Before Applying

Run:

```powershell
terraform plan
```

Review carefully.

The expected behavior is:

```text
Terraform stops managing the resource
        |
        v
AWS resource remains
```

Then:

```powershell
terraform apply
```

Afterwards:

```powershell
terraform state list
```

The resource should no longer appear in Terraform state.

---

# Important After a removed Block

If Terraform no longer manages the resource:

```text
Terraform will no longer:

Update it
Detect its drift
Delete it
Manage its configuration
```

AWS still contains the resource.

---

# Option B - terraform state rm

There is also a direct state command:

```powershell
terraform state rm <resource-address>
```

Example conceptually:

```powershell
terraform state rm 'module.security.aws_security_group.public'
```

This tells Terraform:

```text
Forget this resource
```

but:

```text
Do not delete the AWS resource
```

---

# Important Warning About state rm

Suppose:

```text
Terraform code still contains:

resource "aws_security_group" "public"
```

but you run:

```powershell
terraform state rm 'module.security.aws_security_group.public'
```

Now Terraform sees:

```text
Configuration says:
Public SG should exist

State says:
Public SG does not exist
```

So the next:

```powershell
terraform plan
```

may propose:

```text
Create a new Public SG
```

even though the original SG still exists in AWS.

This can cause duplicate-name or ownership problems.

That is why state operations must be deliberate.

---

# removed vs state rm

Both can make Terraform forget a resource.

The difference in learning terms:

```text
removed block
    =
Declarative
Written in Terraform configuration
Visible in code review
Plan/apply workflow


terraform state rm
    =
Imperative
Direct command against Terraform state
Immediate state operation
```

For normal planned refactoring, the declarative approach is easier to review and document.

For manual state correction, `terraform state rm` may still be useful.

---

# removed / state rm Mental Model

```text
AWS Resource
     |
     | currently managed
     v
Terraform State
     |
     +-----------------------+
     |                       |
     v                       v
removed block           state rm
     |                       |
     +-----------+-----------+
                 |
                 v
Terraform forgets resource
                 |
                 v
AWS resource remains
```

---

# Final Verification

After completing the exercises, verify the environment carefully.

Run:

```powershell
terraform validate
```

Then:

```powershell
terraform state list
```

Then:

```powershell
terraform plan
```

Your final objective is to understand why each resource appears or does not appear in state.

Do not blindly apply a plan that contains unexpected:

```text
destroy
replacement
new duplicate resource
```

---
