# AWS Target Component Context (Superseded)

> ⚠️ **This document has been merged into the unified component context diagram.**
> Please refer to the single authoritative source:
> - Diagram: [`architecture/component-context-diagram.mmd`](./component-context-diagram.mmd)
> - Integration reference: [`architecture/component-context-diagram.md`](./component-context-diagram.md)

## Scope assumptions

- **ServiceNow integration is moved to Phase 2.** Phase 1 starts from GitHub-governed approvals and standardized deployment evidence handoff rather than live ServiceNow-triggered orchestration.
- **Application teams operate in two repository models:** **one repository per environment** and **one repository for all environments**. The target control model supports both.

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

## Supported application team operating models

- **One repository per environment**: each environment-specific repository triggers the same governed pipeline controls for its target environment.
- **One repository for all environments**: a single repository carries environment-specific configuration and promotes the same release through `dev -> test -> prod`.

## Capability mapping

- Artifact management: ECR + CodeArtifact + release manifest + SBOM/provenance
- Runtime compatibility governance: versioned RTCM artifact + SSM Parameter Store mirror + pre-install validation gate
- Infra provisioning: Terraform with isolated backend and environment tfvars
- Image build and configuration: Ansible-driven EC2 build flow over SSM (no Packer dependency)
- Security scanning: SAST/dependency/secret + tfsec/Checkov + Inspector/ECR scans
- Release governance: GitHub Environments with environment protections and approvals
- Observability: CloudWatch dashboards/logs/alarms + OpenTelemetry/X-Ray traces
- Rollback: Blue/green or canary rollback + AMI rollback + controlled Terraform revert

## Diagram

- Mermaid source: `architecture/target-component-context.mmd`
