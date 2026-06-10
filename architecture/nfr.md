# Non-Functional Requirements (NFR) Document

| Field | Value |
|---|---|
| Application Name | Application as Code |
| Application Version | v0.9 |
| Status | Draft |
| Approved Date |  |
| Template Type | NFR |
| Template Version | v1.1 |

> **DO NOT MODIFY** template structure, section titles, or shaded header rows. HLDs not meeting these points will be instantly rejected without review.

> Companion Guide — Scoping, section walkthroughs, worked examples, FAQ, glossary

---

## 1.0 NFR Framework Overview

NFRs define quality attributes and operational constraints beyond functional behaviour. Where an NFR cannot be met, a time-bound, risk-owned exception with compensating controls is required.

---

## 1.1 Section Applicability by Project Type

Not all regulatory sections apply to every project. Use this matrix to determine which sections are mandatory for your system.

How to use: Identify your system's project type(s), then complete all sections marked Mandatory. For sections marked "N/A", document why they do not apply in your Evidence column. For "Recommended" sections, adopt where feasible.

| Section | All Projects | Payment Data [PCI Scope] | Personal Data [GDPR] | Aviation Essential Services [CAA/NIS] | Applicable [Y/N] | Justification [If No] |
|---|---|---|---|---|---|---|
| Operational Excellence (OE) | Mandatory | Mandatory | Mandatory | Mandatory | Y |  |
| Security (SEC) | Mandatory | Mandatory | Mandatory | Mandatory | Y |  |
| Privacy & Data Protection (PRIV) | If personal data | If personal data | Mandatory | If personal data | N |  |
| Data Retention & Disposal (DATA) | Mandatory | Mandatory | Mandatory | Mandatory | Y |  |
| Compliance Auditability (COMP) | Recommended | Mandatory | Mandatory | Mandatory | Y |  |
| PCI DSS (PCI) | Specialist | Specialist | Specialist | Specialist | N | Handled separately under Compass |
| UK Cyber Essentials (CE) | Mandatory | Mandatory | Mandatory | Mandatory | Y |  |
| UK CAA / NIS (CAA) | N/A | N/A | N/A | Mandatory | N |  |
| Interoperability (INT) | If APIs exposed | If APIs exposed | If APIs exposed | If APIs exposed | Y |  |
| Reliability (REL) | Mandatory | Mandatory | Mandatory | Mandatory | Y |  |
| Performance Efficiency (PERF) | Mandatory | Mandatory | Mandatory | Mandatory | Y |  |
| Cost Optimisation (COST) | Mandatory | Mandatory | Mandatory | Mandatory | Y |  |
| Sustainability (SUS) | Recommended | Recommended | Recommended | Recommended | Y |  |

---

## 2.0 Non-Functional Requirements (NFRs)

For guidance, worked examples, and tier-specific targets for each section, see the Companion Guide.

---

## 2.1 Operational Excellence

| Aspect | Your Target |
|---|---|
| Service Hours | 24x7 automated platform availability for production pipeline execution and monitoring; business hours support (05:00–17:00) for standard service requests and non-production assistance. |
| Support Model | Tiered support model: Product Team owns application-level issues, Platform Engineering owns CI/CD platform/workflow issues, and cloud/vendor support is engaged as an escalation path where required. |
| MTTA Target | ≤ 30 minutes for Priority 1 incidents during support coverage; ≤ 2 hours for standard operational incidents. |
| MTTR Target | ≤ 4 hours for Priority 1 incidents and ≤ 1 business day for non-critical operational issues, subject to dependency/vendor constraints. |

| NFR ID | Requirement | Evidence | Status |
|---|---|---|---|
| NFR-OE-01 | Infrastructure as Code — Infrastructure managed as code, version-controlled, and peer-reviewed. | Infrastructure definitions are maintained in Git-based repositories, all changes are submitted through pull requests, approvals are enforced through branch protection/CODEOWNERS, and deployment changes are traceable to workflow run history. | Not Started |
| NFR-OE-02 | Observability — Metrics, logs, and traces with actionable alerts aligned to user-impacting KPIs. | Central dashboards and logs are available through the reporting/observability platform; pipeline outcomes, drift events, remediation events, and alert thresholds are defined and linked to service KPIs such as deployment success rate, failure rate, and recovery time. | Not Started |
| NFR-OE-03 | Runbooks — Runbooks for common operations, failure modes, and incident response. | Documented runbooks exist for deployment failure, rollback, drift remediation, credential/access issues, and pipeline recovery; runbooks are version-controlled and reviewed periodically. | Not Started |
| NFR-OE-04 | Change Management — Small, reversible changes with a defined rollback strategy. | Changes are delivered via pull requests and reusable workflows, approvals are enforced before promotion, deployment decisions are recorded, and rollback/remediation procedures are defined for failed or non-compliant releases. | Not Started |
| NFR-OE-05 | Support & Incident Response — Support hours, on-call ownership, escalation paths, and MTTA/MTTR targets defined per tier. | A documented support model defines service hours, ownership by Product Team and Platform Engineering, incident severity classification, escalation paths, and target MTTA/MTTR values for operational incidents. | Not Started |

### Observability Strategy

Operational monitoring is standardised by application criticality:

- **SL1/SL2:** Datadog for logs, metrics, and traces, with SLO-based alerting, dashboards, and synthetic tests.
- **SL3/SL4:** CloudWatch alarms with events routed to a ServiceNow AIOps endpoint for enrichment and ticketing.

| Application criticality | Operational Monitoring Tool | Reason is different from the standard |
|---|---|---|
| App as Code CI/CD Platform — SL1 | Datadog (logs, metrics, traces, SLO-based alerting, dashboards, synthetic tests) | — |
| Compliance Evidence Platform — SL1 | Datadog (audit event ingestion, compliance dashboards, drift posture alerting) | — |
| Security Detection & Response — SL2 | Datadog (security event streaming, SOC alerting, security posture dashboards) | — |
| Runtime Configuration & Deployment Governance — SL2 | Datadog (parameter change events, RTCM validation alerts) | Monitored at SL2/Datadog level rather than SL3/CloudWatch because RTCM and deployment-gate decisions are compliance-critical events that require full audit trail and SLO-aligned alerting. |
| Artifact Stores (ECR, CodeArtifact) — SL3 | CloudWatch Alarms + SNS | Phase 1: ServiceNow AIOps alert routing deferred to Phase 2; SNS provides interim operational notification to distribution lists. |
| Observability Infrastructure (CloudWatch, X-Ray, OpenTelemetry) — SL4 | CloudWatch Alarms + SNS | Phase 1: ServiceNow AIOps alert routing deferred to Phase 2; CloudWatch self-monitors with SNS alert routing. |

---

## 2.2 Security

| NFR ID | Requirement | Evidence | Status |
|---|---|---|---|
| NFR-SEC-01 | Identity & Access Management — Least privilege, role-based access, and separation of duties for admin actions. | All pipeline cloud access uses GitHub OIDC identity exchanged for short-lived IAM role credentials; no persistent console access for Product Teams. IAM role trust policies are scoped per environment with least-privilege boundaries. Separation of duties is enforced by environment protection rules and approval gates. | Not Started |
| NFR-SEC-02 | Audit Logging — Security-relevant actions and configuration changes traceable with defined retention. | All pipeline, drift, compliance, and remediation events are captured by the Audit Evidence Platform (EventBridge + Lambda + S3 Object Lock). CloudTrail records all AWS API calls. Logs are retained under defined policy using WORM-protected S3 Object Lock with KMS encryption. | Not Started |
| NFR-SEC-03 | Encryption — Data encrypted at rest and in transit with controlled key management and documented rotation. | Data in transit is protected by TLS/HTTPS enforced across all pipeline and AWS service communications. Data at rest is encrypted using AWS KMS-managed keys (S3, SSM Parameter Store). GitHub Actions secrets are stored in the encrypted GitHub Secrets store. Audit log forwarding to Datadog uses encrypted transport. | Not Started |
| NFR-SEC-04 | Network Security — Defence-in-depth: segmentation, least access paths, controlled egress. | Scope limited to GitHub security controls. GitHub organisation-level policies enforce branch protection rules, required reviewers, and environment protection gates. Snyk provides SAST, dependency scanning, and container vulnerability scanning to control attack surface within the CI/CD platform. | Not Started |
| NFR-SEC-05 | Production Database Access — Production databases are not directly reachable from end-user devices without formal risk acceptance. | No database solution exists in this scope. This requirement is not applicable. | Not Applicable |
| NFR-SEC-06 | Secrets Management — No hard-coded secrets; stored and rotated using an approved mechanism. | All secrets and configuration parameters are stored in AWS SSM Parameter Store or equivalent approved vaulting. No static credentials are stored in repository secrets or workflow environment variables. Credential rotation cadence is defined per platform policy. | Not Started |
| NFR-SEC-07 | Vulnerability Management — Scanning, patching, and remediation process with SLAs per BA Cyber vulnerability management guidelines. | Image build pipeline incorporates hardening controls via Ansible playbooks targeting approved golden AMI baselines. The Runtime Compatibility Validation Gate enforces approved tool versions. Drift detection identifies runtime deviation from approved baseline and triggers remediation within defined SLAs. | Not Started |
| NFR-SEC-08 | Incident Response — Alert routing to SOC, triage steps, and forensic log availability defined. | Security events are streamed from the Audit Evidence Platform to Datadog for SOC monitoring and alerting. Incident triage steps are documented in operational runbooks. Forensic evidence is available through immutable S3 Object Lock audit records and CloudTrail history. | Not Started |
| NFR-SEC-09 | Multi-Factor Authentication — MFA enforced for all human access to cloud services, consoles, and production systems. | GitHub Organisation SSO with MFA is enforced for all human users accessing the CI/CD platform. AWS console access for privileged roles requires MFA as per IAM policy. No direct developer console access to production environments is provisioned outside of approved break-glass procedures. | Not Started |

---

## 2.3 Privacy & Data Protection

| NFR ID | Requirement | Evidence | Status |
|---|---|---|---|
| NFR-PRIV-01 | Privacy by Design — Data minimisation, purpose limitation, and documented lawful basis for processing. | Only operational metadata is collected by default. | Not Started |
| NFR-PRIV-02 | Data Residency — Personal data processed and stored in approved jurisdictions (UK/EEA) only. | AWS account/region guardrails restrict storage and processing to approved UK/EEA regions; cross-region replication outside approved jurisdictions is disabled by policy. | Not Started |
| NFR-PRIV-03 | Right to Erasure — Complete deletion of personal data across all stores within 30 days. | No PII data is handled in this solution scope. This requirement is not applicable. | Not Applicable |
| NFR-PRIV-04 | Subject Access Requests — Export of all personal data for a data subject within 30 days in machine-readable format. | No PII data is handled in this solution scope. This requirement is not applicable. | Not Applicable |
| NFR-PRIV-05 | Data Minimisation — Only data necessary for the specified processing purpose is collected and retained. | No PII data is handled in this solution scope. This requirement is not applicable. | Not Applicable |
| NFR-PRIV-06 | Consent Management — Where consent is the lawful basis, records shall be immutable, timestamped, and auditable. | Pipeline/events capture technical identifiers only where possible; retention schedules and field-level justification are documented and periodically reviewed. | Not Started |
| NFR-PRIV-07 | Breach Notification — ICO notification within 72 hours of becoming aware of a qualifying breach. | SOC alert routing and forensic log availability support evidence gathering; 72-hour SLA is formally defined. | Not Started |
| NFR-PRIV-08 | Records of Processing — ROPA are maintained and accessible for supervisory authority inspection. | No PII data is handled in this solution scope. This requirement is not applicable. | Not Applicable |

---

## 2.4 Data Retention & Disposal

| NFR ID | Requirement | Evidence | Status |
|---|---|---|---|
| NFR-DATA-01 | Retention & Disposal — Documented retention and secure disposal policies aligned to data classification and legal needs. | GitHub Actions logs/artifacts and audit events are used for operational retention with configured repository/organisation retention settings. For long-term compliance retention and secure disposal, audit evidence is exported to immutable S3 Object Lock (WORM) with KMS encryption, policy-defined retention periods, and lifecycle-based disposal aligned to classification and legal requirements. | Not Started |

---

## 2.5 Compliance Auditability

| NFR ID | Requirement | Evidence | Status |
|---|---|---|---|
| NFR-COMP-01 | Compliance Mapping — Auditable mapping of obligations/controls to implemented mechanisms with defined review cadence. | Evidence includes GitHub policy settings (branch protection, required reviews, environment approvals), CI/CD workflow execution records, CloudTrail activity logs, and Datadog/S3 audit evidence with scheduled periodic review checkpoints. | Not Started |

---

## 2.6 UK Cyber Essentials

| NFR ID | Requirement | Evidence | Status |
|---|---|---|---|
| NFR-CE-01 | MFA Enforcement — MFA is enforced for all user accounts on all cloud services and internet-facing systems. | For GitHub, organisation settings enforce 2FA/MFA for all members and outside collaborators before access is granted. Admin access is further protected with SSO and protected org/repo roles. | Not Started |
| NFR-CE-02 | Malware Protection — Malware protection on all endpoints and servers capable of running malware. | Endpoint/server malware control is provided by GitHub-managed SaaS and runner platform controls. Repository risk is reduced using Snyk (SAST, dependency scanning, container scanning) and branch protection before merge. | Not Started |
| NFR-CE-03 | Patch Management — Security patches applied in line with BA Cyber Guidelines. Automatic updates are enabled where feasible. | GitHub-hosted runners are patched/updated by GitHub. Repository dependencies and GitHub Actions versions are monitored and updated via Dependabot/security update workflow, with PR-based approval and audit trail. | Not Started |
| NFR-CE-04 | Hardened Base Configurations — All compute resources are deployed from hardened, approved base configurations. Default credentials removed before deployment. | CI compute uses GitHub-hosted ephemeral runner images managed by GitHub hardening baselines; no static default credentials are stored in repositories, and secrets are managed through GitHub Secrets/OIDC short-lived credentials. | Not Started |
| NFR-CE-05 | Cloud Asset Inventory — Complete inventory of all in-scope cloud resources maintained and reviewed quarterly. | In-scope assets include GitHub organisations, repositories, teams, environments, runners, apps, and secrets/policies. Inventory is maintained via GitHub API/export and reviewed quarterly through governance review. | Not Started |
| NFR-CE-06 | End-of-Life Prohibition — No end-of-life operating systems, frameworks, or runtimes in production. Migration plan required 6 months before EOL. | GitHub controls enforce supported runtimes/actions in workflows, with Dependabot and security alerts used to identify deprecated/EOL dependencies and trigger upgrade PRs before EOL milestones. | Not Started |

---

## 2.7 UK CAA / NIS Regulations

> **Not applicable** — UK CAA / NIS Regulations do not apply to this solution, as confirmed in the Section Applicability matrix (Section 1.1). All entries below are recorded for completeness only.

| NFR ID | Requirement | Evidence | Status |
|---|---|---|---|
| NFR-CAA-01 | Incident Reporting — Significant cyber incidents reported to CAA within 72 hours. | Not applicable — UK CAA/NIS Regulations are out of scope for this solution as indicated in the Section Applicability matrix. | Not Applicable |
| NFR-CAA-02 | Supply Chain Security — Third-party suppliers subject to security risk assessments with right-to-audit clauses. | Not applicable — UK CAA/NIS Regulations are out of scope for this solution as indicated in the Section Applicability matrix. | Not Applicable |
| NFR-CAA-03 | Asset Inventory — Complete inventory of assets supporting essential aviation services, including dependencies. | Not applicable — UK CAA/NIS Regulations are out of scope for this solution as indicated in the Section Applicability matrix. | Not Applicable |
| NFR-CAA-04 | Cybersecurity Training — Annual training for all staff with access to essential aviation systems. | Not applicable — UK CAA/NIS Regulations are out of scope for this solution as indicated in the Section Applicability matrix. | Not Applicable |
| NFR-CAA-05 | Anomaly Detection — Behavioural baselines established with alerting on deviations from normal patterns. | Not applicable — UK CAA/NIS Regulations are out of scope for this solution as indicated in the Section Applicability matrix. | Not Applicable |
| NFR-CAA-06 | Post-Incident Review — Reviews completed within 5 working days with root cause analysis and tracked remediation. | Not applicable — UK CAA/NIS Regulations are out of scope for this solution as indicated in the Section Applicability matrix. | Not Applicable |
| NFR-CAA-07 | IR Plan Testing — Incident response plan tested annually through tabletop exercises or live simulations. | Not applicable — UK CAA/NIS Regulations are out of scope for this solution as indicated in the Section Applicability matrix. | Not Applicable |
| NFR-CAA-08 | Safety Classification — Systems affecting airworthiness or flight safety are classified with additional safety assurance NFRs. | Not applicable — UK CAA/NIS Regulations are out of scope for this solution as indicated in the Section Applicability matrix. | Not Applicable |
| NFR-CAA-09 | ISMS Requirement — Aviation systems subject to EASA Part IS or CAA AMC 1753 shall implement ISO 27001-aligned ISMS. | Not applicable — UK CAA/NIS Regulations are out of scope for this solution as indicated in the Section Applicability matrix. | Not Applicable |

---

## 2.8 Interoperability

| NFR ID | Requirement | Evidence | Status |
|---|---|---|---|
| NFR-INT-01 | API Standards & Versioning — Standard protocols, versioned interfaces, backward compatibility, and documented SLAs. | The CI/CD solution uses standard HTTPS/API-based integrations between GitHub Actions, AWS APIs, and evidence services. Version control is enforced through the Runtime Technology Compatibility Matrix, versioned package repositories in CodeArtifact, immutable container/image references in ECR and AMIs, and a JSON release manifest that carries approved version identifiers across environments. Backward compatibility is supported by controlled promotion through GitHub Environments and fail-closed validation of declared runtime versions before deployment. Documented operational expectations are represented through governed workflow approvals, release controls, and phase-based integration boundaries; formal consumer-facing API SLA documentation remains an external service management artifact outside the CI/CD platform itself. | Not Started |

---

## 2.9 Reliability

| Aspect | Your Target |
|---|---|
| Availability | 99.9% for production CI/CD control plane and deployment services |
| RTO | 4 hours |
| RPO | 1 hour |
| Multi-AZ Required | Not directly applicable to the GitHub control plane because GitHub is a SaaS service. Multi-AZ design for the GitHub platform is managed by GitHub, not by this solution. |
| Backup Frequency | Applicable only to customer-managed CI/CD assets hosted in AWS (for example evidence store, configuration data, Terraform state, and related artifacts). It does not apply to the GitHub SaaS platform itself. |
| DR Test Cadence | Applicable for customer-managed AWS services and operational recovery procedures supporting the CI/CD solution. It is not defined for the GitHub SaaS platform, which is managed by GitHub. |
| Infrastructure / HA | Not directly applicable to GitHub SaaS infrastructure. High availability of the GitHub platform is provided by the SaaS provider. This solution only defines HA requirements for customer-managed AWS components, where used. |

| NFR ID | Requirement | Evidence | Status |
|---|---|---|---|
| NFR-REL-01 | Availability Target — Service availability target defined and reflected in architecture choices per tier. | GitHub Actions SaaS availability is governed by GitHub's published SLA and is not defined by this solution. Customer-managed AWS components (S3, EventBridge, SSM Parameter Store) are regionally redundant AWS-managed services with published availability SLAs. No additional configuration is required for these managed service tiers. | Not Started |
| NFR-REL-02 | Self-Healing — Critical components tolerate single-instance failure through automation. | GitHub Actions automatically queues and retries pipeline jobs on runner failure. AWS managed services used by this solution (EventBridge, S3, SSM) are self-healing by design. Ephemeral builder EC2 instances are terminated after each AMI build run; a fresh instance is launched on the next pipeline execution, eliminating persistent single-instance failure risk. | Not Started |
| NFR-REL-03 | Multi-AZ Resilience — Application deployed Multi-AZ where required by tier, with appropriate failover. | Not applicable to the GitHub CI/CD control plane. GitHub is a SaaS service; Multi-AZ design for the platform is managed by GitHub. Customer-managed AWS components (S3, EventBridge, Lambda) are inherently multi-AZ AWS managed services. Builder EC2 instances are ephemeral and single-use per pipeline run; they are not long-lived stateful services requiring AZ redundancy. | Not Applicable (GitHub SaaS); Met (AWS managed services) |
| NFR-REL-04 | Backup & Restore — Backup and restore for all stateful data with defined retention and tested procedures. | Compliance evidence bucket (S3) is protected by Object Lock, versioning enabled, and SSE-KMS encryption. SSM Parameter Store parameters (RTCM baseline, deployment decisions) should be exported as part of the recovery runbook. Backup scope and restore procedures are applicable only to these customer-managed AWS assets; GitHub SaaS data is managed by GitHub. | Not Started |
| NFR-REL-05 | Disaster Recovery — RTO/RPO targets defined with the DR approach selected and periodically tested. | Not applicable to the GitHub SaaS control plane. DR for the GitHub platform is managed by GitHub. For customer-managed AWS components, recovery is supported by S3 Object Lock versioned evidence and SSM Parameter Store exports. Formal RTO/RPO targets and a tested DR runbook for customer-managed components (evidence store and audit data buckets) are required but not yet defined. | Not Started |
| NFR-REL-06 | Service Limits — AWS service limits are monitored and raised where needed to prevent outages. | CloudWatch Alarms and SNS alert routing are modelled for pipeline and runtime health. AWS Service Quotas for ECR, EventBridge, S3, and SSM Parameter Store should be reviewed and, where near-limit thresholds are reached, quota increase requests raised. | Not Started |

---

## 2.10 Performance Efficiency

| NFR ID | Requirement | Evidence | Status |
|---|---|---|---|
| NFR-PERF-01 | Performance Targets — Latency, throughput, and concurrency requirements defined and validated via testing. | Architecture includes observability stack (CloudWatch, OpenTelemetry, X-Ray) for measurement, but explicit numeric SLO/SLA targets (latency/throughput/concurrency) and performance test evidence are not yet defined in this repository. | Not Started |
| NFR-PERF-02 | Scalability — Application scales to demand using appropriate patterns with documented limits. | Design uses scalable managed components (GitHub Actions orchestration, EventBridge, S3, SSM) and container/image pipelines; however, documented scaling limits, threshold values, and capacity test results are not yet captured. | Not Started |
| NFR-PERF-03 | Trade-off Decisions — Architecture trade-offs (latency vs consistency, cost vs performance) documented. | Current architecture documents tool selections and governance rationale, but explicit performance trade-off records (for example cost/performance decision logs with accepted impacts) are not formally documented. | Not Started |
| NFR-PERF-04 | Managed Services — Managed services are preferred where they reduce operational overhead (unless justified). | Core platform design is managed-service-first throughout all layers: **CI/CD orchestration** — GitHub Actions (SaaS); **pipeline integration** — EventBridge, S3, SSM Parameter Store; **observability** — CloudWatch, X-Ray, SNS; **security scanning and detection** — Snyk (SaaS — SAST, dependency, and container vulnerability scanning), Amazon Inspector, Amazon ECR Enhanced Scanning, Amazon GuardDuty, AWS Security Hub, AWS IAM Access Analyzer; **IaC policy scanning** — tfsec, Checkov (executed as pipeline steps inside GitHub Actions SaaS, no self-managed infrastructure required); **cryptographic controls** — AWS KMS (managed CMK); **audit and logging** — Datadog, AWS CloudTrail. No self-managed security tooling infrastructure is introduced; all scanning, detection, and logging capabilities are consumed as managed services or SaaS. | Met |

---

## 2.11 Cost Optimisation

| NFR ID | Requirement | Evidence | Status |
|---|---|---|---|
| NFR-COST-01 | Cost Allocation Tagging — Mandatory tagging and account/region attribution for all in-scope resources. | Environment/account separation is modelled (dev/test/prod and per-environment Terraform backends), but a mandatory enterprise tagging standard and enforcement control are not explicitly documented in current artifacts. | Partially Met |
| NFR-COST-02 | Budget Alerts — Budgets and alerts configured for application spend and anomalous usage. | Operational alerting (CloudWatch + SNS) is described, but AWS Budgets / cost anomaly alert configuration and thresholds are not explicitly defined as cost controls. | Not Started |
| NFR-COST-03 | Right-Sizing — Capacity is right-sized and reviewed periodically; autoscaling and scheduling are used to avoid idle spend. | Managed/serverless-first components reduce idle overhead (EventBridge, S3), and ephemeral builder instances are created per run and terminated after AMI build. Formal right-sizing review cadence and capacity baselines are not yet documented. | Partially Met |
| NFR-COST-04 | Data Lifecycle — Retention, tiering, and archival policies are defined to control storage cost over time. | Evidence storage retention is defined (S3 Object Lock, 7-year retention, versioning). Explicit lifecycle tiering/archival transitions (for example IA/Glacier classes and transition schedule) are not yet documented. | Partially Met |

---

## 2.12 Sustainability

| NFR ID | Requirement | Evidence | Status |
|---|---|---|---|
| NFR-SUS-01 | Sustainability Metrics — The established goals and metrics are appropriate to the service. | The managed-service-first design (managed event bus, SaaS CI/CD) structurally reduces per-transaction energy overhead relative to self-hosted alternatives, but no formal sustainability targets have been established for this solution. | Not Started |
| NFR-SUS-02 | Utilisation Maximisation — Avoid chronic overprovisioning using autoscaling/scheduling and periodic reviews. | Ephemeral builder EC2 instances are launched per pipeline run and terminated immediately after AMI registration, eliminating persistent idle infrastructure. EventBridge Scheduler and GitHub Actions SaaS runners are event-driven with no always-on compute. Scheduled drift scan (EventBridge Scheduler) runs on cadence and consumes no resources outside its execution window. | Partially Met |
| NFR-SUS-03 | Data Locality — Minimise unnecessary data movement and retention. | All customer-managed AWS components (S3 evidence bucket, SSM Parameter Store, ECR) are deployed within a single defined AWS region. Evidence is produced and stored in the same region without cross-region replication overhead. Retention is bounded by defined policy (7-year Object Lock for evidence; ephemeral builder instances leave no persistent data). Cross-region data movement is not introduced by the architecture. | Met |
