# Requirement Traceability Matrix (Single-Diagram View)

This matrix is intentionally simplified to use **one canonical diagram** as traceability evidence:
- `/tmp/workspace/wingt903/CICD/architecture/component-context-diagram.mmd`

All references below use the **numbered flow IDs** on that diagram.

## Scope Assumptions

| Assumption | Detail |
|---|---|
| Digital signature controls are out of scope | Image signing / signature verification are excluded unless explicitly re-scoped. |
| ServiceNow integration is Phase 2 | ServiceNow-triggered orchestration and CMDB callbacks are target-state (Phase 2). |
| App repo model can vary by team | Supports one-repo-per-environment and one-repo-for-all-environments models. |

## Requirement Traceability (Condensed)

| Requirement ID | Requirement Focus | Diagram Evidence (Flow IDs) | Verdict | Notes |
|---|---|---|---|---|
| App_as_Code_001 | Automated and repeatable deployment/configuration | 5-9, 19-45 | **Partially Met** | End-to-end automation and repeatability are modeled after pipeline trigger; direct ServiceNow trigger remains Phase 2. |
| App_as_Code_002 | Detect and auto-remediate drift | 56-70, 71-76 | **Met** | Scheduled drift scan, live-state collection, baseline comparison, compliant/drift branching, auto-remediation, and DB drift handling are explicit. |
| App_as_Code_003 | Apply and validate security hardening/patching | 13-18, 21-35, 46-50, 56-69 | **Met** | Security gates, AMI/runtime scans, and remediation/convergence loop provide automated apply+validate flow. |
| App_as_Code_004 | Continuous compliance evidence, auditability, reporting | 56-70, 77-95 | **Met** | Approved baseline publication, scheduled drift comparison, compliant/drift event storage, auto-remediation outcomes, S3-backed audit persistence, and Datadog dashboard reporting are modeled in one chain. |
| App_as_Code_005 | Reduce manual intervention with consistent automation | 13-18, 19-45, 56-69, 77-89 | **Met** | Automated gate-to-deploy and reconciliation flows reduce manual setup/verification and produce auditable execution records. |
| App_as_Code_006 | Continuous platform/runtime compliance monitoring (excluding app code logic) | 56-76, 82-86, 90-95 | **Largely Met** | Platform/runtime and DB health/compliance monitoring is explicit; app-code exclusion must be enforced by control taxonomy/policy. |
| App_as_Code_007 | Governed secure onboarding templates and fail-closed control enforcement | 5, 13-18, 32-33, 77-81 | **Met (architecture intent)** | Mandatory controls and fail-closed gating are modeled; template governance specifics are implemented through governed workflow standards. |
| App_as_Code_008 | Runtime compatibility baseline validation and blocking non-compliant stacks | 10-12, 15, 77-78 | **Met** | RTCM lookup + validation gate occurs before build/deploy, and each decision is recorded as compliance evidence. |

## Diagram-Only Evidence Rule

For this document, requirement traceability evidence is accepted only when it maps to one or more explicit flow IDs in:
- `/tmp/workspace/wingt903/CICD/architecture/component-context-diagram.mmd`

Supporting documents may still provide implementation detail, but this matrix remains the single-diagram index.
