# Full Pipeline Technology Stack

| Layer | Component | Chosen Tool | Architectural Role & Business Value |
|---|---|---|---|
| Governance & Portal | Request & CMDB | ServiceNow (IntegrationHub) | Operational intake and CMDB update source for migration activities. |
| Orchestration | CI/CD Engine | GitHub Actions | Event-driven pipeline manager for build, test, scan, release, and controlled promotion. |
| Environment Governance | Promotion Controls | GitHub Environments (`dev`, `test`, `prod`) | Enforces release order, approvals, and deployment protection rules per stage. |
| Identity / Trust | Security Gateway | AWS IAM OIDC Provider | Federated short-lived credentials for GitHub deployments without long-lived keys. |
| Artifact Registry | Container Repository | Amazon ECR | Stores immutable container tags and digest-based deployment references. |
| Artifact Registry | Package Repository | AWS CodeArtifact | Manages versioned Python/Java package lifecycle for build reproducibility. |
| Image Assembly | Compute Packager | HashiCorp Packer (HCL2) | Produces immutable AMIs for OS and middleware baseline standardization. |
| Configuration | Dynamic State Provisioner | Ansible | Applies OS hardening and middleware/application configuration as code. |
| Infrastructure Provisioning | Runtime Provisioner | Terraform | Provisions environment-specific AWS runtime infrastructure with isolated state. |
| IaC Security | Policy and Static Checks | tfsec + Checkov | Blocks non-compliant infrastructure changes before apply. |
| Application Security | Code and Dependency Scanning | GitHub Advanced Security / Dependency / Secret Scanning | Detects code, package, and secret risks early in PR workflow. |
| Image Security | Runtime Artifact Scanning | Amazon Inspector + ECR Enhanced Scanning | Detects container and AMI vulnerabilities before environment promotion. |
| Runtime Security Posture | Continuous Threat Monitoring | Security Hub + GuardDuty + IAM Access Analyzer | Centralized security posture and threat detection across accounts. |
| Communication Channel | Zero-Trust Tunnel | AWS SSM Session Manager | Secure control path for private build/configuration actions without SSH exposure. |
| Config & Secret Store | Runtime Configuration | AWS Systems Manager Parameter Store + AWS Secrets Manager | Segregates environment config and secrets (`/dev`, `/test`, `/prod`) from code. |
| Observability | Telemetry and Tracing | CloudWatch + OpenTelemetry + AWS X-Ray | Provides logs, metrics, traces, and release health visibility for triage. |
| Incident Signaling | Alert Routing | CloudWatch Alarms + SNS | Enables centralized alert notifications and incident integration. |
| Release Contract | Release Manifest | JSON Manifest Artifact | Carries approved digests, AMI paths, and IaC version as the deployable unit. |
| Rollback | Safe Recovery Controls | Blue/Green/Canary + AMI rollback + IaC revert | Enables automated/controlled rollback for app, OS image, and infra failures. |
