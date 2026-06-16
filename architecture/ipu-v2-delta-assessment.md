# IPU v2 (In-Place Upgrade as a Service) – Architecture Delta Assessment

| Field | Value |
|---|---|
| Document Version | v0.1 (Draft) |
| Date | 2026-06-16 |
| Status | **In Progress** |
| Owner | Platform Engineering Team |
| Baseline Reference | [`architecture/app-as-code-architecture-baseline.md`](./app-as-code-architecture-baseline.md) v1.0 |

> **Delta document.** This document captures how the IPU v2 project relates to the frozen App as Code Architecture Baseline (v1.0). It does not restate the full baseline; it records only decisions that are reused, modified, or new. All patterns not listed as modified or new should be treated as inherited unchanged from the baseline.

---

## 1. Purpose

IPU v2 (In-Place Upgrade as a Service) is a related platform capability that enables controlled, governed, in-place operating system and middleware upgrades on existing running instances — without replacing them with a new AMI. While IPU v2 shares significant orchestration and governance patterns with the App as Code platform, its upgrade model, deployment unit, and compliance boundary differ materially.

This document:

- Establishes which baseline patterns IPU v2 **reuses as-is**.
- Identifies which patterns IPU v2 **reuses with modification**.
- Captures what is **new for IPU v2** only.
- Records open questions and assumptions that require clarification before IPU v2 architecture is finalised.

---

## 2. Baseline Inherited as-Is

The following platform patterns from the App as Code baseline are inherited by IPU v2 without modification. IPU v2 must not redefine these patterns; it must integrate with the existing implementations.

| Pattern | Baseline Reference | IPU v2 Usage |
|---|---|---|
| GitHub Actions orchestration | `full-pipeline-tech-stack.md` §2 | IPU v2 upgrade workflows run as GitHub Actions jobs using the same event-driven, environment-gated model. |
| OIDC to AWS federation | `full-pipeline-tech-stack.md` §3 | All IPU v2 pipeline–AWS interactions use OIDC-federated, short-lived credentials. No long-lived keys introduced. |
| RTCM policy gate | `full-pipeline-tech-stack.md` §2.1 | Pre-upgrade version validation reads the approved baseline from SSM Parameter Store and fails closed on unsupported target OS/middleware versions. |
| Fail-closed promotion controls (SSM Decision Records) | `component-context-diagram.md` flows 36–38 | IPU v2 upgrade decisions (approved / blocked) are written as SSM Decision Records. A blocked upgrade identity cannot be re-triggered until resolved. |
| Compliance evidence model (EventBridge Evidence Bus) | `component-context-diagram.md` flows 77–89 | All IPU v2 upgrade gate results, pre-check outcomes, and post-upgrade validation results are published as evidence events to the shared EventBridge Evidence Bus. |
| S3 Object Lock evidence store | `full-pipeline-tech-stack.md` §7 | IPU v2 evidence records land in the same immutable S3 evidence bucket with Object Lock and SSE-KMS. |
| CloudTrail audit trail | `full-pipeline-tech-stack.md` §7 | All IPU v2 evidence access and changes are captured by the existing CloudTrail configuration. |
| Datadog observability | `full-pipeline-tech-stack.md` §(Audit Reporting) | IPU v2 upgrade posture and compliance outcomes appear in Datadog dashboards alongside App as Code data. |
| Secrets governance (three-tier storage) | `secrets-management-strategy.md` | IPU v2 uses Secrets Manager for runtime credentials, SSM Parameter Store for config, and GitHub Encrypted Secrets for CI bootstrap values. |
| IaC policy gates (tfsec + Checkov) | `full-pipeline-tech-stack.md` §(IaC Security) | Any IaC changes introduced by IPU v2 workflows are scanned with tfsec and Checkov before apply. |
| GitHub Advanced Security scanning | `full-pipeline-tech-stack.md` §(Application Security) | IPU v2 workflow and playbook code is subject to the same SAST, dependency, and secret scanning controls. |

---

## 3. Baseline Patterns Reused with Modification

The following patterns are inherited from the baseline but require adjustment to fit the IPU v2 in-place upgrade model. Each modification must be designed, reviewed, and documented here before implementation.

| Pattern | Baseline Behaviour | IPU v2 Modification | Rationale |
|---|---|---|---|
| **Ansible automation role** | Builds golden AMIs from scratch on a temporary builder EC2; produces an immutable image as the deployment unit. | Ansible runs upgrade playbooks against live running instances instead of building new AMIs. Ansible is the primary in-place change agent, not an image factory. | In-place upgrades modify existing instances rather than replacing them; no new AMI is produced per upgrade run. |
| **Deployment unit** | Golden AMI (immutable image) promoted through environments. | The deployment unit is the upgrade playbook + RTCM-approved target version set, not an AMI. Release identity is still recorded, but it references a playbook version and target version set rather than an AMI digest. | IPU v2 does not produce a new AMI; the running instance is upgraded in-place. |
| **Drift detection scope** | Compares live environment state against approved baseline (RTCM + IaC + release manifest). | Drift detection must additionally compare installed OS/middleware version against the post-upgrade approved target state. Rollback baseline is the pre-upgrade snapshot, not a prior AMI. | The drift model must be extended to track upgrade completion state and detect regression to pre-upgrade versions. |
| **Rollback mechanism** | Blue/green or canary switch; AMI rollback via SSM Parameter Store approved AMI path; IaC revert pipeline. | Rollback is an Ansible-driven restore-to-prior-version playbook using a pre-upgrade configuration snapshot or OS-level rollback capability. Blue/green AMI switch is not applicable. | No new AMI means no simple AMI-based rollback; rollback must be handled at the OS/package management level. |
| **Onboarding / intake flow** | Product Team submits a GitHub-governed migration request; Phase 2 routes through ServiceNow catalog. | *(TBD — see Section 5)* IPU v2 intake may be triggered by a scheduled upgrade campaign, a ServiceNow change order, or a direct operator dispatch. The intake model must be defined. | The upgrade trigger model for IPU v2 is not yet confirmed. |
| **Compliance scope boundary** | Platform/runtime compliance only; app source-code logic excluded. | Scope must be extended to cover OS-level package state, kernel version, and middleware upgrade completion as compliance dimensions. App source-code logic remains excluded. | In-place OS/middleware upgrades expand the compliance surface to include OS-layer artefacts not present in the AMI-replacement model. |
| **Runtime targets** | WebLogic, Tomcat, Python on AMI-based or container-based workloads. | *(TBD — see Section 5)* IPU v2 target runtimes and OS families (e.g., RHEL, Amazon Linux) must be declared and added to the RTCM. | The runtime target scope for IPU v2 has not yet been confirmed. |

---

## 4. New for IPU v2 Only

The following components and capabilities are net new for IPU v2 and have no direct equivalent in the App as Code baseline.

| Component / Capability | Description | Baseline Gap |
|---|---|---|
| **Pre-upgrade health snapshot** | Before any in-place upgrade begins, capture a full snapshot of the instance state (OS version, installed packages, running services, configuration files) as a pre-upgrade baseline record. Stored as an evidence event and used as the rollback reference point. | App as Code baseline has no concept of a pre-change instance snapshot; it relies on AMI as the prior-state artifact. |
| **Upgrade Orchestrator** | A dedicated Ansible playbook or workflow that sequences the upgrade steps: pre-check → snapshot → upgrade → post-upgrade validation → evidence publication → decision record. Replaces the AMI build pipeline as the primary upgrade pipeline stage. | Not present in the baseline; replaces the image-build pipeline for IPU v2. |
| **Post-upgrade validation gate** | After upgrade completion, run automated checks (OS version match, service health, RTCM compliance) to confirm the instance reached the target state. Publish pass/fail as evidence. Fail closed if validation fails; trigger rollback. | App as Code validates artifacts before deployment (image scan gate). IPU v2 requires validation after in-place change, against the running instance. |
| **Rollback playbook (in-place)** | An Ansible playbook that restores the instance to the pre-upgrade snapshot state, using package manager rollback, config file restore, or service-level recovery. | Baseline rollback uses AMI swap or IaC revert. In-place rollback is a distinct operation requiring new tooling. |
| **Upgrade campaign management** | If upgrades are applied across a fleet of instances, IPU v2 requires batching, sequencing, and rollout controls (e.g., canary percentage, pause-on-failure, per-environment approvals) that are not needed in the single-release AMI model. | Not modelled in the baseline; needed for large-scale in-place upgrade coordination. |
| **Pre-upgrade compatibility check** | Before executing the upgrade, verify that the target OS/middleware version is compatible with the running application version using the RTCM. Fail closed if the combination is not approved. | RTCM validation in the baseline checks incoming stack versions before image build, not runtime compatibility of existing app + new OS version combinations. |
| **IPU v2 Requirement Traceability Matrix** | A separate RTM mapping IPU v2-specific requirements (to be defined) to flow IDs, design decisions, and evidence sources. | The baseline RTM (`requirement-traceability.md`) covers App as Code 001–008 only and must not be modified for IPU v2. |

---

## 5. Open Questions and Assumptions

The following items require clarification from the product/architecture team before IPU v2 design can be finalised. Until resolved, no IPU v2-specific architecture decisions should be treated as agreed.

| # | Question | Impact |
|---|---|---|
| OQ-01 | What is the upgrade intake / trigger model? (Scheduled campaign, ServiceNow change order, operator GitHub dispatch?) | Determines the onboarding flow modification in Section 3 and whether the ServiceNow Phase 2 integration applies earlier for IPU. |
| OQ-02 | What OS families and middleware versions are in scope for IPU v2? | Required to extend the RTCM with IPU v2-approved target versions and compatibility rules. |
| OQ-03 | Does IPU v2 share the same GitHub Organisation, repository, and AWS account structure as App as Code? | Determines whether IPU v2 uses the same OIDC role structure, SSM paths, and environment names, or needs separate isolation. |
| OQ-04 | Is the compliance boundary for IPU v2 confirmed to include OS-layer artefacts? | Required to scope the compliance evidence model and drift detection extensions in Section 3. |
| OQ-05 | What is the rollback SLA and acceptable data-loss window for a failed in-place upgrade? | Determines the depth of the pre-upgrade snapshot and the rollback playbook design. |
| OQ-06 | Are there regulatory or change management requirements (e.g., CAB approval gates) specific to IPU v2 that are not present in App as Code? | May introduce new governance steps not currently modelled in the baseline pipeline. |
| OQ-07 | Does IPU v2 need to operate on instances not currently managed by Terraform (i.e., manually provisioned legacy instances)? | Affects whether Terraform state is available as a drift comparison baseline for IPU v2 targets. |

---

## 6. IPU v2 Document Index (Planned)

The following documents will be created as IPU v2 architecture is defined. Until they exist, this delta assessment is the sole IPU v2 architecture record.

| Document | Path | Status |
|---|---|---|
| IPU v2 Architecture Delta Assessment (this document) | `architecture/ipu-v2-delta-assessment.md` | Draft |
| IPU v2 Requirement Traceability Matrix | `architecture/ipu-v2-requirement-traceability.md` | Not started |
| IPU v2 Component Context Diagram | `architecture/ipu-v2-component-context.mmd` | Not started |
| IPU v2 Technology Stack | `architecture/ipu-v2-tech-stack.md` | Not started |
| IPU v2 Sequence Diagram | `architecture/ipu-v2-sequence-diagram.mmd` | Not started |

---

## 7. Cross-References

| Document | Relationship |
|---|---|
| [`architecture/app-as-code-architecture-baseline.md`](./app-as-code-architecture-baseline.md) | Frozen baseline this document assesses against. |
| [`architecture/requirement-traceability.md`](./requirement-traceability.md) | Frozen App as Code RTM; do not modify for IPU v2. |
| [`architecture/full-pipeline-tech-stack.md`](./full-pipeline-tech-stack.md) | Baseline technology stack detail inherited by IPU v2. |
| [`architecture/component-context-diagram.md`](./component-context-diagram.md) | Baseline integration flows inherited or modified by IPU v2. |
