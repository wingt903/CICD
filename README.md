# AWS Cloud Migration CI/CD Project

This repository provides a reference project for CI/CD setup during AWS cloud migration for applications running on:
- Oracle WebLogic
- Apache Tomcat
- Python

It includes:
- Target architecture diagram
- Sample CI/CD pipeline definition
- Sample application code and containerization patterns

## Repository Structure

- `architecture/aws-migration-cicd.mmd` - Mermaid architecture diagram for the end-to-end flow
- `architecture/component-context-diagram.mmd` - Mermaid component context diagram for the key platform integrations
- `cicd/github-actions/aws-migration-pipeline.yml` - Sample GitHub Actions pipeline for build, test, image publishing, and deployment trigger
- `sample-code/weblogic/` - WebLogic sample deployment artifact and Dockerfile
- `sample-code/tomcat/` - Tomcat sample web app and Dockerfile
- `sample-code/python/` - Python Flask sample app and Dockerfile

## CI/CD Migration Flow (High Level)

1. Developer pushes changes to GitHub.
2. GitHub Actions runs validation and builds deployable artifacts.
3. Container images are pushed to Amazon ECR.
4. Deployment stage updates target runtime:
   - WebLogic workload (EC2/EKS with domain configuration)
   - Tomcat workload (ECS/EKS)
   - Python workload (ECS/EKS/Lambda depending on app design)
5. Post-deployment checks and rollback hooks are executed.

## How to Use This Project

1. Adapt sample code to your application standards.
2. Replace placeholder AWS account/region values in pipeline configuration.
3. Configure OpenID Connect or IAM credentials for GitHub Actions.
4. Add environment-specific deployment scripts and approvals.

## Notes

- This repository is intentionally lightweight and focuses on migration reference patterns.
- Extend the pipeline with security scanning, IaC validation, and integration tests for production usage.
