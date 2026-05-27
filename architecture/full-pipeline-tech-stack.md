# Full Pipeline Technology Stack

| Layer | Component | Chosen Tool | Architectural Role & Business Value |
|---|---|---|---|
| Governance & Portal | Request & CMDB | ServiceNow (IntegrationHub) | Operational intake and CMDB update source for migration activities. |
| Governance Automation | Change-Controlled Runbooks | Ansible Playbooks | Executes CMDB-driven pre-check, patch, and remediation runbooks as code, with auditable execution logs linked to change records. |
| Orchestration | CI/CD Engine | GitHub Actions | Event-driven pipeline manager for build, test, scan, release, and controlled promotion. |
| Environment Governance | Promotion Controls | GitHub Environments (`dev`, `test`, `prod`) | Enforces release order, approvals, and deployment protection rules per stage. |
| Identity / Trust | Security Gateway | AWS IAM OIDC Provider | Federated short-lived credentials for GitHub deployments without long-lived keys. |
| Artifact Registry | Container Repository | Amazon ECR | Stores immutable container tags and digest-based deployment references. |
| Artifact Registry | Package Repository | AWS CodeArtifact | Manages versioned Python/Java package lifecycle for build reproducibility. |
| Image Assembly | AMI Build Automation | Ansible (`amazon.aws` modules) | Automates builder lifecycle (launch, configure, stop, snapshot, terminate) and produces immutable golden AMIs for OS and middleware baselines. |
| Configuration | Dynamic State Provisioner | Ansible | Applies OS hardening and middleware/application configuration as code. |
| Infrastructure Provisioning | Runtime Provisioner | Terraform | Provisions environment-specific AWS runtime infrastructure with isolated state. |
| IaC Security | Policy and Static Checks | tfsec + Checkov | Blocks non-compliant infrastructure changes before apply. |
| Application Security | Code and Dependency Scanning | GitHub Advanced Security / Dependency / Secret Scanning | Detects code, package, and secret risks early in PR workflow. |
| Image Security | Runtime Artifact Scanning | Amazon Inspector + ECR Enhanced Scanning | Detects container and AMI vulnerabilities before environment promotion. |
| Runtime Security | Application Detection & Response | Amazon GuardDuty + AWS Security Hub + Amazon EventBridge | Provides application-focused detection and response coverage by correlating runtime threats, centralizing findings, and triggering automated containment or remediation workflows. |
| Runtime Security Posture | Continuous Threat Monitoring | Security Hub + GuardDuty + IAM Access Analyzer | Centralized security posture and threat detection across accounts. |
| Communication Channel | Zero-Trust Tunnel | AWS SSM Session Manager | Secure control path for private build/configuration actions without SSH exposure. |
| Config & Secret Store | Runtime Configuration | AWS Systems Manager Parameter Store + AWS Secrets Manager | Segregates environment config and secrets (`/dev`, `/test`, `/prod`) from code. |
| Operations Feedback | Asset State Reconciliation | AWS SSM Inventory + ServiceNow CMDB Sync | Reconciles runtime software/OS state from managed nodes back to CMDB to improve audit accuracy and operational visibility. |
| Observability | Telemetry and Tracing | CloudWatch + OpenTelemetry + AWS X-Ray | Provides logs, metrics, traces, and release health visibility for triage. |
| Incident Signaling | Alert Routing | CloudWatch Alarms + SNS | Enables centralized alert notifications and incident integration. |
| Release Contract | Release Manifest | JSON Manifest Artifact | Carries approved digests, AMI paths, and IaC version as the deployable unit. |
| Rollback | Safe Recovery Controls | Blue/Green/Canary + AMI rollback + IaC revert | Enables automated/controlled rollback for app, OS image, and infra failures. |

## Detailed Technology Stack

### 1) Governance, Intake, and Change Control
- **ServiceNow Catalog + CMDB**
  - Service request intake, approval routing, and CI ownership mapping.
  - Stores target app metadata (`app_id`, `middleware_type`, `env`) and change context (`change_id`).
- **ServiceNow IntegrationHub**
  - Triggers GitHub repository dispatch events.
  - Receives callback payloads (AMI ID, Ansible run status).

### 2) CI/CD Orchestration and Build Toolchain
- **GitHub Actions**
  - Workflow trigger on push/PR and external repository dispatch.
  - Matrix build flow for `weblogic`, `tomcat`, and `python` tracks.
- **Build runtimes**
  - Python sample validation via `python -m py_compile sample-code/python/app.py`.
  - Java stacks compile to deployment artifacts (`.war` / `.ear`) where applicable.
- **Containerization**
  - Docker-based packaging from per-stack folders under `sample-code/`.

### 3) Identity, Access, and Trust
- **AWS IAM OIDC Provider for GitHub**
  - Issues short-lived credentials to GitHub Actions jobs.
  - Removes the need for long-lived static AWS access keys.
- **Least-privilege IAM roles**
  - Separate permissions for build orchestration, Ansible automation, AMI registration, and inventory collection.

### 4) Image Assembly and Configuration
- **Ansible (Image Build + Configuration)**
  - Launches temporary private-subnet builder EC2 instances via `amazon.aws.ec2_instance`.
  - Performs in-instance configuration:
    - WebLogic provisioning and domain setup
    - Tomcat deployment and JVM tuning
    - Python virtual environment and dependency setup
  - Stops builder instances after configuration is complete.
  - Creates immutable golden AMIs via `amazon.aws.ec2_ami`.
  - Terminates temporary builders after AMI registration.
- **AWS SSM Session Manager**
  - Provides encrypted control channel for private execution without SSH exposure.

### 5) Configuration Data and Runtime Parameters
- **AWS SSM Parameter Store**
  - Centralized storage for app/runtime parameters and sensitive references.
  - Decouples environment configuration from application artifacts.

### 6) Operational Feedback and CMDB Reconciliation
- **AWS SSM Inventory**
  - Captures managed-node software/OS/runtime details after build/deployment steps.
- **CMDB Sync Loop**
  - Updates ServiceNow CIs with active AMI, Ansible execution evidence, and reconciled runtime state.
  - Improves audit readiness and operational traceability.
