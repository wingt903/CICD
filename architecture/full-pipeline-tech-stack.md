# Full Pipeline Technology Stack

| Layer | Component | Chosen Tool | Architectural Role & Business Value |
|---|---|---|---|
| Governance & Portal | Request & CMDB | ServiceNow (IntegrationHub) | The operational entry point. Captures user metadata and maps system relationships inside the CMDB. |
| Orchestration | CI/CD Engine | GitHub Actions | Event-driven pipeline manager. Handles code checkouts, compiles Java code, and coordinates AWS actions. |
| Identity / Trust | Security Gateway | AWS IAM OIDC Provider | Establishes cryptographic trust between GitHub and AWS, provisioning temporary IAM access keys. |
| Runtime Security | Application Detection & Response | Amazon GuardDuty + AWS Security Hub + Amazon EventBridge | Continuously detects application/runtime threats, centralizes findings, and triggers automated containment or remediation workflows. |
| Image Assembly | Compute Packager | HashiCorp Packer (HCL2) | Automated engine that builds temporary EC2 environments, configures them, and registers final target AMIs. |
| Configuration | Dynamic State Provisioner | Ansible | Orchestrates local configurations (installing WebLogic clusters, tuning Tomcat JVM pools, isolating Python environments). |
| Communication Channel | Zero-Trust Tunnel | AWS SSM Session Manager | Enables GitHub and Packer to execute Ansible code inside isolated private AWS subnets. |
| Data & Parameter Store | Config & Secrets Management | AWS SSM Parameter Store | Standardizes configuration by decoupling credentials and database connection strings from the application code. |
