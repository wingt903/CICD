# POC: Deploy Apache Tomcat "Hello World" to AWS ECS (Fargate)

This guide walks you through deploying the sample Tomcat application in this repository to AWS Elastic Container Service (ECS) using Fargate — step by step, with no prior CICD, Terraform, or Ansible experience required.

---

## What You Will Build

A running Apache Tomcat 10.1 container in AWS, accessible via a public URL, serving a "Hello World" web page.

---

## Prerequisites

Before starting, make sure you have the following installed and configured on your local machine:

### 1. AWS Account
- Sign up at https://aws.amazon.com if you don't have one.
- Note your **AWS Account ID** (12-digit number, visible top-right in AWS Console).
- Choose a **region** — this guide uses `ap-southeast-1` (Singapore). You can use any region.

### 2. AWS CLI
- Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
- After install, configure it with your credentials:
  ```bash
  aws configure
  ```
  Enter your AWS Access Key ID, Secret Access Key, region (`ap-southeast-1`), and output format (`json`).

> **How to get credentials:** In AWS Console → top-right menu → Security Credentials → Access Keys → Create Access Key.

### 3. Docker Desktop
- Install: https://www.docker.com/products/docker-desktop
- After install, make sure Docker is running (Docker whale icon in taskbar).

### 4. Git
- Install: https://git-scm.com/downloads
- Clone this repository if you haven't already:
  ```bash
  git clone https://github.com/wingt903/CICD.git
  cd CICD
  ```

---

## Step 1 — Understand the Sample Application

The Tomcat sample app is in `sample-code/tomcat/`:

```
sample-code/tomcat/
├── Dockerfile          ← instructions to build the container image
└── webapp/
    └── index.jsp       ← the "Hello World" web page served by Tomcat
```

The `Dockerfile` uses the official `tomcat:10.1-jdk17` image and copies `index.jsp` into the Tomcat webapps folder. No changes are needed — it is ready to use as-is.

---

## Step 2 — Create an ECR Repository (Image Registry)

Amazon ECR (Elastic Container Registry) is where you store your Docker image before deploying it to ECS.

```bash
# Replace ACCOUNT_ID with your 12-digit AWS Account ID
# Replace REGION with your chosen region (e.g. ap-southeast-1)
aws ecr create-repository \
  --repository-name poc-tomcat \
  --region ap-southeast-1
```

You will see output like:
```json
{
  "repository": {
    "repositoryUri": "123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/poc-tomcat"
  }
}
```

Copy the `repositoryUri` — you will need it in the next steps.

---

## Step 3 — Build and Push the Docker Image

### 3a. Log Docker into ECR

```bash
aws ecr get-login-password --region ap-southeast-1 \
  | docker login --username AWS --password-stdin \
    123456789012.dkr.ecr.ap-southeast-1.amazonaws.com
```

Replace `123456789012` with your Account ID.

### 3b. Build the image

From the root of this repository:

```bash
docker build -t poc-tomcat sample-code/tomcat/
```

This reads the `Dockerfile` in `sample-code/tomcat/` and builds the image locally.

### 3c. Tag the image for ECR

```bash
docker tag poc-tomcat:latest \
  123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/poc-tomcat:latest
```

Replace `123456789012` with your Account ID.

### 3d. Push the image to ECR

```bash
docker push \
  123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/poc-tomcat:latest
```

Once complete, your image is stored in AWS and ready for deployment.

---

## Step 4 — Create an ECS Cluster

An ECS cluster is the logical grouping that runs your container.

```bash
aws ecs create-cluster \
  --cluster-name poc-tomcat-cluster \
  --region ap-southeast-1
```

---

## Step 5 — Create a Task Definition

A Task Definition tells ECS what container to run, how much CPU/memory to allocate, and which ports to open.

Save the following as `/tmp/task-def.json` (copy and paste into a text file):

```json
{
  "family": "poc-tomcat-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::123456789012:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "tomcat",
      "image": "123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/poc-tomcat:latest",
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/poc-tomcat",
          "awslogs-region": "ap-southeast-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

> **Replace** all occurrences of `123456789012` with your actual Account ID.

### 5a. Create the ECS Task Execution Role (one-time setup)

ECS needs permission to pull the image from ECR. Run:

```bash
# Create the role
aws iam create-role \
  --role-name ecsTaskExecutionRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ecs-tasks.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'

# Attach the managed policy
aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```

### 5b. Create a CloudWatch log group

```bash
aws logs create-log-group \
  --log-group-name /ecs/poc-tomcat \
  --region ap-southeast-1
```

### 5c. Register the task definition

```bash
aws ecs register-task-definition \
  --cli-input-json file:///tmp/task-def.json \
  --region ap-southeast-1
```

---

## Step 6 — Find Your VPC, Subnets, and Security Group

ECS Fargate needs to know which VPC/subnets to run in.

### 6a. Get your default VPC ID

```bash
aws ec2 describe-vpcs \
  --filters Name=isDefault,Values=true \
  --query "Vpcs[0].VpcId" \
  --output text \
  --region ap-southeast-1
```

This returns something like `vpc-0abc12345def67890`. Note it down.

### 6b. Get subnet IDs in that VPC

```bash
aws ec2 describe-subnets \
  --filters Name=vpc-id,Values=vpc-0abc12345def67890 \
  --query "Subnets[*].SubnetId" \
  --output text \
  --region ap-southeast-1
```

You will get 2–3 subnet IDs. Note at least two of them.

### 6c. Create a Security Group that allows web traffic

```bash
aws ec2 create-security-group \
  --group-name poc-tomcat-sg \
  --description "Allow HTTP access for Tomcat POC" \
  --vpc-id vpc-0abc12345def67890 \
  --region ap-southeast-1
```

Note the `GroupId` returned (e.g. `sg-0123456789abcdef0`).

Then allow inbound traffic on port 8080:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-0123456789abcdef0 \
  --protocol tcp \
  --port 8080 \
  --cidr 0.0.0.0/0 \
  --region ap-southeast-1
```

---

## Step 7 — Run the ECS Service

This creates and starts the Tomcat container on ECS Fargate, with a public IP assigned automatically.

```bash
aws ecs create-service \
  --cluster poc-tomcat-cluster \
  --service-name poc-tomcat-service \
  --task-definition poc-tomcat-task \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={
    subnets=[subnet-AAAAAAAAAA,subnet-BBBBBBBBBB],
    securityGroups=[sg-0123456789abcdef0],
    assignPublicIp=ENABLED
  }" \
  --region ap-southeast-1
```

Replace:
- `subnet-AAAAAAAAAA,subnet-BBBBBBBBBB` with your actual subnet IDs from Step 6b.
- `sg-0123456789abcdef0` with your security group ID from Step 6c.

---

## Step 8 — Find the Public IP and Verify

### 8a. Wait for the task to start (about 1–2 minutes)

```bash
aws ecs list-tasks \
  --cluster poc-tomcat-cluster \
  --region ap-southeast-1
```

You will see a task ARN like `arn:aws:ecs:ap-southeast-1:123456789012:task/poc-tomcat-cluster/abc123...`

### 8b. Get the public IP

```bash
# Replace <task-id> with the ID portion at the end of your task ARN
aws ecs describe-tasks \
  --cluster poc-tomcat-cluster \
  --tasks <task-id> \
  --region ap-southeast-1 \
  --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" \
  --output text
```

Note the `networkInterfaceId` (e.g. `eni-0abc123`), then:

```bash
aws ec2 describe-network-interfaces \
  --network-interface-ids eni-0abc123 \
  --query "NetworkInterfaces[0].Association.PublicIp" \
  --output text \
  --region ap-southeast-1
```

### 8c. Open the app in your browser

Navigate to:
```
http://<PUBLIC_IP>:8080
```

You should see the Tomcat Hello World page:

> **Tomcat CI/CD Migration Sample**  
> Deployed via pipeline to AWS runtime target.

---

## Step 9 — Clean Up (to avoid AWS charges)

When you are done with the POC, delete all resources:

```bash
# Delete ECS service
aws ecs update-service \
  --cluster poc-tomcat-cluster \
  --service poc-tomcat-service \
  --desired-count 0 \
  --region ap-southeast-1

aws ecs delete-service \
  --cluster poc-tomcat-cluster \
  --service poc-tomcat-service \
  --region ap-southeast-1

# Delete ECS cluster
aws ecs delete-cluster \
  --cluster poc-tomcat-cluster \
  --region ap-southeast-1

# Delete ECR repository (and all images inside it)
aws ecr delete-repository \
  --repository-name poc-tomcat \
  --force \
  --region ap-southeast-1

# Delete CloudWatch log group
aws logs delete-log-group \
  --log-group-name /ecs/poc-tomcat \
  --region ap-southeast-1

# Delete security group
aws ec2 delete-security-group \
  --group-id sg-0123456789abcdef0 \
  --region ap-southeast-1
```

---

## Summary of What Was Done

| Step | What Happened |
|------|--------------|
| 1 | Reviewed the sample Tomcat app and Dockerfile |
| 2 | Created an ECR repository to store the Docker image |
| 3 | Built the Docker image locally and pushed it to ECR |
| 4 | Created an ECS cluster |
| 5 | Defined the container task (CPU, memory, ports, image) |
| 6 | Identified VPC, subnets, and created a security group |
| 7 | Launched the container as an ECS Fargate service |
| 8 | Retrieved the public IP and confirmed the app is live |
| 9 | Cleaned up all resources |

---

## Troubleshooting

| Problem | Likely Cause | Fix |
|---------|-------------|-----|
| `docker push` fails | Not logged into ECR | Re-run Step 3a |
| Task stays in `PENDING` | Role missing or image URI wrong | Check `executionRoleArn` and `image` in task definition |
| Browser shows nothing | Security group not open | Confirm port 8080 is allowed in Step 6c |
| `ecsTaskExecutionRole` already exists | Role was created previously | Skip Step 5a, the role is already there |

---

*This POC uses ECS Fargate with a public IP for simplicity. A production setup would add an Application Load Balancer, private subnets, HTTPS, and IAM least-privilege controls — as modelled in the full architecture in the `architecture/` folder of this repository.*
