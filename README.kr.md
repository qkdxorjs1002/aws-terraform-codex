# AWS Terraform Codex

한국어 문서입니다. For English documentation, see [`README.md`](./README.md).

스펙 중심으로 AWS 인프라를 정의하고, Terraform 모듈이 이를 해석해 프로비저닝하는 저장소입니다.

이 프로젝트의 핵심은 간단합니다. 인프라 요구사항은 `spec.yaml`에 선언하고, 루트 모듈은 이를 읽어 얇게 오케스트레이션하며, 실제 리소스 생성 책임은 도메인별 모듈에 위임합니다.

## 한눈에 보기

- `spec.yaml`이 단일 입력 소스입니다.
- 루트 Terraform은 YAML을 읽고 리소스 타입별로 분류합니다.
- 실제 구현은 도메인 모듈로 분리되어 있습니다.
- 하드코딩보다 명시적인 입력/출력 계약을 우선합니다.
- Terraform 코드 변경 검증은 `terraform validate`를 기본으로 합니다.

## 왜 이렇게 구성했나요

이 저장소는 Terraform 코드를 여기저기 직접 수정하는 방식보다, 요구사항을 먼저 스펙으로 정리한 뒤 모듈이 이를 일관되게 해석하는 방식을 지향합니다.

이 접근의 장점은 다음과 같습니다.

- 요구사항과 구현의 경계가 분명합니다.
- 반복되는 인프라 패턴을 모듈로 재사용할 수 있습니다.
- 루트 구성이 얇아져 변경 영향도를 읽기 쉬워집니다.
- 새 리소스를 추가할 때 어디를 수정해야 하는지 명확합니다.

## 빠른 시작

### 1. 사전 준비

- Terraform `>= 1.5.0`
- AWS Provider `>= 5.33.0`
- 필요 시 AWS CLI 프로파일 설정

루트 모듈은 아래 설정을 사용합니다.

- 기본 스펙 파일: `spec.yaml`
- 대체 스펙 파일:
  - `plan`, `apply`, `destroy`는 `-var="spec_file=..."`
  - `validate`는 `TF_VAR_spec_file=...`

### 2. 스펙 파일 만들기

템플릿 또는 예제를 기준으로 시작합니다.

```bash
cp spec.example.yaml spec.yaml
```

또는 더 빈 틀에 가까운 템플릿을 기준으로 작성할 수 있습니다.

- `spec.template.yaml`: 스키마 중심 템플릿
- `spec.example.yaml`: 실사용 예시
- `spec.schema.yaml`: 구조 검증을 위한 스키마 참고

### 3. 스펙 수정하기

`spec.yaml`에서 최소한 아래 항목을 채웁니다.

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

리소스는 `resources` 배열 안에서 타입별 블록으로 선언합니다.

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

중요한 점은 참조가 이름 기반이라는 것입니다. 예를 들어 서브넷은 VPC의 실제 ID가 아니라 `vpc: "main-vpc"`처럼 논리 이름을 참조합니다. 루트 모듈이 이를 생성된 리소스 ID로 매핑합니다.
현재 스펙에서 관리하지 않는 네트워크 리소스를 참조한 경우에도 Terraform이 기존 AWS 리소스를 `Name` 태그 기준으로 조회해 실제 ID로 매핑합니다(보안 그룹은 SG name 기준 조회).

`project.environment`, `project.managed_by`, `project.maintainer`는 필수이며, 루트 provider의 `default_tags`로 모든 태깅 가능한 리소스에 전역 적용됩니다(`Environment`, `ManagedBy`, `Maintainer`).

`Name` 태그는 각 리소스의 논리 식별자(`name`, `family`, `domain_name`, `alias` 등)로 자동 적용되므로, 스펙마다 `tags.Name`를 반복 입력할 필요가 없습니다.

Terraform state에 없는 AWS 리소스는 이미 존재하더라도 Terraform이 수정/삭제하지 않습니다. 권한 레이어까지 강제하려면 `aws:ResourceTag/ManagedBy`가 프로젝트 값과 다를 때 update/delete를 거부하는 IAM/SCP 정책을 함께 사용하는 것을 권장합니다.

`security_groups` 규칙에서 `source.type`/`destination.type`이 `security-group`인 경우, `value`에는 같은 스펙 내 논리 SG 이름 또는 실제 SG ID(`sg-...`)를 사용할 수 있습니다.

EKS Pod Identity association의 `role_arn`은 리터럴 ARN뿐 아니라 role 이름(`iam_roles` 또는 `eks_irsa_roles`의 논리 이름)도 입력할 수 있습니다.
EKS Pod Identity에 사용하는 role의 IAM trust policy principal은 `pods.eks.amazonaws.com`이어야 하며 `sts:AssumeRole`, `sts:TagSession` 액션을 포함해야 합니다.
`iam_roles.inline_policies`와 `eks_irsa_roles.inline_policies`는 `document_json` 또는 `document_url` 중 하나로 지정할 수 있습니다(예: `https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/refs/heads/main/docs/install/iam_policy.json`).

EC2 Launch Template의 `image_id`는 AMI ID(`ami-*`)뿐 아니라 AMI 이름도 받을 수 있습니다. AMI 이름을 사용할 때는 `image_owners`(기본값: `["self"]`)와 `image_most_recent`(기본값: `true`)로 조회 동작을 제어할 수 있습니다.
Launch Template의 user data는 `user_data_file`로 파일 경로(저장소 루트 기준 상대경로 또는 절대경로)를 지정해 불러올 수 있습니다. 우선순위는 `user_data_base64` > `user_data_file` > 인라인 `user_data`입니다.
Launch Template의 `vpc_security_groups`/`security_groups`는 `templatestring()` 보간을 지원합니다. `${security_group["<name>"]}`와 `${cluster["<eks-cluster-name>"].security_group_id}`(별칭: `${eks_cluster["<eks-cluster-name>"].security_group_id}`)를 사용할 수 있습니다.
`eks_addons.configuration_values`의 `templatestring()` 보간도 `${cluster["<eks-cluster-name>"].security_group_id}`(별칭: `${eks_cluster["<eks-cluster-name>"].security_group_id}`)를 지원하며, `${subnet["<name>"]}`, `${security_group["<name>"]}` 같은 네트워크 맵과 함께 사용할 수 있습니다.
Launch Template에서 `cluster.*.security_group_id`를 참조하면 Terraform이 EKS 클러스터를 먼저 만든 뒤 Launch Template을 생성하므로, Node Group에서 안전하게 참조할 수 있습니다.
EKS Node Group의 `launch_template.version`은 명시 버전뿐 아니라 `$Latest`/`$Default`도 받을 수 있으며, 반복 plan diff 방지를 위해 내부적으로 숫자 버전으로 해석됩니다.
`eks_helm_releases`에서 private ECR OCI 저장소(`oci://<account>.dkr.ecr.<region>.amazonaws.com/...`)를 사용하면 모듈이 ECR 인증 토큰을 자동 조회해 Helm 저장소 인증 정보를 주입합니다.
`eks_helm_releases`는 `wait_for_jobs`를 지원하며(특히 AWS Load Balancer Controller 권장), webhook 준비를 완료하는 chart Job까지 Helm이 대기하도록 설정할 수 있습니다.
`eks_helm_releases`는 `image_pull_policy`를 Helm `set` 값 `image.pullPolicy`의 축약 필드로 지원합니다(`set`에 `image.pullPolicy`가 이미 있으면 무시).
`k8s_target_group_bindings`는 `target_group_arn` 또는 `target_group_name` 중 하나를 지정해야 합니다. 모듈은 Kubernetes `TargetGroupBinding`(`elbv2.k8s.aws/v1beta1`) 리소스를 생성하며, AWS Load Balancer Controller CRD가 설치되어 있어야 합니다.

### 4. 초기화 및 검증

모듈과 provider를 초기화한 뒤 검증합니다.

```bash
terraform init -backend=false
terraform validate
```

다른 스펙 파일을 쓰고 싶다면 다음처럼 지정할 수 있습니다.

```bash
TF_VAR_spec_file=spec.example.yaml terraform validate
```

### 5. 실제 배포가 필요할 때

이 저장소의 작업 원칙상 코드 변경 검증은 `terraform validate`를 기본으로 하지만, 실제 인프라 반영이 필요할 때는 일반적인 Terraform 흐름으로 진행할 수 있습니다.

```bash
terraform plan
terraform apply
```

대체 스펙 파일 사용 시:

```bash
terraform plan -var="spec_file=spec.example.yaml"
terraform apply -var="spec_file=spec.example.yaml"
```

스펙별로 state를 분리해서 하나씩 바로 실행하려면 Terraform workspace를 사용하세요.

```bash
terraform init
terraform workspace select spec-vdh-stg-01-network || terraform workspace new spec-vdh-stg-01-network
terraform plan  -var="spec_file=spec.vdh.stg.01.network.yaml"
terraform apply -var="spec_file=spec.vdh.stg.01.network.yaml"
```

## 작업 방법

이 저장소는 아래 순서로 작업할 때 가장 안정적으로 유지됩니다.

### 1. 요구사항을 먼저 `spec.yaml`로 번역합니다

예를 들어:

- 어떤 VPC가 필요한지
- 퍼블릭/프라이빗 서브넷이 몇 개인지
- EKS, RDS, Lambda, S3 같은 어떤 리소스가 필요한지
- 리소스 간 참조 관계가 무엇인지

이 정보를 먼저 스펙으로 정리합니다.

### 2. 구현은 도메인 모듈에 추가합니다

루트에서 리소스를 직접 많이 만들지 않습니다. 루트는 아래 역할에 집중합니다.

- `spec.yaml` 로드
- 리소스 타입별 분류
- 이름 기반 참조를 실제 ID로 해석
- 도메인 모듈 호출

실제 AWS 리소스 로직은 반드시 해당 도메인 모듈에서 구현하는 것을 권장합니다.

### 3. 루트 오케스트레이션은 얇게 유지합니다

새 리소스를 추가하더라도 아래 원칙을 지킵니다.

- 루트에는 분기와 연결만 둡니다.
- 리소스 생성 로직은 모듈로 이동합니다.
- 입력값은 명시적으로 받고, 출력값도 명시적으로 노출합니다.
- 모듈 내부에서 외부 값을 하드코딩하지 않습니다.

### 4. Terraform 변경 후에는 `terraform validate`로 확인합니다

이 저장소의 기본 검증 규칙은 단순합니다.

- Terraform 코드를 수정했다면 `terraform validate`만 수행합니다.

## 저장소 구조

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

## 도메인별 책임

### Root Module

루트 모듈은 `spec.yaml`을 읽고 `yamldecode`로 파싱한 뒤, 리소스 타입별로 펼쳐서 각 모듈에 연결합니다.

대표 책임:

- `project.region`, `project.profile` 기반 AWS provider 설정
- `resources` 배열을 타입별 맵으로 변환
- 이름 기반 참조를 실제 리소스 ID로 매핑
- 모듈 호출 및 의존성 순서 관리
- Security Group 리소스와 SG 논리 rule 리소스를 EKS 모듈보다 먼저 적용하도록 순서 보장
- Security Group rule은 `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule` 분리 리소스로 관리해 재조정(churn) 이슈를 방지

### `modules/network-identity`

주로 네트워크 및 IAM 계층을 담당합니다.

- IAM Roles
- Network ACLs
- VPC Endpoints
- VPC Flow Logs

### `modules/compute-storage`

컴퓨트와 스토리지 계층을 담당합니다.

- RDS
- EC2
- Launch Template
- ALB
- S3

### `modules/eks-extended`

EKS 확장 구성을 담당합니다.

- EKS Fargate Profiles
- IRSA Roles
- Helm Releases
- Kubernetes Storage Classes
- Kubernetes Deployments
- Kubernetes TargetGroupBindings
- EKS Access Entries
- Pod Identity Associations
- 루트 오케스트레이션은 EKS cluster/node group/add-on 의존 신호를 `eks-extended`로 전달하며, 이를 통해 Helm/Kubernetes 작업은 클러스터 프로비저닝 선행조건 이후에 평가됩니다.
- Helm/Kubernetes 인증은 `aws eks get-token`을 사용하며, `project.profile`이 설정된 경우 해당 프로파일을 포함해 호출합니다.
- EKS cluster creator admin bootstrap이 비활성화된 경우, Helm/Kubernetes 리소스보다 먼저 Terraform 실행 주체에 대한 `eks_access_entries`를 정의해야 합니다.
- `eks-extended` 내부에서는 access entry 및 access policy association이 pod identity association보다 먼저 적용됩니다.
- EKS 오케스트레이션 순서는 `eks_clusters -> eks_node_groups -> eks_addons -> eks_extended`로 고정됩니다.

### `modules/edge-containers-observability`

엣지, 컨테이너, 관측 영역을 담당합니다.

- WAF
- CloudFront
- ECS
- CloudWatch

### `modules/app-platform`

애플리케이션 플랫폼 계층을 담당합니다.

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

## 스펙 작성 팁

### 1. 논리 이름을 먼저 안정적으로 정하세요

이 저장소는 리소스 간 연결을 이름으로 많이 해석합니다. 따라서 아래처럼 일관된 논리 이름 규칙을 먼저 정해두면 관리가 쉬워집니다.

- `<project>-<environment>-vpc`
- `<project>-<environment>-private-a`
- `<project>-<environment>-eks-cluster`

### 2. 태그는 초기에 정리해두는 편이 좋습니다

운영 단계로 갈수록 태그 일관성이 중요해집니다.

```yaml
tags:
  Service: "network"
  Owner: "platform-team"
```

### 3. 예제를 먼저 복사한 뒤 줄여 나가면 빠릅니다

처음부터 빈 스펙을 작성하기보다 `spec.example.yaml`을 복사한 뒤 필요한 리소스만 남기는 방식이 더 안정적입니다.

### 4. 루트보다 모듈에 책임을 두세요

새 기능이 필요할 때 아래처럼 판단하면 좋습니다.

- 입력 스키마를 어떻게 받을지 먼저 결정
- 루트에서는 타입 분류와 매핑만 수행
- 실제 리소스 생성은 도메인 모듈에 구현

## 추천 작업 흐름

1. 요구사항을 읽고 `spec.yaml` 구조로 변환합니다.
2. 필요 리소스가 이미 지원되는지 `spec.template.yaml`과 각 모듈을 확인합니다.
3. 미지원 리소스라면 도메인에 맞는 모듈에 구현을 추가합니다.
4. 루트에서 최소한의 연결만 추가합니다.
5. `terraform init -backend=false` 후 `terraform validate`를 수행합니다.

## 자주 쓰는 명령

```bash
# 초기화
terraform init -backend=false

# 기본 spec.yaml 검증
terraform validate

# 특정 스펙 파일로 계획 확인
terraform plan -var="spec_file=spec.example.yaml"

# 특정 스펙 파일로 적용
terraform apply -var="spec_file=spec.example.yaml"
```

`justfile` 단축 명령으로도 스펙 파일을 지정해 실행할 수 있습니다.

```bash
# 기본 spec.yaml 검증
just validate

# 특정 스펙 파일 검증
just validate spec.example.yaml

# 특정 스펙 파일로 계획/적용/삭제
just plan spec.example.yaml
just apply spec.example.yaml
just destroy spec.example.yaml
```

workspace를 자동 선택/생성해서 spec별 state를 분리하려면:

```bash
# workspace 기반 실행 전 1회 초기화
just init

# spec 파일명 기반 workspace + 실행
just plan-spec spec.vdh.stg.01.network.yaml
just apply-spec spec.vdh.stg.01.network.yaml
just destroy-spec spec.vdh.stg.01.network.yaml
```

## 협업 원칙

- 요구사항은 먼저 `spec.yaml`에 반영합니다.
- 루트 모듈은 얇게 유지합니다.
- 모듈 경계를 흐리지 않습니다.
- 입력/출력 계약을 명시적으로 유지합니다.
- 하드코딩을 피합니다.
- Terraform 변경 검증은 `terraform validate`로 수행합니다.

## 마무리

처음 시작할 때는 아래 세 파일만 먼저 보면 충분합니다.

- `spec.template.yaml`
- `spec.example.yaml`
- `main.tf`

그 다음 필요한 도메인 모듈로 내려가면 전체 흐름을 빠르게 이해할 수 있습니다.
