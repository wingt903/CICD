# App as Code – Architecture Baseline (v1)

| Field | Value |
|---|---|
| Baseline Version | v1.0 |
| Baseline Date | 2026-06-16 |
| Status | **Frozen** |
| Owner | Platform Engineering Team |
| Next Review | On material scope change only |

> **FROZEN BASELINE.** This document and all canonical artefacts listed below represent the authoritative, agreed architecture for the **App as Code CI/CD platform** (Phase 1). No content in these artefacts should be altered unless a formal correction is required. New projects (e.g., IPU v2) must document their divergence in a separate delta document rather than editing this baseline.

---

## 1. Purpose

This document serves as the single entry point for the App as Code Architecture Baseline. It:

- Declares the scope boundary of the frozen architecture.
- Lists every canonical artefact that forms the baseline.
- Distinguishes stable platform patterns (reusable by future projects) from App-as-Code-specific design decisions (subject to change for other projects).
- Defines document governance rules to protect baseline integrity.

---

## 2. Scope of the Frozen Architecture

### 2.1 In Scope

| Area | Description |
|---|---|
| CI/CD Orchestration | GitHub Actions-based pipeline for build, scan, test, release, and environment promotion. |
| Identity & Trust | AWS IAM OIDC federation for GitHub Actions; no long-lived pipeline credentials. |
| Image Build & Configuration | Ansible-driven AMI build and OS/middleware configuration; golden AMI registry in EC2 AMI Registry. |
| Runtime Baseline Governance | Runtime Technology Compatibility Matrix (RTCM) stored in `architecture/runtime-compatibility-matrix.json` and SSM Parameter Store. |
| Infrastructure Provisioning | Terraform for environment-specific AWS runtime infrastructure; tfsec + Checkov for IaC policy gates. |
| Security Gates | SAST / dependency / secret scanning via GitHub Advanced Security; image scanning via Amazon Inspector + ECR. |
| Promotion Controls | GitHub Environments (`dev → test → prod`) with required approvals; fail-closed SSM Decision Records blocking re-deploy of rejected releases. |
| Drift Detection & Remediation | EventBridge Scheduler-triggered drift scans; automated restore-to-baseline via Terraform, Ansible, and DB migration controls. |
| Compliance Evidence & Audit | EventBridge Evidence Bus → Evidence Ingestor Lambda → S3 (Object Lock, SSE-KMS, 7-year retention) → CloudTrail. Phase 2 schema/storage draft deferred. |
| Observability & Reporting | Datadog for compliance posture dashboards, drift alerts, and remediation outcomes backed by immutable S3 evidence. |
| Secrets Management | AWS Secrets Manager for runtime secrets; SSM Parameter Store for config; GitHub Encrypted Secrets for CI bootstrap; AWS KMS CMKs for signing. |
| Application Team Repository Models | Supports both **one-repo-per-environment** and **one-repo-for-all-environments** models under the same mandatory controls. |

### 2.2 Out of Scope (Phase 1)

| Area | Disposition |
|---|---|
| ServiceNow integration | Phase 2 target state. Phase 1 uses GitHub-governed approvals and manual ITSM/CMDB handoff. |
| Digital signature controls | Explicitly excluded unless re-scoped by the platform team. |
| FR-04 evidence schema / reporting | Detailed schema and reporting controls deferred to Phase 2 for further clarification. |
| Application source-code logic / testing | Platform governs runtime environment only; app-code behaviour is excluded from compliance scope. |

---

## 3. Canonical Artefact Index

The following files are the frozen baseline artefacts. Any change to these files must be treated as a **baseline correction**, reviewed, and re-approved before merging.

| Artefact | Path | Description |
|---|---|---|
| Architecture Baseline (this document) | `architecture/app-as-code-architecture-baseline.md` | Single entry point and governance index for the frozen baseline. |
| Component Context Diagram (Mermaid/draw.io) | `architecture/component-context-diagram.mmd` | Canonical component integration diagram; all flow IDs are the primary traceability evidence. |
| Component Context Integration Reference | `architecture/component-context-diagram.md` | Prose explanation of every numbered integration flow. |
| Full Pipeline Technology Stack | `architecture/full-pipeline-tech-stack.md` | Layer-by-layer technology selection rationale and detailed component descriptions. |
| Requirement Traceability Matrix | `architecture/requirement-traceability.md` | Maps App_as_Code_001–008 to diagram flow IDs with verdicts and notes. |
| C4 Level 1 – Context Diagram | `architecture/c4-context-drawio.mmd` | System context: actors, platform boundary, and external integrations. |
| C4 Level 2 – Container Diagram | `architecture/c4-container-drawio.mmd` | Container-level decomposition of the platform. |
| C4 Level 3 – Component Diagram | `architecture/c4-component-drawio.mmd` | Component-level decomposition of key containers. |
| Data Architecture ERD | `architecture/data-architecture-erd.md` | Focused ERD for six core platform entities and their ownership model. |
| Data Architecture ERD Diagram | `architecture/data-architecture-erd.mmd` | Mermaid ERD source (draw.io-compatible). |
| Sequence Diagram | `architecture/sequence-diagram.md` | End-to-end flow: commit approval → drift scan → remediation → audit. |
| Sequence Diagram Source | `architecture/sequence-diagram.mmd` | Mermaid sequence diagram source. |
| Non-Functional Requirements | `architecture/nfr.md` | Quality attributes, reliability, security, and compliance targets for the platform. |
| Secrets Management Strategy | `architecture/secrets-management-strategy.md` | HLD-level secrets classification, approved stores, and access/rotation posture. |
| Compliance Evidence Store | `architecture/compliance-evidence-store.md` | Evidence schema, storage controls, and audit trail design (Phase 2 draft sections noted inline). |
| Runtime Compatibility Matrix | `architecture/runtime-compatibility-matrix.json` | Approved application, middleware, and database version baseline. |

---

## 4. Stable Platform Patterns (Reusable by Future Projects)

The following patterns are generic enough that future projects (including IPU v2) should inherit them rather than redefine them. Any future project wishing to deviate from these must justify the deviation in its own delta document.

| Pattern | Description |
|---|---|
| **GitHub Actions orchestration** | Event-driven pipeline engine; matrix build and environment-promotion model. |
| **OIDC to AWS federation** | Federated, short-lived credentials for all pipeline–AWS interactions; no long-lived keys. |
| **Terraform + Ansible split** | Terraform provisions environment infrastructure; Ansible configures OS/middleware/app layer inside instances and builds golden AMIs. |
| **Compliance evidence model** | All pipeline gates, scan results, RTCM decisions, and drift outcomes produce normalised evidence events published to the EventBridge Evidence Bus. |
| **S3 Object Lock evidence store** | Signed, immutable, append-only evidence archive in S3 with Object Lock (Governance mode, 7-year minimum). |
| **Fail-closed promotion controls** | Release identities that fail a gate are blocked from re-deployment via SSM Decision Records until a new, validated release identity is produced. |
| **CloudTrail audit trail** | All evidence access and change events are captured in a separate write-once CloudTrail audit bucket. |
| **Datadog observability** | Compliance posture, drift, and remediation dashboards fed from S3-backed evidence records. |
| **RTCM policy gate** | Pre-install runtime version validation that reads approved versions from SSM Parameter Store and fails closed on unsupported stacks. |
| **Secrets governance** | Three-tier storage: Secrets Manager (runtime secrets), SSM Parameter Store (config), GitHub Encrypted Secrets (CI bootstrap). |

---

## 5. App-as-Code-Specific Design Decisions (May Change for Future Projects)

The following decisions are specific to the App as Code project scope and should be re-evaluated by any future project before assuming they apply.

| Decision | App as Code Rationale | IPU / Other Project Consideration |
|---|---|---|
| **Onboarding flow** | Product Team submits a GitHub-governed migration request; Phase 2 will route through ServiceNow catalog. | IPU v2 may have a different intake model (e.g., direct upgrade trigger, no ServiceNow). |
| **Runtime targets** | WebLogic, Tomcat, Python — containerised or AMI-based. | IPU v2 may target different middleware or in-place upgrade paths rather than AMI replacement. |
| **Migration / remediation flows** | Ansible restore-to-baseline; DB schema migration with rollback. | IPU v2 may require OS-level in-place upgrade logic, different rollback strategies, or vendor-specific upgrade tooling. |
| **Compliance scope** | Platform/runtime compliance only; application source-code logic explicitly excluded. | IPU v2 must define its own compliance boundary, particularly if OS-level changes expand or contract the scope. |
| **Repository models** | One-repo-per-environment and one-repo-for-all-environments both supported. | IPU v2 may use a single dedicated upgrade orchestration repository model. |
| **AMI as deployment unit** | Golden AMI is the primary deployable artifact for OS/middleware. | IPU v2 in-place upgrades may not produce a new AMI; the deployment unit is the upgraded running instance. |

---

## 6. Document Governance

| Rule | Detail |
|---|---|
| **Baseline documents: change only for corrections** | A correction is a factual error, inconsistency, or agreed re-scope. Style edits, additions related to new projects, and speculative future-state content are not corrections. |
| **New project deltas: separate document** | IPU v2 and all future projects must document their architecture in a separate delta document that references this baseline. Do not edit baseline artefacts to accommodate new project decisions. |
| **Shared pattern changes: baseline first** | If a change affects a pattern listed in Section 4, update this baseline artefact first, get it reviewed, and then update all referencing delta documents. |
| **Traceability: baseline RTM is frozen** | `architecture/requirement-traceability.md` is the frozen App as Code traceability record. Future projects must create their own RTM referencing their own requirement IDs. |
| **Diagram standards** | All diagrams must be draw.io-compatible Mermaid sources. Do not create parallel non-draw.io copies. |

---

## 7. Cross-References

| Document | Relationship |
|---|---|
| [`architecture/ipu-v2-delta-assessment.md`](./ipu-v2-delta-assessment.md) | IPU v2 architecture delta; identifies what is reused, modified, or new relative to this baseline. |
| [`architecture/requirement-traceability.md`](./requirement-traceability.md) | Frozen App as Code requirement-to-architecture mapping (App_as_Code_001–008). |
| [`architecture/full-pipeline-tech-stack.md`](./full-pipeline-tech-stack.md) | Full technology selection detail behind every layer in the baseline. |
