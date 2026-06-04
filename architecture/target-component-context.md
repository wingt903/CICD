# AWS Target Component Context (Superseded)

> ⚠️ **This document has been merged into the unified component context diagram.**
> Please refer to the single authoritative source:
> - Diagram: [`architecture/component-context-diagram.mmd`](./component-context-diagram.mmd)
> - Integration reference: [`architecture/component-context-diagram.md`](./component-context-diagram.md)

## Scope assumptions

- **ServiceNow integration is moved to Phase 2.** Phase 1 starts from GitHub-governed approvals and standardized deployment evidence handoff rather than live ServiceNow-triggered orchestration.
- **Application teams operate in two repository models:** **one repository per environment** and **one repository for all environments**. The target control model supports both.

## Promotion model

- Single promotion path: `dev -> test -> prod`
- Separate deploy roles per environment/account via GitHub OIDC:
  - `AWS_DEV_ROLE_ARN`
  - `AWS_TEST_ROLE_ARN`
  - `AWS_PROD_ROLE_ARN`
- Environment-specific approved AMI paths in Parameter Store:
  - `/dev/approved/ami/base`
  - `/test/approved/ami/base`
  - `/prod/approved/ami/base`

## Supported application team operating models

- **One repository per environment**: each environment-specific repository triggers the same governed pipeline controls for its target environment.
- **One repository for all environments**: a single repository carries environment-specific configuration and promotes the same release through `dev -> test -> prod`.

## Capability mapping

- Approved baseline publication: governed commit approval produces a release manifest and published desired-state baseline.
- Drift control: EventBridge Scheduler triggers recurring drift scans that collect live state and compare it to the approved baseline.
- Compliance decisioning: comparison returns either a compliant state or a drift event that must be stored.
- Auto-remediation: drift events trigger restore-to-baseline automation through Terraform, Ansible, or DB migration controls.
- Audit persistence and reporting: audit events land in a DynamoDB-backed audit database and are surfaced through Splunk and Grafana dashboards.

## Diagram

- Mermaid source: `architecture/target-component-context.mmd`
