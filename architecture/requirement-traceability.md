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
- `architecture/target-component-context.mmd:65-77`
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
- `architecture/component-context-diagram.mmd:74-78`  
  Runtime findings and inventory state are fed back from runtime/SSM inventory into ServiceNow for continuous visibility.
- `architecture/full-pipeline-tech-stack.md:6,18-19,22`  
  The solution defines remediation runbooks as code, continuous runtime security posture monitoring, and inventory reconciliation.
- `process-flow-diagram.md:59-63`  
  Post-build SSM document includes inventory capture and remediation baseline, with evidence looped to ServiceNow.
- `architecture/target-component-context.mmd:49-56,91-100`
  Adds explicit scheduled reconciliation control, live-vs-repo drift comparison, policy gate, baseline enforcement, and convergence verification loop with compliance evidence feedback.
- `architecture/target-component-context.mmd:58-63,102-105`
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
| Automatically apply approved security hardening and patches | Approved hardening controls and patches are applied automatically when components are deployed, updated, or need remediation. | **Met** | `architecture/sequence-diagram.mmd:34-36`, `architecture/aws-migration-cicd.mmd:79-85`, `process-flow-diagram.md:34`, `process-flow-diagram.md:59`, `architecture/target-component-context.mmd:G4-G5`, `architecture/component-context-diagram.mmd:SGATE, IGATE` |
| Security hardening and patches are validated after application | System confirms required controls/patches are correctly applied and records any failure, partial application, or non-compliance. | **Met** | `architecture/component-context-diagram.mmd:AMISCAN, IGATE`, `architecture/sequence-diagram.mmd:36`, `process-flow-diagram.md:49-51`, `architecture/sequence-diagram.mmd:45-46`, `process-flow-diagram.md:59-62`, `architecture/target-component-context.mmd:G6`, `architecture/target-component-context.mmd:H4` |

**Traceability Evidence**

_Scenario 1 – Automatically apply approved security hardening and patches_

| Evidence | Traceability |
|---|---|
| `architecture/sequence-diagram.mmd:34-36` | Ansible hardens base OS automatically during builder EC2 execution before middleware setup. |
| `architecture/aws-migration-cicd.mmd:79-85` | Middleware-specific Ansible baselines (`D2A/D2B/D2C`) are auto-applied for WebLogic, Tomcat, and Python. |
| `process-flow-diagram.md:34` | CMDB-selected SSM pre-check/compliance runbook is auto-triggered before image bake. |
| `process-flow-diagram.md:59` | Post-build SSM document executes remediation baseline and inventory capture automatically. |
| `architecture/full-pipeline-tech-stack.md:row 13` | Ansible is defined as hardening/configuration-as-code engine in pipeline design. |
| `architecture/target-component-context.mmd:G4-G5` | Policy gate approves and Enforce Repo Baseline re-applies approved controls for remediation events. |
| `architecture/component-context-diagram.mmd:SGATE, IGATE` | Security/image scan failures auto-route remediation back to ServiceNow instead of manual handling. |

_Scenario 2 – Validate security hardening and patches after application_

| Evidence | Traceability |
|---|---|
| `architecture/component-context-diagram.mmd:AMISCAN, IGATE` | Inspector + ECR enhanced scan validates build outputs; failures are blocked and recorded via gate flow. |
| `architecture/sequence-diagram.mmd:36` | Builder returns streaming logs and success/failure status for hardening execution validation. |
| `process-flow-diagram.md:49-51` | Middleware flow includes explicit verify step before AMI serialization. |
| `architecture/sequence-diagram.mmd:45-46` | AMI ID + Ansible evidence are patched back to ServiceNow/CMDB for audit traceability. |
| `process-flow-diagram.md:59-62` | Post-build SSM inventory provides installed-state validation evidence back to pipeline. |
| `architecture/full-pipeline-tech-stack.md:rows 18-19` | Security Hub/GuardDuty/EventBridge detect non-compliance continuously and trigger automated response workflows. |
| `architecture/target-component-context.mmd:G6` | Convergence verification records compliant/non-compliant outcomes to security and CMDB systems. |
| `architecture/target-component-context.mmd:H4` | Database post-remediation validation confirms patch/control application and publishes findings. |
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

**Status**: **Partially Met**

**Scenario Compliance Summary**

| Scenario | Requirement Expectation | Verdict | Key References |
|---|---|---|---|
| Continuous Configuration Compliance Monitoring | Systems are automatically assessed against approved configuration and patch baselines when deployed or updated. | **Met** | `architecture/target-component-context.mmd:49-56,91-99`, `architecture/sequence-diagram.mmd:48-79`, `architecture/component-context-diagram.mmd:74-78`, `architecture/full-pipeline-tech-stack.md:18-22` |
| Evidence Generation and Storage | Results are stored with timestamps, system identifiers, baseline references, and compliance status. | **Partially Met** | `architecture/sequence-diagram.mmd:45-46,51,63,76,78`, `process-flow-diagram.md:59-62`, `architecture/component-context-diagram.mmd:77-78`, `architecture/target-component-context.mmd:17-25` |
| Audit Reporting | Historical and current compliance status can be exported in clear reports across systems. | **Partially Met** | `architecture/target-component-context.md:22-24`, `architecture/full-pipeline-tech-stack.md:22-24`, `architecture/component-context-diagram.mmd:74-78` |
| Integrity and Auditability of Evidence | Evidence storage is tamper-evident and all changes/access maintain a complete audit trail. | **Not Met** | No explicit immutable evidence store, access audit trail, or tamper-evident control is modeled in the current diagrams. |
| Security hardening and patches are validated after application | Applied controls and patches are verified, and failures/non-compliance are detected and recorded. | **Met** | `architecture/component-context-diagram.mmd:24-26,69-78`, `architecture/sequence-diagram.mmd:35-46`, `process-flow-diagram.md:49-62`, `architecture/target-component-context.mmd:55-56,62,96-106` |

**Traceability Evidence**

_Scenario 1 – Continuous Configuration Compliance Monitoring_

| Evidence | Traceability |
|---|---|
| `architecture/target-component-context.mmd:49-56,91-99` | EventBridge scheduled reconciliation, drift comparison, findings publication, policy decision, baseline enforcement, and convergence verification together implement continuous compliance monitoring against the approved baseline. |
| `architecture/sequence-diagram.mmd:48-79` | The sequence diagram models recurring compliance assessment for both infrastructure and databases, with detected drift or compliant state recorded back into ServiceNow. |
| `architecture/component-context-diagram.mmd:74-78` | Runtime security posture and SSM inventory state are fed back into central governance systems for ongoing compliance visibility. |
| `architecture/full-pipeline-tech-stack.md:18-22` | Security Hub, GuardDuty, IAM Access Analyzer, and SSM Inventory provide continuous security and configuration posture monitoring. |

_Scenario 2 – Evidence Generation and Storage_

| Evidence | Traceability |
|---|---|
| `architecture/sequence-diagram.mmd:45-46` | CMDB and change records are updated with AMI identifiers and Ansible execution evidence, forming auditable deployment records. |
| `architecture/sequence-diagram.mmd:51,63,76,78` | Drift findings, closure evidence, DB remediation evidence, and compliant-state records are published to ServiceNow, providing stored compliance outcomes over time. |
| `process-flow-diagram.md:59-62` | Post-build SSM inventory capture and execution IDs are collected and sent back to ServiceNow, supporting evidence records with system context. |
| `architecture/component-context-diagram.mmd:77-78` | SSM Inventory syncs runtime state into CMDB, improving evidence completeness for software/OS compliance status. |
| `architecture/target-component-context.mmd:17-25,30-31` | Release manifest, approved AMI parameters, and SBOM/provenance provide baseline references that can be linked to compliance evidence. |
| Gap | The current diagrams do not explicitly show a normalized evidence record containing timestamp, system ID, baseline reference, and compliance status in one governed evidence store. |

_Scenario 3 – Audit Reporting_

| Evidence | Traceability |
|---|---|
| `architecture/full-pipeline-tech-stack.md:22-24` | CMDB sync, CloudWatch telemetry, and alerting provide the raw data sources needed for reporting. |
| `architecture/target-component-context.md:22-24` | Observability and security posture capabilities support review and investigation of current state. |
| `architecture/component-context-diagram.mmd:74-78` | Runtime findings and inventory are already aggregated into central systems, which supports report generation inputs. |
| Gap | No explicit reporting service, export workflow, dashboard-to-report path, or historical compliance report artifact is modeled for auditors. |

_Scenario 4 – Integrity and Auditability of Evidence_

| Evidence | Traceability |
|---|---|
| Gap | The architecture does not explicitly model immutable/WORM evidence storage, cryptographic integrity protection, evidence retention controls, or access/change audit logs for stored compliance evidence. |
| Gap | There is no explicit service such as CloudTrail, AWS Audit Manager, Security Lake, signed evidence manifests, or S3 Object Lock shown to make evidence tamper-evident and fully auditable. |

_Scenario 5 – Security hardening and patches are validated after application_

| Evidence | Traceability |
|---|---|
| `architecture/component-context-diagram.mmd:24-26,69-78` | Inspector/ECR scan gates, runtime security posture, and inventory feedback detect and record post-application compliance state. |
| `architecture/sequence-diagram.mmd:35-46` | Builder execution returns logs/status and writes AMI plus execution evidence back to CMDB for auditability. |
| `process-flow-diagram.md:49-62` | Middleware verification, post-build inventory capture, and callback to ServiceNow record the validation outcome. |
| `architecture/target-component-context.mmd:55-56,62,96-106` | Convergence verification and post-remediation DB validation confirm remediation success and publish findings into the compliance evidence loop. |

**Required Enhancements to Fully Meet App_as_Code_004**

| Gap Area | Needed Architectural Addition |
|---|---|
| Central evidence record | Add a dedicated compliance evidence store that captures timestamp, system identifier, baseline reference, control/patch result, and remediation status for every assessment. |
| Exportable audit reporting | Add an explicit reporting layer that can generate current and historical compliance reports from CMDB, Security Hub, inventory, and drift findings for audit export. |
| Tamper-evident evidence | Add immutable evidence storage and integrity controls, such as signed evidence artifacts and retention-protected storage. |
| Audit trail of access and change | Add explicit access/change logging for evidence reads and updates so reviewers can trace who accessed or modified evidence and when. |

**Architect Verdict**
- App_as_Code_004 is only **partially fulfilled** by the current architecture. The solution already provides strong continuous monitoring and validation signals through drift reconciliation, Security Hub/GuardDuty, SSM Inventory, CMDB updates, and post-remediation verification. However, the architecture does not yet explicitly model a dedicated auditable evidence repository, an exportable cross-system reporting capability, or tamper-evident evidence storage with a complete access/change audit trail. Those additions are required before the requirement can be marked fully met.

### 5) Requirement 5 (ID to be confirmed)
**Status**: Pending input

### 6) Requirement 6 (ID to be confirmed)
**Status**: Pending input

### 7) Requirement 7 (ID to be confirmed)
**Status**: Pending input

### 8) Requirement 8 (ID to be confirmed)
**Status**: Pending input
