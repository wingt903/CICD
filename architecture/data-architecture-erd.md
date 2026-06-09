# Data Architecture – Focused Entity-Relationship View

This document defines a focused ERD for six core entities only:
`PIPELINE_RUN`, `APPROVED_BASELINE`, `COMPLIANCE_EVIDENCE`, `GOLDEN_AMI`, `AWS_LOG`, and `GITHUB_LOG`.

> **Diagram source:** `data-architecture-erd.mmd` (Mermaid ERD source file used for GitHub rendering and manual draw.io Mermaid import).

---

## Scope and Ownership

| Scope | Definition |
|---|---|
| **In scope** | Pipeline execution, approved runtime baseline, per-check compliance evidence, produced AMI metadata, AWS audit/security logs, and GitHub Actions logs. |
| **Ownership** | These records are platform-owned or platform-custodied operational/audit data. |
| **Out of scope** | Application source code and IaC source code entities are intentionally excluded from this focused model. |

> **Key constraint:** The platform does not own application source code; this focused ERD models only platform operational/governance and log-custody entities.

---

## Entity Catalogue

| Entity | Store | Description |
|---|---|---|
| `PIPELINE_RUN` | GitHub Actions metadata + DynamoDB | Execution record for one workflow run and its lifecycle status. |
| `APPROVED_BASELINE` | SSM Parameter Store | Approved runtime compatibility baseline used for governance and policy enforcement. |
| `COMPLIANCE_EVIDENCE` | DynamoDB + S3 evidence archive | Per-check auditable evidence records with app repository identity/version, baseline reference, timestamp, and compliance result. |
| `GOLDEN_AMI` | EC2 AMI Registry | Hardened machine image metadata produced by image-build workflows. |
| `GITHUB_LOG` | S3 archive of GitHub Actions logs | Job-level GitHub workflow logs retained for audit and troubleshooting. |
| `AWS_LOG` | CloudTrail / CloudWatch / GuardDuty | AWS-native operational and security logs correlated to pipeline activities. |

---

## Relationship Summary

| Relationship | Cardinality | Notes |
|---|---|---|
| `APPROVED_BASELINE` → `PIPELINE_RUN` | 1-to-many | One approved baseline can govern many pipeline runs. |
| `APPROVED_BASELINE` → `COMPLIANCE_EVIDENCE` | 1-to-many | One approved baseline can be referenced by many per-check evidence records. |
| `PIPELINE_RUN` → `GOLDEN_AMI` | 1-to-0-or-1 | A run produces at most one golden AMI, and non-image runs produce none. |
| `PIPELINE_RUN` → `GITHUB_LOG` | 1-to-many | A run generates one or more GitHub job logs. |
| `PIPELINE_RUN` → `COMPLIANCE_EVIDENCE` | 1-to-many | A run emits one evidence record per executed compliance check. |
| `PIPELINE_RUN` ↔ `AWS_LOG` | many-to-many | Pipeline activity is correlated with multiple AWS log events, and AWS events can map to multiple runs over time. |

### `COMPLIANCE_EVIDENCE` minimum fields (per-check)

- `evidence_id` (record identifier)
- `run_id` (pipeline correlation ID)
- `baseline_id` (approved baseline reference)
- `app_repo_name` (system identifier: application repository name)
- `app_repo_version` (system identifier: application repository version/tag/commit)
- `check_name` (individual check identifier)
- `compliance_status` (e.g., pass/fail/drift)
- `checked_at` (evidence timestamp)

---

## PII Register (Entity Level)

| Entity | Classification | Basis | Mitigation |
|---|---|---|---|
| `PIPELINE_RUN` | 🔴 PII | May include triggering user identity from GitHub events | IAM-scoped access and controlled retention |
| `APPROVED_BASELINE` | 🔴 PII | May include approver identity | Restricted governance access |
| `COMPLIANCE_EVIDENCE` | ⚠️ Quasi-PII | May include repository/team identifiers and execution metadata | Encryption at rest, least-privilege access, and retention governance |
| `GITHUB_LOG` | 🔴 PII | May contain user handles and usernames | Encrypted archival and least-privilege access |
| `AWS_LOG` | ⚠️ Quasi-PII | May contain source IP and principal ARN | Role-based access controls and retention policies |
| `GOLDEN_AMI` | 🟢 Non-PII | Image and build metadata only | Standard configuration governance |

---

## Ownership Boundary Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│ CICD Platform data scope                                             │
│                                                                      │
│ APPROVED_BASELINE  PIPELINE_RUN  COMPLIANCE_EVIDENCE  GOLDEN_AMI     │
│ AWS_LOG            GITHUB_LOG                                        │
└──────────────────────────────────────────────────────────────────────┘

Out of scope for this focused ERD: app source code and IaC source code.
```
