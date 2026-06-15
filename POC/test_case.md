# POC Test Cases – Containerize Legacy BA Opco Applications

## Summary

This test case document captures the POC summary and validation scenarios for containerizing legacy BA Opco applications.

| Area | Summary |
|------|---------|
| Target platform | Amazon ECS on Fargate with images stored in Amazon ECR |
| In-scope stack | Linux workloads, Apache, Tomcat, Redis-backed session persistence, Entra ID, Datadog/CloudWatch log routing, GitHub Actions deployment |
| Deployment model | Fully automated GitHub Actions pipeline with no developer AWS console access |
| Key outcomes | Rehost, Reconfigure, Refactor, or Retain based on the application assessment result |
| POC success focus | Healthy ECS deployment, Apache/Tomcat validation, session persistence, Entra ID auth, Datadog/CloudWatch logging, scaling, pipeline automation, and image hardening |

---

## Traceability Matrix

| Test Case | POC Outcome / Scope |
|-----------|---------------------|
| TC-POC-001 | Linux workload successfully containerized and deployed on ECS Fargate |
| TC-POC-002 | Apache + Tomcat architecture validated on Fargate |
| TC-POC-003 | Session persistence validated |
| TC-POC-004 | Entra ID authentication confirmed |
| TC-POC-005 | Log routing confirmed |
| TC-POC-006 | Horizontal scaling confirmed |
| TC-POC-007 | Fully automated pipeline deployment |
| TC-POC-008 | Image hardening baseline confirmed |

---

## Test Cases

### TC-POC-001 – ECS Fargate deployment is healthy
| Field | Value |
|-------|-------|
| **Given** | A GitHub Actions deployment run completes for the POC application |
| **When** | The ECS service and tasks are reviewed after deployment |
| **Then** | The ECS service is stable and the desired task count is met |
| **Evidence** | GitHub Actions run URL, ECS service status, task health output |
| **Pass criteria** | All required tasks are running and healthy |
| **Fail criteria** | Service is unstable, tasks are unhealthy, or desired count is not met |

### TC-POC-002 – Apache and Tomcat communication works
| Field | Value |
|-------|-------|
| **Given** | Apache and Tomcat are deployed as separate services/tasks |
| **When** | The application endpoint is accessed through the load balancer |
| **Then** | Apache successfully routes traffic to Tomcat and the application responds correctly |
| **Evidence** | ALB URL response, application page output, service discovery configuration |
| **Pass criteria** | End user request succeeds through the full Apache-to-Tomcat path |
| **Fail criteria** | Routing, name resolution, or application response fails |

### TC-POC-003 – Session persistence survives task restart
| Field | Value |
|-------|-------|
| **Given** | The application uses Redis-backed session persistence with ALB sticky sessions |
| **When** | A user session is established and a Tomcat task restart is simulated |
| **Then** | The user session remains valid after failover/restart |
| **Evidence** | Session ID continuity, Redis validation, restart record |
| **Pass criteria** | Session data remains available after restart |
| **Fail criteria** | Session is lost or application forces re-authentication unexpectedly |

### TC-POC-004 – Entra ID authentication succeeds
| Field | Value |
|-------|-------|
| **Given** | Entra ID integration is configured for the POC application |
| **When** | A user signs in through the application |
| **Then** | Authentication completes successfully in the containerized runtime |
| **Evidence** | Successful login result, application logs, identity flow confirmation |
| **Pass criteria** | Authorized user can access the application through Entra ID |
| **Fail criteria** | Authentication fails or the application cannot complete the identity flow |

### TC-POC-005 – Application logs reach Datadog or CloudWatch
| Field | Value |
|-------|-------|
| **Given** | Apache and Tomcat logging is configured with `awslogs` and/or FireLens |
| **When** | Application requests are generated |
| **Then** | Application logs are visible in Datadog and/or CloudWatch Logs |
| **Evidence** | Log entries for Apache access/error and Tomcat application events |
| **Pass criteria** | Expected log events appear in the configured observability destination |
| **Fail criteria** | Logs are missing, incomplete, or not routed to the expected destination |

### TC-POC-006 – Horizontal scaling works as expected
| Field | Value |
|-------|-------|
| **Given** | ECS Service Auto Scaling is configured for the workload |
| **When** | Load is increased beyond the scaling threshold |
| **Then** | Task count scales out and later scales back in when load drops |
| **Evidence** | Scaling policy events, ECS service history, CloudWatch metrics |
| **Pass criteria** | Scale-out and scale-in actions both occur within the defined policy behavior |
| **Fail criteria** | No scaling action occurs or task recovery does not stabilize |

### TC-POC-007 – Deployment is GitHub Actions driven only
| Field | Value |
|-------|-------|
| **Given** | The deployment pipeline is triggered by merge or `workflow_dispatch` |
| **When** | The full deployment workflow executes |
| **Then** | Build, push, deploy, smoke validation, and summary publication complete without developer console access |
| **Evidence** | Workflow run log, deployment summary, commit SHA linkage |
| **Pass criteria** | Deployment completes end-to-end from GitHub Actions only |
| **Fail criteria** | Manual console action is required or deployment evidence is incomplete |

### TC-POC-008 – Image hardening baseline is enforced
| Field | Value |
|-------|-------|
| **Given** | Hardened base images and agreed validation checks are part of the POC pipeline |
| **When** | The image is built and validated before deployment |
| **Then** | The image passes the defined hardening and security checks |
| **Evidence** | Build output, scan results, image metadata, approval records if applicable |
| **Pass criteria** | Image complies with the agreed baseline and is approved for deployment |
| **Fail criteria** | Image fails hardening or security validation checks |

---

## Exit Criteria

- All eight POC test cases pass.
- Deployment evidence is traceable to the GitHub Actions run and commit SHA.
- No developer AWS console access is needed to complete the POC deployment.

---

## GitHub Actions Executable Procedure

The executable workflow is defined in `/home/runner/work/CICD/CICD/wingt903/CICD/.github/workflows/poc-executable-tests.yml`.

### How to run

1. Open **GitHub Actions**.
2. Select **POC Executable Tests**.
3. Choose `workflow_dispatch`.
4. Select the target environment (`dev`, `test`, or `prod`).
5. Optionally override the application URL and expected smoke-test text.
6. Start the workflow.

### Required GitHub environment variables

Configure these in the target GitHub Environment:

| Variable | Purpose |
|----------|---------|
| `AWS_ROLE_ARN` | OIDC role assumed by the workflow for the selected environment |
| `AWS_REGION` | AWS region for the validation run |
| `POC_APP_URL` | Application URL for smoke validation |
| `POC_ECS_CLUSTER` | ECS cluster name hosting the POC workload |
| `POC_ECS_SERVICE` | ECS service name hosting the POC workload |
| `POC_CLOUDWATCH_LOG_GROUP` | CloudWatch log group used for application log validation |

Optional variables:

| Variable | Purpose |
|----------|---------|
| `POC_EXPECTED_TEXT` | Expected text returned by the smoke-test page |
| `POC_LOG_SEARCH_PATTERN` | Log pattern used to confirm recent application log events |
| `POC_MIN_RUNNING_TASKS` | Minimum acceptable running task count |
| `POC_ECR_REPOSITORY` | ECR repository name for image evidence collection |
| `POC_AUTH_PROBE_URL` | URL used to validate Entra authentication redirect behavior |
| `POC_AUTH_EXPECT_STATUS` | Expected HTTP status for the auth probe |
| `POC_AUTH_EXPECT_LOCATION_REGEX` | Regex for the expected auth redirect target |
| `POC_SESSION_PROBE_URL` | URL used for session validation |
| `POC_SESSION_EXPECTED_REGEX` | Regex that extracts a stable session marker from the session probe response |
| `POC_ENABLE_DESTRUCTIVE_SESSION_TEST` | Set to `true` only when you allow the workflow to force a new ECS deployment for session validation |

### Automated coverage

| Test Case | Workflow behavior |
|-----------|-------------------|
| `TC-POC-001` | Validates ECS service health and running task count |
| `TC-POC-002` | Executes an HTTP smoke test and checks the expected response text |
| `TC-POC-003` | Optional destructive session-persistence validation when a dedicated probe is configured |
| `TC-POC-004` | Optional authentication redirect validation when a dedicated auth probe is configured |
| `TC-POC-005` | Confirms recent application log events in CloudWatch Logs |
| `TC-POC-006` | Verifies ECS Application Auto Scaling target and policy configuration |
| `TC-POC-007` | Captures GitHub Actions run URL and commit SHA as deployment evidence |
| `TC-POC-008` | Verifies the running task definition uses an immutable image reference |
