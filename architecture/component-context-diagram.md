# Component Context Diagram – Integration Reference

This document explains each numbered integration in the component context diagram (`component-context-diagram.mmd`), grouped by flow area.

---

## Governance & Request

| # | From → To | Explanation |
|---|-----------|-------------|
| 1 | ServiceNow → GitHub Actions | GitHub Actions pulls CMDB context (server details, environment metadata) from ServiceNow to parameterise the pipeline run. |
| 2 | ServiceNow → IntegrationHub | ServiceNow raises a migration/change request and emits a trigger event to IntegrationHub to start the automation flow. |
| 3 | IntegrationHub → GitHub Actions | IntegrationHub translates the ServiceNow event into a GitHub Actions workflow dispatch call, kicking off the pipeline. |
| F3 | ServiceNow → Team | When a remediation action is required (e.g., change request rejected), ServiceNow notifies the Project / Migration Team directly. |

---

## Pipeline Bootstrap

| # | From → To | Explanation |
|---|-----------|-------------|
| 4 | GitHub Repository → GitHub Actions | A code push or workflow dispatch event in the GitHub repository triggers the CI/CD pipeline run. |
| 5 | GitHub Actions → IAM OIDC Provider | GitHub Actions requests a short-lived AWS access token via the OIDC federation endpoint, with no long-lived credentials stored. |
| 6 | IAM OIDC Provider → GitHub Actions | The IAM OIDC Provider returns temporary STS credentials scoped to the permitted IAM role for the pipeline job. |

---

## RTCM & Security Scan Gates

| # | From → To | Explanation |
|---|-----------|-------------|
| 7 | GitHub Repository → RTCM Approved Versions | The pipeline reads the declared runtime stack versions from the repository and submits them for approval checking against the RTCM baseline. |
| 8 | SSM Parameter Store → RTCM Approved Versions | The approved runtime compatibility baseline stored in SSM Parameter Store is mirrored into the RTCM component for policy evaluation. |
| 9 | GitHub Actions → RTCM Validator | GitHub Actions invokes the RTCM Validator to compare the stack's declared versions against the approved baseline. |
| 10 | RTCM Approved Versions → RTCM Validator | The RTCM component supplies its version policy rules to the validator so it can determine pass/fail. |
| 11 | GitHub Actions → Code Scans (SAST + Dep + Secret) | GitHub Actions triggers static application security testing, dependency vulnerability checks, and secret scanning against the repository code. |
| 12 | GitHub Actions → IaC Scans (tfsec + Checkov) | GitHub Actions runs tfsec and Checkov against the Terraform and Ansible IaC files to detect misconfigurations. |
| 13 | RTCM Validator → Security Gates | The RTCM Validator forwards its pass/fail result as evidence to the Security Gates decision point. |
| 14 | Code Scans → Security Gates | The SAST/dependency/secret scan results are forwarded as gate evidence to the Security Gates decision point. |
| 15 | IaC Scans → Security Gates | The IaC scan results from tfsec and Checkov are forwarded as gate evidence to the Security Gates decision point. |
| 16 | Security Gates → Ansible Image Build | When all security gates pass, the pipeline proceeds to the image build step via Ansible. |
| F1 | Security Gates → ServiceNow | When a security gate fails, a remediation ticket is automatically raised back in ServiceNow for the team to action. |

---

## Image Build

| # | From → To | Explanation |
|---|-----------|-------------|
| 17 | Ansible Image Build → Private Builder EC2 | The Ansible image-build job executes the playbook against the private builder EC2 instance to produce the golden AMI. |
| 18 | GitHub Actions → SSM Session Manager | GitHub Actions opens an SSM Session Manager session to the builder EC2, avoiding any direct SSH or console access. |
| 19 | SSM Session Manager → Private Builder EC2 | SSM Session Manager establishes an encrypted channel to the builder EC2 through which build commands are executed. |
| 20 | GitHub Actions → Ansible | GitHub Actions invokes Ansible with the launch configuration parameters needed for the build run. |
| 21 | Ansible → Private Builder EC2 | Ansible runs its playbook to configure the EC2 host — installing runtimes, applying hardening, and building the target artefact. |
| 22 | SSM Parameter Store → Private Builder EC2 | Build-time parameters (e.g., package versions, environment settings) are pulled from SSM Parameter Store by the EC2 build process. |

---

## AMI Scan & Deploy

| # | From → To | Explanation |
|---|-----------|-------------|
| 23 | Private Builder EC2 → Golden AMI Registry | The builder EC2 publishes the newly created AMI to the Golden AMI Registry (ECR/AMI store) as a candidate image. |
| 24 | Golden AMI Registry → Artifact Scans (ECR + Inspector) | The candidate AMI/container image is submitted to ECR and AWS Inspector for vulnerability scanning before promotion. |
| 25 | Artifact Scans → Image Scan Gate | Inspector/ECR scan findings are forwarded to the Image Scan Gate decision point as evidence. |
| 26 | Image Scan Gate → Target Workloads | When the image scan passes, the approved image is deployed to the target workloads (WebLogic / Tomcat / Python). |
| F2 | Image Scan Gate → ServiceNow | When the image scan fails, a remediation ticket is raised in ServiceNow to address the identified vulnerabilities. |
| 27 | Private Builder EC2 → SSM Inventory | The builder EC2 reports its installed software and configuration state into SSM Inventory after the build completes. |
| 28 | SSM Inventory → ServiceNow | SSM Inventory syncs the up-to-date host inventory data back to the ServiceNow CMDB to keep configuration records current. |
| 29 | Target Workloads → Runtime Posture (SecHub + GuardDuty + IAM AA) | Deployed workloads emit runtime security telemetry to AWS Security Hub, GuardDuty, and IAM Access Analyser for continuous posture monitoring. |
| 30 | Runtime Posture → ServiceNow | Posture findings and alerts from Security Hub/GuardDuty are fed back to ServiceNow to trigger remediation workflows. |

---

## Evidence Flows

| # | From → To | Explanation |
|---|-----------|-------------|
| 31 | GitHub Actions → EventBridge Evidence Bus | GitHub Actions publishes pipeline execution events (start, success, failure) to EventBridge as compliance evidence. |
| 32 | RTCM Validator → EventBridge Evidence Bus | The RTCM Validator emits its version-check result to EventBridge so it is captured as a compliance evidence record. |
| 33 | Code Scans → EventBridge Evidence Bus | SAST/dependency/secret scan results are published to EventBridge as evidence of security gate evaluation. |
| 34 | IaC Scans → EventBridge Evidence Bus | IaC scan results from tfsec and Checkov are published to EventBridge as evidence of infrastructure policy checks. |
| 35 | Artifact Scans → EventBridge Evidence Bus | Image/container scan results from ECR and Inspector are published to EventBridge as artifact security evidence. |
| 36 | Runtime Posture → EventBridge Evidence Bus | Ongoing runtime posture findings from Security Hub and GuardDuty are published to EventBridge as continuous compliance evidence. |
| 37 | SSM Inventory → EventBridge Evidence Bus | SSM Inventory state snapshots are published to EventBridge to provide host-level inventory evidence records. |
| 38 | EventBridge → Evidence Ingestor Lambda | EventBridge routes all evidence events to the Evidence Ingestor Lambda, which validates and digitally signs each record. |
| 39 | Evidence Ingestor Lambda → S3 Evidence Bucket | The validated and signed evidence record is written to the S3 Evidence Bucket with Object Lock and SSE-KMS to ensure immutability. |
| 40 | Evidence Ingestor Lambda → DynamoDB Evidence Index | A metadata index entry for each evidence record is written to DynamoDB to enable fast querying and cross-referencing. |
| 41 | S3 Evidence Bucket → Integrity Verifier Lambda | A daily scheduled check triggers the Integrity Verifier Lambda to re-validate stored evidence records for tampering. |
| 42 | S3 Evidence Bucket → CloudTrail | S3 object-level events on the evidence bucket are automatically captured by CloudTrail for audit of all access and changes. |
| 43 | Integrity Verifier Lambda → CloudTrail | If the Integrity Verifier detects a tampered record, it raises a tamper alert that is logged to CloudTrail for investigation. |

---

## Audit Reporting

| # | From → To | Explanation |
|---|-----------|-------------|
| 44 | S3 Evidence Bucket → Audit Manager | AWS Audit Manager aggregates evidence records from S3 to produce structured compliance assessment reports. |
| 45 | S3 Evidence Bucket → Athena | Athena is pointed at the S3 Evidence Bucket to enable ad-hoc SQL queries over raw evidence data for custom reporting. |
| 46 | DynamoDB Evidence Index → Athena | The DynamoDB index metadata is made available to Athena queries, allowing joins between index fields and S3 evidence objects. |
| 47 | Audit Manager → Auditor Export API | Audit Manager exports structured compliance reports through the Auditor Export API for consumption by auditors or external GRC tools. |
| 48 | Athena → Auditor Export API | Athena query results are surfaced via the Auditor Export API, providing on-demand evidence exports for audit requests. |
