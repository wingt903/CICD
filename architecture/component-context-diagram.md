# Component Context Diagram – Integration Reference

This document explains each numbered integration in the unified component context diagram (`component-context-diagram.mmd`), grouped by flow area.

> **Note:** This is the single authoritative component context diagram. It merges the original component context diagram and the target component context diagram into one consolidated view.

## Scope assumptions

- **ServiceNow integration is moved to Phase 2.** Any ServiceNow / CMDB automation below should be read as target-state integration. Phase 1 uses GitHub approvals / workflow dispatch plus manual ITSM / CMDB handoff.
- **Application teams use two operating models.** The same controls apply whether teams use **one repository per environment** or **one repository for all environments**.
- **No-redeploy governance** is enforced via SSM Decision Records — once a release is marked failed, it cannot be re-deployed to the same environment.

---

## Governance & Request (Phase 2)

| # | From → To | Explanation |
|---|-----------|-------------|
| 1 | Team → ServiceNow | The CAR Architecture Team submits a catalog migration request into ServiceNow to initiate the governance and approval workflow. |
| 2 | ServiceNow → GitHub Actions | **Phase 2 target state:** GitHub Actions pulls CMDB context (server details, environment metadata) from ServiceNow to parameterise the pipeline run. In Phase 1, equivalent inputs come from GitHub-governed deployment metadata and approved change references. |
| 3 | ServiceNow → IntegrationHub | **Phase 2 target state:** ServiceNow raises a migration/change request and emits a trigger event to IntegrationHub to start the automation flow. |
| 4 | IntegrationHub → GitHub Actions | **Phase 2 target state:** IntegrationHub translates the ServiceNow event into a GitHub Actions workflow dispatch call, kicking off the pipeline. |
| F1 | ServiceNow → Team | **Phase 2 target state:** when a remediation action is required (e.g., change request rejected or gate failure), ServiceNow notifies the CAR Architecture Team directly. Phase 1 uses the same remediation decision through GitHub governance and manual ITSM follow-up. |

---

## Pipeline Bootstrap

| # | From → To | Explanation |
|---|-----------|-------------|
| 5 | Application Repo(s) → GitHub Actions | A code push or workflow dispatch event in the application repository triggers the CI/CD pipeline run. Supports both team models: one repository per environment and one repository for all environments. |
| 6 | OS/Image as Code Repo → GitHub Actions | A change to the Ansible image build or configuration repository triggers the image build pipeline. |
| 7 | Infrastructure as Code Repo → GitHub Actions | A change to the Terraform IaC repository triggers the infrastructure provisioning pipeline. |
| 8 | GitHub Actions → IAM OIDC Provider | GitHub Actions requests a short-lived AWS access token via the OIDC federation endpoint, with no long-lived credentials stored. |
| 9 | IAM OIDC Provider → GitHub Actions | The IAM OIDC Provider returns temporary STS credentials scoped to the permitted IAM role for the pipeline job. |

---

## RTCM & Security Scan Gates

| # | From → To | Explanation |
|---|-----------|-------------|
| 10 | GitHub Actions → RTCM Validation Gate | GitHub Actions invokes the RTCM Validation Gate to compare the stack's declared middleware and DB versions against the approved baseline before any build proceeds. |
| 11 | SSM Parameter Store → RTCM Approved Versions | The approved runtime compatibility baseline stored in SSM Parameter Store is mirrored into the RTCM component for policy evaluation. |
| 12 | RTCM Approved Versions → RTCM Validation Gate | The RTCM component supplies its version policy rules to the gate so it can determine pass/fail. |
| 13 | GitHub Actions → Code Scans (SAST + Dep + Secret) | GitHub Actions triggers static application security testing, dependency vulnerability checks, and secret scanning against the repository code. |
| 14 | GitHub Actions → IaC Scans (tfsec + Checkov) | GitHub Actions runs tfsec and Checkov against the Terraform and Ansible IaC files to detect misconfigurations. |
| 15 | RTCM Validation Gate → Security Gates | The RTCM Validator forwards its pass/fail result as evidence to the Security Gates decision point. |
| 16 | Code Scans → Security Gates | The SAST/dependency/secret scan results are forwarded as gate evidence to the Security Gates decision point. |
| 17 | IaC Scans → Security Gates | The IaC scan results from tfsec and Checkov are forwarded as gate evidence to the Security Gates decision point. |
| 18 | Security Gates → Ansible | When all security gates pass, the pipeline proceeds to the image build step via Ansible. |
| F2 | Security Gates → ServiceNow | **Phase 2 target state:** when a security gate fails, a remediation ticket is automatically raised in ServiceNow. In Phase 1, the failure is captured in GitHub evidence and handed off manually through ITSM / change governance. |

---

## Image Build

| # | From → To | Explanation |
|---|-----------|-------------|
| 19 | GitHub Actions → SSM Session Manager | GitHub Actions opens an SSM Session Manager session to the private builder EC2, avoiding any direct SSH or console access. |
| 20 | SSM Session Manager → Private Builder EC2 | SSM Session Manager establishes an encrypted channel to the builder EC2 through which build commands are executed. |
| 21 | GitHub Actions → Ansible | GitHub Actions invokes Ansible with the launch configuration parameters needed for the build run. |
| 22 | Ansible → Private Builder EC2 | Ansible runs its playbook to configure the EC2 host — installing runtimes, applying hardening, and building the target artifact. |
| 23 | SSM Parameter Store → Private Builder EC2 | Build-time parameters (e.g., package versions, environment settings) are pulled from SSM Parameter Store by the EC2 build process. |
| 24 | Private Builder EC2 → Golden AMI Registry | The builder EC2 publishes the newly created AMI to the Golden AMI Registry as a candidate image. |

---

## Artifact Management

| # | From → To | Explanation |
|---|-----------|-------------|
| 25 | GitHub Actions → Amazon ECR | Built container images are pushed to ECR with immutable tags and digest pinning for traceability. |
| 26 | GitHub Actions → AWS CodeArtifact | Python and Java packages produced by the pipeline are published to CodeArtifact for versioned artifact management. |
| 27 | GitHub Actions → SSM Parameter Store | Environment-specific approved AMI paths and runtime parameters are stored in SSM Parameter Store for downstream consumption. |
| 28 | GitHub Actions → RTCM Approved Versions | The pipeline publishes the validated RTCM baseline artifact back to the RTCM component for reference by future runs. |
| 29 | GitHub Actions → SBOM + Build Provenance | GitHub Actions generates a Software Bill of Materials and build provenance record during the pipeline run. |
| 30 | SBOM + Build Provenance → Release Manifest | The SBOM and provenance records are included in the Release Manifest alongside the AMI ID and IaC version for end-to-end traceability. |

---

## AMI Scan & Deploy

| # | From → To | Explanation |
|---|-----------|-------------|
| 31 | Golden AMI Registry → Artifact Scans (ECR + Inspector) | The candidate AMI/container image is submitted to ECR and AWS Inspector for vulnerability scanning before promotion. |
| 32 | Artifact Scans → Image Scan Gate | Inspector/ECR scan findings are forwarded to the Image Scan Gate decision point as evidence. |
| 33 | Image Scan Gate → GitHub Environments | When the image scan passes, the approved image is promoted through GitHub Environments (dev → test → prod) for governed deployment. |
| F3 | Image Scan Gate → ServiceNow | **Phase 2 target state:** when the image scan fails, a remediation ticket is raised in ServiceNow to address the identified vulnerabilities. In Phase 1, the failure is handled through GitHub controls plus manual ITSM follow-up. |
| 34 | Private Builder EC2 → SSM Inventory | The builder EC2 reports its installed software and configuration state into SSM Inventory after the build completes. |
| 35 | SSM Inventory → ServiceNow | **Phase 2 target state:** SSM Inventory syncs the up-to-date host inventory data back to the ServiceNow CMDB to keep configuration records current. In Phase 1, the same inventory evidence is packaged for manual CMDB update. |

---

## No-Redeploy Governance

| # | From → To | Explanation |
|---|-----------|-------------|
| 36 | GitHub Actions → SSM Decision Records | Before each deployment, the governed template queries the centralised SSM decision record for the release identity to enforce fail-closed no-redeploy controls. |
| 37 | SSM Decision Records → GitHub Actions | If the release identity is already marked failed/blocked, the governed deployment stage is denied and re-deploy of that same release is prevented. |
| 38 | GitHub Actions → SSM Decision Records | Deployment outcomes (passed/failed) are written back as authoritative decisions for the release identity and target environment. |
| 39 | SSM Decision Records → ServiceNow | **Phase 2 target state:** failed/blocked decisions are propagated to ServiceNow as remediation context so operational teams can track and resolve security control violations. In Phase 1, the same decision record drives manual ITSM / CMDB updates. |

---

## Release Promotion

| # | From → To | Explanation |
|---|-----------|-------------|
| 40 | GitHub Environments → Release Manifest | GitHub Environments capture the approved release (AMI ID, digest, IaC version) into the Release Manifest before each promotion step. |
| 41 | Release Manifest → Dev Account | The governed Release Manifest drives the initial deployment to the Dev AWS account. |
| 42 | Dev Account → Terraform Provisioned Runtime | Terraform provisions the target runtime infrastructure (VPC, IAM, ECS/EKS/ASG, ALB) within the Dev account. |
| 43 | Dev Account → Test Account | After Dev validation, the release is promoted to the Test AWS account. |
| 44 | Test Account → Prod Account | After Test validation, the release is promoted to the Prod AWS account following required approvals. |
| 45 | Prod Account → Target Workloads | The approved release is deployed to target workloads (WebLogic / Tomcat / Python) in the Prod account. |

---

## Runtime Security

| # | From → To | Explanation |
|---|-----------|-------------|
| 46 | Artifact Scans → Dev Account | ECR/Inspector scans are run against deployed artifacts in the Dev account as part of continuous posture enforcement. |
| 47 | Artifact Scans → Test Account | ECR/Inspector scans are run against deployed artifacts in the Test account as part of continuous posture enforcement. |
| 48 | Artifact Scans → Prod Account | ECR/Inspector scans are run against deployed artifacts in the Prod account as part of continuous posture enforcement. |
| 49 | Target Workloads → Runtime Posture (SecHub + GuardDuty + IAM AA) | Deployed workloads emit runtime security telemetry to AWS Security Hub, GuardDuty, and IAM Access Analyzer for continuous posture monitoring. |
| 50 | Runtime Posture → ServiceNow | **Phase 2 target state:** posture findings and alerts from Security Hub/GuardDuty are fed back to ServiceNow to trigger remediation workflows. In Phase 1, findings are routed through GitHub / evidence outputs and manual operational follow-up. |

---

## Operations & Rollback

| # | From → To | Explanation |
|---|-----------|-------------|
| 51 | Terraform Provisioned Runtime → CloudWatch + OpenTelemetry + X-Ray | The runtime environment emits logs, metrics, and distributed traces to the observability stack for ongoing health monitoring. |
| 52 | CloudWatch + OpenTelemetry + X-Ray → CloudWatch Alarms + SNS | Observability signals trigger CloudWatch alarms and SNS notifications when thresholds are breached. |
| 53 | CloudWatch Alarms + SNS → Blue/Green or Canary Rollback | Alarms trigger automated blue/green or canary rollback to the previous known-good deployment. |
| 54 | CloudWatch Alarms + SNS → AMI Rollback | Alarms trigger rollback to the previously approved AMI ID stored in SSM Parameter Store. |
| 55 | CloudWatch Alarms + SNS → IaC Controlled Revert Pipeline | Alarms trigger a controlled IaC revert pipeline to restore Terraform state to the previous baseline. |

---

## Drift Detection & Reconciliation

| # | From → To | Explanation |
|---|-----------|-------------|
| 56 | EventBridge Scheduler → Drift Reconciler | EventBridge fires a scheduled trigger to the Drift Reconciler Lambda/Step Function at configured intervals. |
| 57 | Dev Account → Drift Reconciler | The Drift Reconciler reads the live configuration state from the Dev account for comparison against the Git baseline. |
| 58 | Test Account → Drift Reconciler | The Drift Reconciler reads the live configuration state from the Test account for comparison against the Git baseline. |
| 59 | Prod Account → Drift Reconciler | The Drift Reconciler reads the live configuration state from the Prod account for comparison against the Git baseline. |
| 60 | IaC Repo → Drift Reconciler | The Drift Reconciler reads the Terraform baseline from the IaC repository as the source of truth for desired state. |
| 61 | Drift Reconciler → Drift Findings | Any deviation between live state and the Git baseline is reported as a drift finding. |
| 62 | Drift Findings → Policy Decision / Approval Gate | Drift findings are submitted to the Policy Gate to determine whether auto-remediation or manual approval is required. |
| 63 | Policy Gate → Team | When manual approval is required, the Policy Gate requests approval from the CAR Architecture Team before enforcement. |
| 64 | Team → Policy Gate | The team approves the controlled remediation, authorising the enforce step. |
| 65 | Policy Gate → Enforce Repo Baseline | The Policy Gate authorises enforcement; Terraform apply and/or config re-run is executed to restore desired state. |
| 66 | Enforce Repo Baseline → Convergence Verification | After enforcement, the Convergence Verifier checks whether live state now matches the baseline. |
| 67 | Convergence Verification → Drift Findings | The convergence result (resolved or still drifted) is fed back into Drift Findings for updated status reporting. |
| 68 | Convergence Verification → CloudWatch + OpenTelemetry + X-Ray | The reconciled infrastructure state is reported back to the observability stack. |
| 69 | Convergence Verification → Runtime Posture | The updated posture state after reconciliation is forwarded to Runtime Posture for continuous compliance tracking. |
| 70 | Drift Findings → ServiceNow | **Phase 2 target state:** drift findings and closure evidence are pushed to ServiceNow CMDB to update compliance status. In Phase 1, handled via evidence records and manual ITSM update. |

---

## Database Drift Management

| # | From → To | Explanation |
|---|-----------|-------------|
| 71 | Terraform Provisioned Runtime → Database Drift Detector | The runtime database schema and configuration state is fed into the Database Drift Detector for comparison against the versioned migration baseline. |
| 72 | Database Drift Detector → Migration Orchestrator | Detected drift triggers the Migration Orchestrator to prepare and execute the appropriate versioned DB migration plan. |
| 73 | Migration Orchestrator → Post-Remediation DB Validation | After migration execution, the Post-Remediation Validator checks that the database schema matches the target baseline. |
| 74 | Migration Orchestrator → DB Rollback Path | If migration validation fails, the Migration Orchestrator invokes the Rollback Path (snapshot restore or previous migration). |
| 75 | DB Rollback Path → Post-Remediation DB Validation | After rollback, the validator re-checks database state to confirm successful restoration. |
| 76 | Post-Remediation DB Validation → Drift Findings | DB remediation results are reported back as drift findings to keep compliance posture up to date. |

---

## Evidence Flows

| # | From → To | Explanation |
|---|-----------|-------------|
| 77 | GitHub Actions → EventBridge Evidence Bus | GitHub Actions publishes pipeline execution events (start, success, failure) to EventBridge as compliance evidence. |
| 78 | RTCM Validation Gate → EventBridge Evidence Bus | The RTCM Validator emits its version-check result to EventBridge so it is captured as a compliance evidence record. |
| 79 | Code Scans → EventBridge Evidence Bus | SAST/dependency/secret scan results are published to EventBridge as evidence of security gate evaluation. |
| 80 | IaC Scans → EventBridge Evidence Bus | IaC scan results from tfsec and Checkov are published to EventBridge as evidence of infrastructure policy checks. |
| 81 | Artifact Scans → EventBridge Evidence Bus | Image/container scan results from ECR and Inspector are published to EventBridge as artifact security evidence. |
| 82 | Runtime Posture → EventBridge Evidence Bus | Ongoing runtime posture findings from Security Hub and GuardDuty are published to EventBridge as continuous compliance evidence. |
| 83 | SSM Inventory → EventBridge Evidence Bus | SSM Inventory state snapshots are published to EventBridge to provide host-level inventory evidence records. |
| 84 | Convergence Verification → EventBridge Evidence Bus | Drift remediation convergence results are published to EventBridge as infrastructure compliance evidence. |
| 85 | Post-Remediation DB Validation → EventBridge Evidence Bus | DB remediation and validation outcomes are published to EventBridge as database compliance evidence. |
| 86 | Drift Findings → EventBridge Evidence Bus | Drift finding records (including status and remediation state) are published to EventBridge for evidence capture. |
| 87 | EventBridge Evidence Bus → Evidence Ingestor Lambda | EventBridge routes all evidence events to the Evidence Ingestor Lambda, which validates schema and ingests each record. |
| 88 | Evidence Ingestor Lambda → S3 Evidence Bucket | The validated evidence record is written to the S3 Evidence Bucket with Object Lock and SSE-KMS to ensure immutability. |
| 89 | Evidence Ingestor Lambda → DynamoDB Evidence Index | A metadata index entry for each evidence record is written to DynamoDB to enable fast querying and cross-referencing. |
| 90 | S3 Evidence Bucket → Integrity Verifier Lambda | A daily scheduled check triggers the Integrity Verifier Lambda to re-validate stored evidence records for tampering. |
| 91 | Integrity Verifier Lambda → CloudTrail | If the Integrity Verifier detects a tampered record, it raises a tamper alert that is logged to CloudTrail for investigation. |
| 92 | S3 Evidence Bucket → CloudTrail | S3 object-level events on the evidence bucket are automatically captured by CloudTrail for audit of all access and changes. |

---

## Audit Reporting

| # | From → To | Explanation |
|---|-----------|-------------|
| 93 | S3 Evidence Bucket → Audit Manager | AWS Audit Manager aggregates evidence records from S3 to produce structured compliance assessment reports. |
| 94 | S3 Evidence Bucket → Athena | Athena is pointed at the S3 Evidence Bucket to enable ad-hoc SQL queries over raw evidence data for custom reporting. |
| 95 | DynamoDB Evidence Index → Athena | The DynamoDB index metadata is made available to Athena queries, allowing joins between index fields and S3 evidence objects. |
| 96 | Audit Manager → Auditor Export API | Audit Manager exports structured compliance reports through the Auditor Export API for consumption by auditors or external GRC tools. |
| 97 | Athena → Auditor Export API | Athena query results are surfaced via the Auditor Export API, providing on-demand evidence exports for audit requests. |

---

## Glossary

| Short Form | Long Name |
|---|---|
| AMI | Amazon Machine Image |
| AMISCAN | AMI/Image Security Scan stage (ECR + Inspector) |
| API | Application Programming Interface |
| AWS | Amazon Web Services |
| CI/CD | Continuous Integration / Continuous Delivery |
| CMDB | Configuration Management Database |
| DynamoDB | Amazon DynamoDB |
| EC2 | Amazon Elastic Compute Cloud |
| ECR | Amazon Elastic Container Registry |
| GRC | Governance, Risk, and Compliance |
| IaC | Infrastructure as Code |
| IAM | Identity and Access Management |
| OIDC | OpenID Connect |
| DREC | SSM Decision Records |
| RTCM | Runtime Compatibility Matrix |
| S3 | Amazon Simple Storage Service |
| SAST | Static Application Security Testing |
| SBOM | Software Bill of Materials |
| SecHub | AWS Security Hub |
| SSE-KMS | Server-Side Encryption with AWS Key Management Service |
| SSM | AWS Systems Manager |
| STS | AWS Security Token Service |
| tfsec | Terraform Security Scanner |
