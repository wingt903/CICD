# CI/CD Migration Pipeline — Sequence Diagram

## Diagram

```mermaid
sequenceDiagram
    autonumber
    actor Team as CAR Architecture Team
    participant GH as GitHub Actions Runner
    participant Baseline as Approved Baseline Publisher
    participant Scheduler as EventBridge Scheduler
    participant Collector as State Collector
    participant Compare as Comparison Engine
    participant Remediate as Auto Remediation
    participant EvidenceBus as EventBridge Evidence Bus
    participant AuditDB as Audit Database
    participant Splunk as Splunk
    participant Grafana as Grafana

    %% Phase 1: Commit Approval and Baseline Publication
    activate GH
    GH->>GH: Git commit approved through governed workflow
    GH->>Baseline: Publish approved baseline
[release manifest, AMI, IaC, runtime versions]
    Baseline->>AuditDB: Record baseline publication event

    %% Phase 2: Scheduled Drift Scan
    Scheduler->>Collector: Start scheduled drift scan
    Collector->>Collector: Collect live infra, runtime, and DB state
    Collector->>Compare: Submit current state snapshot
    Baseline->>Compare: Supply approved baseline
    Compare->>Compare: Evaluate live state vs approved baseline

    alt No drift found
        Compare->>EvidenceBus: Publish compliant state event
[result=PASS, remediation_state=NOT_REQUIRED]
        EvidenceBus->>AuditDB: Store compliance event
    else Drift found
        Compare->>EvidenceBus: Publish drift event
[result=FAIL, remediation_state=PENDING]
        EvidenceBus->>AuditDB: Store drift event
        AuditDB->>Remediate: Trigger auto-remediation workflow
        Remediate->>Remediate: Restore approved baseline
[terraform apply, config rerun, DB migration]
        Remediate->>Collector: Re-collect post-remediation state
        Collector->>Compare: Submit post-remediation snapshot
        Compare->>EvidenceBus: Publish remediation outcome
[result=PASS|FAIL, remediation_state=COMPLETE|FAILED]
        EvidenceBus->>AuditDB: Store remediation event
    end

    %% Phase 3: Reporting
    AuditDB->>Splunk: Forward audit and drift events
    AuditDB->>Grafana: Refresh compliance dashboards
    deactivate GH
```

## Component Descriptions

| # | Component | Description |
|---|-----------|-------------|
| 1 | **CAR Architecture Team** | The human actor who approves the governed change and owns the approved target baseline. |
| 2 | **GitHub Actions Runner** | The orchestration engine that publishes approved baselines and manages the scheduled drift control workflow. |
| 3 | **Approved Baseline Publisher** | The component that records the approved release manifest, AMI, IaC version, and runtime policy used as drift-comparison input. |
| 4 | **EventBridge Scheduler** | The time-based trigger that starts recurring drift scans after the approved baseline is published. |
| 5 | **State Collector** | The component that gathers live infrastructure, runtime, and database state for the drift scan. |
| 6 | **Comparison Engine** | The evaluator that compares collected state with the approved baseline and decides whether drift exists. |
| 7 | **Auto Remediation** | The restore-to-baseline automation that runs Terraform, configuration re-runs, or database migrations after a drift event is stored. |
| 8 | **EventBridge Evidence Bus** | The evidence routing layer that carries compliant, drift, and remediation events to the audit data store. |
| 9 | **Audit Database** | The indexed audit repository that stores baseline publication, compliance, drift, and remediation events for reporting. |
| 10 | **Splunk** | The SIEM/reporting sink that receives audit and drift events for operational analysis. |
| 11 | **Grafana** | The dashboard sink that visualizes drift posture, remediation results, and compliance state over time. |
