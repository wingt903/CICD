# Full Pipeline Technology Stack

## Scope assumptions

- **ServiceNow integration is moved to Phase 2.** Phase 1 starts from governed GitHub approvals / workflow dispatch and uses standardized evidence packs plus manual ITSM / CMDB handoff instead of live ServiceNow-triggered orchestration.
- **Application teams operate in two repository models.** The target pipeline must support both **one repository per environment** and **one repository for all environments** without changing the mandatory controls.

| Layer | Component | Chosen Tool | Architectural Role & Business Value |
|---|---|---|---|
| Governance & Portal | Request & CMDB | ServiceNow (IntegrationHub) | **Phase 2 target-state** operational intake and CMDB update source. In Phase 1, the equivalent control point is handled through GitHub approvals, required change references, and manual ITSM / CMDB handoff. |
| Governance Automation | Change-Controlled Runbooks | Ansible Playbooks | Executes governed pre-check, patch, and remediation runbooks as code, with auditable execution logs linked to change records. ServiceNow-driven invocation is deferred to Phase 2. |
| Runtime Baseline Governance | Runtime Technology Compatibility Matrix | Versioned JSON artifact + AWS SSM Parameter Store | Stores the approved application, middleware, and database version baseline consumed by the pipeline before any installation or deployment activity. |
| Orchestration | CI/CD Engine | GitHub Actions | Event-driven pipeline manager for build, test, scan, release, and controlled promotion across both application team repository models: one repository per environment and one repository for all environments. |
| Runtime Compliance Gate | Pre-install Version Validation | GitHub Actions + RTCM Validator | Reads declared stack versions from deployment payloads/manifests, checks them against the approved RTCM, fails closed on unsupported versions, and logs every approval/rejection decision. |
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
| Deployment Governance | Fail-Closed Release Decision Record | AWS Systems Manager Parameter Store | Stores pass/fail deployment decisions per immutable release identity and environment; blocks re-deploy of previously failed/blocked releases by policy. |
| Operations Feedback | Asset State Reconciliation | AWS SSM Inventory + ServiceNow CMDB Sync | Reconciles runtime software/OS state from managed nodes back to CMDB as a **Phase 2 target state**. In Phase 1, the same evidence is exported for governed manual ITSM / CMDB update. |
| Observability | Telemetry and Tracing | CloudWatch + OpenTelemetry + AWS X-Ray | Provides logs, metrics, traces, and release health visibility for triage. |
| Incident Signaling | Alert Routing | CloudWatch Alarms + SNS | Enables centralized alert notifications and incident integration. |
| Release Contract | Release Manifest | JSON Manifest Artifact | Carries approved digests, AMI paths, and IaC version as the deployable unit. |
| Rollback | Safe Recovery Controls | Blue/Green/Canary + AMI rollback + IaC revert | Enables automated/controlled rollback for app, OS image, and infra failures. |
| Compliance Evidence Store | Immutable Evidence Repository | Amazon S3 (Object Lock + Versioning) + AWS KMS CMK | Stores signed, append-only compliance evidence records from all pipeline and runtime sources. Object Lock (Governance mode, 7-year retention) prevents tampering or premature deletion. |
| Evidence Ingest | Evidence Normalization Pipeline | EventBridge + AWS Lambda (Evidence Ingestor) | Receives normalized evidence events from GitHub Actions, RTCM Validator, SSM, Security Hub, Drift Reconciler, and DB Drift Controller; validates schema, signs records with KMS, and writes to the evidence store. |
| Evidence Integrity | Cryptographic Verification | AWS KMS (Sign/Verify) + AWS Lambda (Integrity Verifier) | Daily scheduled Lambda re-derives SHA-256 hashes and validates KMS signatures for every evidence record; publishes pass/fail metrics and alerts via CloudWatch and SNS on any anomaly. |
| Evidence Audit Trail | Access and Change Logging | AWS CloudTrail (S3 data events + management events) | Captures every evidence read, write, delete attempt, and lock override as immutable CloudTrail records delivered to a separate write-once audit log bucket. |
| Compliance Index | Evidence Query Layer | Amazon DynamoDB (GSIs on system_id, control_id, timestamp) | Maintains a queryable index of all evidence records to support point-in-time and historical reporting without scanning S3 directly. |
| Audit Reporting | Compliance Report Generation | AWS Audit Manager + Amazon Athena + Amazon S3 | Audit Manager aggregates evidence per App_as_Code control framework. Athena provides ad-hoc and scheduled SQL queries over the partitioned evidence store. Reports are exported as PDF or CSV via a read-only auditor API. |

## Detailed Technology Stack

### 1) Governance, Intake, and Change Control
- **ServiceNow Catalog + CMDB**
  - **Phase 2 target state** for service request intake, approval routing, and CI ownership mapping.
  - Stores target app metadata (`app_id`, `middleware_type`, `env`) and change context (`change_id`) when the ServiceNow integration is introduced.
- **ServiceNow IntegrationHub**
  - **Phase 2 target state** to trigger GitHub repository dispatch events.
  - **Phase 2 target state** to receive callback payloads (AMI ID, Ansible run status).
  - Phase 1 starts from governed GitHub approval / dispatch and manual evidence handoff instead of live ServiceNow orchestration.

### 2) CI/CD Orchestration and Build Toolchain
- **GitHub Actions**
  - Workflow trigger on push/PR and governed workflow dispatch.
  - Supports both application team operating models:
    - one repository per environment
    - one repository for all environments
  - Matrix build flow for `weblogic`, `tomcat`, and `python` tracks.
  - Dedicated pre-install RTCM validation job reads declared app, middleware, and database versions from the payload/manifests and blocks unsupported stacks before any image build or installation.
- **Build runtimes**
  - Python sample validation via `python -m py_compile sample-code/python/app.py`.
  - Java stacks compile to deployment artifacts (`.war` / `.ear`) where applicable.
- **Containerization**
  - Docker-based packaging from per-stack folders under `sample-code/`.

### 2.1) Runtime Compatibility Baseline
- **Runtime Technology Compatibility Matrix (`architecture/runtime-compatibility-matrix.json`)**
  - Versioned approved matrix for application runtimes, middleware, and database engines.
  - Each entry defines approved versions, support status, security baseline date, and fail-closed policy metadata.
  - Mirrored to AWS SSM Parameter Store at `/cicd/rtcm/approved/current` for runtime retrieval by pipeline jobs.

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
  - Mirrors the current approved Runtime Technology Compatibility Matrix baseline used by the RTCM validation gate.
  - Stores governed deployment decision records at `/cicd/deployment-decisions/<release_id>/<environment>` so failed releases are blocked from re-deploy until a new release identity is produced and revalidated.

### 6) Operational Feedback and CMDB Reconciliation
- **AWS SSM Inventory**
  - Captures managed-node software/OS/runtime details after build/deployment steps.
- **CMDB Sync Loop**
  - **Phase 2 target state:** updates ServiceNow CIs with active AMI, Ansible execution evidence, and reconciled runtime state.
  - **Phase 1:** produces the same evidence for manual / governed ITSM and CMDB update.
  - Improves audit readiness and operational traceability in both phases.

### 7) Compliance Evidence Store and Audit Controls
- **EventBridge Compliance Evidence Bus**
  - All pipeline stages, RTCM validation decisions, SSM executions, Security Hub findings, drift reconciler, and DB drift controller publish normalized evidence events to a dedicated EventBridge event bus.
- **Evidence Ingestor Lambda**
  - Validates incoming evidence against the canonical schema (see `architecture/compliance-evidence-store.md`).
  - Signs each record with KMS (`kms:Sign`) before writing to S3.
  - Writes the record to S3 and inserts the index entry into DynamoDB.
- **Amazon S3 — Compliance Evidence Bucket**
  - Object Lock enabled in Governance mode with a minimum 7-year retention period.
  - Versioning enabled; SSE-KMS encryption with a dedicated Customer Managed Key.
  - S3 server access logging and CloudTrail S3 data events (read + write) enabled for all objects.
  - Partitioned by `year/month/day/env` for efficient Athena querying.
- **Amazon DynamoDB — Evidence Index**
  - Global Secondary Indexes on `system_id`, `control_id`, and `timestamp` allow point-in-time and historical queries without S3 scans.
- **AWS KMS — Evidence Signing CMK**
  - Customer Managed Key used exclusively for evidence signing and verification.
  - Key policy restricts usage to the Ingestor Lambda role and the Integrity Verifier Lambda role.
- **Integrity Verifier Lambda**
  - Scheduled daily via EventBridge.
  - Re-derives SHA-256 hash of each evidence record and validates the KMS signature.
  - Publishes `EvidenceIntegrityPass` / `EvidenceIntegrityFailure` metrics to CloudWatch.
  - Real-time SNS alert on any failure.
- **AWS CloudTrail — Evidence Access and Change Audit Trail**
  - Org-level trail with S3 data events enabled for the evidence bucket.
  - Captures every read, write, delete attempt, and Object Lock override attempt with full actor, timestamp, and request metadata.
  - Logs delivered to a separate write-once audit log bucket (Object Lock, Compliance mode, 7-year retention).
- **AWS Audit Manager**
  - Custom framework mapping App_as_Code controls (001–004) to evidence sources.
  - Automatically aggregates evidence records from S3 into assessment cycles.
  - Generates assessment reports for auditor review and export.
- **Amazon Athena — Ad-hoc and Scheduled Reporting**
  - SQL queries over partitioned evidence S3 prefix for current posture, historical trend, remediation history, integrity, and access audit reports.
  - Report outputs written to `s3://compliance-evidence-<account>/reports/`.
- **Auditor Export API**
  - API Gateway + read-only Lambda authenticated via IAM Identity Center.
  - Issues S3 presigned URLs for report download; access logged to CloudTrail.
