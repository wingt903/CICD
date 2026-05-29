# POC: GitHub Actions–Only Deployment of Apache Tomcat "Hello World" to ECS

This POC is rewritten to match your requirement:

- **No developer AWS Console login**
- **No manual AWS CLI deployment from developer laptop**
- **Everything executed through GitHub Actions with AWS OIDC roles**

---

## 1) Target Outcome

After completing this POC:

1. A developer only pushes code (or triggers `workflow_dispatch`).
2. GitHub Actions builds the Tomcat image from `sample-code/tomcat`.
3. GitHub Actions pushes the image to ECR.
4. GitHub Actions applies Terraform for ECS/Fargate infrastructure.
5. GitHub Actions updates ECS service to the new image.
6. GitHub Actions runs smoke validation and publishes endpoint/output.

---

## 2) Current Repository Baseline (Important)

Already present:

- App sample: `sample-code/tomcat`
- Pipeline scaffold: `cicd/github-actions/aws-migration-pipeline.yml`
- Terraform scaffold: `infrastructure/terraform`

Gap to close for this POC:

- Current Terraform does **not** yet provision ECS/ECR/ALB/network for Tomcat runtime.
- Current deploy jobs are placeholders.

This POC fills those gaps in an automated, pipeline-first way.

---

## 3) Operating Model and Responsibilities

### Developer
- Commit app/infrastructure changes
- Open PR / merge to `main`
- Trigger workflow (`workflow_dispatch`) if needed

### Platform/Admin (one-time bootstrap)
- Configure GitHub OIDC trust with AWS IAM role
- Configure GitHub repo/environment variables and secrets
- Enable protected environments (`dev`, optionally `test`, `prod`)

> After bootstrap, developers do not need AWS console access.

---

## 4) Step-by-Step Implementation

### Step 0 — Branch and working convention

Create a branch for POC automation changes:

```bash
git checkout -b poc/ecs-tomcat-github-actions
```

---

### Step 1 — One-time AWS OIDC bootstrap (Platform/Admin)

Create IAM role(s) for GitHub Actions with trust policy for your repo and branch/environment constraints.

Minimum role capabilities for this POC:

- ECR push/pull
- ECS service/task updates
- CloudWatch Logs access
- Terraform-managed resource create/update/delete for ECS stack
- `iam:PassRole` for ECS task execution role

Store role ARNs in GitHub environment/repo variables used by pipeline, e.g.:

- `AWS_DEV_ROLE_ARN`
- `AWS_TEST_ROLE_ARN`
- `AWS_PROD_ROLE_ARN`

(Your workflow already references these variable names.)

---

### Step 2 — Define Terraform for ECS Tomcat runtime

Under `infrastructure/terraform`, add ECS POC resources (or module):

1. ECR repository for Tomcat image
2. ECS cluster
3. ECS task definition (Tomcat container on port 8080)
4. ECS service (Fargate, desired count 1)
5. ALB + target group + listener (HTTP for POC)
6. Security groups (ALB ingress, ECS from ALB)
7. CloudWatch log group
8. Required IAM execution/task roles

Required Terraform outputs for pipeline handoff:

- `ecr_repository_url`
- `ecs_cluster_name`
- `ecs_service_name`
- `ecs_task_definition_family`
- `alb_dns_name`

---

### Step 3 — Add environment variable files for dev

Create environment-specific tfvars under `infrastructure/terraform/environments`, for example:

- `dev.tfvars`

Include at least:

- `environment`
- `aws_region`
- network IDs (VPC/subnet IDs)
- alarm email (if used)

Keep sensitive values in GitHub Secrets, not plaintext files.

---

### Step 4 — Update pipeline: build, push, deploy (fully automated)

Use `cicd/github-actions/aws-migration-pipeline.yml` as your source workflow and implement these concrete deploy actions (replace placeholders):

1. **Authenticate to AWS** with `aws-actions/configure-aws-credentials@v4` via OIDC role.
2. **Build Tomcat image** from `sample-code/tomcat`.
3. **Log in to ECR** and push image with immutable tag (`${{ github.sha }}`).
4. **Terraform apply (dev)** using `infrastructure/terraform` + `environments/dev.tfvars`.
5. **Render/register ECS task definition** using new image tag.
6. **Update ECS service** and wait for steady state.
7. **Smoke test** `http://<alb_dns_name>/` (HTTP for POC only; use HTTPS in non-POC environments).
8. **Publish deployment summary** (image, service, URL, commit SHA).

Also keep existing gates:

- `tfsec`
- `Checkov`
- application/security scans

---

### Step 5 — Configure GitHub Environments and approvals

In repository settings:

1. Create environment `dev` (and later `test`, `prod`)
2. Add required reviewers for non-dev environments
3. Add environment-scoped variables/secrets (role ARN, tfvars sensitive values)

This enforces promotion control without console-based release activity.

---

### Step 6 — Execute POC via GitHub Actions only

Run one of these:

- Merge PR to `main`, or
- Trigger `workflow_dispatch`

Expected run order:

1. Validate/build/scan
2. IaC policy checks (`tfsec` + `Checkov`)
3. Release manifest
4. Deploy to `dev` (real deployment, no placeholder)
5. Smoke validation and summary

No console action is required from developer.

---

### Step 7 — Verification criteria (POC success)

POC is successful when all are true:

1. Developer did not use AWS console for deployment
2. GitHub Actions run shows successful deploy stage
3. ECS service is healthy and running desired tasks
4. ALB URL returns Tomcat Hello World page
5. Deployment metadata ties to commit SHA and workflow run

---

## 5) Minimal Deliverables Checklist

- [ ] Terraform ECS runtime resources for Tomcat (dev)
- [ ] Pipeline deploy-dev job changed from placeholder to real deployment
- [ ] ECR push + ECS update done in workflow
- [ ] Smoke test and deployment summary in workflow
- [ ] `dev` environment configured with OIDC role variable
- [ ] Evidence of successful run (Actions URL + endpoint output)

---

## 6) Recommended Next Hardening (after POC)

1. Blue/green deployment strategy
2. HTTPS listener and ACM certificate
3. WAF and stricter SG rules
4. Private subnets + NAT design
5. Task role least privilege and secret injection via SSM/Secrets Manager
6. Promotion from `dev` to `test`/`prod` with approvals and quality gates

---

## 7) Key Principle for This POC

**Deployment is a GitHub event, not a human console activity.**

That is the required operating model for this repository’s AWS CI/CD architecture.
