# GitHub Account Access Options for CI/CD-to-Application Repositories

In this model, the CI/CD repository is separate from application repositories. The CI/CD runner account (DevOps-owned GitHub Actions execution context) needs controlled cross-repository access.

## Option 1: GitHub App (Recommended)

1. Create a GitHub App owned by the organization (for example, `org-cicd-bot`).
2. Install the app on the CI/CD repository and target application repositories.
3. Grant minimum required permissions (for example, `contents: read`, and only additional scopes when required).
4. Store app credentials in CI/CD repository secrets/variables (`APP_ID`, `APP_PRIVATE_KEY`).
5. In workflows, mint short-lived installation tokens and use them to access app repositories.

**Pros**
- Short-lived tokens
- Fine-grained repository-level permissions
- Better auditability and security posture

**Cons**
- Initial setup is more complex than PAT-based access

## Option 2: Machine User (Bot) + PAT

1. Create a dedicated machine user (for example, `cicd-bot`).
2. Grant this account explicit access to required application repositories.
3. Generate a PAT for the machine user with least privilege (for example, `contents: read`, and only additional scopes as required).
4. Store the PAT as a CI/CD repository secret.
5. Use that token in GitHub Actions for checkout/API calls to app repositories.

**Pros**
- Fast and simple to set up
- Easy to understand operationally

**Cons**
- Long-lived credential management burden
- Rotation and governance are weaker than GitHub App tokens

## Option 3: App Repositories Trigger CI/CD Repository (Dispatch Model)

1. Keep source ownership and build context in each application repository.
2. App workflows send `repository_dispatch` or `workflow_dispatch` events to the CI/CD repository.
3. CI/CD workflow consumes payload (artifact version/image tag/target environment) and executes deployment logic.
4. CI/CD repository does not need full read access to app source code by default.
   Explicit read access is only needed for specific use cases:
   - centralized code scanning
   - cross-repo dependency analysis
   - policy checks that inspect source

**Pros**
- Strong separation of responsibilities
- Reduces cross-repo read requirements from CI/CD side
- Aligns well with centralized deployment governance

**Cons**
- Requires event contract/payload governance between repositories

## Recommendation Summary

- **Preferred for enterprise/security-first setups:** Option 1 (GitHub App)
- **Preferred for strict repo separation with app-owned triggers:** Option 3 (Dispatch model)
- **Use Option 2 only when rapid setup is needed and governance controls are acceptable**
