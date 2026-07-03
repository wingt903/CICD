# Tomcat on AWS EC2 – Ansible Demo Playbook

This demo deploys **Apache Tomcat 10.1 (JDK 17)** directly onto an AWS EC2 instance using Ansible.  
No Docker or ECR required – ideal for a quick hands-on trial.

## Folder Structure

```
demo/
├── deploy-tomcat.yml      # Main playbook
├── inventory.ini          # Static EC2 host inventory  (edit before running)
├── group_vars/
│   └── all.yml            # All configurable variables
├── templates/
│   └── server.xml.j2      # Hardened Tomcat server.xml template
└── README.md              # This file
```

## Prerequisites

| Requirement | Notes |
|---|---|
| Ansible ≥ 2.15 | `pip install ansible` |
| AWS EC2 instance | Amazon Linux 2023 or Ubuntu 22.04 LTS recommended |
| Security Group | Inbound TCP **8080** open from your IP |
| SSH key pair | `.pem` file downloaded from AWS Console |

## Quick Start

### 1. Launch an EC2 instance

Use the AWS Console or CLI to launch an EC2 instance:

```bash
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \   # Amazon Linux 2023 – replace with your region's AMI
  --instance-type t3.micro \
  --key-name <YOUR_KEY_NAME> \
  --security-group-ids <YOUR_SG_ID> \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=tomcat-demo}]'
```

Make sure the Security Group allows **inbound TCP 8080** from your IP and **inbound TCP 22** for SSH.

### 2. Edit the inventory

Open `demo/inventory.ini` and replace the placeholders:

```ini
[tomcat]
tomcat-demo ansible_host=<EC2_PUBLIC_IP_OR_DNS> ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/<YOUR_KEY>.pem
```

### 3. Run the playbook

```bash
cd demo
ansible-playbook -i inventory.ini deploy-tomcat.yml
```

### 4. Verify

Open your browser at `http://<EC2_PUBLIC_IP>:8080/`  
You should see the Tomcat welcome page (or a 404 if no ROOT app is deployed, which still confirms Tomcat is running).

## Deploying a WAR File

To deploy your own application WAR at the same time:

```bash
ansible-playbook -i inventory.ini deploy-tomcat.yml \
  -e "tomcat_war_src=../sample-code/tomcat/myapp.war" \
  -e "tomcat_app_name=ROOT"
```

The WAR is copied to `webapps/ROOT.war` and served at `/`.

## Key Variables (`group_vars/all.yml`)

| Variable | Default | Description |
|---|---|---|
| `tomcat_version` | `10.1.39` | Tomcat release to install |
| `java_package` | `java-17-amazon-corretto-headless` | Java package name (Amazon Linux) |
| `tomcat_install_dir` | `/opt/tomcat` | Installation directory on EC2 |
| `tomcat_http_port` | `8080` | HTTP port Tomcat listens on |
| `tomcat_java_opts` | `-Xms256m -Xmx512m …` | JVM options passed via systemd |
| `tomcat_war_src` | _(empty)_ | Local path to WAR file to deploy |
| `tomcat_app_name` | `ROOT` | WAR name (served at `/`) |

## What the Playbook Does

1. **Pre-flight** – asserts supported OS, prints deployment summary.
2. **Java** – installs Amazon Corretto 17 (Amazon Linux) or OpenJDK 17 (Ubuntu).
3. **User/Group** – creates a dedicated `tomcat` system account (UID 1001, no login shell).
4. **Install** – downloads the official Apache Tomcat tarball from the Apache CDN and extracts it to `/opt/tomcat`.
5. **Harden** – removes default webapps (`ROOT`, `examples`, `manager`, `host-manager`, `docs`), sets restrictive file permissions, and disables the shutdown port.
6. **Configure** – renders a hardened `server.xml` from the Jinja2 template.
7. **Deploy WAR** – (optional) copies your WAR to the webapps directory.
8. **systemd** – installs a systemd unit, enables Tomcat on boot, and starts the service.
9. **Smoke test** – waits for port 8080 and performs an HTTP GET to confirm Tomcat is responding.

## Next Steps (Production)

For a production-grade pipeline see `ansible/playbooks/deploy-tomcat.yml` which adds:

- ECR image pull with immutable SHA enforcement
- RTCM (Runtime Compatibility Matrix) validation against SSM Parameter Store
- Docker container deployment with Datadog log labels
- Deployment decision audit records in SSM
- Configuration drift detection
