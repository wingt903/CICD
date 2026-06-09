# Data Architecture – Focused Entity-Relationship View

This document defines a focused ERD for five core entities only:
`PIPELINE_RUN`, `APPROVED_BASELINE`, `GOLDEN_AMI`, `AWS_LOG`, and `GITHUB_LOG`.

> **Diagram source:** `data-architecture-erd.mmd` (Mermaid `erDiagram` source used for architecture diagram workflows).

---

## Scope and Ownership

| Scope | Definition |
|---|---|
| **In scope** | Pipeline execution, approved runtime baseline, produced AMI metadata, AWS audit/security logs, and GitHub Actions logs. |
| **Ownership** | These records are platform-owned or platform-custodied operational/audit data. |
| **Out of scope** | Application source code and IaC source code entities are intentionally excluded from this focused model. |

> **Key constraint:** The platform does not own application source code; this focused ERD models only platform operational/governance and log-custody entities.

---

## Entity Catalogue

| Entity | Store | Description |
|---|---|---|
| `PIPELINE_RUN` | GitHub Actions metadata + DynamoDB | Execution record for one workflow run and its lifecycle status. |
| `APPROVED_BASELINE` | SSM Parameter Store | Approved runtime compatibility baseline used for governance and policy enforcement. |
| `GOLDEN_AMI` | EC2 AMI Registry | Hardened machine image metadata produced by image-build workflows. |
| `GITHUB_LOG` | S3 archive of GitHub Actions logs | Job-level GitHub workflow logs retained for audit and troubleshooting. |
| `AWS_LOG` | CloudTrail / CloudWatch / GuardDuty | AWS-native operational and security logs correlated to pipeline activities. |

---

## Relationship Summary

| Relationship | Cardinality | Notes |
|---|---|---|
| `APPROVED_BASELINE` → `PIPELINE_RUN` | 1-to-many | One approved baseline can govern many pipeline runs. |
| `GOLDEN_AMI` → `PIPELINE_RUN` | 0-or-1-to-1 | Each golden AMI is produced by exactly one pipeline run; most runs produce no AMI. |
| `PIPELINE_RUN` → `GITHUB_LOG` | 1-to-many | A run generates one or more GitHub job logs. |
| `PIPELINE_RUN` ↔ `AWS_LOG` | many-to-many | Pipeline activity is correlated with multiple AWS log events, and AWS events can map to multiple runs over time. |

---

## PII Register (Entity Level)

| Entity | Classification | Basis | Mitigation |
|---|---|---|---|
| `PIPELINE_RUN` | 🔴 PII | May include triggering user identity from GitHub events | IAM-scoped access and controlled retention |
| `APPROVED_BASELINE` | 🔴 PII | May include approver identity | Restricted governance access |
| `GITHUB_LOG` | 🔴 PII | May contain user handles and usernames | Encrypted archival and least-privilege access |
| `AWS_LOG` | ⚠️ Quasi-PII | May contain source IP and principal ARN | Role-based access controls and retention policies |
| `GOLDEN_AMI` | 🟢 Non-PII | Image and build metadata only | Standard configuration governance |

---

## Ownership Boundary Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│ CICD Platform data scope                                             │
│                                                                      │
│ APPROVED_BASELINE  PIPELINE_RUN  GOLDEN_AMI                          │
│ AWS_LOG            GITHUB_LOG                                        │
└──────────────────────────────────────────────────────────────────────┘

Out of scope for this focused ERD: app source code and IaC source code.
```
