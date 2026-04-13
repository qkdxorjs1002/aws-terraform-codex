# AWS Terraform Codex

English documentation. For the Korean version, see [`README.kr.md` 한국어](./README.kr.md).

This repository defines AWS infrastructure from a spec-first workflow. Requirements are declared in `spec.yaml`, the root Terraform layer keeps orchestration thin, and domain modules own the actual resource implementation.

## Overview

- `spec.yaml` is the single source of input.
- The root module reads YAML and groups resources by type.
- Actual provisioning logic lives in domain modules.
- Explicit module contracts are preferred over hard-coded values.
- The default verification rule for Terraform changes is `terraform validate`.

## Why This Repository Is Structured This Way

Instead of editing Terraform logic everywhere, this project treats infrastructure requirements as data first and implementation second.

That gives us a few practical benefits:

- clearer separation between requirements and implementation
- reusable patterns across infrastructure domains
- a thinner root module that is easier to reason about
- a more predictable place to extend support for new resource types

## Quick Start

### 1. Prerequisites

- Terraform `>= 1.5.0`
- AWS Provider `>= 5.33.0`
- AWS CLI profile configuration when needed

The root module uses:

- default spec file: `spec.yaml`
- alternate spec file:
  - `-var="spec_file=..."` for `plan`, `apply`, `destroy`
  - `TF_VAR_spec_file=...` for `validate`

### 2. Create a Spec File

Start from the example:

```bash
cp spec.example.yaml spec.yaml
```

You can also use the template-oriented files as references:

- `spec.template.yaml`: schema-oriented template
- `spec.example.yaml`: working example
- `spec.schema.yaml`: structural schema reference

### 3. Edit the Spec

At minimum, fill in the project block:

```yaml
project:
  name: "my-project"
  profile: "my-aws-profile"
  region: "ap-northeast-2"
  env: "dev"
  resources: []
```

Resources are declared as type-specific blocks inside `resources`:

```yaml
project:
  name: "my-project"
  profile: "my-aws-profile"
  region: "ap-northeast-2"
  env: "dev"

  resources:
    - vpcs:
        - name: "main-vpc"
          cidr: "10.0.0.0/16"
          additional_cidr_blocks:
            - "10.1.0.0/16"
          tags:
            Environment: "dev"

    - subnets:
        - name: "private-a"
          vpc: "main-vpc"
          availability_zone: "ap-northeast-2a"
          cidr: "10.1.1.0/24"
```

References are name-based. For example, a subnet points to `vpc: "main-vpc"` instead of a raw VPC ID, and the root module resolves that logical name to the created resource ID.

### 4. Initialize and Validate

```bash
terraform init -backend=false
terraform validate
```

To validate with another spec file:

```bash
TF_VAR_spec_file=spec.example.yaml terraform validate
```

### 5. Plan or Apply When Needed

The working rule for this repository is to verify Terraform changes with `terraform validate`, but normal Terraform planning and apply flows still work when you need to provision infrastructure.

```bash
terraform plan
terraform apply
```

With an alternate spec:

```bash
terraform plan -var="spec_file=spec.example.yaml"
terraform apply -var="spec_file=spec.example.yaml"
```

## Working Method

This repository is easiest to maintain when changes follow this sequence.

### 1. Translate Requirements Into `spec.yaml`

Define the requirements first:

- what VPCs are needed
- how many public and private subnets are needed
- which resources are required, such as EKS, RDS, Lambda, or S3
- how resources reference one another

Turn that into `spec.yaml` before changing Terraform logic.

### 2. Add Implementation in the Right Domain Module

The root layer should not directly own most resource creation. Its main responsibilities are:

- loading `spec.yaml`
- grouping resources by type
- resolving logical names into real IDs
- calling domain modules

Actual AWS resource logic should live in the appropriate module.

### 3. Keep Root Orchestration Thin

When adding support for a new resource or feature:

- keep branching and wiring in the root layer
- move provisioning logic into a module
- keep inputs and outputs explicit
- avoid hard-coded external values inside modules

### 4. Validate Terraform Changes With `terraform validate`

The repository policy is simple:

- if Terraform code changes, verify with `terraform validate`

## Repository Layout

```text
.
├── justfile
├── main.tf
├── modules_domains.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── spec.template.yaml
├── spec.example.yaml
├── spec.schema.yaml
└── modules/
    ├── vpc/
    ├── subnet/
    ├── internet-gateway/
    ├── nat-gateway/
    ├── route-table/
    ├── security-group/
    ├── network-identity/
    ├── compute-storage/
    ├── eks-cluster/
    ├── eks-node-group/
    ├── eks-addon/
    ├── eks-extended/
    ├── edge-containers-observability/
    └── app-platform/
```

## Domain Responsibilities

### Root Module

The root module reads `spec.yaml` with `yamldecode`, expands resources by type, resolves references, and wires modules together.

Primary responsibilities:

- configure the AWS provider from `project.region` and `project.profile`
- transform the `resources` array into per-type maps
- resolve name-based references into resource IDs
- coordinate module dependencies

### `modules/network-identity`

Owns network and IAM oriented resources:

- IAM Roles
- Network ACLs
- VPC Endpoints
- VPC Flow Logs

### `modules/compute-storage`

Owns compute and storage resources:

- RDS
- EC2
- Launch Template
- ALB
- S3

### `modules/eks-extended`

Owns extended EKS functionality:

- EKS Fargate Profiles
- IRSA Roles
- Helm Releases
- Kubernetes Storage Classes
- EKS Access Entries
- Pod Identity Associations

### `modules/edge-containers-observability`

Owns edge, container, and observability concerns:

- WAF
- CloudFront
- ECS
- CloudWatch

### `modules/app-platform`

Owns platform-level application services:

- KMS
- Secrets Manager
- ECR
- Lambda
- API Gateway HTTP API
- Route53
- ACM
- DynamoDB
- ElastiCache
- SQS
- SNS
- EventBridge

## Spec Authoring Tips

### 1. Choose Stable Logical Names Early

This repository resolves many relationships by logical name, so consistent naming pays off.

- `<project>-<env>-vpc`
- `<project>-<env>-private-a`
- `<project>-<env>-eks-cluster`

### 2. Standardize Tags Early

Tag consistency becomes more important over time.

```yaml
tags:
  Name: "my-project-dev-vpc"
  Environment: "dev"
  ManagedBy: "terraform"
```

### 3. Start From the Example, Then Trim Down

It is usually faster and safer to copy `spec.example.yaml` and remove what you do not need than to start from a blank file.

### 4. Put Responsibility in Modules, Not the Root

When a new feature is needed:

- define the spec shape first
- keep type grouping and reference mapping in the root
- implement resource creation in the domain module

## Recommended Change Flow

1. Read the requirement and map it into `spec.yaml`.
2. Check whether the resource type is already supported in `spec.template.yaml` and the relevant modules.
3. If not supported, add the implementation in the correct domain module.
4. Keep root-level wiring minimal.
5. Run `terraform init -backend=false` and then `terraform validate`.

## Common Commands

```bash
# Initialize providers and modules
terraform init -backend=false

# Validate against the default spec.yaml
terraform validate

# Plan with a specific spec file
terraform plan -var="spec_file=spec.example.yaml"

# Apply with a specific spec file
terraform apply -var="spec_file=spec.example.yaml"
```

You can also use `justfile` shortcuts to run Terraform with a chosen spec file:

```bash
# Validate with default spec.yaml
just validate

# Validate with a specific spec file
just validate spec.example.yaml

# Plan / Apply / Destroy with a specific spec file
just plan spec.example.yaml
just apply spec.example.yaml
just destroy spec.example.yaml
```

## Collaboration Principles

- reflect requirements in `spec.yaml` first
- keep the root module thin
- preserve domain module boundaries
- keep module inputs and outputs explicit
- avoid hard-coded values
- verify Terraform changes with `terraform validate`

## Where to Start

If you are new to the repository, start with these files:

- `spec.template.yaml`
- `spec.example.yaml`
- `main.tf`

Then move into the relevant domain module for the implementation details.
