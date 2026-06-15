# POC Workflow Setup Guide

**Audience:** Platform Engineer / Product Team lead setting up the POC for the first time  
**Relates to:** `.github/workflows/poc-executable-tests.yml`, `POC/test_case.md`

---

## 1. What Is Already Created

The following assets are already committed to this repository and require no code changes:

| Asset | Location | Description |
|-------|----------|-------------|
| Executable workflow | `.github/workflows/poc-executable-tests.yml` | GitHub Actions workflow that runs TC-POC-001 through TC-POC-008 automatically against your live AWS environment |
| Test case document | `POC/test_case.md` | Describes all 8 POC test cases, pass/fail criteria, and automated coverage mapping |
| Developer secrets guide | `POC/developer-guide-github-secrets-to-kms.md` | Explains the approved secrets and variable strategy (OIDC, Secrets Manager, SSM) |

You do **not** need to write the workflow yourself — it is ready to run once the prerequisites below are completed.

---

## 2. Prerequisites Before First Run

### Step 1 — Deploy POC Infrastructure

The workflow validates live AWS resources. Before running it, the following must exist in your AWS dev account:

| Resource | Notes |
|----------|-------|
| ECR repository | For the containerized Tomcat image |
| ECS cluster | Fargate launch type |
| ECS service | Running at least one Tomcat task |
| Application Load Balancer (ALB) | With a DNS-resolvable URL |
| CloudWatch log group | Receiving ECS task logs |
| ElastiCache for Redis (optional) | Required only if running TC-POC-003 session test |

Refer to `poc.md` for the Terraform structure guidance under `infrastructure/terraform/`.

---

### Step 2 — Configure GitHub OIDC Trust in AWS

The workflow uses OIDC federation — no static AWS keys are used or stored.

In your AWS dev account, create an IAM Identity Provider for GitHub:

- **Provider URL:** `https://token.actions.githubusercontent.com`
- **Audience:** `sts.amazonaws.com`

Then create an IAM role with the following trust condition:

```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::<dev-account-id>:oidc-provider/token.actions.githubusercontent.com"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
    },
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:wingt903/CICD:environment:dev"
    }
  }
}
```

**Minimum IAM permissions for the dev role:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition",
        "ecs:ListTasks",
        "ecs:DescribeTasks",
        "ecs:UpdateService",
        "application-autoscaling:DescribeScalableTargets",
        "application-autoscaling:DescribeScalingPolicies",
        "logs:FilterLogEvents",
        "ecr:DescribeImages",
        "ecr:DescribeRepositories"
      ],
      "Resource": "*"
    }
  ]
}
```

Note down the role ARN — you will need it in Step 4.

---

### Step 3 — Create the GitHub Environment

1. Go to your GitHub repository → **Settings** → **Environments**
2. Click **New environment** and name it `dev`
3. (Optional) Add environment protection rules or reviewers if needed

---

### Step 4 — Add GitHub Environment Variables for `dev`

In the `dev` environment you just created, add the following **Variables** (not Secrets — these are non-sensitive):

#### Required variables

| Variable | Example value | Purpose |
|----------|---------------|---------|
| `AWS_DEV_ROLE_ARN` | `arn:aws:iam::123456789012:role/github-actions-poc-dev` | OIDC role the workflow assumes for the dev environment |
| `AWS_REGION` | `ap-southeast-1` | AWS region where your POC resources are deployed |
| `POC_APP_URL` | `http://poc-dev-alb-1234567890.ap-southeast-1.elb.amazonaws.com` | ALB DNS URL for smoke validation |
| `POC_ECS_CLUSTER` | `poc-dev-cluster` | ECS cluster name |
| `POC_ECS_SERVICE` | `poc-dev-tomcat-service` | ECS service name |
| `POC_CLOUDWATCH_LOG_GROUP` | `/ecs/poc-dev-tomcat` | CloudWatch log group for application log validation |

#### Optional variables (leave unset to skip those test steps)

| Variable | Default if unset | Purpose |
|----------|-----------------|---------|
| `POC_EXPECTED_TEXT` | `Tomcat CI/CD Migration Sample` | Text expected in the smoke-test HTTP response |
| `POC_LOG_SEARCH_PATTERN` | `Tomcat` | Pattern used to confirm recent log events |
| `POC_LOG_LOOKBACK_MINUTES` | `30` | How far back to search CloudWatch logs |
| `POC_MIN_RUNNING_TASKS` | `1` | Minimum acceptable running task count |
| `POC_ECR_REPOSITORY` | _(not run)_ | ECR repository name — needed for TC-POC-008 image evidence |
| `POC_AUTH_PROBE_URL` | _(skipped)_ | URL to probe for Entra ID redirect — needed for TC-POC-004 |
| `POC_AUTH_EXPECT_STATUS` | `302` | Expected HTTP status from auth probe |
| `POC_AUTH_EXPECT_LOCATION_REGEX` | `login\|entra\|microsoftonline` | Regex to validate auth redirect target |
| `POC_SESSION_PROBE_URL` | _(skipped)_ | URL to probe for session persistence — needed for TC-POC-003 |
| `POC_SESSION_EXPECTED_REGEX` | _(skipped)_ | Regex to extract stable session marker from response |
| `POC_ENABLE_DESTRUCTIVE_SESSION_TEST` | `false` | Set `true` only to allow the workflow to force an ECS redeployment during session testing |

> **Note:** Do not add `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY`. The workflow uses OIDC role assumption — no static AWS credentials are used.

---

## 3. How to Run the Workflow

1. Go to **GitHub Actions** in this repository
2. Select **POC Executable Tests** from the left sidebar
3. Click **Run workflow**
4. Select environment: `dev`
5. Optionally override the application URL or expected smoke-test text
6. Click **Run workflow**

The workflow will:
- Assume the AWS OIDC role configured for the selected environment
- Execute all 8 POC test cases
- Publish a test summary to the Actions run page

---

## 4. Test Coverage Summary

| Test Case | What the workflow validates automatically |
|-----------|------------------------------------------|
| TC-POC-001 | ECS service health and running task count |
| TC-POC-002 | Apache-to-Tomcat HTTP smoke test |
| TC-POC-003 | Session persistence after ECS forced deployment _(optional — requires probe URL and destructive flag)_ |
| TC-POC-004 | Entra ID authentication redirect _(optional — requires auth probe URL)_ |
| TC-POC-005 | Application log events in CloudWatch Logs |
| TC-POC-006 | ECS Application Auto Scaling target and policy configuration |
| TC-POC-007 | GitHub Actions run URL and commit SHA as deployment evidence |
| TC-POC-008 | Running task uses an immutable image reference _(optional — requires ECR repository)_ |

---

## 5. Secrets and Access Management

- Static AWS credentials are **prohibited** in this pipeline.
- All AWS access uses **OIDC → STS short-lived session tokens**.
- Runtime application secrets (DB passwords, API tokens) must be stored in **AWS Secrets Manager**.
- Non-sensitive environment configuration must be stored in **AWS SSM Parameter Store**.

See `POC/developer-guide-github-secrets-to-kms.md` for the full approved secrets migration guide.

---

## References

- `.github/workflows/poc-executable-tests.yml` — Executable workflow source
- `POC/test_case.md` — POC test case definitions and traceability matrix
- `POC/developer-guide-github-secrets-to-kms.md` — Secrets and credentials approved store guide
- `poc.md` — POC infrastructure and Terraform guidance
