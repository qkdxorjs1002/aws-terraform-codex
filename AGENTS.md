# Terraform Spec-Driven Working Guide

## Goal
- Analyze the requirements provided by the user and define them in `spec.yaml`.
- Read `spec.yaml` and implement provisioning Terraform code with clear module boundaries.

## Required Workflow
1. Analyze incoming requirements and map them to `spec.yaml` fields.
2. Create or update `spec.yaml` using `spec.template.yaml` as the schema reference.
3. Implement Terraform in a modular way so each domain is separated and reusable.
4. Keep root orchestration thin and push resource logic into modules.
5. Keep module input/output contracts explicit and avoid hard-coded values.

## Terraform Change Policy
- When Terraform code is changed, verify with `terraform validate` only.

## Output Expectation For Each Task
- Updated `spec.yaml` aligned to the user requirements.
- Modular Terraform code that provisions from `spec.yaml`.
- Validation result from `terraform validate` only.
