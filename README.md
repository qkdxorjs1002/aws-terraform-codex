# AWS Terraform Codex

![AWS Terraform Codex Banner](./images/aws-terraform-codex-banner.svg)

English documentation. 한국어 문서는 [`README.kr.md`](./README.kr.md)를 참고하세요.

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

## Workflow

![AWS Terraform Codex Workflow](./images/aws-terraform-codex-workflow.svg)

Spec definition and Terraform deployment are executed in this sequence, with an explicit iteration loop before apply when plan/review feedback requires updates.

## Quick Start

### 1. Prerequisites

- Terraform `>= 1.5.0`
- AWS Provider `>= 5.33.0`
- AWS CLI profile configuration when needed
- `kubectl` installed when using `k8s_target_group_bindings`
- Python `>= 3.8` for Graphviz DOT -> D2 conversion script
- Graphviz (`dot`) when using `just graph`
- Optional: D2 CLI (`d2`) when rendering `graph.d2` into images

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
  environment: "dev"
  managed_by: "terraform-codex"
  maintainer: "platform-team@example.com"
  resources: []
```

Resources are declared as type-specific blocks inside `resources`:

```yaml
project:
  name: "my-project"
  profile: "my-aws-profile"
  region: "ap-northeast-2"
  environment: "dev"
  managed_by: "terraform-codex"
  maintainer: "platform-team@example.com"

  resources:
    - vpcs:
        - name: "main-vpc"
          cidr: "10.0.0.0/16"
          additional_cidr_blocks:
            - "10.1.0.0/16"
          tags:
            Service: "network"

    - subnets:
        - name: "private-a"
          vpc: "main-vpc"
          availability_zone: "ap-northeast-2a"
          cidr: "10.1.1.0/24"
```

Use this checklist while editing:

#### Core Rules

- References are name-based. For example, use `vpc: "main-vpc"` instead of raw IDs.
- If a referenced network resource is not managed in the current spec, Terraform resolves it from existing AWS resources by `Name` tag (security groups: group name lookup).
- `project.environment`, `project.managed_by`, and `project.maintainer` are required. They are applied globally via provider `default_tags` as `Environment`, `ManagedBy`, and `Maintainer`.
- `Name` tags are auto-derived from each resource logical identifier (`name`, `family`, `domain_name`, `alias`, and similar), so `tags.Name` usually should not be duplicated.
- Resources not in Terraform state are not modified or deleted, even if they already exist in AWS.
- For stricter guardrails, consider IAM/SCP controls that deny update/delete when `aws:ResourceTag/ManagedBy` does not match your project value.
- For `security_groups` rules with `source.type`/`destination.type = security-group`, `value` can be either a logical security group name or a literal `sg-...` ID.
- Security group rule identity and route-table associations use order-insensitive keys, so list reordering alone does not trigger resource address drift.

#### Feature Notes

- EKS Pod Identity: `role_arn` accepts either a literal ARN or a role name from `iam_roles`/`eks_irsa_roles`; the role trust principal must be `pods.eks.amazonaws.com` with `sts:AssumeRole` and `sts:TagSession`.
- Inline IAM policies: `iam_roles.inline_policies` and `eks_irsa_roles.inline_policies` accept either `document_json` or `document_url` (for example `https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/refs/heads/main/docs/install/iam_policy.json`).
- Launch templates AMI: `image_id` accepts either `ami-*` or an AMI name; AMI-name lookup can be tuned with `image_owners` (default `["self"]`) and `image_most_recent` (default `true`).
- Launch templates user data: priority is `user_data_base64` > `user_data_file` > inline `user_data`; `user_data_file` supports repo-relative or absolute paths.
- Launch templates interpolation: `vpc_security_groups`/`security_groups` support `templatestring()` with `${security_group["<name>"]}` and `${cluster["<eks-cluster-name>"].security_group_id}` (alias `${eks_cluster["<eks-cluster-name>"].security_group_id}`).
- EC2 Auto Scaling Groups: `ec2_auto_scaling_groups` can reference managed `ec2_launch_templates` by logical name and ALB target groups by logical name, while still accepting literal existing launch template names/IDs and target group ARNs.
- EC2 Auto Scaling instance refresh: `instance_refresh` supports rolling replacements with `triggers` and `preferences` such as `min_healthy_percentage` and `instance_warmup`.
- EKS add-ons interpolation: `eks_addons.configuration_values` supports the same cluster security-group interpolation, plus `${subnet["<name>"]}` and `${security_group["<name>"]}` maps.
- EKS add-on rollout phase: `eks_addons.provision_phase` supports `before_nodegroup`, `after_nodegroup`, and `auto` (default). `before_nodegroup` add-ons are applied before node groups, and `after_nodegroup` add-ons are applied after node groups.
- EKS add-on auto defaults: `auto` applies `vpc-cni`, `kube-proxy`, and `eks-pod-identity-agent` in `before_nodegroup`; other add-ons (for example `coredns`, `aws-ebs-csi-driver`) default to `after_nodegroup` to avoid replica readiness stalls before worker nodes exist.
- EKS dependency ordering: if a launch template references `cluster.*.security_group_id`, the cluster is resolved first so node groups can consume the launch template safely.
- EKS node groups: `launch_template.version` supports explicit versions plus `$Latest`/`$Default`, and symbolic versions are normalized to numeric versions to avoid persistent plan drift.
- EKS Helm with private ECR OCI (`oci://<account>.dkr.ecr.<region>.amazonaws.com/...`): module auto-fetches ECR auth and injects Helm repository credentials.
- EKS Helm jobs: `wait_for_jobs` is supported and recommended for charts like AWS Load Balancer Controller that rely on jobs for webhook readiness.
- EKS Helm image pull policy: `image_pull_policy` is a shorthand for Helm `set` key `image.pullPolicy` (ignored when `set` already includes `image.pullPolicy`).
- Kubernetes Services: `k8s_services` manages `Service` resources used by in-cluster traffic and TargetGroupBinding backends.
- Kubernetes TargetGroupBinding: `k8s_target_group_bindings` must set either `target_group_arn` or `target_group_name`; module applies `elbv2.k8s.aws/v1beta1` `TargetGroupBinding` via `kubectl` (`aws eks update-kubeconfig` + `kubectl apply/delete`) and expects AWS Load Balancer Controller CRDs and a backend Kubernetes Service with matching endpoints.

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

If you want to run one spec at a time while keeping state separated per spec, use Terraform workspaces:

```bash
terraform init
terraform workspace select spec-vdh-stg-01-network || terraform workspace new spec-vdh-stg-01-network
terraform plan  -var="spec_file=spec.vdh.stg.01.network.yaml"
terraform apply -var="spec_file=spec.vdh.stg.01.network.yaml"
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
├── scripts/
│   ├── graphviz_to_d2.py
│   └── graphviz_init_order.py
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
- ensure Security Group resources and SG logical-rule resources are applied before EKS modules
- manage Security Group rules with standalone `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule` resources to avoid reconciliation churn

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
- EC2 Auto Scaling Group
- ALB
- S3

### `modules/eks-extended`

Owns extended EKS functionality:

- EKS Fargate Profiles
- IRSA Roles
- Helm Releases
- Kubernetes Storage Classes
- Kubernetes Deployments
- Kubernetes Services
- Kubernetes TargetGroupBindings
- EKS Access Entries
- Pod Identity Associations
- Root orchestration passes EKS cluster/node group/add-on dependency signals into `eks-extended`, so Helm/Kubernetes operations are evaluated after cluster provisioning prerequisites.
- Helm/Kubernetes authentication uses `aws eks get-token` and includes `project.profile` when set.
- If EKS cluster creator admin bootstrap is disabled, define `eks_access_entries` for the Terraform execution principal before Helm/Kubernetes resources.
- Within `eks-extended`, access entries and access policy associations are applied before pod identity associations.
- EKS orchestration order is fixed as `eks_clusters -> eks_addons(before_nodegroup) -> eks_node_groups -> eks_addons(after_nodegroup) -> eks_extended`.

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

- `<project>-<environment>-vpc`
- `<project>-<environment>-private-a`
- `<project>-<environment>-eks-cluster`

### 2. Standardize Tags Early

Tag consistency becomes more important over time.

```yaml
tags:
  Service: "network"
  Owner: "platform-team"
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

# Import an existing resource into state
just import aws_s3_bucket.example my-bucket
just import aws_s3_bucket.example my-bucket spec.example.yaml
```

For workspace-aware execution (auto select/create workspace from spec filename):

```bash
# One-time Terraform init for workspace-based runs
just init

# Plan / Apply / Destroy with per-spec workspace + per-spec state
just plan-spec spec.vdh.stg.01.network.yaml
just apply-spec spec.vdh.stg.01.network.yaml
just destroy-spec spec.vdh.stg.01.network.yaml

# Import with per-spec workspace + per-spec state
just import-spec spec.vdh.stg.01.network.yaml aws_s3_bucket.example my-bucket
```

To export Terraform dependency graph outputs (`graph.d2`, `graph.svg`) without creating `graph.dot`:

```bash
# Generate graph files from default spec.yaml
just graph

# Generate graph files from a specific spec
just graph spec.example.yaml

# Pass extra terraform graph args when needed
just graph spec.example.yaml -draw-cycles

# Pipe terraform graph output directly to D2 conversion
TF_VAR_spec_file="spec.example.yaml" terraform graph | python3 scripts/graphviz_to_d2.py --output graph.d2
```

If you have D2 CLI installed, you can render the generated D2 file:

```bash
d2 graph.d2 graph.d2.svg
```

To summarize Terraform resource initialization order as CLI steps:

```bash
# Print to stdout
just graph-order

# Print with a specific spec file
just graph-order spec.example.yaml

# Save to a text file
just graph-order spec.example.yaml graph.init-order.txt

# Direct pipeline usage (without just)
TF_VAR_spec_file="spec.example.yaml" terraform graph | python3 scripts/graphviz_init_order.py
```

Example output:

```text
1. vpc['main']
2-1. subnet['private-a']
2-2. subnet['private-b']
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
