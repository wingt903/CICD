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

- `architecture/sequence-diagram.mmd:34-36`  
  The inner-loop Ansible execution on the temporary builder EC2 explicitly **hardens the base OS** as step 1, before middleware configuration and artifact injection. This ensures every golden AMI has hardening baked in automatically.
- `architecture/aws-migration-cicd.mmd:79-85`  
  Stage 4 selects the appropriate middleware profile (WebLogic / Tomcat / Python) and applies the corresponding Ansible baseline (`D2A`, `D2B`, `D2C`). Hardening and configuration are applied automatically as part of the pipeline, not manually.
- `process-flow-diagram.md:34`  
  A CMDB-selected **SSM Automation Document pre-check/compliance runbook** is triggered before image baking (`M1`), ensuring any required pre-patch validation or remediation baseline is enforced prior to AMI construction.
- `process-flow-diagram.md:59`  
  A **post-build SSM Document** (`V`) executes inventory capture and applies the remediation baseline after the image is serialised, confirming the hardening state of the resulting AMI before it is registered.
- `architecture/full-pipeline-tech-stack.md:row 13`  
  Ansible is the designated configuration and hardening engine: *"Applies OS hardening and middleware/application configuration as code."* Hardening playbooks are version-controlled and run automatically through the pipeline.
- `architecture/target-component-context.mmd:G4-G5`  
  For already-deployed components identified as requiring security remediation, the **Policy Decision and Approval Gate** (`G4`) authorises the **Enforce Repo Baseline** step (`G5`), which re-applies Terraform and configuration controls automatically to return the live environment to the approved secure baseline.
- `architecture/component-context-diagram.mmd:SGATE, IGATE`  
  Failed security or image scan gates block promotion and raise a **remediation request back to ServiceNow** (`SGATE → SN`, `IGATE → SN`), ensuring the pipeline automatically initiates the remediation cycle rather than allowing a non-compliant artefact to proceed.

_Scenario 2 – Validate security hardening and patches after application_

- `architecture/component-context-diagram.mmd:AMISCAN, IGATE`  
  After every image build, **Amazon Inspector + ECR Enhanced Scanning** (`AMISCAN`) analyses the golden AMI for residual vulnerabilities. The result flows into the **Image Scan Gate** (`IGATE`): a failed scan blocks deployment and routes to ServiceNow for recording. This is the automated post-application validation gate.
- `architecture/sequence-diagram.mmd:36`  
  The builder EC2 returns **streaming logs and a success/failure code** (`EC2-->>GH`) immediately after Ansible execution, giving the pipeline real-time confirmation (or failure signal) of the hardening run outcome.
- `process-flow-diagram.md:49-51`  
  Each middleware Ansible block ends with **"Verify Configurations & Shutdown Instance"** (`S`), an automated in-pipeline validation step that confirms the expected configuration state before the instance is serialised as an AMI.
- `architecture/sequence-diagram.mmd:45-46`  
  The pipeline sends an **API Patch to ServiceNow** containing the new AMI ID and Ansible execution references. The CMDB CI and change record are updated with this evidence, creating an auditable compliance record of what hardening was applied and when.
- `process-flow-diagram.md:59-62`  
  The **post-build SSM Document and SSM Inventory capture** (`V–W`) collect runtime software and OS state from the managed node and feed that back through GitHub Actions, providing an authoritative inventory of what is actually installed versus what was expected.
- `architecture/full-pipeline-tech-stack.md:rows 18-19`  
  **Amazon GuardDuty + AWS Security Hub + Amazon EventBridge** provide continuous post-deployment threat detection and security posture monitoring. Security Hub centralises findings, and EventBridge triggers automated containment or remediation workflows when non-compliance or a threat is detected at runtime — fulfilling the requirement to detect and record failures without manual intervention.
- `architecture/target-component-context.mmd:G6`  
  The **Convergence Verification** step (`G6`) runs after every baseline enforcement cycle, confirms that the live environment matches the desired baseline, and publishes closure evidence back to CloudWatch, Security Hub, and the CMDB — recording the result whether it is compliant or not.
- `architecture/target-component-context.mmd:H4`  
  For database components, **Post-Remediation DB Validation** (`H4`) executes after every migration or rollback, with findings published to the shared findings store (`G3`) and ServiceNow — ensuring database-level patch and configuration compliance is also validated and recorded.
- `architecture/full-pipeline-tech-stack.md:row 15`  
  **tfsec + Checkov** (`C2`) perform pre-apply IaC policy scans, blocking any infrastructure change that introduces a non-compliant or insecure configuration before it reaches any environment — preventing hardening regressions at the infrastructure layer.

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
