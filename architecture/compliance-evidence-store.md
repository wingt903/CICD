# Compliance Evidence Store — Design and Controls

This document specifies the evidence schema, storage controls, access/change audit trail, and audit reporting layer that close the gaps identified in App_as_Code_004.

## Scope assumptions

- **ServiceNow integration is moved to Phase 2.** References to ServiceNow / CMDB webhooks or incident creation below describe the target-state integration. Phase 1 uses the same evidence outputs with manual or governed ITSM / CMDB handoff.
- **Application teams operate in two repository models:** **one repository per environment** and **one repository for all environments**. The evidence model applies to both without changing schema or control expectations.

---

## 1. Evidence Schema

Every compliance assessment event produces a single normalized evidence record with the following mandatory fields.

| Field | Type | Description |
|---|---|---|
| `evidence_id` | UUID v4 | Globally unique identifier auto-generated at ingest time. |
| `timestamp` | ISO 8601 UTC | Moment the assessment outcome was determined (not ingest time). |
| `system_id` | String | CMDB CI identifier of the assessed asset (matches ServiceNow CI record). |
| `environment` | Enum: `dev` / `test` / `prod` | Target environment of the assessed asset. |
| `baseline_ref` | String | Canonical reference to the approved baseline: AMI ID, Terraform commit SHA, SSM document version, or RTCM version/commit. |
| `control_id` | String | Security control, runtime compatibility control, or patch identifier (e.g., CIS benchmark ID, `rtcm-compatibility-check`, CVE, patch KB, Ansible role tag). |
| `result` | Enum: `PASS` / `FAIL` / `PARTIAL` | Outcome of the compliance assessment for this control on this asset. |
| `remediation_state` | Enum: `NOT_REQUIRED` / `PENDING` / `IN_PROGRESS` / `COMPLETE` / `FAILED` | Current remediation lifecycle status. |
| `source_system` | String | Originating system (e.g., `github-actions`, `rtcm-validator`, `aws-ssm`, `security-hub`, `drift-reconciler`, `db-drift-controller`). |
| `run_id` | String | Pipeline run ID or SSM Automation Execution ID that produced this record. |
| `details_ref` | S3 URI | Pointer to the full execution log or scan artifact archived in the evidence store. |
| `signature` | String | KMS-signed SHA-256 hash of all other fields to enable integrity verification. |

All fields are required. Evidence records are immutable once written; corrections are appended as new records with `remediation_state` progressing the lifecycle.

---

## 2. Evidence Ingest Sources

| Source | Trigger | Evidence Type |
|---|---|---|
| RTCM Validator | Immediately after source checkout and manifest inspection | Approved/rejected runtime compatibility decision for application, middleware, and database versions, including rejection reason and approved version range |
| GitHub Actions (build pipeline) | End of each successful / failed build stage | SAST, IaC policy scan, image scan, AMI registration, SSM inventory capture |
| Ansible / SSM | Post-build SSM document completion | OS hardening result, middleware configuration validation, inventory snapshot |
| Drift Reconciler | Post-convergence verification | Infrastructure drift detection, baseline enforcement, convergence confirmation |
| Database Drift Controller | Post-remediation DB validation | Schema/config drift status, migration outcome, rollback events |
| Security Hub / GuardDuty | EventBridge finding event | Runtime threat/posture findings linked to CI asset |
| ServiceNow (CMDB) | CMDB CI update webhook | **Phase 2 target state:** CMDB change record reference and change closure confirmation. In Phase 1, the same reference is attached through manual / governed ITSM handoff. |

Each source publishes evidence to an **Evidence Ingestor Lambda** via an EventBridge event bus using the normalized schema above.

---

## 3. Central Evidence Store — Architecture

```
Source Systems
   │
   ▼ (EventBridge event bus: compliance-evidence-bus)
Evidence Ingestor Lambda
   │  - validates schema
   │  - signs record with KMS Customer Managed Key (alias/evidence-signing)
   │  - generates evidence_id, adds ingest timestamp
   ▼
S3 Evidence Bucket (compliance-evidence-<account>)
   │  - Object Lock: Governance mode, 7-year retention
   │  - Versioning: enabled
   │  - Server-side encryption: SSE-KMS (dedicated CMK)
   │  - S3 Access Logging: enabled → S3 Audit Log Bucket
   │  - Object-level logging: CloudTrail data events (read + write)
   ▼
Evidence Index (Amazon DynamoDB — GSIs on system_id, control_id, timestamp)
   │  - TTL disabled (records retained permanently to match 7-year evidence retention)
   │  - Streams → integrity verifier
   ▼
Integrity Verifier Lambda (scheduled daily via EventBridge)
   │  - Re-derives SHA-256 hash of each record
   │  - Validates KMS signature
   │  - Publishes pass/fail metric to CloudWatch
   │  - Alerts via SNS on any verification failure
   ▼
Audit Reporting Layer
   │  - Athena queries over S3 partitioned by env/date
   │  - AWS Audit Manager (custom framework mapped to App_as_Code controls)
   │  - Pre-built report templates: point-in-time, historical, per-control, per-asset
   │  - Export: S3 presigned URL or direct audit manager report PDF
```

### S3 Bucket Layout

```
s3://compliance-evidence-<account>/
  evidence/
    year=YYYY/
      month=MM/
        day=DD/
          env=<dev|test|prod>/
            <evidence_id>.json.gz     # signed evidence record
            <evidence_id>.log.gz      # raw execution log (details_ref target)
  reports/
    <YYYY-MM-DD>/
      <report-type>-<scope>.pdf
  integrity-results/
    <YYYY-MM-DD>/
      verification-summary.json
```

---

## 4. Tamper-Evident Controls

| Control | Implementation |
|---|---|
| Immutable retention | S3 Object Lock in Governance mode with 7-year minimum retention period. No object can be deleted or overwritten within the retention window, even by privileged users, without explicit S3 lock override (which itself generates a CloudTrail event). |
| Versioning | S3 versioning is enabled. Any overwrite attempt creates a new version rather than silently replacing the original. |
| Encryption at rest | SSE-KMS with a dedicated Customer Managed Key (CMK). Key policy restricts usage to the Evidence Ingestor Lambda role and the Integrity Verifier Lambda role only. |
| Cryptographic integrity | Evidence Ingestor Lambda computes SHA-256 of the serialized JSON record, then calls `kms:Sign` with the CMK to produce an RSA-PSS signature embedded in the `signature` field. |
| Hash chain | Each evidence record's `details_ref` log is SHA-256 hashed and stored in the index. Integrity Verifier rebuilds the hash and compares to index on every scheduled run. |
| Access logging | S3 server access logging and CloudTrail S3 data events (PutObject, GetObject, DeleteObject) are enabled for the evidence bucket. All access and change events are streamed to a separate write-once audit log bucket. |
| CloudTrail management events | All IAM and S3 management plane calls are captured in an org-level CloudTrail trail with CloudWatch Logs integration and SNS alerting on policy changes or lock override attempts. |

---

## 5. Access and Change Audit Trail

| Event Type | Captured By | Fields Logged |
|---|---|---|
| Evidence write (new record) | CloudTrail S3 data event (PutObject) | `actor` (IAM principal), `timestamp`, `bucket`, `key`, `sourceIPAddress`, `userAgent`, `requestId` |
| Evidence read (access) | CloudTrail S3 data event (GetObject) | `actor`, `timestamp`, `key`, `sourceIPAddress`, `requestId` |
| Evidence delete attempt | CloudTrail S3 data event (DeleteObject) | `actor`, `timestamp`, `key`, `errorCode` (blocked by Object Lock) |
| Object Lock override attempt | CloudTrail management event (BypassGovernanceRetention) | `actor`, `timestamp`, `key`, `result` (denied unless break-glass role) |
| KMS key usage | CloudTrail KMS data event (Sign, Verify, Decrypt) | `actor`, `key ARN`, `timestamp`, `requestId` |
| Index mutation | DynamoDB Streams → audit Lambda | `actor` (Lambda execution role), `before`/`after` state, `timestamp` |
| Integrity check failure | CloudWatch metric alarm → SNS | `evidence_id`, `expected_hash`, `actual_hash`, `timestamp` |

All CloudTrail logs are delivered to the audit log S3 bucket with Object Lock (Compliance mode, 7-year retention) and cannot be modified after delivery.

A dedicated IAM role (`compliance-evidence-audit-reader`) with read-only permissions on the audit log bucket is the only mechanism for auditors to access trail records. All access by this role is itself logged.

---

## 6. Audit Reporting Layer

### Report Types

| Report | Scope | Description |
|---|---|---|
| Current compliance posture | Per environment, per control, or per asset | Snapshot of the most recent assessment result for every active CI against every in-scope control. |
| Historical compliance trend | Date range, per control or per asset | Time-series of PASS/FAIL/PARTIAL counts to show compliance progression or regression. |
| Remediation history | Per asset or per incident | Full lifecycle of a compliance gap from detection through closure with timestamps and actor references. |
| Evidence integrity report | All evidence, or targeted range | Output of the Integrity Verifier showing which records passed or failed hash/signature verification, with any anomalies highlighted. |
| Access/change audit report | Date range | Extract of CloudTrail evidence access and mutation events for a given period for auditor review. |

### Generation and Export

- **AWS Audit Manager** is configured with a custom framework that maps each App_as_Code control (001–008) to the evidence sources defined in Section 2, including RTCM validation evidence for App_as_Code_008. Audit Manager automatically aggregates evidence and generates assessment reports.
- **Amazon Athena** queries the partitioned evidence S3 prefix for ad-hoc and scheduled report generation. Results are written to `s3://compliance-evidence-<account>/reports/`.
- **Export** is available as PDF (via Audit Manager) or CSV/JSON (via Athena query result) through an auditor-facing presigned URL API (API Gateway + Lambda, read-only, authenticated via IAM Identity Center).
- Report generation events are logged to CloudTrail.

---

## 7. Integrity and Trail Verification Controls

| Control | Mechanism | Schedule / Trigger |
|---|---|---|
| Evidence hash verification | Integrity Verifier Lambda re-hashes all records and validates KMS signatures | Daily at 02:00 UTC via EventBridge rule |
| Tamper anomaly alerting | CloudWatch Metric Alarm on `EvidenceIntegrityFailure` count > 0 | Real-time alarm → SNS → PagerDuty / **Phase 2** ServiceNow incident |
| Unexpected access alerting | CloudWatch Logs Insights rule on CloudTrail — GetObject by non-approved principals | Real-time via CloudWatch Logs subscription filter |
| Lock override alerting | CloudTrail CloudWatch Logs metric filter on `BypassGovernanceRetention` | Real-time alarm → SNS |
| Periodic attestation | Integrity Verifier publishes signed attestation JSON to `integrity-results/` prefix | Weekly; summary linked to Audit Manager assessment cycle |
| Evidence completeness check | Lambda compares expected evidence records (from CMDB CI list × control matrix) against actual records in index | Daily; gaps published as CloudWatch metric and manual / governed ITSM handoff in Phase 1 or ServiceNow incident in Phase 2 |
