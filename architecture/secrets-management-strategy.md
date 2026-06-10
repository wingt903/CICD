# Secrets Management Strategy (HLD)

## Purpose and Scope

This document defines the **architectural secrets management strategy** for the App as Code CI/CD platform. It covers secret categories, approved storage standards, access patterns, rotation posture, custodian ownership, audit principles, and exception governance.

This document operates at High-Level Design (HLD) scope. It does **not** enumerate individual secrets or include implementation inventories; those are captured in the Low-Level Design (LLD) and Low-Level Implementation (LLI) artefacts.

---

## Guiding Principles

| # | Principle | Rationale |
|---|---|---|
| 1 | **No static long-lived credentials in code or CI artefacts** | Long-lived keys committed to repositories or embedded in workflow files are the primary cause of credential-based breaches. All pipeline trust uses federated identity (OIDC). |
| 2 | **Least-privilege access, just-in-time** | Credentials are scoped to the minimum required permissions and are ephemeral wherever technically feasible. |
| 3 | **Single approved store per category** | Each secret category has one canonical store, eliminating shadow copies and simplifying audit coverage. |
| 4 | **Fail-closed on secret retrieval failures** | Pipeline jobs and runtime processes must not fall back to embedded defaults if a secret cannot be retrieved. The job fails; the delivery chain is blocked. |
| 5 | **All secret access is logged and attributed** | Every retrieval, creation, rotation, and deletion is captured in an immutable, tamper-evident audit trail. |
| 6 | **Rotation is policy-enforced, not ad-hoc** | Cadence bands are defined per category and enforced through automated mechanisms. Manual-only rotation is an exception requiring documented compensating controls. |

---

## Secrets Strategy Table

| Secret Category | Storage Standard | Access Pattern (high level) | Rotation Cadence | Ownership (Custodian) | Audit & Monitoring Principle | Exceptions Allowed? |
|---|---|---|---|---|---|---|
| **Pipeline Identity Credentials** — AWS credentials used by GitHub Actions to deploy and configure AWS resources | AWS IAM with OIDC federation; no persistent keys issued. GitHub Actions requests a short-lived STS token at job start via the IAM OIDC Provider. | Federated / ephemeral. Each GitHub Actions job exchanges a signed OIDC token for a time-bounded STS credential scoped to the permitted IAM role. No secret is stored; trust is asserted through the OIDC JWT. | No rotation required — credentials are generated per-job and expire with the job session (default 1-hour max lifetime). IAM role trust policies and OIDC conditions are reviewed at least annually. | Platform Engineering team (IAM role definitions and OIDC provider config). | CloudTrail records every `AssumeRoleWithWebIdentity` call with caller identity, role ARN, session name, and timestamp. CloudWatch Alarm on unexpected role assumption from non-pipeline principals. | No. Static AWS access keys for pipeline use are prohibited. Any deviation requires CISO written approval. |
| **Runtime Application Secrets** — database passwords, third-party API tokens, integration credentials consumed by running application workloads | AWS Secrets Manager, segregated by environment path (`/dev/`, `/test/`, `/prod/`). Secrets are never placed in environment variables or deployment artefacts. | Runtime pull. Application processes and Ansible-driven configuration tasks retrieve secrets directly from Secrets Manager at execution time using IAM role-based access. Secrets are never written to disk or logs. | **90 days** for database credentials (automated via Secrets Manager rotation with Lambda). **180 days** for third-party API tokens (automated where provider supports it; manual with compensating controls where not). Rotation triggers automated validation test before decommissioning the previous version. | Product Team (application custodian) for app-specific secrets; Platform Engineering for platform-shared runtime secrets. | CloudTrail logs every `GetSecretValue` call. Datadog alert on anomalous retrieval volume or retrieval by unexpected IAM principal. Rotation events and failures logged to CloudWatch. | Yes — third-party API tokens whose providers do not support programmatic rotation. Exception must be documented in the LLI, approved by the Platform Engineering lead, and mitigated by IP-restricted API calls, access logging at provider, and an enhanced 90-day manual review cadence. |
| **Infrastructure Configuration Parameters** — non-secret runtime config (runtime compatibility baseline, AMI IDs, deployment decision records, environment-specific settings) | AWS Systems Manager Parameter Store (`SecureString` tier for sensitive parameters, `String` for non-sensitive). Segregated by environment prefix (`/dev/`, `/test/`, `/prod/`) and functional path (e.g., `/cicd/rtcm/`, `/cicd/deployment-decisions/`). | Pipeline and runtime pull. GitHub Actions jobs and Ansible playbooks read parameters using the IAM role assumed via OIDC. No direct console access by application team members. | Configuration parameters do not carry rotation cadence, but are versioned and subject to change-control governance. SSM Parameter Store maintains full version history for audit. `SecureString` parameters with credential-equivalent values (e.g., bootstrap tokens) follow the **90-day** cadence. | Platform Engineering for platform-scoped paths; Product Team for application-scoped config under delegated path prefixes. | CloudTrail records every `GetParameter`, `PutParameter`, and `DeleteParameter` API call. Version history retained in SSM. Datadog alert on unexpected bulk parameter reads or writes outside pipeline context. | No. Parameters must not be stored in GitHub Actions environment variables, workflow files, or source repositories. |
| **CI/CD Platform Secrets** — GitHub Actions workflow-level secrets required before OIDC federation is established (e.g., environment identifiers, non-credential workflow inputs) | GitHub Actions Encrypted Secrets (organisation or repository scope). Restricted to the minimum set that cannot be supplied by OIDC or SSM at job start. | GitHub Actions runtime injection. Secrets are injected as environment variables only within the scope of the job step that requires them and are masked in all log output. | **Annual review** to confirm continued necessity. Secrets no longer required are removed immediately. | Platform Engineering for organisation-scoped secrets; Product Team lead for repository-scoped secrets. | GitHub audit log records every secret creation, update, deletion, and access event. Datadog alert on unexpected changes to organisation-scoped secrets. Secret scanning (GitHub Advanced Security) detects any accidental exposure of secret values in repository content. | Yes — limited to workflow bootstrap values that are technically non-injectable through OIDC. Each GitHub Actions secret must be individually justified in the LLI with a reference to why OIDC or SSM cannot satisfy the requirement. |
| **Encryption Keys** — KMS Customer Managed Keys (CMKs) for S3 evidence bucket encryption, SSM SecureString, and evidence record signing | AWS Key Management Service (KMS) CMKs. Keys are never exported or transmitted; all cryptographic operations occur inside KMS. Separate CMKs per functional domain (evidence signing, data at rest, SSM SecureString). | Service-to-service via KMS API. Only explicitly allowed IAM roles (e.g., Evidence Ingestor Lambda, Integrity Verifier Lambda) can call `kms:GenerateDataKey`, `kms:Decrypt`, `kms:Sign`, or `kms:Verify`. No human-direct key access in normal operations. | AWS KMS automatic annual key material rotation enabled for all CMKs. Key policies and grants reviewed at least annually and after every permission-model change. | Platform Engineering (key policy authorship and rotation oversight). | CloudTrail records every KMS API call (GenerateDataKey, Decrypt, Sign, Verify, ScheduleKeyDeletion) with full principal and key ARN. CloudWatch Alarm on any `kms:ScheduleKeyDeletion` or key policy change. Datadog alert on anomalous KMS usage patterns. | No. Key export or use of AWS-managed keys in place of CMKs requires CISO written approval. |
| **Hardened Image Build Credentials** — temporary credentials used during AMI build (package repository access, OS hardening scripts) | Retrieved from AWS Secrets Manager at build time by the Ansible build role. Not stored in Ansible playbooks, inventory, or any code file. Builder EC2 instances access Secrets Manager via instance profile (IAM role) over SSM Session Manager — no SSH or static credential required. | Role-based pull at build time only. The builder EC2 instance profile grants scoped Secrets Manager read access for the duration of the image build. Credentials are not persisted in the resulting AMI. | **90-day** cadence for any package repository tokens or OS vendor credentials, aligned with runtime application secrets. | Platform Engineering (build role and credential ownership). | CloudTrail logs `GetSecretValue` calls from builder instance profile. Inspector and ECR Enhanced Scanning verify no credentials are baked into produced AMIs. Alert if secrets are detected in image layer content. | No. Build-time credentials must not be embedded in AMI, Ansible variable files, or CI workflow YAML. |

---

## Rotation Posture Summary

| Cadence Band | Categories | Mechanism |
|---|---|---|
| **Per-job ephemeral** | Pipeline Identity Credentials (OIDC STS) | AWS STS issues and expires automatically; no custodian action required. |
| **90 days** | Runtime database passwords; hardened image build credentials; `SecureString` config parameters with credential-equivalent values | Automated via Secrets Manager rotation Lambda or pipeline-enforced policy. Rotation is validated before old version is decommissioned. |
| **180 days** | Third-party API tokens (where provider supports programmatic rotation) | Automated where possible; documented manual procedure with compensating controls where not. |
| **Annual** | GitHub Actions Encrypted Secrets (non-credential bootstrap values); KMS key material rotation; IAM role and OIDC trust policy review | Automated KMS rotation; manual review gate for GitHub Secrets (supported by GitHub audit log evidence). |

---

## Access Pattern Summary

```
GitHub Actions job (OIDC JWT)
    └─► IAM OIDC Provider ──► STS short-lived credential
              │
              ├─► AWS Secrets Manager   (runtime app secrets, build credentials)
              ├─► AWS SSM Parameter Store (config, RTCM baseline, deployment decisions)
              └─► AWS KMS               (data-at-rest encryption, evidence signing)

Running Application (EC2 instance profile / ECS task role)
    └─► AWS Secrets Manager             (db passwords, API tokens — runtime pull)
    └─► AWS SSM Parameter Store         (runtime config — runtime pull)

Ansible / SSM Session Manager
    └─► AWS Secrets Manager             (build-time credentials — ephemeral pull)
    └─► AWS SSM Parameter Store         (environment parameters)
```

All paths use IAM role-based access. No human operator holds direct secret values in normal operations.

---

## Break-Glass Principles

Break-glass access is the controlled, audited procedure for emergency human retrieval of a secret outside the normal automated access path. The following principles govern break-glass use on this platform:

1. **Named break-glass IAM role** — A dedicated, time-limited IAM role grants read access to Secrets Manager and SSM Parameter Store. Assumption of this role requires MFA and is logged in CloudTrail.
2. **Pre-approval required** — Break-glass access requires documented approval from the Platform Engineering lead or delegate before the role is assumed, except where a live production incident makes pre-approval impossible (post-hoc approval must be completed within 4 hours).
3. **Immediate notification** — Assumption of the break-glass role triggers a real-time CloudWatch Alarm → SNS → Datadog alert to the Platform Engineering and security teams.
4. **Post-use rotation** — Any secret accessed via break-glass is rotated as soon as the incident is resolved, regardless of its normal cadence band.
5. **Incident record required** — Every break-glass event must be linked to an incident record (change ticket in Phase 1; ServiceNow incident in Phase 2). The CloudTrail evidence is attached to the record.
6. **No standing access** — Break-glass role assignments are ephemeral (maximum 4-hour session). The role has no persistent trust policy attachment outside of incident activation.

---

## Exceptions Governance

All exceptions to the standards in this document must follow this process:

| Step | Action | Approver |
|---|---|---|
| 1 | Document the exception: category affected, reason standard cannot be met, proposed compensating controls, and time-limited expiry date | Product Team lead |
| 2 | Review compensating controls for adequacy | Platform Engineering lead |
| 3 | Approve or reject | CISO (or delegate) |
| 4 | Record the approved exception in the LLI secrets inventory with cross-reference to this document | Platform Engineering |
| 5 | Review at next quarterly security review; renew or remediate by expiry date | Platform Engineering + CISO |

Exceptions do not create permanent entitlements. All exceptions expire at the date documented at approval time.

---

## Related Documents

| Document | Purpose |
|---|---|
| `architecture/full-pipeline-tech-stack.md` | Technology selection rationale including IAM OIDC Provider, Secrets Manager, SSM Parameter Store, and KMS |
| `architecture/nfr.md` | NFR-SEC-03 (encryption), NFR-SEC-06 (secrets management) non-functional requirements |
| `architecture/compliance-evidence-store.md` | Evidence store design including KMS signing CMK usage |
| `architecture/requirement-traceability.md` | Requirement-to-architecture mapping (App_as_Code_003, App_as_Code_004, App_as_Code_007) |
| LLD / LLI (forthcoming) | Individual secret enumeration, rotation runbooks, and implementation inventory |
