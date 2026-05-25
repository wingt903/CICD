# Full Pipeline Technology Stack

| Layer | Component | Chosen Tool | Architectural Role & Business Value |
|---|---|---|---|
| Governance & Portal | Request & CMDB | ServiceNow (IntegrationHub) | The operational entry point. Captures user metadata and maps system relationships inside the CMDB. |
| Governance Automation | Change-Controlled Runbooks | AWS SSM Documents / Automation | Executes CMDB-driven operational runbooks (pre-check, patch, remediation) with auditable execution status linked to change records. |
| Orchestration | CI/CD Engine | GitHub Actions | Event-driven pipeline manager. Handles code checkouts, compiles Java code, and coordinates AWS actions. |
| Identity / Trust | Security Gateway | AWS IAM OIDC Provider | Establishes cryptographic trust between GitHub and AWS, provisioning temporary IAM access keys. |
| Image Assembly | Compute Packager | HashiCorp Packer (HCL2) | Automated engine that builds temporary EC2 environments, configures them, and registers final target AMIs. |
| Configuration | Dynamic State Provisioner | Ansible | Orchestrates local configurations (installing WebLogic clusters, tuning Tomcat JVM pools, isolating Python environments). |
| Communication Channel | Zero-Trust Tunnel | AWS SSM Session Manager | Enables GitHub and Packer to execute Ansible code inside isolated private AWS subnets. |
| Data & Parameter Store | Config & Secrets Management | AWS SSM Parameter Store | Standardizes configuration by decoupling credentials and database connection strings from the application code. |
| Operations Feedback | Asset State Reconciliation | AWS SSM Inventory + ServiceNow CMDB Sync | Reconciles runtime software/OS state from managed nodes back to CMDB to improve audit accuracy and operational visibility. |

## Detailed Technology Stack

### 1) Governance, Intake, and Change Control
- **ServiceNow Catalog + CMDB**
  - Service request intake, approval routing, and CI ownership mapping.
  - Stores target app metadata (`app_id`, `middleware_type`, `env`) and change context (`change_id`).
- **ServiceNow IntegrationHub**
  - Triggers GitHub repository dispatch events.
  - Receives callback payloads (AMI ID, SSM execution IDs, run status).
- **AWS SSM Documents / Automation**
  - Executes CMDB-selected runbooks (pre-check, compliance, remediation, post-build inventory tasks).
  - Produces auditable execution records tied to change tickets.

### 2) CI/CD Orchestration and Build Toolchain
- **GitHub Actions**
  - Workflow trigger on push/PR and external repository dispatch.
  - Matrix build flow for `weblogic`, `tomcat`, and `python` tracks.
- **Build runtimes**
  - Python sample validation via `python -m py_compile sample-code/python/app.py`.
  - Java stacks compile to deployment artifacts (`.war` / `.ear`) where applicable.
- **Containerization**
  - Docker-based packaging from per-stack folders under `/tmp/workspace/wingt903/CICD/sample-code/`.

### 3) Identity, Access, and Trust
- **AWS IAM OIDC Provider for GitHub**
  - Issues short-lived credentials to GitHub Actions jobs.
  - Removes the need for long-lived static AWS access keys.
- **Least-privilege IAM roles**
  - Separate permissions for build orchestration, SSM automation, AMI registration, and inventory collection.

### 4) Image Assembly and Configuration
- **HashiCorp Packer (HCL2)**
  - Launches temporary private-subnet builder EC2 instances.
  - Bakes immutable golden AMIs for each target middleware stack.
- **Ansible**
  - Performs in-instance configuration:
    - WebLogic provisioning and domain setup
    - Tomcat deployment and JVM tuning
    - Python virtual environment and dependency setup
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
  - Updates ServiceNow CIs with active AMI, execution evidence, and reconciled runtime state.
  - Improves audit readiness and operational traceability.
