# AWS Target Component Context (Dev/Test/Prod)

This target context extends the reference migration diagram with full automated CI/CD controls for AWS-only deployments.

## Promotion model

- Single promotion path: `dev -> test -> prod`
- Separate deploy roles per environment/account via GitHub OIDC:
  - `AWS_DEV_ROLE_ARN`
  - `AWS_TEST_ROLE_ARN`
  - `AWS_PROD_ROLE_ARN`
- Environment-specific approved AMI paths in Parameter Store:
  - `/dev/approved/ami/base`
  - `/test/approved/ami/base`
  - `/prod/approved/ami/base`

## Capability mapping

- Artifact management: ECR + CodeArtifact + release manifest + SBOM/provenance
- Infra provisioning: Terraform with isolated backend and environment tfvars
- Image build and configuration: Ansible-driven EC2 build flow over SSM (no Packer dependency)
- Security scanning: SAST/dependency/secret + tfsec/Checkov + Inspector/ECR scans
- Release governance: GitHub Environments with environment protections and approvals
- Observability: CloudWatch dashboards/logs/alarms + OpenTelemetry/X-Ray traces
- Rollback: Blue/green or canary rollback + AMI rollback + controlled Terraform revert

## Diagram

- Mermaid source: `architecture/target-component-context.mmd`
