# Requirement Traceability Matrix

This document traces business requirements to the architecture artifacts under `./architecture`.

## Requirement Assessments

### 1) App_as_Code_001

**Requirement Summary**
- Deployment and configuration should be automated.
- Deployment should be repeatable across environments.
- Scope clarification provided: manual HLD approval is acceptable; from ServiceNow request approval onward, the process should be automated.

**Status**: **Met** (based on clarified scope)

**Traceability Evidence**
- `architecture/aws-migration-cicd.mmd:52-54`  
  `A11 -- Yes --> A9` shows transition from approved ServiceNow request to CI/CD handoff.
- `architecture/aws-migration-cicd.mmd:57-109`  
  Stage 2 onward models system-driven build, gates, AWS role assumption via OIDC, Ansible build/configuration, AMI registration, CMDB patch, and promotion deployment.
- `architecture/sequence-diagram.mmd:12-40`  
  ServiceNow webhook triggers GitHub Actions; subsequent execution flow is automated through AWS SSM/EC2 and CMDB callback.
- `architecture/target-component-context.mmd integrations 15-21` — store params, publish RTCM, promote release, deploy dev, provision runtime, promote test, promote prod
  Pipeline-driven promotion and repeatability controls are modeled (release manifest, approved AMIs, `dev -> test -> prod` progression).
- `architecture/full-pipeline-tech-stack.md:12-14,21,25`  
  Ansible and Terraform automation, environment parameterization, and release manifest support consistent, repeatable deployments.

**Architect Verdict**
- The architecture fulfills App_as_Code_001 when interpreted as: manual governance up to ServiceNow approval is allowed, and all post-approval deployment/configuration execution is automated and repeatable.

---

### 2) App_as_Code_002

**Requirement Summary**
- Continuously detect unauthorized/unsupported configuration drift in in-scope workloads.
- Automatically remediate drift so live state returns to repository-approved baseline.

**Status**: **Met**

**Traceability Evidence**
- `architecture/component-context-diagram.mmd integrations 28-30` — inventory sync to CMDB, posture telemetry, posture feedback  
  Runtime findings and inventory state are fed back from runtime/SSM inventory into ServiceNow for continuous visibility.
- `architecture/full-pipeline-tech-stack.md:6,18-19,22`  
  The solution defines remediation runbooks as code, continuous runtime security posture monitoring, and inventory reconciliation.
- `process-flow-diagram.md:59-63`  
  Post-build SSM document includes inventory capture and remediation baseline, with evidence looped to ServiceNow.
- `architecture/target-component-context.mmd integrations 33-44 and 53-56` — scheduled reconciliation, live state comparison, drift findings, policy decision, baseline enforcement, convergence verification, evidence publication
  Adds explicit scheduled reconciliation control, live-vs-repo drift comparison, policy gate, baseline enforcement, and convergence verification loop with compliance evidence feedback.
- `architecture/target-component-context.mmd integrations 45-50 and 54` — DB drift detection, migration planning, rollback path, validation, DB evidence publication
  Adds dedicated database drift detection/remediation lane, including migration orchestration, rollback path, and post-remediation validation.
- `architecture/sequence-diagram.mmd:48-63`
  Models closed-loop control flow end to end: detect drift -> policy/approval decision -> enforce repository baseline -> verify convergence -> publish closure evidence.
- `architecture/sequence-diagram.mmd:65-79`
  Models dedicated database drift trigger, remediation decision, migration execution, rollback, and validation reporting.

**Architect Verdict**
- App_as_Code_002 is now explicitly evidenced with continuous reconciliation controls, a closed-loop remediation path to repo baseline, and a dedicated database drift control lane.

### 3) App_as_Code_003

**Requirement Summary**
- Automatically apply approved security hardening and security patches to middleware and database components when they are deployed, updated, or identified as requiring security remediation.
- Validate that applied hardening and patches are correctly in place after execution.
- Detect, surface, and record any failure, partial application, or non-compliance without manual intervention.

**Status**: **Met**

**Scenario Compliance Summary**

| Scenario | Requirement Expectation | Verdict | Key References |
|---|---|---|---|
| Automatically apply approved security hardening and patches | Approved hardening controls and patches are applied automatically when components are deployed, updated, or need remediation. | **Met** | `architecture/sequence-diagram.mmd:34-36`, `architecture/aws-migration-cicd.mmd:79-85`, `process-flow-diagram.md:34`, `process-flow-diagram.md:59`, `architecture/target-component-context.mmd integrations 39-40` — policy decision and baseline enforcement, `architecture/component-context-diagram.mmd integrations 13-16, 25-26, F1, F2` — gate evidence, pass/fail decisions, remediation routing |
| Security hardening and patches are validated after application | System confirms required controls/patches are correctly applied and records any failure, partial application, or non-compliance. | **Met** | `architecture/component-context-diagram.mmd integrations 24-26, 35, F2` — scan candidate, gate evidence, deploy/remediate decision, image evidence publication, `architecture/sequence-diagram.mmd:36`, `process-flow-diagram.md:49-51`, `architecture/sequence-diagram.mmd:45-46`, `process-flow-diagram.md:59-62`, `architecture/target-component-context.mmd integrations 42-44 and 53` — convergence state, telemetry feedback, posture update, drift evidence publication, `architecture/target-component-context.mmd integrations 49-50 and 54` — DB validation, DB findings, DB evidence publication |

**Traceability Evidence**

_Scenario 1 – Automatically apply approved security hardening and patches_

| Evidence | Traceability |
|---|---|
| `architecture/sequence-diagram.mmd:34-36` | Ansible hardens base OS automatically during builder EC2 execution before middleware setup. |
| `architecture/aws-migration-cicd.mmd:79-85` | Middleware-specific Ansible baselines (`D2A/D2B/D2C`) are auto-applied for WebLogic, Tomcat, and Python. |
| `process-flow-diagram.md:34` | CMDB-selected SSM pre-check/compliance runbook is auto-triggered before image bake. |
| `process-flow-diagram.md:59` | Post-build SSM document executes remediation baseline and inventory capture automatically. |
| `architecture/full-pipeline-tech-stack.md:row 13` | Ansible is defined as hardening/configuration-as-code engine in pipeline design. |
| `architecture/target-component-context.mmd integrations 39-40` — policy decision and baseline enforcement | Policy gate approves and Enforce Repo Baseline re-applies approved controls for remediation events. |
| `architecture/component-context-diagram.mmd integrations 13-16, 25-26, F1, F2` — gate evidence, pass/fail decisions, remediation routing | Security/image scan failures auto-route remediation back to ServiceNow instead of manual handling. |

_Scenario 2 – Validate security hardening and patches after application_

| Evidence | Traceability |
|---|---|
| `architecture/component-context-diagram.mmd integrations 24-26, 35, F2` — scan candidate, gate evidence, deploy/remediate decision, image evidence publication | Inspector + ECR enhanced scan validates build outputs; failures are blocked and recorded via gate flow. |
| `architecture/sequence-diagram.mmd:36` | Builder returns streaming logs and success/failure status for hardening execution validation. |
| `process-flow-diagram.md:49-51` | Middleware flow includes explicit verify step before AMI serialization. |
| `architecture/sequence-diagram.mmd:45-46` | AMI ID + Ansible evidence are patched back to ServiceNow/CMDB for audit traceability. |
| `process-flow-diagram.md:59-62` | Post-build SSM inventory provides installed-state validation evidence back to pipeline. |
| `architecture/full-pipeline-tech-stack.md:rows 18-19` | Security Hub/GuardDuty/EventBridge detect non-compliance continuously and trigger automated response workflows. |
| `architecture/target-component-context.mmd integrations 42-44 and 53` — convergence state, telemetry feedback, posture update, drift evidence publication | Convergence verification records compliant/non-compliant outcomes to security and CMDB systems. |
| `architecture/target-component-context.mmd integrations 49-50 and 54` — DB validation, DB findings, DB evidence publication | Database post-remediation validation confirms patch/control application and publishes findings. |
| `architecture/full-pipeline-tech-stack.md:row 15` | tfsec/Checkov pre-apply checks prevent policy regressions before deployment. |

**Architect Verdict**
- App_as_Code_003 is fulfilled through a layered, automated security hardening and validation pipeline. Hardening is applied automatically at image build time via Ansible (OS baseline + middleware profile), validated immediately by Inspector/ECR scans and in-pipeline configuration verification, and recorded in ServiceNow/CMDB with Ansible execution evidence. For running workloads, the drift reconciliation loop (EventBridge → Drift Reconciler → Policy Gate → Enforce Baseline → Convergence Verification → CMDB) detects and applies security remediation automatically and records every outcome. Database components have a dedicated remediation and post-validation path. Runtime non-compliance is surfaced continuously through Security Hub and GuardDuty with automated EventBridge-triggered responses, ensuring no manual intervention is required for the detection and recording of failures or partial application.

### 4) App_as_Code_004

**Requirement Summary**
- Continuously assess deployed systems against approved configuration and patch baselines.
- Store auditable compliance evidence with timestamps, system identifiers, baseline references, and compliance status.
- Produce clear, exportable historical and current compliance reporting for auditors.
- Ensure stored evidence is tamper-evident and preserves a complete audit trail of changes and access.
- Validate applied hardening and patch controls and record failures or non-compliance.

**Status**: **Met**

**Scenario Compliance Summary**

| Scenario | Requirement Expectation | Verdict | Key References |
|---|---|---|---|
| Continuous Configuration Compliance Monitoring | Systems are automatically assessed against approved configuration and patch baselines when deployed or updated. | **Met** | `architecture/target-component-context.mmd integrations 33-44` — scheduled reconciliation, live state comparison, drift findings, policy decision, baseline enforcement, convergence verification, posture update, `architecture/sequence-diagram.mmd:48-79`, `architecture/component-context-diagram.mmd integrations 28-30` — inventory sync to CMDB, posture telemetry, posture feedback, `architecture/full-pipeline-tech-stack.md:18-22` |
| Evidence Generation and Storage | Results are stored with timestamps, system identifiers, baseline references, and compliance status. | **Met** | `architecture/compliance-evidence-store.md:§1-§2`, `architecture/sequence-diagram.mmd` (evidence publish steps), `architecture/target-component-context.mmd integrations 51-59` — evidence ingest, validate/sign, write record, index record |
| Audit Reporting | Historical and current compliance status can be exported in clear reports across systems. | **Met** | `architecture/compliance-evidence-store.md:§6`, `architecture/target-component-context.mmd integrations 63-67` — evidence aggregation, ad-hoc queries, index queries, report export, `architecture/full-pipeline-tech-stack.md` (Audit Reporting row) |
| Integrity and Auditability of Evidence | Evidence storage is tamper-evident and all changes/access maintain a complete audit trail. | **Met** | `architecture/compliance-evidence-store.md:§4-§5`, `architecture/target-component-context.mmd integrations 58, 60-62` — write record, daily integrity check, tamper alert, S3 audit events, `architecture/full-pipeline-tech-stack.md` (Evidence Integrity + Evidence Audit Trail rows) |
| Security hardening and patches are validated after application | Applied controls and patches are verified, and failures/non-compliance are detected and recorded. | **Met** | `architecture/component-context-diagram.mmd integrations 24-30 and 35-37` — image scan gate, deploy/remediate decision, inventory sync, posture feedback, evidence publication, `architecture/sequence-diagram.mmd:35-46`, `process-flow-diagram.md:49-62`, `architecture/target-component-context.mmd integrations 42-44 and 49-54` — convergence verification, DB validation, findings, evidence publication |

**Traceability Evidence**

_Scenario 1 – Continuous Configuration Compliance Monitoring_

| Evidence | Traceability |
|---|---|
| `architecture/target-component-context.mmd integrations 33-44` — scheduled reconciliation, live state comparison, drift findings, policy decision, baseline enforcement, convergence verification, posture update | EventBridge scheduled reconciliation, drift comparison, findings publication, policy decision, baseline enforcement, and convergence verification together implement continuous compliance monitoring against the approved baseline. |
| `architecture/sequence-diagram.mmd:48-79` | The sequence diagram models recurring compliance assessment for both infrastructure and databases, with detected drift or compliant state recorded back into ServiceNow. |
| `architecture/component-context-diagram.mmd integrations 28-30` — inventory sync to CMDB, posture telemetry, posture feedback | Runtime security posture and SSM inventory state are fed back into central governance systems for ongoing compliance visibility. |
| `architecture/full-pipeline-tech-stack.md:18-22` | Security Hub, GuardDuty, IAM Access Analyzer, and SSM Inventory provide continuous security and configuration posture monitoring. |

_Scenario 2 – Evidence Generation and Storage_

| Evidence | Traceability |
|---|---|
| `architecture/compliance-evidence-store.md:§1` | Defines the normalized evidence schema (evidence_id, timestamp, system_id, environment, baseline_ref, control_id, result, remediation_state, source_system, run_id, details_ref, signature) — all required fields present. |
| `architecture/compliance-evidence-store.md:§2` | Defines ingest sources: GitHub Actions, SSM/Ansible, Drift Reconciler, DB Drift Controller, Security Hub/GuardDuty, ServiceNow/CMDB — all pipeline and runtime sources publish normalized records. |
| `architecture/target-component-context.mmd integrations 51-59` — evidence ingest, validate/sign, write record, index record | Evidence Ingestor Lambda validates and signs records before writing to S3 (Object Lock) and indexing in DynamoDB with GSIs on system_id, control_id, and timestamp. |
| `architecture/sequence-diagram.mmd` (evidence publish steps) | Build pipeline, drift reconciler, and DB drift controller all explicitly publish evidence events to the evidence bus; ingestor writes signed, immutable records to the evidence store. |
| `architecture/full-pipeline-tech-stack.md` (Evidence Ingest row) | EventBridge + Lambda Evidence Ingestor provides centralized, normalized ingest from all pipeline and runtime sources. |

_Scenario 3 – Audit Reporting_

| Evidence | Traceability |
|---|---|
| `architecture/compliance-evidence-store.md:§6` | Defines five report types (current posture, historical trend, remediation history, integrity report, access/change audit report) and the generation/export mechanism. |
| `architecture/target-component-context.mmd integrations 63-67` — evidence aggregation, ad-hoc queries, index queries, report export | AWS Audit Manager (App_as_Code control framework), Athena report queries (current posture, history, remediation), and Auditor Export API (API Gateway + IAM Identity Center) are explicitly modeled. |
| `architecture/full-pipeline-tech-stack.md` (Audit Reporting row) | Audit Manager + Athena + S3 export architecture is documented in the tech stack. |
| `architecture/component-context-diagram.mmd integrations 44-48` — evidence aggregation, query, and report export flows | Audit Manager and Athena draw from the evidence store; export is available via the auditor API with full access logging. |

_Scenario 4 – Integrity and Auditability of Evidence_

| Evidence | Traceability |
|---|---|
| `architecture/compliance-evidence-store.md:§4` | S3 Object Lock (Governance mode, 7-year retention), versioning, SSE-KMS encryption, KMS-signed SHA-256 per record, and hash-chain integrity controls are fully specified. |
| `architecture/compliance-evidence-store.md:§5` | Complete access/change audit trail is defined: CloudTrail S3 data events (read/write/delete) and management events, DynamoDB Streams for index mutations, with actor, timestamp, before/after, and reason code captured for every event. |
| `architecture/target-component-context.mmd integrations 58, 60-62` — write record, daily integrity check, tamper alert, S3 audit events | S3 Evidence Bucket (Object Lock + SSE-KMS), Integrity Verifier Lambda (daily hash + signature verification), and CloudTrail Evidence Audit Log are explicitly modeled. |
| `architecture/full-pipeline-tech-stack.md` (Evidence Integrity and Evidence Audit Trail rows) | KMS Sign/Verify + Integrity Verifier Lambda and CloudTrail with S3 data events are documented in the tech stack. |
| `architecture/compliance-evidence-store.md:§7` | Integrity alerting (CloudWatch metric alarm on EvidenceIntegrityFailure), unexpected access alerting, lock override alerting, weekly attestation reports, and daily evidence completeness checks are all specified. |

_Scenario 5 – Security hardening and patches are validated after application_

| Evidence | Traceability |
|---|---|
| `architecture/component-context-diagram.mmd integrations 24-30 and 35-37` — image scan gate, deploy/remediate decision, inventory sync, posture feedback, evidence publication | Inspector/ECR scan gates, runtime security posture, and inventory feedback detect and record post-application compliance state. |
| `architecture/sequence-diagram.mmd:35-46` | Builder execution returns logs/status and writes AMI plus execution evidence back to CMDB for auditability. |
| `process-flow-diagram.md:49-62` | Middleware verification, post-build inventory capture, and callback to ServiceNow record the validation outcome. |
| `architecture/target-component-context.mmd integrations 42-44 and 49-54` — convergence verification, DB validation, findings, evidence publication | Convergence verification and post-remediation DB validation confirm remediation success and publish findings into the compliance evidence loop. |

**Architectural Additions Made to Fully Meet App_as_Code_004**

| Gap Area (Closed) | Architectural Addition |
|---|---|
| Central evidence record | Added Evidence Ingestor Lambda + S3 Evidence Bucket + DynamoDB Evidence Index. Every assessment outcome is normalized to the canonical schema (timestamp, system_id, baseline_ref, control_id, result, remediation_state, source_system, run_id, details_ref, signature) and written as an immutable record. |
| Exportable audit reporting | Added AWS Audit Manager (App_as_Code control framework), Athena report queries, and Auditor Export API. Five report types (current posture, historical trend, remediation history, integrity report, access/change audit) are available for export as PDF or CSV/JSON. |
| Tamper-evident evidence | Added S3 Object Lock (Governance mode, 7-year retention), SSE-KMS encryption, KMS-signed SHA-256 per record, hash-chain integrity, and daily Integrity Verifier Lambda. Evidence cannot be modified or deleted within the retention window. |
| Audit trail of access and change | Added CloudTrail S3 data events (PutObject/GetObject/DeleteObject) and management events for the evidence bucket, DynamoDB Streams for index mutations, and a separate write-once audit log bucket (Compliance mode Object Lock). Every evidence read, write, delete attempt, and lock override is captured with full actor, timestamp, and request metadata. |

**Architect Verdict**
- App_as_Code_004 is now **fully met**. The architecture explicitly models a dedicated compliance evidence store with a normalized schema, tamper-evident S3 Object Lock storage, KMS cryptographic signing, a complete CloudTrail-based access/change audit trail, a daily integrity verification loop, and an exportable audit reporting layer via AWS Audit Manager and Athena. All five scenarios are satisfied. See `architecture/compliance-evidence-store.md` for the full design specification.

### 5) App_as_Code_005

**Requirement Summary**
- Configuration checks, setup activities, and post-deployment changes must be performed automatically and consistently.
- Reliance on manual intervention must be reduced.
- Configuration-related incidents must be minimised.
- Engineering teams should focus on delivering value rather than rework.

**Status**: **Met**

**Acceptance Criteria**

| Scenario | Given | When | Then | Verdict |
|---|---|---|---|---|
| Elimination of Manual Verification Steps | A deployment pipeline exists | A release progresses through environments | All configuration and security checks must be executed automatically within the pipeline, removing manual approval or verification steps wherever possible | ✅ Met |
| Reduction of Post-Deployment Fixes | A deployment has completed | The system enters operational use | There must be no requirement for manual configuration fixes due to missed or inconsistent setup activities | ✅ Met |
| Security Risk Reduction through Automation | Manual configuration activities are identified as a source of risk | Automation policies are implemented | The number of configuration-related security incidents must be reduced through consistent, repeatable automated controls | ✅ Met |
| Auditability of Automated Controls | Automated processes replace manual controls | Configuration actions and validations occur | The system must produce auditable logs demonstrating that controls were executed consistently and successfully | ✅ Met |
| Engineering Productivity Improvement | Engineering teams perform deployments and configuration tasks | Automation is in place | The time spent on manual setup, validation, and rework must be reduced, enabling focus on higher-value engineering and security improvements | ✅ Met |

**Scenario Compliance Summary**

| Scenario | Requirement Expectation | Verdict | Key References |
|---|---|---|---|
| Elimination of Manual Verification Steps | All configuration and security checks executed automatically within the pipeline; manual approval or verification steps removed wherever possible. | **Met** | `architecture/aws-migration-cicd.mmd:57-109`, `architecture/component-context-diagram.mmd integrations 13-16, 25-26, F1, F2` — gate evidence, pass/fail decisions, remediation routing, `architecture/full-pipeline-tech-stack.md:rows 5,15-17`, `architecture/sequence-diagram.mmd:22-52` |
| Reduction of Post-Deployment Fixes | No manual configuration fixes required due to missed or inconsistent setup activities after a deployment completes. | **Met** | `architecture/aws-migration-cicd.mmd:76-109`, `architecture/full-pipeline-tech-stack.md:rows 8,13,22`, `architecture/target-component-context.mmd integrations 33-50` — drift reconciliation and DB drift remediation flow, `architecture/sequence-diagram.mmd:54-72` |
| Security Risk Reduction through Automation | Automation policies reduce configuration-related security incidents through consistent, repeatable automated controls. | **Met** | `architecture/component-context-diagram.mmd integrations 11-15, 24-30, 33-36` — code/IaC scans, image scan gate, runtime posture, evidence publication, `architecture/full-pipeline-tech-stack.md:rows 5,7,15-18`, `architecture/target-component-context.mmd integrations 7-10, 22-27, 39-40` — code/IaC scans, artifact/runtime posture scans, policy enforcement |
| Auditability of Automated Controls | System produces auditable logs demonstrating that automated controls were executed consistently and successfully. | **Met** | `architecture/component-context-diagram.mmd integrations 31-43` — evidence publication, validation/signing, immutable storage, integrity check, audit logging, `architecture/sequence-diagram.mmd:50-52,70-72,86-88`, `architecture/full-pipeline-tech-stack.md:rows 6,27-30`, `architecture/aws-migration-cicd.mmd:E1` |
| Engineering Productivity Improvement | Time spent on manual setup, validation, and rework is reduced, enabling focus on higher-value engineering. | **Met** | `architecture/aws-migration-cicd.mmd:57-109`, `architecture/sequence-diagram.mmd:20-52`, `architecture/target-component-context.mmd integrations 33-44` — scheduled reconciliation, live state comparison, drift findings, policy decision, baseline enforcement, convergence verification, `architecture/full-pipeline-tech-stack.md:rows 3,26` |

**Traceability Evidence**

_Scenario 1 – Elimination of Manual Verification Steps_

| Evidence | Traceability |
|---|---|
| `architecture/aws-migration-cicd.mmd:57-109` | Stages 2–5 are entirely system-driven (blue nodes). From the GitHub dispatch payload through quality gates, builder execution, middleware configuration, AMI serialization, and promotion deployment, every step is executed by the pipeline without requiring a human verification action. |
| `architecture/component-context-diagram.mmd integrations 13-16, 25-26, F1, F2` — gate evidence, pass/fail decisions, remediation routing | Security and quality gate decisions (`SGATE`, `IGATE`) are evaluated automatically by the pipeline. Failures auto-route to remediation tasks tracked in ServiceNow; passing gates auto-proceed to the next stage. |
| `architecture/full-pipeline-tech-stack.md:rows 5,15-17` | GitHub Actions (CI/CD engine), tfsec + Checkov (IaC policy), GitHub Advanced Security / Dependency / Secret Scanning, and Amazon Inspector + ECR Enhanced Scanning all run automatically on every pipeline execution without manual trigger or approval. |
| `architecture/sequence-diagram.mmd:22-52` | Steps 2–13 model fully automated orchestration: Git checkout, OIDC token acquisition, Ansible controller initialisation, SSM session, EC2 launch, OS hardening, middleware setup, AMI registration, and CMDB patch — no human action between ServiceNow webhook and CMDB update. |

_Scenario 2 – Reduction of Post-Deployment Fixes_

| Evidence | Traceability |
|---|---|
| `architecture/aws-migration-cicd.mmd:76-109` | Middleware-specific Ansible baselines (D2A WebLogic, D2B Tomcat, D2C Python) are applied automatically before AMI serialization, ensuring all required configuration is baked into the golden image before any deployment occurs. |
| `architecture/full-pipeline-tech-stack.md:rows 8,13` | Ansible applies OS hardening and middleware/application configuration as code; Terraform provisions environment-specific runtime infrastructure with isolated state — both mechanisms guarantee consistent, complete setup with no room for missed manual steps. |
| `architecture/full-pipeline-tech-stack.md:row 22` | AWS SSM Inventory + ServiceNow CMDB Sync reconciles live runtime software and OS state back to CMDB after build and deployment, detecting any gap between expected and actual configuration. |
| `architecture/target-component-context.mmd integrations 33-44` — scheduled reconciliation, live state comparison, drift findings, policy decision, baseline enforcement, convergence verification | EventBridge scheduled reconciliation (G1) triggers the Drift Reconciler (G2) to compare live AWS state against the Git/Terraform baseline. Drift findings (G3) feed a policy gate (G4) that authorizes automatic baseline enforcement (G5), followed by convergence verification (G6) — eliminating any manual correction cycle. |
| `architecture/sequence-diagram.mmd:54-72` | The closed-loop drift detection and auto-remediation sequence runs on a schedule: detect → policy gate → Terraform/config enforce → convergence verify → CMDB closure. Where policy permits, no human action is needed to correct post-deployment configuration drift. |
| `architecture/target-component-context.mmd integrations 45-50` — DB drift detection, migration planning, rollback path, validation | Database Drift Detector and Migration Orchestrator address database configuration drift automatically, including rollback path and post-remediation validation, removing manual database fix activities. |

_Scenario 3 – Security Risk Reduction through Automation_

| Evidence | Traceability |
|---|---|
| `architecture/component-context-diagram.mmd integrations 11-15, 24-30, 33-36` — code/IaC scans, image scan gate, runtime posture, evidence publication | SAST + Dependency + Secret Scanning, IaC Policy Scans, Inspector/ECR image scanning, and Security Hub/GuardDuty runtime posture monitoring are all automated controls applied consistently on every pipeline run and in continuous runtime operation. |
| `architecture/full-pipeline-tech-stack.md:rows 15-18` | tfsec + Checkov block non-compliant infrastructure changes before apply. GitHub Advanced Security detects code/package/secret risks at PR stage. Inspector scans every AMI before promotion. GuardDuty + Security Hub + EventBridge automatically trigger containment or remediation workflows at runtime — every layer is repeatable and consistent. |
| `architecture/full-pipeline-tech-stack.md:row 7` | AWS IAM OIDC Provider issues short-lived federated credentials for every pipeline run, removing long-lived static keys as a source of configuration-related credential risk. |
| `architecture/full-pipeline-tech-stack.md:row 20` | AWS SSM Session Manager provides a zero-trust encrypted control channel, eliminating SSH exposure as a manual configuration risk surface. |
| `architecture/target-component-context.mmd integrations 39-40` — policy decision and baseline enforcement | Policy Gate + Enforce Repo Baseline ensures that every approved security control is consistently re-applied whenever drift is detected, rather than relying on a human to remember and execute manual hardening. |
| `architecture/aws-migration-cicd.mmd:B3-B5` | Pipeline quality and security gate evaluation (B3) blocks non-compliant builds (B4 → B5) and opens a tracked remediation task automatically, preventing insecure configurations from progressing. |

_Scenario 4 – Auditability of Automated Controls_

| Evidence | Traceability |
|---|---|
| `architecture/component-context-diagram.mmd integrations 31-40` — evidence publication, validation/signing, write/index record | Every automated control execution (pipeline stages, scan gates, SSM executions, Security Hub findings, drift reconciler, DB drift controller) publishes a normalised evidence event to the EventBridge Compliance Evidence Bus. The Evidence Ingestor Lambda validates schema and signs each record with KMS before writing to S3. |
| `architecture/sequence-diagram.mmd:50-52` | The build pipeline publishes a normalised 12-field evidence event immediately after the CMDB patch step; the Evidence Ingestor Lambda writes a signed, immutable record to S3 Object Lock and indexes it in DynamoDB — creating an auditable log of the automated build and configuration controls. |
| `architecture/sequence-diagram.mmd:70-72` | The Drift Reconciler publishes a drift remediation evidence event after every automated enforcement cycle; the Evidence Ingestor creates a signed, immutable record demonstrating the automated control was executed and converged. |
| `architecture/sequence-diagram.mmd:86-88` | The DB Drift Controller publishes evidence events for both detected and compliant states, creating a complete auditable log of all database configuration control executions. |
| `architecture/full-pipeline-tech-stack.md:row 6` | Ansible execution logs are linked to ServiceNow change records, providing per-change-record evidence that automated configuration controls ran and what the outcome was. |
| `architecture/full-pipeline-tech-stack.md:rows 27-30` | S3 Object Lock (Governance mode, 7-year retention), KMS signing, CloudTrail S3 data events, and Integrity Verifier Lambda collectively ensure that all auditable logs of automated controls are tamper-evident, complete, and verifiable. |
| `architecture/aws-migration-cicd.mmd:E1` | CMDB and change record are patched with AMI ID plus Ansible execution evidence immediately after the automated build — the audit trail is closed in the same pipeline run that executed the controls. |

_Scenario 5 – Engineering Productivity Improvement_

| Evidence | Traceability |
|---|---|
| `architecture/aws-migration-cicd.mmd:57-109` | All post-approval pipeline stages (2–5) are system-driven with no manual engineering action required for build, configuration, image bake, or deployment. Engineering time is freed from repetitive setup and verification tasks. |
| `architecture/sequence-diagram.mmd:20-52` | The ServiceNow webhook → GitHub Actions → SSM → Ansible → AMI registration → CMDB update flow is fully automated end-to-end, removing engineer involvement from routine deployment and configuration activities. |
| `architecture/target-component-context.mmd integrations 33-44` — scheduled reconciliation, live state comparison, drift findings, policy decision, baseline enforcement, convergence verification | Automated drift detection and reconciliation eliminates the need for engineers to manually identify and correct post-deployment configuration deviations, which is a primary source of unplanned rework. |
| `architecture/full-pipeline-tech-stack.md:row 26` | Blue/Green/Canary rollback, AMI rollback via previous approved ID, and IaC-controlled revert pipeline provide automated safe recovery paths, reducing the engineering effort required to resolve deployment failures. |
| `architecture/full-pipeline-tech-stack.md:row 3` | GitHub Actions event-driven pipeline manager handles build, test, scan, release, and controlled promotion automatically on code push or external dispatch, freeing engineers from orchestrating individual pipeline steps. |
| `architecture/full-pipeline-tech-stack.md:rows 21,22` | SSM Parameter Store segregates environment configuration from code (no manual environment-specific edits at deployment time); SSM Inventory + CMDB Sync automates asset state reconciliation (no manual CMDB update work). |

**Architect Verdict**
- App_as_Code_005 is **fully met**. The architecture eliminates manual verification steps by automating all post-ServiceNow-approval pipeline stages (Stages 2–5 in `aws-migration-cicd.mmd`) including automated security gates (SAST, IaC scans, image scans) and system-driven deployment promotion. Post-deployment fixes are prevented by Ansible configuration-as-code baked into immutable golden AMIs before deployment, and a scheduled drift detection and auto-remediation loop (EventBridge → Drift Reconciler → Policy Gate → Enforce Baseline → Convergence Verification) that corrects any post-deployment drift without manual engineering action. Security risk is reduced through consistent, repeatable automated controls applied identically on every pipeline run (tfsec/Checkov, Inspector, GuardDuty, OIDC short-lived credentials, SSM zero-trust tunnel). Every automated control execution publishes a normalised, KMS-signed, tamper-evident evidence record to the compliance evidence store, providing complete auditability. Engineering productivity is improved because all build, configuration, scan, deployment, and reconciliation activities are orchestrated automatically, removing manual setup, verification, and rework from the engineering workflow.

### 6) App_as_Code_006

**Requirement Summary**
- Continuously monitor and validate baseline health and baseline configuration compliance for platform, middleware, runtime, and database layers.
- Detect issues across availability, performance, resource utilization, and error conditions while systems are in operation.
- Exclude custom application code from this requirement’s monitoring/validation scope.
- Retain timestamped, system-linked health/compliance evidence for audit and forensics.

**Status**: **Partially Met** (core monitoring and evidence controls are present; explicit scope-exclusion control for custom application code must be formalized)

**Scenario Compliance Summary**

| Scenario | Requirement Expectation | Verdict | Key References |
|---|---|---|---|
| Continuous Platform Health Monitoring | Baseline health and baseline compliance for platform/middleware/runtime/database are continuously monitored in operation. | **Met** | `architecture/target-component-context.mmd integrations 28-32 and 33-50` — telemetry, alarms/rollback, drift reconciliation, DB drift management, `architecture/component-context-diagram.mmd integrations 27-30 and 36-37` — inventory state, sync to CMDB, posture telemetry/feedback, inventory/posture evidence, `architecture/sequence-diagram.mmd:54-93`, `architecture/full-pipeline-tech-stack.md:19,22-24` |
| Exclusion of Custom Application Code | Monitoring and validation for this control are restricted to platform, middleware, runtime, and database layers, excluding custom code. | **Partially Met** | `architecture/target-component-context.mmd integrations 33-50` — drift reconciliation and DB drift management, `architecture/sequence-diagram.mmd:54-93`, `architecture/compliance-evidence-store.md:11-24,32-39` |
| Evidence and Audit Logging | Monitoring/validation outputs are retained with timestamps, system identifiers, and health/compliance status for audit/forensics. | **Met** | `architecture/compliance-evidence-store.md:11-27,56-71,117-127`, `architecture/component-context-diagram.mmd integrations 38-48` — validate/sign, write/index, integrity checks, audit log, audit report export, `architecture/target-component-context.mmd integrations 51-67` — evidence ingest, storage, integrity verification, audit reporting, `architecture/sequence-diagram.mmd:50-53,70-73,86-93` |

**Traceability Evidence**

_Scenario 1 – Continuous Platform Health Monitoring_

| Evidence | Traceability |
|---|---|
| `architecture/target-component-context.mmd integrations 28-32 and 33-44` — telemetry, alarms, rollback, scheduled reconciliation, policy enforcement, convergence verification | CloudWatch + OpenTelemetry + X-Ray telemetry, CloudWatch alarms/SNS, scheduled reconciliation, drift findings, baseline enforcement, and convergence verification establish continuous operational monitoring for runtime/platform layers. |
| `architecture/target-component-context.mmd integrations 45-50` — DB drift detection, migration orchestration, rollback path, validation | Dedicated database drift detector, migration orchestration, rollback path, and post-remediation validation provide continuous DB-layer health/compliance validation. |
| `architecture/component-context-diagram.mmd integrations 27-30 and 36-37` — inventory state, sync to CMDB, posture telemetry/feedback, inventory/posture evidence | Runtime security posture plus SSM inventory feedback continuously surfaces runtime and platform state into governance systems. |
| `architecture/sequence-diagram.mmd:54-93` | EventBridge-driven recurring drift and DB control loops validate baseline compliance and publish outcomes continuously during operation. |
| `architecture/full-pipeline-tech-stack.md:19,22-24` | Continuous threat/posture monitoring, asset state reconciliation, telemetry/tracing, and alarm routing provide sustained availability/performance/resource/error visibility. |

_Scenario 2 – Exclusion of Custom Application Code_

| Evidence | Traceability |
|---|---|
| `architecture/target-component-context.mmd integrations 33-50` — drift reconciliation and DB drift management | Drift and DB control lanes are modeled around infrastructure baseline, middleware/runtime configuration, and database schema/parameter controls (not custom code logic validation). |
| `architecture/sequence-diagram.mmd:54-93` | Continuous validation sequence is scoped to Terraform/config baseline convergence and DB schema/config drift control workflows. |
| `architecture/compliance-evidence-store.md:11-24,32-39` | Evidence model and sources support control-scoped records (`control_id`, `source_system`) that can enforce non-code monitoring scope, but explicit exclusion policy is not yet defined. |

_Scenario 3 – Evidence and Audit Logging_

| Evidence | Traceability |
|---|---|
| `architecture/compliance-evidence-store.md:11-24` | Canonical evidence schema includes required timestamp (`timestamp`), system identifier (`system_id`), baseline reference (`baseline_ref`), and compliance/health outcome (`result`, `remediation_state`). |
| `architecture/component-context-diagram.mmd integrations 38-48` — validate/sign, write/index, integrity checks, audit log, audit report export | EventBridge evidence bus, signing ingestor, immutable S3 evidence store, integrity verifier, and CloudTrail audit log provide retained, tamper-evident evidence. |
| `architecture/target-component-context.mmd integrations 51-67` — evidence ingest, storage, integrity verification, audit reporting | Central evidence ingest/index, daily integrity verification, and access/change audit logging are modeled as first-class architecture components. |
| `architecture/sequence-diagram.mmd:50-53,70-73,86-93` | Pipeline, drift, and DB monitoring flows all emit normalized evidence and generate CloudTrail-captured write events for forensic traceability. |

**Architectural Additions Required to Fully Meet App_as_Code_006**

| Gap Area (Open) | Required Addition to Fulfill Requirement |
|---|---|
| Explicit exclusion of custom application code | Add a formal monitoring-scope policy for App_as_Code_006 that limits eligible `control_id` domains to `platform`, `middleware`, `runtime`, and `database`, and rejects/filters `application_code` controls at evidence ingest and reporting layers. |
| Enforced evidence classification for scope auditing | Extend evidence governance with a mandatory layer-scope attribute and validation rule so auditors can prove all App_as_Code_006 records exclude custom code assessments. |
| Visual scope-boundary representation in architecture diagrams | Update architecture diagrams to explicitly label the monitoring scope boundary so the exclusion of custom application code is auditable and unambiguous. |

**Implementation Recommendations to Close App_as_Code_006 Gaps**

1. **Define a monitoring-scope allowlist policy** — Introduce a formal policy document (or policy-as-code rule) that declares the eligible `control_id` domain prefixes for App_as_Code_006 as: `platform`, `middleware`, `runtime`, and `database`. Configure the evidence signing ingestor to reject or quarantine any evidence record carrying an `application_code`-scoped `control_id`, and surface rejections in the reporting layer so auditors have a traceable exclusion log.

2. **Add a mandatory `layer_scope` attribute to the compliance evidence schema** — Extend the canonical evidence record (defined in `architecture/compliance-evidence-store.md`) with a required `layer_scope` field accepting values `platform | middleware | runtime | database | application_code`. Enforce at the signing ingestor that any evidence record tagged to the App_as_Code_006 control set must not carry `layer_scope: application_code`; records that violate this rule must be rejected with an ingest error and written to the audit log.

3. **Surface the scope-exclusion boundary explicitly in architecture diagrams** — Update `architecture/target-component-context.mmd` or `architecture/sequence-diagram.mmd` to add a labeled scope boundary (e.g., a subgraph or annotation) that visually distinguishes the platform/middleware/runtime/database monitoring zone from the custom application code zone. This makes the exclusion boundary auditable from the diagrams alone, without requiring a reader to interpret the evidence schema rules.

**Architect Verdict**
- App_as_Code_006 is **largely implemented** for continuous platform/runtime/database health and compliance monitoring with strong evidence retention and auditability. To fully satisfy the requirement, the architecture must add an explicit and enforceable scope-boundary control that excludes custom application code from this requirement's monitoring and validation evidence set. The three implementation recommendations above — a scope allowlist policy, a mandatory `layer_scope` evidence attribute, and a visual diagram boundary — together close the remaining gaps.

### 7) App_as_Code_007

**Requirement Summary**
- Provide a centralized, governed CI/CD template library for application onboarding.
- Ensure apps deployed through governed templates inherit standard organizational security configuration.
- Automatically execute mandatory cyber controls (for example: secret scanning and image signing).
- Detect and block attempts to override mandatory security controls, and return clear policy-violation errors.

**Status**: **Met** (architecture now explicitly models centralized governed template consumption, mandatory secret-scan and image-signing controls, and fail-closed override detection with policy-violation errors)

**Scenario Compliance Summary**

| Scenario | Requirement Expectation | Verdict | Key References |
|---|---|---|---|
| Standardised Deployment using a Governed Template | New applications use approved governed templates that enforce standard security configuration and mandatory controls automatically. | **Met** | `architecture/component-context-diagram.mmd:11-13,39-42,85-87`, `architecture/target-component-context.mmd:9-12,60-63,103-106`, `architecture/sequence-diagram.mmd:22-32`, `architecture/full-pipeline-tech-stack.md:4-7,16-20` |
| Detection of Non-Compliant Configuration | Attempts to override mandatory security controls fail the pipeline and return policy-violation feedback. | **Met** | `architecture/sequence-diagram.mmd:26-30,43-57`, `architecture/component-context-diagram.mmd:40-42,85-87`, `architecture/target-component-context.mmd:61-63,103-106` |

**Traceability Evidence**

_Scenario 1 – Standardised Deployment using a Governed Template_

| Evidence | Traceability |
|---|---|
| `architecture/component-context-diagram.mmd:11-13,39-42,85-87` | A centralized governed template library (`workflow_call`) and PR-time template governance validator are explicit components; pipelines that do not preserve mandatory controls are blocked before merge/run. |
| `architecture/target-component-context.mmd:9-12,60-63,103-106` | Target architecture enforces template-repo consumption and non-bypass PR guardrails as first-class interactions, not optional implementation notes. |
| `architecture/sequence-diagram.mmd:22-32` | Onboarding flow explicitly requires referencing a governed template version and validates pipeline diffs before deployment execution. |
| `architecture/full-pipeline-tech-stack.md:4-7,16-20` | Technology baseline defines reusable governed templates plus branch protection/CODEOWNERS/required checks and mandatory security controls (including secret scanning and image signing verification). |
| `architecture/sequence-diagram.mmd:39-51` | Image signing is mandatory after build and signature verification is mandatory before each promotion stage, ensuring inherited and consistent security behavior across environments. |

_Scenario 2 – Detection of Non-Compliant Configuration_

| Evidence | Traceability |
|---|---|
| `architecture/sequence-diagram.mmd:26-30` | If a mandatory control is removed/overridden, PR validator returns FAIL and the pipeline emits a deterministic policy-violation error (`Policy violation [CTRL-007]`). |
| `architecture/sequence-diagram.mmd:43-57` | Promotion loop enforces additional fail-closed policy responses for mandatory signing and immutable promotion controls with explicit error contracts (`[IMG-SIGN-001]`, `[PROMO-IMMUTABLE-001]`). |
| `architecture/component-context-diagram.mmd:40-42,85-87` | Logical integration mandates validator pass/fail enforcement for mandatory controls and documents the non-bypass governance rule. |
| `architecture/target-component-context.mmd:61-63,103-106` | PR-time guardrail validator is wired to the workflow orchestrator with pass/fail control-flow semantics, proving override attempts are blocked by design. |

**Fulfillment Design Details (How App_as_Code_007 is Satisfied)**

| Capability | Design Detail |
|---|---|
| Centralized governed onboarding model | Application repositories reference approved reusable workflow templates from a governed template repository using pinned versions, establishing a single hardened deployment blueprint for all onboarding pipelines. |
| Embedded mandatory cyber controls | Secret scanning, IaC policy scanning, image signing, and pre-promotion signature verification are modeled as mandatory fail-closed stages that every governed pipeline run must execute. |
| Non-compliant override detection and response | PR-time guardrail validation blocks attempted removal/override of mandatory controls and returns standardized policy-violation errors to the requestor. |
| Scale and consistency governance | Branch protection, CODEOWNERS, and required status checks enforce template governance at scale and prevent drift from organizational security baselines. |

**Architect Verdict**
- App_as_Code_007 is **met** at the architecture level. The diagrams now explicitly define centralized governed template usage, mandatory embedded security controls (including secret scanning and image-sign/verify), and deterministic fail-closed behavior with policy-violation errors for override attempts. This satisfies both acceptance scenarios for standardized secure deployment and non-compliant configuration detection.

### 8) App_as_Code_008

**Requirement Summary**
- The CI/CD pipeline must automatically verify application, middleware, and database versions against an approved Runtime Technology Compatibility Matrix (RTCM) and security baseline.
- Only supported, secure, and compliant technology stacks are permitted to be deployed into any environment.
- Validation must occur before any installation takes place.
- Unapproved or non-compliant runtimes must be automatically blocked by pipeline guardrails.
- Every validation decision (approved or rejected) must be automatically logged with the deployment identity, decision outcome, and, where rejected, the reason for rejection — forming a retrievable audit trail over time.

**Status**: **Met**

**Scenario Compliance Summary**

| Scenario | Requirement Expectation | Verdict | Key References |
|---|---|---|---|
| Automatically verify against security baseline | All runtime technologies and versions are checked against the approved RTCM before any installation takes place. | **Met** | `architecture/aws-migration-cicd.mmd:57-66`, `architecture/sequence-diagram.mmd:22-39`, `architecture/runtime-compatibility-matrix.json`, `architecture/full-pipeline-tech-stack.md:5-10,49-59` |
| Unsupported runtime stacks are automatically blocked | Guardrails prevent deployment of unapproved or non-compliant technology stacks. | **Met** | `architecture/aws-migration-cicd.mmd:61-66`, `architecture/component-context-diagram.mmd integrations 7-16 and 32` — RTCM baseline lookup, validator gate evidence, build/remediation decision, RTCM evidence publication, `architecture/target-component-context.mmd integrations 4-16 and 52` — RTCM validation gate, scan initiation, artifact publication, RTCM evidence publication |
| Provide clear audit trail of approved and rejected deployments | Every validation decision is automatically logged with deployment identity, outcome, and rejection reason. | **Met** | `architecture/compliance-evidence-store.md:7-41,147-149`, `architecture/sequence-diagram.mmd:28-39,62-64`, `architecture/component-context-diagram.mmd integrations 32 and 38-43` — RTCM evidence publication, validation/signing, immutable storage, audit logging |

**Traceability Evidence**

_Scenario 1 – Automatically verify against security baseline_

| Evidence | Traceability |
|---|---|
| `architecture/aws-migration-cicd.mmd:57-66` | Stage 2 now explicitly loads the approved RTCM from the repository and SSM Parameter Store, validates application, middleware, and database versions against it, and only then proceeds to the remaining quality/security gates. This makes the compatibility check pre-installation and fail-closed. |
| `architecture/sequence-diagram.mmd:22-39` | The sequence diagram adds an explicit RTCM lookup and validation step immediately after checkout and before IAM role assumption, image build, middleware installation, or DB migration. Rejected validations terminate the pipeline before any installation activity begins. |
| `architecture/runtime-compatibility-matrix.json` | The solution now includes a governed RTCM artifact with approved versions for application runtimes, middleware, and databases, plus policy metadata requiring fail-closed enforcement before image build, middleware installation, database migration, and environment promotion. |
| `architecture/full-pipeline-tech-stack.md:5-10,49-59` | The technology stack now documents the RTCM artifact, the GitHub Actions RTCM validator, the SSM Parameter Store mirror path, and the pre-install version-gating control as part of the standard platform design. |

_Scenario 2 – Unsupported runtime stacks are automatically blocked_

| Evidence | Traceability |
|---|---|
| `architecture/aws-migration-cicd.mmd:61-66` | The Stage 2 gate now evaluates RTCM validation alongside the other quality/security controls, and failures open a remediation task with RTCM/policy rejection detail while preventing downstream image build and deployment. |
| `architecture/component-context-diagram.mmd integrations 7-16` — RTCM baseline lookup, validator gate evidence, build/remediation decision | A dedicated `RTCM Validator` now feeds gate evidence into `SGATE`, and the approved matrix is modeled as a distinct control source consumed by the pipeline before image build. |
| `architecture/component-context-diagram.mmd integrations 32 and 38-40` — RTCM evidence publication, validation/signing, write/index record | The RTCM validator also publishes approved or rejected validation evidence to the central evidence bus, ensuring unsupported stacks are both blocked and recorded. |
| `architecture/target-component-context.mmd integrations 4-16 and 52` — RTCM validation gate, scan initiation, artifact publication, RTCM evidence publication | The target solution now includes a dedicated RTCM validation gate in CI/governance, a versioned RTCM artifact in artifact management, and an evidence publication path for each RTCM decision. |

_Scenario 3 – Provide clear audit trail of approved and rejected deployments_

| Evidence | Traceability |
|---|---|
| `architecture/compliance-evidence-store.md:7-24` | The evidence schema now explicitly supports RTCM baseline references and the `rtcm-compatibility-check` control identifier, making approval/rejection records first-class compliance evidence. |
| `architecture/compliance-evidence-store.md:30-41` | `RTCM Validator` is now a named evidence ingest source with an explicit evidence type covering approved/rejected compatibility decisions, including the rejection reason and approved version range. |
| `architecture/sequence-diagram.mmd:28-39,62-64` | The sequence diagram models both rejected and approved RTCM decisions being published to the evidence bus with the control ID, result, baseline reference, run ID, and details reference. |
| `architecture/component-context-diagram.mmd integrations 32 and 38-43` — RTCM evidence publication, validation/signing, immutable storage, audit logging | The component context diagram shows RTCM decisions flowing into the EventBridge evidence bus, being signed and stored immutably, and having all S3 write events logged into CloudTrail for long-term audit retrieval. |

**Architectural Additions Made to Fully Meet App_as_Code_008**

| Implemented Area | Architectural Addition |
|---|---|
| Governed RTCM baseline artifact | Added `architecture/runtime-compatibility-matrix.json` as a versioned baseline artifact with approved application, middleware, and database versions, policy metadata, repository path, and SSM Parameter Store mirror location. |
| Dedicated RTCM validation gate | Added a pre-install RTCM validation step to the Stage 2 orchestration flow and the sequence diagrams so the pipeline validates all declared stack versions before any installation, image build, or migration execution. |
| Fail-closed blocking flow | Wired RTCM decisions into the existing gate/remediation path so unsupported stacks are blocked automatically and routed to ServiceNow with explicit rejection detail. |
| Structured RTCM evidence records | Added RTCM validation as a named evidence source and modeled approved/rejected evidence publication to the immutable evidence store with control ID, baseline reference, run ID, and retrievable rejection detail. |

**Architect Verdict**
- App_as_Code_008 is now **fully met**. The architecture explicitly defines a governed Runtime Technology Compatibility Matrix artifact, mirrors the approved baseline into SSM Parameter Store, validates application/middleware/database versions before any installation or build activity, blocks unsupported stacks through the existing fail-closed gate and remediation flow, and publishes an approved or rejected RTCM evidence record for every validation decision into the immutable compliance evidence store. The result is a pre-install guardrail with a complete, retrievable audit trail over time.
