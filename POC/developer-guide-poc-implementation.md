# Developer Guide – Implementing the ECS Tomcat POC

**Audience:** Developer or Platform Engineer implementing the POC for the first time  
**Relates to:** `poc.md`, `.github/workflows/poc-ecs-tomcat-deploy.yml`, `POC/poc-workflow-setup-guide.md`

---

## Overview

This guide walks you through implementing the POC end-to-end so that a developer can push code and GitHub Actions automatically:

1. Builds the Tomcat container image
2. Pushes it to Amazon ECR
3. Applies Terraform to provision/update ECS infrastructure
4. Deploys the image to ECS Fargate
5. Runs a smoke test and publishes a deployment summary

**No developer AWS Console login is required at any point.**

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| AWS account (dev) | Dedicated non-production account |
| VPC with subnets | At least two public subnets for ALB; optional private subnets for ECS tasks |
| GitHub repository | `wingt903/CICD` with admin access to configure environments and secrets |
| Terraform ≥ 1.5 | Used by the workflow; no local installation needed |
| S3 bucket (optional) | For remote Terraform state — recommended for team use |

---

## Step 1 – Write Terraform ECS Resources

The existing `infrastructure/terraform/main.tf` only defines CloudWatch logs, SNS, and SSM parameters. You must add ECS/ECR/ALB resources for the POC.

Create a new file `infrastructure/terraform/ecs-poc.tf` with the following resources:

### 1.1 ECR Repository

```hcl
resource "aws_ecr_repository" "tomcat" {
  name                 = "poc-tomcat"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

resource "aws_ecr_lifecycle_policy" "tomcat" {
  repository = aws_ecr_repository.tomcat.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

output "ecr_repository_url" {
  value = aws_ecr_repository.tomcat.repository_url
}
```

### 1.2 ECS Cluster

```hcl
resource "aws_ecs_cluster" "poc" {
  name = "poc-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.common_tags
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.poc.name
}
```

### 1.3 IAM Roles for ECS

```hcl
data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_execution" {
  name               = "poc-${var.environment}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
  tags = local.common_tags
}

resource "aws_iam_role" "ecs_task" {
  name               = "poc-${var.environment}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
  tags               = local.common_tags
}
```

### 1.4 CloudWatch Log Group for ECS

```hcl
resource "aws_cloudwatch_log_group" "ecs_tomcat" {
  name              = "/ecs/poc-${var.environment}-tomcat"
  retention_in_days = 30
  tags              = local.common_tags
}

output "cloudwatch_log_group" {
  value = aws_cloudwatch_log_group.ecs_tomcat.name
}
```

### 1.5 ECS Task Definition

```hcl
resource "aws_ecs_task_definition" "tomcat" {
  family                   = "poc-${var.environment}-tomcat"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = "tomcat"
    image = "${aws_ecr_repository.tomcat.repository_url}:latest"  # replaced at deploy time
    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.ecs_tomcat.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "tomcat"
      }
    }
    essential = true
  }])

  tags = local.common_tags
}

output "ecs_task_definition_family" {
  value = aws_ecs_task_definition.tomcat.family
}
```

### 1.6 Security Groups

```hcl
resource "aws_security_group" "alb" {
  name        = "poc-${var.environment}-alb-sg"
  description = "Allow HTTP inbound to ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

resource "aws_security_group" "ecs" {
  name        = "poc-${var.environment}-ecs-sg"
  description = "Allow traffic from ALB to ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}
```

### 1.7 ALB and ECS Service

```hcl
resource "aws_lb" "poc" {
  name               = "poc-${var.environment}-alb"
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]
  tags               = local.common_tags
}

resource "aws_lb_target_group" "tomcat" {
  name        = "poc-${var.environment}-tomcat-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.poc.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tomcat.arn
  }
}

resource "aws_ecs_service" "tomcat" {
  name            = "poc-${var.environment}-tomcat-service"
  cluster         = aws_ecs_cluster.poc.id
  task_definition = aws_ecs_task_definition.tomcat.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids != null ? var.private_subnet_ids : var.public_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = var.private_subnet_ids == null ? true : false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tomcat.arn
    container_name   = "tomcat"
    container_port   = 8080
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  tags = local.common_tags

  lifecycle {
    ignore_changes = [task_definition]  # Task definition updated by pipeline, not Terraform
  }
}

output "ecs_service_name" {
  value = aws_ecs_service.tomcat.name
}

output "alb_dns_name" {
  value = aws_lb.poc.dns_name
}
```

### 1.8 Add Variables for Networking

Add the following to `infrastructure/terraform/variables.tf`:

```hcl
variable "vpc_id" {
  type        = string
  description = "VPC ID for POC ECS and ALB resources"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for the ALB"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for ECS tasks (optional; falls back to public)"
  default     = null
}
```

### 1.9 Update `environments/dev.tfvars`

```hcl
environment        = "dev"
alarm_email        = "devops-dev@example.com"
vpc_id             = "vpc-0123456789abcdef0"
public_subnet_ids  = ["subnet-aaaa0001", "subnet-aaaa0002"]
private_subnet_ids = ["subnet-bbbb0001", "subnet-bbbb0002"]
```

> **Do not commit real VPC or subnet IDs if this repository is public.** Store sensitive network IDs as GitHub environment variables (`DEV_VPC_ID`, `DEV_PUBLIC_SUBNET_IDS`, etc.) and reference them as `TF_VAR_*` in the workflow.

---

## Step 2 – Configure AWS OIDC Trust (Platform Admin, one-time)

This is a one-time bootstrap that allows GitHub Actions to assume an IAM role without static credentials.

### 2.1 Create an OIDC Identity Provider in AWS IAM

1. Open the AWS Console in your **dev account** → IAM → Identity providers → Add provider
2. Choose **OpenID Connect**
3. Provider URL: `https://token.actions.githubusercontent.com`
4. Audience: `sts.amazonaws.com`
5. Click **Add provider**

> After bootstrap, developers do not need AWS Console access.

### 2.2 Create an IAM Role for GitHub Actions

Create a role named `github-actions-poc-dev` with this trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
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
  ]
}
```

### 2.3 Attach IAM Permissions

Attach the following inline policy (or use managed policies):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage",
        "ecr:CreateRepository",
        "ecr:DescribeRepositories",
        "ecr:DescribeImages",
        "ecr:PutLifecyclePolicy"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecs:CreateCluster",
        "ecs:DescribeClusters",
        "ecs:CreateService",
        "ecs:UpdateService",
        "ecs:DescribeServices",
        "ecs:RegisterTaskDefinition",
        "ecs:DescribeTaskDefinition",
        "ecs:DeregisterTaskDefinition",
        "ecs:ListTasks",
        "ecs:DescribeTasks"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:AttachRolePolicy",
        "iam:PassRole",
        "iam:GetRole",
        "iam:PutRolePolicy",
        "iam:DeleteRole",
        "iam:DeleteRolePolicy",
        "iam:DetachRolePolicy"
      ],
      "Resource": "arn:aws:iam::<dev-account-id>:role/poc-dev-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:*",
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:CreateSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:DeleteSecurityGroup",
        "ec2:DescribeAccountAttributes"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:PutRetentionPolicy",
        "logs:DescribeLogGroups",
        "logs:DeleteLogGroup",
        "logs:TagResource",
        "logs:ListTagsForResource"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sns:CreateTopic",
        "sns:Subscribe",
        "sns:GetTopicAttributes",
        "sns:SetTopicAttributes",
        "sns:DeleteTopic",
        "sns:TagResource",
        "sns:ListTagsForResource"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:PutParameter",
        "ssm:DeleteParameter",
        "ssm:AddTagsToResource",
        "ssm:ListTagsForResource",
        "ssm:GetParameters"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::<tf-state-bucket>",
        "arn:aws:s3:::<tf-state-bucket>/*"
      ]
    }
  ]
}
```

Note down the role ARN: `arn:aws:iam::<dev-account-id>:role/github-actions-poc-dev`

---

## Step 3 – Configure GitHub Environment and Variables

### 3.1 Create `dev` Environment

1. Go to your GitHub repository → **Settings** → **Environments**
2. Click **New environment**, name it `dev`
3. Optionally add required reviewers for extra gate control

### 3.2 Add Environment Variables (non-sensitive)

In the `dev` environment, add the following **Variables** (not Secrets):

| Variable | Example value | Purpose |
|----------|---------------|---------|
| `AWS_DEV_ROLE_ARN` | `arn:aws:iam::123456789012:role/github-actions-poc-dev` | OIDC role ARN for dev deployments |
| `AWS_REGION` | `ap-southeast-1` | AWS region |
| `POC_ECR_REPOSITORY` | `poc-tomcat` | ECR repository name |
| `POC_ECS_CLUSTER` | `poc-dev-cluster` | ECS cluster name (fallback if Terraform output unavailable) |
| `POC_ECS_SERVICE` | `poc-dev-tomcat-service` | ECS service name (fallback) |
| `POC_ALB_DNS` | `poc-dev-alb-xxxxx.ap-southeast-1.elb.amazonaws.com` | ALB DNS name (fallback) |
| `POC_EXPECTED_TEXT` | `Tomcat CI/CD Migration Sample` | Text expected in smoke test HTTP response |

### 3.3 Networking Variables (if not hardcoded in tfvars)

If you prefer not to commit VPC/subnet IDs to the repository:

| Variable | Example value |
|----------|---------------|
| `DEV_VPC_ID` | `vpc-0123456789abcdef0` |
| `DEV_PUBLIC_SUBNET_IDS` | `["subnet-aaaa0001","subnet-aaaa0002"]` |
| `DEV_PRIVATE_SUBNET_IDS` | `["subnet-bbbb0001","subnet-bbbb0002"]` |

### 3.4 Terraform State Bucket (optional but recommended)

| Variable | Example value |
|----------|---------------|
| `TF_STATE_BUCKET` | `my-org-terraform-state-dev` |

> **Never add `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY`.** The workflow uses OIDC role assumption only.

---

## Step 4 – Understand the Workflow

The workflow `.github/workflows/poc-ecs-tomcat-deploy.yml` runs automatically on push to `main` (when Tomcat or Terraform files change) or can be triggered manually via `workflow_dispatch`.

### Job Flow

```
build-and-scan  ──────┐
                       ├──► deploy-dev ──► smoke-test ──► deployment summary
iac-policy-check ─────┘
```

### Job Descriptions

| Job | What it does |
|-----|-------------|
| `build-and-scan` | Builds the Tomcat Docker image, runs Trivy security scan, generates SBOM |
| `iac-policy-check` | Runs `terraform fmt`, `validate`, `tfsec`, and `Checkov` on Terraform files |
| `deploy-dev` | Authenticates to AWS via OIDC, pushes image to ECR, applies Terraform, registers task definition, updates ECS service, waits for steady state, runs smoke test, publishes summary |

### Deployment Steps Inside `deploy-dev`

| Step | Description |
|------|-------------|
| Configure AWS credentials | Assumes `AWS_DEV_ROLE_ARN` via OIDC — no static credentials |
| Log in to ECR | Obtains ECR authentication token |
| Build and push image | Tags image with immutable commit SHA (`github.sha`) |
| Terraform init + plan + apply | Provisions/updates ECR, ECS cluster, service, ALB, security groups, IAM roles |
| Register task definition | Updates the existing task definition with the new image URI |
| Update ECS service | Triggers a new deployment; waits up to 10 minutes for steady state |
| Smoke test | Sends HTTP GET to ALB URL; validates HTTP 200 and expected response text |
| Deployment summary | Publishes image URI, ECS cluster/service, ALB URL, commit SHA to the Actions run page |

---

## Step 5 – Run the Workflow

### Option A: Trigger by pushing code

```bash
# Make a change to the Tomcat app
echo "<!-- v$(date +%s) -->" >> sample-code/tomcat/webapp/index.jsp
git add sample-code/tomcat/webapp/index.jsp
git commit -m "chore: trigger poc deployment"
git push origin main
```

GitHub Actions will automatically trigger the `POC – ECS Tomcat Deployment` workflow.

### Option B: Trigger manually

1. Go to **GitHub Actions** → **POC – ECS Tomcat Deployment**
2. Click **Run workflow**
3. Select environment: `dev`
4. Click **Run workflow**

---

## Step 6 – Verify POC Success

The POC is successful when all of the following are true:

| Criterion | How to verify |
|-----------|---------------|
| Developer did not use AWS Console | No console activity — all actions are in Actions run log |
| GitHub Actions deploy stage succeeded | Green checkmark on `deploy-dev` job |
| ECS service is healthy | `aws ecs describe-services` shows `runningCount >= 1` and `status = ACTIVE` |
| ALB URL returns Tomcat page | Smoke test step shows `HTTP 200` and expected text found |
| Deployment metadata ties to commit SHA | Deployment summary shows commit SHA and workflow run URL |

### Reading the Deployment Summary

After a successful run, open the workflow run page in GitHub Actions and scroll to the bottom. The **Step Summary** will show:

```
## POC Deployment Summary – dev
| Field           | Value                          |
|-----------------|--------------------------------|
| Commit SHA      | `abc1234...`                   |
| Workflow run    | link to this run               |
| Image URI       | `123456789.dkr.ecr.../poc-tomcat:abc1234...` |
| ECS Cluster     | `poc-dev-cluster`              |
| ECS Service     | `poc-dev-tomcat-service`       |
| Application URL | http://poc-dev-alb-xxx...      |
| Smoke test      | passed                         |
```

---

## Step 7 – Troubleshooting

### Workflow fails at "Configure AWS credentials"

- Verify `AWS_DEV_ROLE_ARN` is set in the `dev` environment variables.
- Verify the IAM role trust policy matches `repo:wingt903/CICD:environment:dev`.
- Check that the OIDC provider is created in the correct AWS account.

### Workflow fails at "Build and push image to ECR"

- Verify the ECR repository exists in the target AWS account and region.
- Check that the IAM role has `ecr:GetAuthorizationToken` and `ecr:PutImage` permissions.

### Workflow fails at "Terraform apply"

- Check the Terraform plan output in the previous step for errors.
- Verify VPC and subnet IDs are correct for the dev account.
- If using remote state, ensure `TF_STATE_BUCKET` is set and the role can access the bucket.

### Workflow fails at "Update ECS service" or times out

- The `aws ecs wait services-stable` command times out after 10 minutes if the ECS task fails to start.
- Check CloudWatch logs at `/ecs/poc-dev-tomcat` for container errors.
- Common causes: incorrect image URI, ECR permissions, or task definition CPU/memory too low.

### Smoke test fails

- Confirm the ALB DNS name resolves and is accessible from GitHub Actions runners (public internet).
- Check the ALB target group health — tasks may be failing health checks.
- Check that security groups allow inbound HTTP (port 80) on the ALB.

---

## Approved Secrets and Credentials Strategy

| What | Where to store | Access method |
|------|---------------|---------------|
| AWS role ARN | GitHub environment variable | OIDC `role-to-assume` |
| DB passwords, API tokens | AWS Secrets Manager | ECS task pulls at startup via `secrets` in task definition |
| Non-sensitive config (URLs, names) | GitHub environment variables or AWS SSM Parameter Store | `vars.*` in workflow or SSM SDK |
| Static AWS keys | ❌ **Never stored anywhere** | Not used |

See `POC/developer-guide-github-secrets-to-kms.md` for the full approved secrets migration guide.

---

## Related Files

| File | Description |
|------|-------------|
| `poc.md` | POC objectives, operating model, and infrastructure guidance |
| `.github/workflows/poc-ecs-tomcat-deploy.yml` | **The deployment workflow** — this guide explains how to use it |
| `.github/workflows/poc-executable-tests.yml` | Post-deployment test validation workflow |
| `POC/test_case.md` | Test case definitions and pass/fail criteria |
| `POC/poc-workflow-setup-guide.md` | Setup guide for the test validation workflow |
| `POC/developer-guide-github-secrets-to-kms.md` | Secrets and credentials approved store guide |
| `infrastructure/terraform/` | Terraform root module (add `ecs-poc.tf` as described in Step 1) |
| `sample-code/tomcat/` | Tomcat sample application and Dockerfile |
