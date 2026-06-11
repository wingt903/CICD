# Developer Guide: Migrating from GitHub Secrets to Approved Secrets Stores

**Audience:** Product Team / Platform Team developers  
**Relates to:** `architecture/secrets-management-strategy.md`, `architecture/full-pipeline-tech-stack.md`

---

## 1. Why GitHub Secrets Are Not Enough

GitHub Actions Encrypted Secrets are **approved only for a narrow bootstrap category** — the minimum set of workflow-level values that are technically required *before* OIDC federation is established. They are **not** an approved store for:

| What you might have put in GitHub Secrets | Approved store instead |
|---|---|
| AWS access key / secret key | ❌ Prohibited entirely — use OIDC federation |
| Database passwords / connection strings | AWS Secrets Manager |
| Third-party API tokens | AWS Secrets Manager |
| Environment config / runtime parameters | AWS SSM Parameter Store (`SecureString`) |
| Encryption keys | AWS KMS (CMK) |

The architecture rule is: **one approved store per category, no shadow copies.**

---

## 2. The Approved Store Map

```
Secret category                   Approved store
────────────────────────────────────────────────────────────
AWS pipeline credentials          IAM OIDC → STS (no secret stored at all)
Runtime app secrets (DB, API)     AWS Secrets Manager  /dev/ /test/ /prod/
Infrastructure config             AWS SSM Parameter Store  /dev/ /test/ /prod/
Encryption keys                   AWS KMS (Customer Managed Keys)
CI bootstrap (last resort only)   GitHub Actions Encrypted Secrets
                                  — must be individually justified in LLI
```

---

## 3. Step-by-Step Migration

### Step 1 — Eliminate static AWS credentials from GitHub Secrets

**Old (prohibited):**
```yaml
env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

**Approved replacement — OIDC federation in your workflow:**

```yaml
permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Assume AWS role via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.AWS_DEPLOY_ROLE_ARN }}
          aws-region: ap-southeast-2
          role-session-name: cicd-pipeline-${{ github.run_id }}
```

The short-lived STS credential is issued per-job and expires automatically. No secret is stored anywhere.

> **Note:** `AWS_DEPLOY_ROLE_ARN` is a non-sensitive GitHub Actions variable (not a secret).

### Step 2 — Move database passwords and API tokens to AWS Secrets Manager

**Old (prohibited):**
```yaml
env:
  DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
  THIRD_PARTY_TOKEN: ${{ secrets.THIRD_PARTY_TOKEN }}
```

**Approved replacement — pull from Secrets Manager at runtime:**

Store the secret (normally via governed pipeline automation):
```bash
aws secretsmanager create-secret \
  --name /prod/myapp/db-password \
  --secret-string "your-password-here" \
  --kms-key-id alias/secrets-cmk-prod
```

Read in workflow after OIDC role assumption:
```yaml
      - name: Retrieve DB password from Secrets Manager
        id: get-secrets
        run: |
          set -euo pipefail
          DB_PASSWORD=$(aws secretsmanager get-secret-value \
            --secret-id /prod/myapp/db-password \
            --query SecretString --output text)
          [ -n "$DB_PASSWORD" ] || { echo "Failed to retrieve /prod/myapp/db-password from Secrets Manager" >&2; exit 1; }
          # Mask secret value in all subsequent GitHub Actions logs.
          echo "::add-mask::$DB_PASSWORD"
          # Pass secret only to the command that needs it (step-scoped usage).
          DB_PASSWORD="$DB_PASSWORD" ./deploy.sh
```

> **Security note:** In this example, `deploy.sh` reads `DB_PASSWORD` from its process environment and must never log, echo, or persist the value.

Use least-privilege IAM: allow `secretsmanager:GetSecretValue` only on required ARNs.

### Step 3 — Move configuration parameters to SSM Parameter Store

Non-secret environment config should be in SSM Parameter Store, not GitHub Secrets.

Store parameter:
```bash
aws ssm put-parameter \
  --name /prod/myapp/approved-ami \
  --value "ami-0abc123def456" \
  --type String \
  --overwrite
```

Read parameter in workflow:
```yaml
      - name: Read approved AMI from SSM
        run: |
          AMI_ID=$(aws ssm get-parameter \
            --name /prod/myapp/approved-ami \
            --query Parameter.Value --output text)
          echo "AMI_ID=$AMI_ID" >> "$GITHUB_ENV"
```

For sensitive config, use `SecureString` with a CMK.

### Step 4 — Understand when GitHub Secrets are still allowed

GitHub Encrypted Secrets are permitted only for minimal bootstrap values that cannot be supplied by OIDC/SSM at job start.

Each remaining GitHub secret must be:
- Justified in LLI
- Minimally scoped
- Reviewed annually
- Removed when no longer required

If no clear justification exists, move it to Secrets Manager or SSM.

---

## 4. KMS — What You Don’t Manage Directly

KMS CMKs are consumed by platform services:

| KMS CMK | Used by |
|---|---|
| `alias/evidence-signing-cmk` | Evidence Ingestor Lambda (record signing) |
| `alias/secrets-cmk-<env>` | Secrets Manager encryption at rest |
| `alias/ssm-cmk-<env>` | SSM SecureString encryption |
| `alias/s3-evidence-cmk` | S3 evidence bucket SSE-KMS |

You reference CMK aliases when creating secrets/parameters. You do not handle key material directly.

---

## 5. Quick Checklist Before PR

- [ ] No AWS access key or secret key in workflow YAML or source code
- [ ] AWS authentication uses OIDC role assumption
- [ ] Runtime secrets moved to Secrets Manager
- [ ] Environment configuration moved to SSM Parameter Store
- [ ] Remaining GitHub secrets have documented LLI justification
- [ ] IAM permissions are least-privilege and resource-scoped
- [ ] Secret values are masked in logs when handled in workflow steps

---

## 6. Where AWS Access Key and Secret Key Are Stored in This Design

They are **not stored at rest** for pipeline usage.  
GitHub Actions uses OIDC to exchange a signed token for short-lived AWS STS session credentials that expire automatically (typically within 1 hour).

If static IAM user access keys currently exist for pipeline use, migrate to OIDC and then revoke/delete those keys.

---

## References

- `architecture/secrets-management-strategy.md`
- `architecture/full-pipeline-tech-stack.md`
- `architecture/compliance-evidence-store.md`
