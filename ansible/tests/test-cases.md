# Ansible Test Cases – App as Code: Apache & Tomcat Containerisation

> **Scope:** These test cases cover the Ansible roles `apache` and `tomcat` that
> the application team uses to deploy containerised Apache httpd and Tomcat
> workloads through the App as Code CI/CD pipeline.  
> Test execution is automated via **Molecule** (Docker driver) in the
> `ansible-validate` GitHub Actions job.

---

## Traceability Matrix

| Test Case | Requirement       | Control / Tag          |
|-----------|-------------------|------------------------|
| TC-PRE-001–003 | App_as_Code_007, App_as_Code_008 | `always`      |
| TC-PRE-010–012 | App_as_Code_007, App_as_Code_008 | `always`      |
| TC-ANS-001 | App_as_Code_001   | `tc_ans_001`           |
| TC-ANS-002 | App_as_Code_001, App_as_Code_002 | `tc_ans_002` |
| TC-ANS-003 | App_as_Code_003   | `tc_ans_003`           |
| TC-ANS-004 | App_as_Code_001   | `tc_ans_004`           |
| TC-ANS-005 | App_as_Code_001   | `tc_ans_005`           |
| TC-ANS-006 | App_as_Code_008   | `tc_ans_006`           |
| TC-ANS-007 | App_as_Code_003   | `tc_ans_007`           |
| TC-ANS-008 | App_as_Code_002   | `tc_ans_008`           |
| TC-ANS-009 | App_as_Code_001   | `tc_ans_009`           |
| TC-ANS-010 | App_as_Code_001   | `tc_ans_010`           |
| TC-ANS-011 | App_as_Code_001   | `tc_ans_011`           |
| TC-ANS-012 | App_as_Code_006   | `tc_ans_012`           |
| TC-ANS-013 | App_as_Code_002   | `tc_ans_013`           |
| TC-ANS-014 | App_as_Code_007   | `tc_ans_014`           |
| TC-ANS-015 | App_as_Code_004   | `tc_ans_015`           |
| TC-ANS-016 | App_as_Code_008   | `tc_ans_016`           |
| TC-ANS-017 | App_as_Code_001   | `tc_ans_017`           |

---

## Pre-Conditions (TC-PRE)

### TC-PRE-001 – Release SHA is set and immutable
| Field       | Value |
|-------------|-------|
| **Role**    | apache, tomcat |
| **Stage**   | converge pre_tasks |
| **Given**   | The CI/CD pipeline is about to run the Ansible playbook |
| **When**    | The converge play starts |
| **Then**    | `release_sha` is defined, non-empty, and does not match a mutable tag pattern (`latest`, `main`, `master`, `dev`, `staging`, `stable`) |
| **Automated** | `molecule/apache/converge.yml` – TC-PRE-001 task |
| **Expected result** | Assertion passes; role proceeds |
| **Failure result** | Assertion fails; play aborts before any deployment |

---

### TC-PRE-002 – `env` variable is a valid environment name
| Field       | Value |
|-------------|-------|
| **Role**    | apache, tomcat |
| **Given**   | A deployment is triggered |
| **When**    | Pre-tasks run |
| **Then**    | `env` is one of `dev`, `test`, `prod` |
| **Automated** | `molecule/apache/converge.yml` – TC-PRE-002 task |

---

### TC-PRE-003 – Apache image references approved version
| Field       | Value |
|-------------|-------|
| **Role**    | apache |
| **Given**   | `apache_image` and `apache_expected_version` are set |
| **When**    | Pre-tasks run |
| **Then**    | `apache_expected_version` string is contained in `apache_image` |
| **Automated** | `molecule/apache/converge.yml` – TC-PRE-003 task |

---

### TC-PRE-010 – Release SHA is set (Tomcat)
*(Mirrors TC-PRE-001 for the tomcat role.)*
| **Automated** | `molecule/tomcat/converge.yml` – TC-PRE-010 task |

---

### TC-PRE-011 – Tomcat image references approved Tomcat and Java versions
| Field       | Value |
|-------------|-------|
| **Role**    | tomcat |
| **Given**   | `tomcat_image`, `tomcat_expected_version`, `tomcat_java_expected_version` are set |
| **When**    | Pre-tasks run |
| **Then**    | Both version strings are present in `tomcat_image` |
| **Automated** | `molecule/tomcat/converge.yml` – TC-PRE-011 task |

---

### TC-PRE-012 – Tomcat image tag is immutable
*(Mirrors TC-PRE-001 for tomcat_image.)*
| **Automated** | `molecule/tomcat/converge.yml` – TC-PRE-012 task |

---

## Functional Test Cases

### TC-ANS-001 – Playbook syntax: role directory structure is created
| Field       | Value |
|-------------|-------|
| **Requirement** | App_as_Code_001 – Automated deployment |
| **Role**    | apache |
| **Given**   | The `apache` role is applied to a host |
| **When**    | The role converges |
| **Then**    | `/etc/apache-container` and `/etc/apache-container/httpd.conf` exist |
| **Automated** | `molecule/apache/verify.yml` – TC-ANS-001 tasks |
| **Pass criteria** | Both paths are found on the target host |
| **Failure criteria** | Either path missing |

---

### TC-ANS-002 – Idempotency: applying the role twice produces no change
| Field       | Value |
|-------------|-------|
| **Requirement** | App_as_Code_001, App_as_Code_002 |
| **Role**    | tomcat |
| **Given**   | The `tomcat` role has already been applied once |
| **When**    | The role is applied a second time (`molecule idempotence`) |
| **Then**    | No tasks report `changed`; the play reports 0 changes |
| **Automated** | `molecule idempotence` command in CI |
| **Pass criteria** | Molecule idempotency check exits 0 |
| **Failure criteria** | Any task reports `changed` on the second run |

---

### TC-ANS-003 – Tomcat server.xml hardening configuration
| Field       | Value |
|-------------|-------|
| **Requirement** | App_as_Code_003 – Security hardening |
| **Role**    | tomcat |
| **Given**   | The `tomcat` role has been applied |
| **When**    | `/etc/tomcat-container/server.xml` is inspected |
| **Then**    | Shutdown port is `-1` (disabled), `xpoweredBy="false"`, `allowTrace="false"` |
| **Sub-tests** | TC-ANS-003, TC-ANS-003a, TC-ANS-003b |
| **Automated** | `molecule/tomcat/verify.yml` |
| **Pass criteria** | All three assertions pass |

---

### TC-ANS-004 – Apache container is running
| Field       | Value |
|-------------|-------|
| **Requirement** | App_as_Code_001 |
| **Role**    | apache |
| **Given**   | The `apache` role has been applied |
| **When**    | Docker container state is inspected |
| **Then**    | Container `apache-httpd-test` exists and `State.Running == true` |
| **Automated** | `molecule/apache/verify.yml` – TC-ANS-004 tasks |

---

### TC-ANS-004a – Apache health endpoint responds HTTP 200
| Field       | Value |
|-------------|-------|
| **Requirement** | App_as_Code_001, App_as_Code_006 |
| **Given**   | Apache container is running |
| **When**    | `GET http://localhost:8081/health` is executed |
| **Then**    | HTTP status code 200 is returned within 25 seconds (5 retries × 5 s) |
| **Automated** | `molecule/apache/verify.yml` – TC-ANS-004a tasks |

---

### TC-ANS-005 – Tomcat container is running
| Field       | Value |
|-------------|-------|
| **Requirement** | App_as_Code_001 |
| **Role**    | tomcat |
| **Given**   | The `tomcat` role has been applied |
| **When**    | Docker container state is inspected |
| **Then**    | Container `tomcat-app-test` exists and `State.Running == true` |
| **Automated** | `molecule/tomcat/verify.yml` – TC-ANS-005 tasks |

---

### TC-ANS-005a – Tomcat HTTP health check responds HTTP 200
| Field       | Value |
|-------------|-------|
| **Requirement** | App_as_Code_001, App_as_Code_006 |
| **Given**   | Tomcat container is running |
| **When**    | `GET http://localhost:8082/` is executed |
| **Then**    | HTTP status code 200 is returned within 60 seconds (6 retries × 10 s) |
| **Automated** | `molecule/tomcat/verify.yml` – TC-ANS-005a tasks |

---

### TC-ANS-006 – RTCM: approved runtime version present in container image tag
| Field       | Value |
|-------------|-------|
| **Requirement** | App_as_Code_008 – Deployment guardrails & runtime compliance |
| **Role**    | apache, tomcat |
| **Given**   | A container has been deployed |
| **When**    | The running container's image tag is inspected |
| **Then**    | Apache: `"2.4"` is in the image name. Tomcat: both `"10.1"` and `"17"` are in the image name |
| **Automated** | `molecule/apache/verify.yml` and `molecule/tomcat/verify.yml` – TC-ANS-006 tasks |
| **Pass criteria** | Version strings found; deployment proceeds |
| **Failure criteria** | Version strings absent; RTCM-001 policy violation raised |

---

### TC-ANS-007 – Security hardening: `no-new-privileges` is set
| Field       | Value |
|-------------|-------|
| **Requirement** | App_as_Code_003 – Automated security hardening |
| **Role**    | apache, tomcat |
| **Given**   | A container has been deployed |
| **When**    | `HostConfig.SecurityOpt` is inspected |
| **Then**    | `"no-new-privileges:true"` is in the `SecurityOpt` list |
| **Automated** | `molecule/apache/verify.yml` and `molecule/tomcat/verify.yml` – TC-ANS-007 tasks |

---

### TC-ANS-007a – Security hardening: `CapDrop=ALL` (Apache)
| Field       | Value |
|-------------|-------|
| **Requirement** | App_as_Code_003 |
| **Role**    | apache |
| **Given**   | Apache container is deployed with hardening enabled |
| **When**    | `HostConfig.CapDrop` is inspected |
| **Then**    | `"ALL"` is in the `CapDrop` list |
| **Automated** | `molecule/apache/verify.yml` – TC-ANS-007a task |

---

### TC-ANS-008 – Configuration drift: release SHA label matches expected value
| Field       | Value |
|-------------|-------|
| **Requirement** | App_as_Code_002 – Configuration drift control |
| **Role**    | apache, tomcat |
| **Given**   | A container has been deployed with `release_sha` injected |
| **When**    | Container label `app.release_sha` is read |
| **Then**    | Label value equals `release_sha` variable |
| **Automated** | Verify playbooks – TC-ANS-008 tasks |
| **Pass criteria** | Label matches; no drift |
| **Failure criteria** | Label absent or mismatch; drift alert raised |

---

### TC-ANS-008a – Environment label matches `env` variable (Apache)
| Field       | Value |
|-------------|-------|
| **Requirement** | App_as_Code_002 |
| **Given**   | Apache container is deployed |
| **When**    | Container label `app.env` is read |
| **Then**    | Label value equals `env` variable (`dev`, `test`, or `prod`) |
| **Automated** | `molecule/apache/verify.yml` – TC-ANS-008a task |

---

### TC-ANS-009 – Configuration rendering: security headers in `httpd.conf`
| Field       | Value |
|-------------|-------|
| **Requirement** | App_as_Code_003 |
| **Role**    | apache |
| **Given**   | Apache role has rendered `httpd.conf` via Jinja2 template |
| **When**    | `/etc/apache-container/httpd.conf` is read |
| **Then**    | The file contains: `X-Content-Type-Options`, `X-Frame-Options`, `Strict-Transport-Security`, `ServerTokens Prod`, `ServerSignature Off` |
| **Automated** | `molecule/apache/verify.yml` – TC-ANS-009 tasks |

---

### TC-ANS-009 (Tomcat) – JAVA_OPTS environment variable injected
| Field       | Value |
|-------------|-------|
| **Requirement** | App_as_Code_001 |
| **Role**    | tomcat |
| **Given**   | Tomcat container is deployed |
| **When**    | `Config.Env` list of the running container is inspected |
| **Then**    | At least one entry matches `JAVA_OPTS=.*` |
| **Automated** | `molecule/tomcat/verify.yml` – TC-ANS-009 task |

---

### TC-ANS-010 – Restart policy is `unless-stopped`
| Field       | Value |
|-------------|-------|
| **Requirement** | App_as_Code_001 |
| **Role**    | apache, tomcat |
| **Given**   | A container has been deployed |
| **When**    | `HostConfig.RestartPolicy.Name` is inspected |
| **Then**    | Value is `"unless-stopped"` |
| **Automated** | Verify playbooks – TC-ANS-010 tasks |

---

### TC-ANS-011 – Tomcat webapps volume is mounted
| Field       | Value |
|-------------|-------|
| **Requirement** | App_as_Code_001 |
| **Role**    | tomcat |
| **Given**   | Tomcat container is deployed |
| **When**    | `HostConfig.Binds` is inspected |
| **Then**    | At least one bind mount path matches `/usr/local/tomcat/webapps` |
| **Automated** | `molecule/tomcat/verify.yml` – TC-ANS-011 task |

---

### TC-ANS-012 – Datadog log label is present
| Field       | Value |
|-------------|-------|
| **Requirement** | App_as_Code_006 – Configuration and health monitoring |
| **Role**    | apache, tomcat |
| **Given**   | A container has been deployed |
| **When**    | Container labels are inspected |
| **Then**    | Label `com.datadog.logs` is present |
| **Automated** | `molecule/tomcat/verify.yml` – TC-ANS-012 task |

---

### TC-ANS-013 – Drift detection: re-running playbook on a manually changed container triggers remediation
| Field       | Value |
|-------------|-------|
| **Requirement** | App_as_Code_002 |
| **Role**    | apache, tomcat |
| **Given**   | A container is running with an older image (simulating drift) |
| **When**    | The Ansible playbook is re-run with the new approved image |
| **Then**    | The old container is removed, new container started with correct image; drift assertion passes |
| **How to test manually** | `docker pull httpd:2.4` then retag as an older SHA, run converge, observe old container replaced |
| **Automated** | Covered by idempotency cycle; manual drift simulation test in integration environment |

---

### TC-ANS-014 – Non-compliant configuration fails deployment (CTRL-007)
| Field       | Value |
|-------------|-------|
| **Requirement** | App_as_Code_007 – Detection of non-compliant configuration |
| **Role**    | apache, tomcat |
| **Given**   | `apache_image` is set to `httpd:latest` (mutable tag) |
| **When**    | The converge pre-task runs |
| **Then**    | The assertion `TC-PRE-001` / `TC-PRE-012` fails with policy violation message |
| **How to test manually** | Override `apache_image: httpd:latest` in molecule vars; run `molecule converge`; expect task failure |
| **Expected error** | `Policy violation [CTRL-007-IMMUTABLE-IMAGE]: Mutable image tags are not permitted` |

---

### TC-ANS-015 – Evidence record persisted to SSM after deployment
| Field       | Value |
|-------------|-------|
| **Requirement** | App_as_Code_004 – Evidence-driven configuration assurance |
| **Role**    | apache, tomcat |
| **Given**   | Deployment completes successfully |
| **When**    | Post-deployment tasks execute |
| **Then**    | AWS SSM `put-parameter` is called for `{{ deployment_decision_prefix }}/ansible/{{ release_sha }}/{apache\|tomcat}/deploy` with value `passed` |
| **How to test manually** | In a real AWS environment, verify the SSM parameter exists with value `passed` after a pipeline run |
| **In Molecule** | Stub AWS CLI confirms the call is issued (exit 0 from stub) |

---

### TC-ANS-016 – Unsupported runtime version blocked by RTCM assertion
| Field       | Value |
|-------------|-------|
| **Requirement** | App_as_Code_008 |
| **Role**    | tomcat |
| **Given**   | `tomcat_image` is set to `tomcat:9.0-jdk11` (unapproved version) |
| **When**    | The `[RTCM] Validate Tomcat version` task runs |
| **Then**    | The `ansible.builtin.assert` fails with `Policy violation [RTCM-001]` |
| **How to test manually** | Override `tomcat_image: tomcat:9.0-jdk11`; run `molecule converge`; expect assertion failure |

---

### TC-ANS-017 – Multi-environment promotion: same playbook deploys to dev / test / prod
| Field       | Value |
|-------------|-------|
| **Requirement** | App_as_Code_001, App_as_Code_007 |
| **Role**    | apache, tomcat |
| **Given**   | A release SHA is promoted across environments |
| **When**    | The playbook is run with `-i inventories/dev`, then `-i inventories/test`, then `-i inventories/prod` |
| **Then**    | The same container image is deployed consistently; environment label `app.env` reflects the target environment |
| **How to verify** | Inspect container label `app.env` in each environment; expect `dev` / `test` / `prod` respectively |

---

## Negative Test Cases

| ID          | Scenario | Expected Outcome |
|-------------|----------|-----------------|
| TC-NEG-001  | `release_sha` is empty string | Converge pre-task fails: "release_sha must be set" |
| TC-NEG-002  | `apache_image: httpd:latest` | Pre-task fails: mutable tag policy violation |
| TC-NEG-003  | `tomcat_image: tomcat:9.0-jdk11` | RTCM assertion fails: unapproved version |
| TC-NEG-004  | `env: staging` (invalid) | Pre-task fails: env must be dev/test/prod |
| TC-NEG-005  | Container started manually with wrong image | Drift assertion fails after playbook re-run |
| TC-NEG-006  | `apache_expected_version: "2.2"` | RTCM assertion fails: version not in approved image |

---

## How to Run Tests

### Local (Molecule)
```bash
cd ansible

# Install dependencies
pip install molecule[docker] ansible-lint
ansible-galaxy collection install -r requirements.yml

# Run full test suite for apache role
molecule test -s apache

# Run full test suite for tomcat role
molecule test -s tomcat

# Run only idempotency check
molecule idempotence -s apache
molecule idempotence -s tomcat

# Run only verify (post-convergence assertions)
molecule verify -s apache
molecule verify -s tomcat
```

### CI (GitHub Actions)
Tests are executed automatically in the `ansible-validate` job on every pull
request and push to `main`. See
`.github/workflows/infra-app.yml` – job `ansible-validate`.

---

## Test Coverage Summary

| Category                        | Test Cases         | Roles Covered  |
|---------------------------------|--------------------|----------------|
| Pre-condition / Input validation | TC-PRE-001–012    | apache, tomcat |
| Automated deployment            | TC-ANS-001, 004, 005, 010, 017 | apache, tomcat |
| Idempotency                     | TC-ANS-002         | tomcat         |
| Security hardening              | TC-ANS-003, 007, 007a, 009 | apache, tomcat |
| RTCM runtime compliance         | TC-ANS-006, 016    | apache, tomcat |
| Drift detection                 | TC-ANS-008, 008a, 013 | apache, tomcat |
| Evidence / audit                | TC-ANS-015         | apache, tomcat |
| Observability (Datadog)         | TC-ANS-012         | apache, tomcat |
| Config rendering                | TC-ANS-003, 009, 011 | apache, tomcat |
| Negative / policy violation     | TC-NEG-001–006     | apache, tomcat |
