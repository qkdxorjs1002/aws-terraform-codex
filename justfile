set shell := ["zsh", "-lc"]

# Usage:
#   just validate                 # uses spec.yaml
#   just validate spec.example.yaml
#   just plan spec.example.yaml
#   just apply spec.example.yaml
#   just destroy spec.example.yaml
#   just graph spec.example.yaml
#   just graph-order spec.example.yaml
#
# Workspace-aware shortcuts:
#   just plan-spec spec.vdh.stg.01.network.yaml
#   just apply-spec spec.vdh.stg.01.network.yaml
#   just destroy-spec spec.vdh.stg.01.network.yaml

default:
  @just --list

init:
  terraform init

use-workspace spec_file="spec.yaml":
  @base=$(basename "{{spec_file}}"); \
  ws=$(echo "$base" | sed -E 's/\\.(ya?ml)$//' | sed -E 's/[^A-Za-z0-9_-]+/-/g'); \
  terraform workspace select "$ws" >/dev/null 2>&1 || terraform workspace new "$ws"

validate spec_file="spec.yaml":
  TF_VAR_spec_file="{{spec_file}}" terraform validate

graph spec_file="spec.yaml" *args:
  TF_VAR_spec_file="{{spec_file}}" terraform graph {{args}} | tee >(python3 scripts/graphviz_to_d2.py --output graph.d2)

graph-order spec_file="spec.yaml" output="-" *args:
  TF_VAR_spec_file="{{spec_file}}" terraform graph {{args}} | python3 scripts/graphviz_init_order.py --output "{{output}}"

plan spec_file="spec.yaml" *args:
  terraform plan -var="spec_file={{spec_file}}" {{args}}

apply spec_file="spec.yaml" *args:
  terraform apply -var="spec_file={{spec_file}}" {{args}}

destroy spec_file="spec.yaml" *args:
  terraform destroy -var="spec_file={{spec_file}}" {{args}}

plan-spec spec_file="spec.yaml" *args:
  @base=$(basename "{{spec_file}}"); \
  ws=$(echo "$base" | sed -E 's/\\.(ya?ml)$//' | sed -E 's/[^A-Za-z0-9_-]+/-/g'); \
  terraform workspace select "$ws" >/dev/null 2>&1 || terraform workspace new "$ws"; \
  terraform plan -var="spec_file={{spec_file}}" {{args}}

apply-spec spec_file="spec.yaml" *args:
  @base=$(basename "{{spec_file}}"); \
  ws=$(echo "$base" | sed -E 's/\\.(ya?ml)$//' | sed -E 's/[^A-Za-z0-9_-]+/-/g'); \
  terraform workspace select "$ws" >/dev/null 2>&1 || terraform workspace new "$ws"; \
  terraform apply -var="spec_file={{spec_file}}" {{args}}

destroy-spec spec_file="spec.yaml" *args:
  @base=$(basename "{{spec_file}}"); \
  ws=$(echo "$base" | sed -E 's/\\.(ya?ml)$//' | sed -E 's/[^A-Za-z0-9_-]+/-/g'); \
  terraform workspace select "$ws" >/dev/null 2>&1 || terraform workspace new "$ws"; \
  terraform destroy -var="spec_file={{spec_file}}" {{args}}
