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

### 4) Requirement 4 (ID to be confirmed)
**Status**: Pending input

### 5) Requirement 5 (ID to be confirmed)
**Status**: Pending input

### 6) Requirement 6 (ID to be confirmed)
**Status**: Pending input

### 7) Requirement 7 (ID to be confirmed)
**Status**: Pending input

### 8) Requirement 8 (ID to be confirmed)
**Status**: Pending input
