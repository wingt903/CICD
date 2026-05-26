# AWS Cloud Migration CI/CD Project

This repository provides a reference implementation for AWS migration CI/CD across:
- Oracle WebLogic
- Apache Tomcat
- Python

It now includes an AWS-only target design for full automated CI/CD with dev/test/prod promotion controls.

## Repository Structure

- `architecture/aws-migration-cicd.mmd` - baseline end-to-end migration flow
- `architecture/component-context-diagram.mmd` - Mermaid component context diagram for key platform integrations
- `architecture/sequence-diagram.mmd` - interaction sequence flow
- `architecture/full-pipeline-tech-stack.md` - technology stack mapping
- `architecture/target-component-context.mmd` - target component context diagram (artifact, IaC, security, governance, observability, rollback)
- `architecture/target-component-context.md` - target design notes and capability mapping
- `cicd/github-actions/aws-migration-pipeline.yml` - multi-stage CI/CD workflow with security, IaC checks, release manifest, and environment promotion
- `infrastructure/terraform/` - Terraform scaffolding for environment-isolated provisioning and approved AMI parameter paths
- `sample-code/weblogic/` - WebLogic sample deployment artifact and Dockerfile
- `sample-code/tomcat/` - Tomcat sample web app and Dockerfile
- `sample-code/python/` - Python Flask sample app and Dockerfile

## CI/CD Flow (Target)

1. Pull request runs build + validation + security scans.
2. Terraform and IaC policy checks run before release manifest generation.
3. Release manifest captures immutable artifact references and environment AMI parameter paths.
4. Main branch deploys only through environment sequence:
   - `dev` (automated)
   - `test` (automated + quality/security gate)
   - `prod` (manual approval using GitHub Environment protections)
5. Post-deploy verification and rollback paths are executed on failure conditions.

## GitHub/AWS Configuration Required

- Configure GitHub OIDC trust in each AWS account.
- Add repository/environment variables:
  - `AWS_DEV_ROLE_ARN`
  - `AWS_TEST_ROLE_ARN`
  - `AWS_PROD_ROLE_ARN`
- Configure GitHub Environments named `dev`, `test`, and `prod` with required reviewers for prod.
- Configure Terraform backend resources per environment as defined in:
  - `infrastructure/terraform/backend/dev.hcl`
  - `infrastructure/terraform/backend/test.hcl`
  - `infrastructure/terraform/backend/prod.hcl`

## Notes

- The workflow uses placeholders for deployment implementation details so teams can plug in ECS/EKS/ASG specifics.
- Security and governance gates are explicitly modeled so unresolved critical/high findings can block promotion.
