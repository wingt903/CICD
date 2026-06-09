# Data Architecture – Entity-Relationship View

This document provides the data architecture model for the **App as Code CICD Platform**. It covers the key data entities, their relationships, ownership boundaries, and any personal-data (PII) fields.

> **Diagram source:** `data-architecture-erd.mmd` (draw.io-compatible Mermaid `erDiagram`).

---

## Scope and Ownership Boundaries

| Boundary | What it means |
|----------|---------------|
| **CICD Platform owned** | Data created, stored, and lifecycle-managed by the CICD platform (AWS-hosted stores: S3, DynamoDB, SSM Parameter Store, CloudTrail, CloudWatch). |
| **External – App Team** | Application source code repositories. The platform reads webhook events from these repos but stores no copy of the code. |
| **External – IaC Team** | Infrastructure / IaC / Ansible repositories. Same read-only relationship; no code copy stored. |
| **External – Identity** | GitHub user identities and IAM principals. Mastered in GitHub and AWS IAM respectively. |

> **Key constraint:** The CICD platform does **not** own or store application code or IaC code. The only externally-originated data the platform stores are **AWS logs** (CloudTrail, CloudWatch, GuardDuty) and **GitHub logs** (Actions job logs) that it ingests for audit and compliance purposes.

---

## Entity Catalogue

### External Entities (not owned by CICD platform)

| Entity | Description | Ownership |
|--------|-------------|-----------|
| `ACTOR` | A human user who interacts with the platform — App Owner, Platform Engineer, or Cyber Security Operations Analyst. | External – GitHub / AWS IAM |
| `APP_CODE_REPO` | A GitHub repository containing application source code managed by the Product Team. | External – App Team |
| `IAC_REPO` | A GitHub repository containing Terraform, Ansible, or image-build configuration managed by the Platform Engineering team. | External – IaC Team |

---

### CICD Platform Owned Entities

| Entity | Store | Description |
|--------|-------|-------------|
| `GOVERNING_TEMPLATE` | GitHub Template Repos | A versioned, CODEOWNERS-governed pipeline template that enforces mandatory controls for all pipeline runs. |
| `PIPELINE_RUN` | GitHub Actions metadata + DynamoDB | A single execution of a GitHub Actions workflow, triggered by a push, PR, or manual dispatch event. |
| `GATE_RESULT` | DynamoDB / EventBridge | The pass/fail outcome of one security or compliance gate within a pipeline run (RTCM, SAST, IaC scan, image scan, secret scan). |
| `APPROVED_BASELINE` | SSM Parameter Store | The approved runtime compatibility version for a given component, published after a governed commit is accepted. |
| `GOLDEN_AMI` | EC2 AMI Registry (AWS) | A hardened Amazon Machine Image produced by the Ansible build pipeline and verified by AWS Inspector. |
| `RELEASE_MANIFEST` | SSM Parameter Store + DynamoDB | The authoritative record of an approved release: AMI ID, IaC version, image digest, and target environment. |
| `SSM_DECISION_RECORD` | SSM Parameter Store | A no-redeploy governance record for a release identity and environment. Enforces fail-closed: a blocked release cannot be re-deployed. |
| `DRIFT_EVENT` | DynamoDB + EventBridge | A detected deviation between the live environment state and the approved baseline, raised by the scheduled drift scan. |
| `EVIDENCE_RECORD` | S3 (Object Lock, SSE-KMS) | An immutable, tamper-evident record of a pipeline or compliance event written to the evidence bucket. |
| `AUDIT_ENTRY` | DynamoDB | A queryable index record derived from an `EVIDENCE_RECORD`, used by Splunk and Grafana for reporting. |
| `AWS_LOG` | CloudTrail / CloudWatch / GuardDuty | AWS-platform-generated log events ingested by the CICD platform for audit and security posture evidence. |
| `GITHUB_LOG` | S3 (archived from GitHub Actions) | Job-level execution logs from GitHub Actions, archived to S3 for long-term audit retention. |

---

## Relationship Summary

| Relationship | Cardinality | Notes |
|---|---|---|
| `ACTOR` → `PIPELINE_RUN` | 1-to-many | One actor can trigger many pipeline runs over time. |
| `ACTOR` → `APPROVED_BASELINE` | 1-to-many | One approver can sign off many baseline entries. |
| `APP_CODE_REPO` → `PIPELINE_RUN` | 1-to-many | Each app repo generates many pipeline runs. |
| `IAC_REPO` → `PIPELINE_RUN` | 1-to-many | Each IaC repo generates many pipeline runs. |
| `GOVERNING_TEMPLATE` → `PIPELINE_RUN` | 1-to-many | A single template version governs many pipeline runs. |
| `PIPELINE_RUN` → `GATE_RESULT` | 1-to-many | Each run has one result per gate type (RTCM, SAST, etc.). |
| `PIPELINE_RUN` → `RELEASE_MANIFEST` | 1-to-0-or-1 | A run produces a manifest only when all gates pass. |
| `PIPELINE_RUN` → `EVIDENCE_RECORD` | 1-to-many | Each pipeline stage emits one or more evidence records. |
| `PIPELINE_RUN` → `GITHUB_LOG` | 1-to-many | Each job within a run generates a log entry. |
| `PIPELINE_RUN` → `GOLDEN_AMI` | 1-to-0-or-1 | An image-build run produces at most one AMI. |
| `APPROVED_BASELINE` → `RELEASE_MANIFEST` | 1-to-many | A baseline version is referenced by all manifests it validates. |
| `RELEASE_MANIFEST` → `SSM_DECISION_RECORD` | 1-to-1 | Each manifest has exactly one governance decision record per environment. |
| `RELEASE_MANIFEST` → `DRIFT_EVENT` | 1-to-many | A baseline manifest can be the reference for many drift scans over time. |
| `GATE_RESULT` → `EVIDENCE_RECORD` | 1-to-many | Each gate result emits an evidence record to the audit store. |
| `DRIFT_EVENT` → `EVIDENCE_RECORD` | 1-to-many | Each drift finding and remediation outcome emits evidence records. |
| `EVIDENCE_RECORD` → `AUDIT_ENTRY` | 1-to-1 | Every immutable S3 record has a corresponding DynamoDB index entry. |
| `EVIDENCE_RECORD` ↔ `AWS_LOG` | many-to-many | Evidence records cross-reference the AWS log events that corroborate them. |

---

## PII Register

The CICD platform does not actively collect personal data as part of its core function. However, the following fields constitute **indirect personal identifiers** inherent to GitHub and AWS operational logs.

| Entity | Field | Classification | Basis | Mitigation |
|--------|-------|----------------|-------|------------|
| `ACTOR` | `github_username` | 🔴 PII | Direct personal identifier (GitHub handle maps to a real person) | Accessed only by authorized platform operators; not exposed in dashboards |
| `PIPELINE_RUN` | `triggered_by` | 🔴 PII | GitHub username of the person who triggered the run | Retained only in audit-locked evidence; access via IAM-controlled DynamoDB |
| `APPROVED_BASELINE` | `approved_by` | 🔴 PII | GitHub username of the person who approved the baseline | Same as above |
| `GITHUB_LOG` | `actor` | 🔴 PII | GitHub username of the job actor | Archived to S3 with SSE-KMS and IAM-scoped access; log retention policy applies |
| `AWS_LOG` | `principal_arn` | ⚠️ Quasi-PII | IAM principal ARN — typically a service role, but can identify a named IAM user | Service role ARNs preferred; named IAM users avoided in pipeline automation |
| `AWS_LOG` | `source_ip_address` | ⚠️ Quasi-PII | Source IP address — personal data under GDPR | Retained in CloudTrail with standard AWS log lifecycle; not surfaced in dashboards |

> **Note:** NFR-PRIV-03 and NFR-PRIV-04 are assessed as not applicable because the platform does not process application-level personal data. The PII fields above are operational identifiers incidental to audit logging.

---

## Ownership Boundary Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│  CICD Platform (data owner)                                          │
│                                                                      │
│  GOVERNING_TEMPLATE  PIPELINE_RUN   GATE_RESULT   APPROVED_BASELINE  │
│  GOLDEN_AMI          RELEASE_MANIFEST              SSM_DECISION_RECORD│
│  DRIFT_EVENT         EVIDENCE_RECORD  AUDIT_ENTRY                    │
│  AWS_LOG  ◄── ingested from AWS (platform is custodian)              │
│  GITHUB_LOG ◄── ingested from GitHub Actions (platform is custodian) │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────┐   ┌──────────────────────────┐
│ App Team (external owner)│   │ IaC Team (external owner) │
│  APP_CODE_REPO           │   │  IAC_REPO                 │
│  (code not stored by CI) │   │  (code not stored by CI)  │
└──────────────────────────┘   └──────────────────────────┘

┌──────────────────────────────┐
│ Identity Systems (external)  │
│  ACTOR (GitHub / AWS IAM)    │
└──────────────────────────────┘
```
