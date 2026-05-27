# Requirement Traceability Document

## Requirement Entry

| Field | Details |
|---|---|
| Requirement ID | RA-DEP-001 |
| Requirement Title | Automated Application Deployment and Configuration |
| Requirement Statement | The organisation must enable automated, repeatable deployment and configuration of applications to reduce reliance on manual activities, lower the risk of misconfiguration, and accelerate the secure delivery of services. |
| Programme Context | Group 2 / Stage 1 - Hardening, Patching & Control Implementation (CI/CD pipelines, IaC, and deployment automation controls) |
| Control Objective | Ensure deployment and configuration changes are performed through controlled, auditable, automated mechanisms rather than manual ad hoc activities. |
| Implementation Evidence (expected) | Version-controlled CI/CD workflows, IaC templates, pull-request approvals, deployment logs, release manifests, environment promotion approvals, rollback records |
| Status | Draft |

## Standards and Framework Mapping (with version validation)

| Source | Requirement Reference | Version to Use for This Requirement | Why this version is correct for this requirement text | Official Source Link |
|---|---|---|---|---|
| ISO/IEC 27001 | A.12.1.2 (Change management) | **ISO/IEC 27001:2013** (Annex A control numbering) | Control identifier format `A.12.1.2` matches Annex A numbering used in ISO/IEC 27001:2013. In ISO/IEC 27001:2022, Annex A was restructured and this exact identifier is not used. | https://www.iso.org/isoiec-27001-information-security.html |
| NIST Cybersecurity Framework | PR.IP-3 (Configuration change control processes in place) | **NIST CSF v1.1** | Subcategory identifier `PR.IP-3` is from CSF v1.1 structure. CSF 2.0 uses a different taxonomy and identifiers. | https://www.nist.gov/cyberframework/framework-version-11 |
| NCSC Cyber Assessment Framework (CAF) | B2.a (Secure configuration of systems) | **NCSC CAF (current published CAF principles/guidance)** | Outcome identifier format `B2.a` corresponds to CAF Objective B, Principle B2. | https://www.ncsc.gov.uk/collection/caf/caf-principles-and-guidance |

## Source-of-Authority Validation Notes

1. The requirement statement itself should be traced to the project/customer governance source (for example policy baseline, contract clause, control catalogue, or regulator mapping).
2. Standards references above are external control frameworks used for control mapping and assurance evidence.
3. Where an identifier is version-specific (`A.12.1.2`, `PR.IP-3`), always record the matching framework version in this document.

## Glossary (Short Terms / Acronyms)

| Term | Meaning |
|---|---|
| CI/CD | Continuous Integration / Continuous Delivery (or Deployment) |
| IaC | Infrastructure as Code |
| ISO | International Organization for Standardization |
| IEC | International Electrotechnical Commission |
| ISO/IEC 27001 | International standard for information security management systems (ISMS) |
| NIST | National Institute of Standards and Technology (United States) |
| CSF | Cybersecurity Framework (published by NIST) |
| PR.IP-3 | NIST CSF v1.1 subcategory: configuration change control processes are in place |
| NCSC | National Cyber Security Centre (United Kingdom) |
| CAF | Cyber Assessment Framework (published by NCSC) |
| B2.a | NCSC CAF outcome under Objective B / Principle B2: secure configuration of systems |
| ISMS | Information Security Management System |

