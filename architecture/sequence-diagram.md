# CI/CD Migration Pipeline — Sequence Diagram

## Diagram

```mermaid
sequenceDiagram
    autonumber
    actor Team as CAR Architecture Team
    participant SN as ServiceNow (CMDB / Phase 2)
    participant GH as GitHub Actions Runner
    participant RTCM as RTCM Baseline
    participant Scheduler as EventBridge Scheduler
    participant DriftReconciler as Drift Reconciler
    participant PolicyGate as Policy/Approval Gate
    participant TerraformEnforcer as Terraform/Config Enforcer
    participant DatabaseDriftController as DB Drift Controller
    participant AWS_SSM as AWS Systems Manager
    participant EC2 as Temporary Builder EC2
    participant EvidenceBus as EventBridge Evidence Bus
    participant EvidenceStore as Evidence Store
    participant AuditTrail as CloudTrail Audit

    %% Phase 1: Intake & Governance
    Team->>SN: Submit Catalog Migration Request
    Note over SN: Approvals complete.<br>Create/Update CMDB CI Configuration.
    SN->>GH: Trigger workflow webhook<br/>[AppID, middleware, env, changeId]
    Note over SN,GH: ServiceNow webhook is Phase 2 target state.<br/>Phase 1 starts from governed GitHub dispatch + manual ITSM handoff.

    %% Phase 2: Orchestration & Checkout
    activate GH
    GH->>GH: Run git checkout (app code + Ansible roles)
    Note over GH: Supports both application team models:<br/>one repository per environment or one repository for all environments.
    Note over GH: If Java (Tomcat/WebLogic):<br/>Compile source to .WAR/.EAR via Maven
    GH->>RTCM: Load approved RTCM baseline<br/>[repo artifact + /cicd/rtcm/approved/current]
    GH->>GH: Validate app middleware + DB versions<br/>against approved RTCM before install
    alt RTCM validation rejected
        GH->>SN: Open remediation task<br/>[technology, declared version, approved range]
        GH->>EvidenceBus: Publish RTCM rejection evidence<br/>[control_id=rtcm-compatibility-check, result=FAIL, baseline_ref, run_id, details_ref]
        EvidenceBus->>EvidenceStore: Ingestor validates schema and signature,<br/>writes to S3 Object Lock + DynamoDB index
        EvidenceStore->>AuditTrail: S3 PutObject event captured (actor, timestamp, key, requestId)
        Note over GH: Pipeline terminates before image build,<br/>middleware install, or DB migration
    else RTCM validation approved
        GH->>EvidenceBus: Publish RTCM approval evidence<br/>[control_id=rtcm-compatibility-check, result=PASS, baseline_ref, run_id, details_ref]
        EvidenceBus->>EvidenceStore: Ingestor validates schema and signature,<br/>writes to S3 Object Lock + DynamoDB index
        EvidenceStore->>AuditTrail: S3 PutObject event captured (actor, timestamp, key, requestId)
    end
    Note over GH,AWS_SSM: Remaining build and installation phases execute only after RTCM PASS
    GH->>AWS_SSM: Assume IAM role via OIDC (temporary credentials)
    GH->>GH: Init Ansible controller + install SSM Session Manager plugin

    %% Phase 3: Cloud Execution via SSM Session Manager
    GH->>GH: Trigger Ansible Image Build Playbook
    activate AWS_SSM
    GH->>AWS_SSM: Launch EC2 in private subnet (no public IP, no SSH) via amazon.aws
    Note over GH, EC2: Ansible communicates over encrypted SSM Session Manager tunnel<br>(no SSH required)
    GH->>EC2: Push app artifacts + Ansible playbooks via SSM tunnel

    %% Phase 4: Inner-Loop Configuration Management
    activate EC2
    Note over EC2: Local Ansible execution starts:<br>1. Hardens Base OS<br>2. Sets up selected Middleware (Tomcat/WebLogic/Python)<br>3. Injects Application Artifacts
    EC2-->>GH: Streaming Logs / Success Code
    deactivate EC2

    %% Phase 5: Image Serialization & CMDB Loopback
    GH->>AWS_SSM: Stop instance + register golden AMI via amazon.aws
    GH->>AWS_SSM: Ansible terminates Temporary Builder Instance
    AWS_SSM-->>GH: Return New AMI ID (e.g., ami-01234abcd)
    deactivate AWS_SSM

    GH->>SN: Send API patch:<br/>Update CMDB CI with new AMI ID + Ansible run refs
    Note over SN: Phase 2 target: CMDB and change record updated with<br/>AMI + Ansible evidence for audit tracking.<br/>Phase 1 uses manual/governed handoff.
    GH->>EvidenceBus: Publish normalized evidence event
    Note over GH,EvidenceBus: Fields include system_id, env, baseline_ref, control_id, result, run_id, source.<br/>Full 12-field schema: compliance-evidence-store.md section 1.
    EvidenceBus->>EvidenceStore: Ingestor validates schema, signs record (KMS),<br/>writes to S3 Object Lock + DynamoDB index
    EvidenceStore->>AuditTrail: S3 PutObject event captured (actor, timestamp, key, requestId)

    %% Phase 6: Continuous Drift Detection and Closed-Loop Remediation
    Scheduler->>DriftReconciler: Scheduled reconciliation trigger
    Note over DriftReconciler: Compare live AWS config<br/>vs Git Terraform baseline (source of truth)
    DriftReconciler->>SN: Publish drift findings and evidence
    DriftReconciler->>PolicyGate: Raise remediation decision request
    alt Policy allows auto-remediation
        PolicyGate->>TerraformEnforcer: Authorize enforce baseline execution
    else Manual approval required
        PolicyGate->>Team: Request approval for controlled remediation
        Team->>PolicyGate: Approve remediation
        PolicyGate->>TerraformEnforcer: Authorize enforce baseline execution
    end
    TerraformEnforcer->>TerraformEnforcer: Run Terraform apply/config re-run<br/>to match repository baseline
    TerraformEnforcer->>DriftReconciler: Return post-remediation state
    DriftReconciler->>DriftReconciler: Verify convergence to desired baseline
    DriftReconciler->>SN: Update CMDB/compliance status with closure evidence
    DriftReconciler->>EvidenceBus: Publish drift remediation evidence event
    Note over DriftReconciler,EvidenceBus: Fields include system_id, baseline_ref, result, remediation_state, source.<br/>Full 12-field schema: compliance-evidence-store.md section 1.
    EvidenceBus->>EvidenceStore: Ingestor signs + writes evidence<br/>to S3 Object Lock + DynamoDB index
    EvidenceStore->>AuditTrail: S3 PutObject event captured

    %% Phase 7: Dedicated Database Drift Detection and Remediation
    Scheduler->>DatabaseDriftController: Scheduled database drift control trigger
    DatabaseDriftController->>DatabaseDriftController: Detect schema/config drift<br/>against versioned migration baseline
    alt DB drift detected
        DatabaseDriftController->>PolicyGate: Request migration remediation decision
        PolicyGate->>DatabaseDriftController: Approve migration execution policy
        DatabaseDriftController->>DatabaseDriftController: Execute migration orchestration
        alt Migration validation fails
            DatabaseDriftController->>DatabaseDriftController: Execute rollback (snapshot restore/previous migration)
        end
        DatabaseDriftController->>DatabaseDriftController: Perform post-remediation validation
        DatabaseDriftController->>SN: Publish DB drift status and remediation evidence
        DatabaseDriftController->>EvidenceBus: Publish DB remediation evidence event
        Note over DatabaseDriftController,EvidenceBus: Fields include system_id, baseline_ref, control_id=db-schema, result, remediation_state, source.<br/>Full 12-field schema: compliance-evidence-store.md section 1.
        EvidenceBus->>EvidenceStore: Ingestor signs + writes evidence<br/>to S3 Object Lock + DynamoDB index
        EvidenceStore->>AuditTrail: S3 PutObject event captured
    else No DB drift
        DatabaseDriftController->>SN: Record compliant DB baseline state
        DatabaseDriftController->>EvidenceBus: Publish compliant DB evidence event<br>[result=PASS, remediation_state=NOT_REQUIRED, source=db-drift-controller]
        EvidenceBus->>EvidenceStore: Ingestor signs + writes compliant evidence
    end
    deactivate GH

    %% Phase 8: Daily Integrity Verification and Audit Reporting
    Note over EvidenceStore,AuditTrail: Daily: Integrity Verifier re-hashes evidence records,<br/>validates KMS signatures, and publishes pass/fail metrics.<br/>CloudWatch alarms on verification failure → SNS alert.
    Note over EvidenceStore,AuditTrail: Cyber Security Operations Analysts access reports via Cyber Security Operations Analyst Export API<br/>(AWS Audit Manager PDF + Athena CSV/JSON).<br/>All report access is logged to CloudTrail.
```

---

## Component Descriptions

| # | Component | Description |
|---|-----------|-------------|
| 1 | **CAR Architecture Team** | The human actor who initiates the process by submitting a migration catalog request and is also the manual approver for controlled remediation decisions. |
| 2 | **ServiceNow (CMDB / Phase 2)** | The entry point where project teams submit migration requests; it manages CMDB CI configuration, approvals, change records, and receives status updates throughout the pipeline. |
| 3 | **GitHub Actions Runner** | The central orchestration engine that coordinates all pipeline stages—from code checkout and RTCM validation to Ansible playbook execution, AMI registration, and evidence publishing. |
| 4 | **RTCM Baseline** | The approved runtime compatibility matrix (stored as a repo artifact and mirrored in SSM Parameter Store) that GitHub Actions queries to validate declared middleware and DB versions before any build proceeds. |
| 5 | **EventBridge Scheduler** | The time-based trigger that fires scheduled reconciliation jobs for both infrastructure drift detection and database drift detection at configured intervals. |
| 6 | **Drift Reconciler** | The component that compares live AWS configuration against the Git Terraform baseline (source of truth) to detect infrastructure drift and verify post-remediation convergence. |
| 7 | **Policy/Approval Gate** | The decision point that evaluates whether drift remediation can be auto-approved or must be escalated to the project team for manual approval before enforcement is authorized. |
| 8 | **Terraform/Config Enforcer** | The executor that runs `terraform apply` or config re-runs to bring live infrastructure back in line with the repository baseline after remediation is authorized. |
| 9 | **DB Drift Controller** | The dedicated controller that detects schema or configuration drift against the versioned migration baseline and orchestrates migration execution, rollback, and post-remediation validation for databases. |
| 10 | **AWS Systems Manager (SSM)** | The AWS control-plane service used for OIDC-based IAM role assumption, launching EC2 instances in private subnets, providing encrypted Session Manager tunnels (no SSH), and registering golden AMIs. |
| 11 | **Temporary Builder EC2** | A short-lived EC2 instance (no public IP, no SSH) launched in a private subnet where the local Ansible execution hardens the OS, installs middleware, and injects application artifacts to produce the golden image. |
| 12 | **EventBridge Evidence Bus** | The event routing layer that receives normalized compliance evidence events from all pipeline components and forwards them to the Evidence Store ingestor for validation and persistence. |
| 13 | **Evidence Store** | The immutable compliance record repository that validates event schemas, signs records with KMS, and writes them to S3 Object Lock (append-only) with a DynamoDB index for query access. |
| 14 | **CloudTrail Audit** | The AWS audit log that automatically captures every S3 `PutObject` event (actor, timestamp, key, requestId) as evidence records are written, and logs all auditor report access. |
