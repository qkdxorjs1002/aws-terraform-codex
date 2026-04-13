set shell := ["zsh", "-lc"]

# Usage:
#   just validate                 # uses spec.yaml
#   just validate spec.example.yaml
#   just plan spec.example.yaml
#   just apply spec.example.yaml
#   just destroy spec.example.yaml

default:
  @just --list

validate spec_file="spec.yaml":
  TF_VAR_spec_file="{{spec_file}}" terraform validate

plan spec_file="spec.yaml" *args:
  terraform plan -var="spec_file={{spec_file}}" {{args}}

apply spec_file="spec.yaml" *args:
  terraform apply -var="spec_file={{spec_file}}" {{args}}

destroy spec_file="spec.yaml" *args:
  terraform destroy -var="spec_file={{spec_file}}" {{args}}
