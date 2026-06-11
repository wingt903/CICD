# POC to Containerize Legacy BA Opco Applications

| Field   | Details          |
|---------|------------------|
| Title   | POC to containerize legacy BA Opco applications |
| Version | 1.2              |
| Date    | 29/07/2025       |

---

## 1. Objective

To conduct analysis and facilitate deployment of BA applications in AWS Fargate containers.

---

## 2. Software Info

### Software Versions, Compatibility & End-of-Life Information

Amazon ECS with Fargate launch type is used to containerize applications with app-specific tech stacks. Container images are stored in an ECR private repository.

| Component | Details |
|-----------|---------|
| Container Orchestration | Amazon ECS (Fargate launch type) |
| Image Registry | Amazon ECR (private repository) |
| Base OS Images | Amazon Linux 2023 / Red Hat UBI (Linux), Windows Server 2019/2022 |
| Web Layer | Apache HTTPD |
| App Layer | Apache Tomcat |
| Session Persistence | Amazon ElastiCache for Redis |
| Service Discovery | AWS Cloud Map / ECS Service Discovery |
| Load Balancing | Application Load Balancer (ALB) |
| Log Routing | Amazon CloudWatch Logs / FireLens (Fluent Bit sidecar) |
| Monitoring | Datadog |
| Messaging | Amazon MQ / Apache ActiveMQ (cloud-native replacement) |
| Batch / Scheduling | AWS Step Functions + Lambda (cloud-native replacement) |
| File Transfer | AWS Transfer Family (cloud-native replacement) |
| Identity Provider | Microsoft Entra ID |

> **Note:** All End-of-Life (EoL) assessments for third-party software (e.g., Tomcat, Apache HTTPD, JDK) must be reviewed against vendor roadmaps prior to containerization. Use only vendor-supported versions that have active security patch coverage.

---

## 3. Qualifying Criteria

### Overview

Moving an application to containers is based on its tech stack and application interface. The following analysis is based on official documentation and other resources.

### R-Factor Classification

| R-Factor | Definition |
|----------|-----------|
| **Rehost** | Can be containerized with no code or configuration changes |
| **Reconfigure** | Remediate application configuration prior to containerization |
| **Refactor** | Remediate application code prior to containerization, or move to a cloud-native solution instead of containerization |
| **Retain** | Cannot be containerized; remains on existing infrastructure |

---

### Technical Criteria Matrix

| Tech Group | Tech Stack / Application Interface | Containerization | Solution | Challenges / Limitations | R-Factor | Remarks |
|------------|-----------------------------------|:----------------:|----------|--------------------------|----------|---------|
| **OS** | Linux | ✅ Green | Amazon Linux / RHEL UBI images — free, lightweight, easy to harden, has own package repos (no subscription needed) | — | Rehost | Agreed hardening and image management process must be followed. See [AWS Foundation for ECS]. |
| **OS** | Linux (app depends on RHEL RPM packages not in UBI repo) | ✅ Green | RHEL Container Base Image with RHEL packages | RHEL packages availability | Retain / Refactor | Agreed hardening and image management process must be followed. Licensing impact must be assessed. |
| **OS** | Windows | ❌ Red | Not recommended | Large image size; limited native support (only 2019 & 2022); Fargate does not natively support AD integration; complex apps (e.g., AD, Tableau) are not suitable | Retain | — |
| **OS** | Windows (simple lightweight apps) | ✅ Green | Containerizable | — | Rehost | Agreed hardening and image management process must be followed. See [AWS Foundation for ECS]. |
| **Web Layer** | Apache | ✅ Green | Install required version of httpd on top of Linux image | — | Rehost | — |
| **Web Layer + IdP** | Integration with Entra ID | ✅ Green | Applications must integrate with Entra for authentication and authorization | — | Reconfigure | Confirmed with Entra ID team — no server-side dependency. All other IdPs (OAM, Ping, etc.) must migrate to Entra to qualify for containerization. |
| **Web Layer + IdP** | Apache + OAM Webgate | ❌ Red | OAM-authenticated applications must switch to Entra before containerization | OAM is not a strategic IdP tool | Refactor | — |
| **Web Layer + IdP** | Integration with Ping | ❌ Red | Ping-authenticated applications must switch to Entra before containerization | Ping is not a strategic IdP tool | Reconfigure | — |
| **App Layer** | Apache + Tomcat | ✅ Green | Apache and Tomcat run in separate ECS tasks | — | Rehost | — |
| **App Layer** | Tomcat | ✅ Green | Install Tomcat on top of Linux image; use AWS Cloud Map / ECS Service Discovery for task discovery | — | Rehost | — |
| **App Layer** | Tomcat Clusters / Stateful Applications | ✅ Green | Amazon ElastiCache for Redis for session persistence; Apache → ALB → Tomcat tasks; enable sticky sessions on ALB | Session stickiness management | Refactor | Session data persisted in Redis. ALB placed in front of ECS service tasks with target stickiness enabled. |
| **App Layer** | Apache + WebLogic | ❌ Red | Not in scope | ECS Fargate does not support multicast (used by WebLogic clusters for node discovery) | Retain / Refactor | All WebLogic applications must be migrated to Tomcat or modernized before containerization. |
| **Application Logs** | Apache / Tomcat logs | ✅ Green | `awslogs` log driver; FireLens (Fluent Bit) sidecar to forward logs to CloudWatch Logs, Datadog, ELK, or other destinations | — | Reconfigure | Final logging solution must be validated with the Monitoring team and adopted accordingly. |
| **Batch Jobs** | Control-M Agent | ❌ Red | Not suitable; transition to cloud-native (e.g., AWS Step Functions + Lambda) | Silent-mode installation; network connectivity to Control-M master; system-level access requirement; LDAP-authenticated master connectivity | Retain / Refactor | — |
| **Batch Jobs** | XCOM | ❌ Red | Not suitable; migrate to cloud-native (e.g., AWS DataSync) | Jobs triggered by Control-M; silent-mode agent installation; certificate installation; user-based inter-server communication | Retain / Refactor | — |
| **Batch Jobs** | FTP | ❌ Red | Not ideal; migrate to cloud-native (e.g., AWS Transfer Family) | SSH key generation and distribution; user-based server communication | Retain / Refactor | — |
| **Batch Jobs** | Oracle Client | ❌ Red | Modernize batch jobs to use AWS-native DB connectivity, eliminating Oracle client dependency | Installation from Capsule; DB connectivity validation via sqlplus | Retain / Refactor | — |
| **MQ Based Apps** | MQ Manager (DRBD setup) | ❌ Red | Not suitable; migrate to Amazon MQ or ActiveMQ | DRBD setup uses EBS mount points, which are not supported in containers | Retain / Refactor | Refactor with AWS Amazon MQ / RabbitMQ. |
| **MQ Based Apps** | MQ Client | ❌ Red | MQ managers must be modernized to use AWS-native services, removing MQ client dependency | Installation and network connectivity with MQ manager | Rehost | Not suitable for containerization — transition to cloud-native solution. |
| **External Software** | COTS Products | ✅ Green | Based on product compatibility, vendor support, and license management | Vendor support required for any COTS product containerization | Retain / Refactor | Vendor support needed. |
| **CI/CD Tools** | SVN / Jenkins integration | ❌ Red | Automate build and deploy externally; deploy to container | — | Refactor | — |
| **Other** | Static IP / host-based licensing | ❌ Red | Not possible — containers are not bound to specific IPs | Licensing tied to IP or hostname | Retain | — |
| **Other** | Slow application startup (minutes-long) | ❌ Red | Not possible for Fargate health check windows | Batch or application startups that take minutes | Refactor | — |
| **Other** | Background daemons (syslog, cron, sshd, systemd) | ❌ Red | Scheduled tasks must be modernized | systemd and equivalent daemons are not supported in Fargate | Refactor | Scheduled tasks must be modernized. |
| **Scaling** | Horizontal Scaling | ✅ Green | Increase ECS task count via Auto Scaling | — | Refactor | Recommended to refactor apps with vertical scaling to use horizontal scaling. |
| **Scaling** | Vertical Scaling | ✅ Green | Update task definition CPU/memory via CI/CD automation | Requires CI/CD pipeline update of task definition | Refactor | TBD. |
| **Other** | Redis (self-managed) | ❌ Red | Proceed with managed SaaS solution (Amazon ElastiCache) | Connectivity verification needed | Retain / Refactor | Must modernize to managed service. |

---

## 4. Upgrade Path / Decision Workflow

The following decision workflow determines the appropriate containerization path for each application.

```
START: Application Assessment
         │
         ▼
┌─────────────────────────────────────┐
│ 1. OS Compatibility Check           │
│    Is the OS Linux or lightweight   │
│    Windows?                         │
└───────────────┬─────────────────────┘
                │
         ┌──────┴──────┐
        YES            NO (Windows / complex)
         │              │
         ▼              ▼
  Continue          → RETAIN (cannot containerize)
                      or REFACTOR (modernize first)

         │
         ▼
┌─────────────────────────────────────┐
│ 2. Identity Provider Check          │
│    Does the app use Entra ID?       │
└───────────────┬─────────────────────┘
                │
         ┌──────┴──────┐
        YES             NO (OAM / Ping / other)
         │              │
         ▼              ▼
  Continue          → REFACTOR
                      (migrate IdP to Entra first)

         │
         ▼
┌─────────────────────────────────────┐
│ 3. App Server / Runtime Check       │
│    Is it Apache / Tomcat / standard │
│    Linux runtime?                   │
└───────────────┬─────────────────────┘
                │
         ┌──────┴──────┐
        YES             NO (WebLogic / COTS with restrictions)
         │              │
         ▼              ▼
  Continue          → RETAIN / REFACTOR
                      (migrate to Tomcat or cloud-native)

         │
         ▼
┌─────────────────────────────────────┐
│ 4. Session / State Check            │
│    Is the app stateless or can      │
│    session be externalised?         │
└───────────────┬─────────────────────┘
                │
         ┌──────┴──────┐
   Stateless/           Stateful (sessions critical)
   Externalisable        │
         │              ▼
         │         → REFACTOR
         │           (ElastiCache Redis + ALB sticky sessions)
         ▼
┌─────────────────────────────────────┐
│ 5. Batch / Daemon / MQ Check        │
│    Does the app rely on Control-M,  │
│    XCOM, FTP, MQ Manager, or        │
│    system daemons?                  │
└───────────────┬─────────────────────┘
                │
         ┌──────┴──────┐
        NO             YES
         │              │
         ▼              ▼
  Continue          → RETAIN / REFACTOR
                      (modernise to cloud-native:
                       Step Functions, DataSync,
                       Transfer Family, Amazon MQ)

         │
         ▼
┌─────────────────────────────────────┐
│ 6. Licensing / Static IP Check      │
│    Does the app require static IP   │
│    or host-based licensing?         │
└───────────────┬─────────────────────┘
                │
         ┌──────┴──────┐
        NO             YES
         │              │
         ▼              ▼
  Continue          → RETAIN
                      (licensing incompatible
                       with containers)

         │
         ▼
┌─────────────────────────────────────┐
│ OUTCOME: REHOST / RECONFIGURE       │
│ Application is containerization-    │
│ ready. Proceed with ECS Fargate     │
│ deployment using agreed hardening   │
│ and image management process.       │
└─────────────────────────────────────┘
```

### Summary of Decision Outcomes

| Outcome | Action |
|---------|--------|
| **Rehost** | Deploy directly to ECS Fargate with minimal changes |
| **Reconfigure** | Update application configuration (e.g., IdP, log driver) then deploy to ECS Fargate |
| **Refactor** | Remediate code or architecture (e.g., session externalisation, WebLogic migration, batch modernisation) before containerizing |
| **Retain** | Application remains on existing infrastructure; not suitable for containerization |

---

## 5. Scope of POC vs Outcome

### POC Scope

The POC covers the following in-scope items to validate the containerization approach for qualifying BA Opco applications:

| # | In-Scope Item | Details |
|---|---------------|---------|
| 1 | Linux-based application containerization | Build and deploy containerized Linux workloads using Amazon Linux / RHEL UBI base images |
| 2 | Apache + Tomcat deployment on ECS Fargate | Validate Apache and Tomcat running as separate ECS tasks with service discovery |
| 3 | Stateful Tomcat session management | Validate session persistence using Amazon ElastiCache for Redis with ALB sticky sessions |
| 4 | Entra ID authentication integration | Validate application authentication via Microsoft Entra ID within container runtime |
| 5 | ECR image storage and lifecycle | Validate image push to ECR private repository and image lifecycle policy management |
| 6 | Application log routing | Validate log routing using `awslogs` driver and FireLens (Fluent Bit) sidecar to Datadog / CloudWatch Logs |
| 7 | ECS Fargate horizontal scaling | Validate ECS Auto Scaling for horizontal task scaling |
| 8 | CI/CD pipeline integration | Validate fully automated build, push, and deploy pipeline via GitHub Actions (no developer console access) |
| 9 | Hardened image management | Validate agreed image hardening process and base image governance |

### Out of Scope for POC

| # | Out-of-Scope Item | Reason |
|---|-------------------|--------|
| 1 | Windows containerization | Not recommended due to image size and Fargate limitations |
| 2 | WebLogic containerization | Fargate does not support multicast; migration to Tomcat required first |
| 3 | Control-M / XCOM / FTP batch job containerization | Not suitable for containerization; cloud-native modernization required |
| 4 | MQ Manager (DRBD) containerization | EBS mount point dependency not supported in containers |
| 5 | OAM / Ping IdP integration | Not strategic; must migrate to Entra ID first |
| 6 | Static IP / host-based licensed applications | Incompatible with container networking model |
| 7 | COTS product containerization | Vendor support and licensing assessment required before proceeding |
| 8 | Vertical scaling automation | Deferred; requires further CI/CD task definition update automation design |

### Expected POC Outcomes

| # | Expected Outcome | Success Criteria |
|---|-----------------|-----------------|
| 1 | Linux workload successfully containerized and deployed on ECS Fargate | ECS tasks running in healthy state with desired task count met |
| 2 | Apache + Tomcat architecture validated on Fargate | Both Apache and Tomcat tasks operational; inter-task communication confirmed via service discovery |
| 3 | Session persistence validated | Redis-backed sessions persist across Tomcat task restarts; ALB sticky sessions function correctly |
| 4 | Entra ID authentication confirmed | Application authenticates users via Entra ID within Fargate task context |
| 5 | Log routing confirmed | Application logs (Apache, Tomcat) visible in Datadog / CloudWatch Logs via FireLens |
| 6 | Horizontal scaling confirmed | ECS Auto Scaling increases / decreases task count based on defined metrics |
| 7 | Fully automated pipeline deployment | Developer does not require AWS console access; all deployment actions driven by GitHub Actions |
| 8 | Image hardening baseline confirmed | Container images pass agreed security hardening checks before deployment |

### POC Limitations and Assumptions

- The POC environment is a non-production `dev` environment only; production-grade hardening, WAF, and private subnet design are post-POC activities.
- Network configuration (VPC, subnets, security groups) must be pre-provisioned or provided as Terraform inputs before POC execution.
- Entra ID application registration must be pre-configured by the Identity team.
- RHEL-subscription-dependent RPM packages are out of scope for this POC; RHEL UBI or Amazon Linux packages are used.
- All licensing impacts for COTS or RHEL-based images must be assessed separately before production rollout.

---

*For related pipeline implementation details, refer to [`poc.md`](../poc.md) and the CI/CD pipeline in [`cicd/github-actions/aws-migration-pipeline.yml`](../cicd/github-actions/aws-migration-pipeline.yml).*
