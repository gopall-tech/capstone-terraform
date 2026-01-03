# GitHub Actions CI/CD Setup

This document explains how to set up GitHub Actions for automated deployment of the capstone project.

## Repository Structure

The project is split into three repositories:
- **capstone-Backend**: Backend services (backend-a and backend-b)
- **capstone-Frontend**: React frontend application
- **capstone-terraform**: Infrastructure as Code and Kubernetes manifests

## Required GitHub Secrets

You need to add the following secrets to each repository:

### 1. AZURE_CREDENTIALS

Create an Azure Service Principal with contributor access:

```bash
az ad sp create-for-rbac \
  --name "github-actions-gopal" \
  --role contributor \
  --scopes /subscriptions/606e824b-aaf7-4b4e-9057-b459f6a4436d \
  --sdk-auth
```

Copy the entire JSON output and add it as a secret named `AZURE_CREDENTIALS` in each repository.

The output should look like:
```json
{
  "clientId": "...",
  "clientSecret": "...",
  "subscriptionId": "606e824b-aaf7-4b4e-9057-b459f6a4436d",
  "tenantId": "...",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

### 2. POSTGRES_ADMIN_PASSWORD

Add the PostgreSQL admin password as a secret:
- Secret name: `POSTGRES_ADMIN_PASSWORD`
- Secret value: `P@ssw0rd123!`

## Adding Secrets to GitHub Repositories

For each repository (capstone-Backend, capstone-Frontend, capstone-terraform):

1. Go to the repository on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add both secrets:
   - `AZURE_CREDENTIALS`
   - `POSTGRES_ADMIN_PASSWORD`

## Workflow Overview

### capstone-Backend Workflows

**File**: `.github/workflows/deploy.yml`

**Triggers**:
- Push to `main` or `develop` branches
- Manual trigger via workflow_dispatch

**What it does**:
- **Build Job**: Builds Docker images for backend-a and backend-b, pushes to dev ACR
- **Deploy-Dev Job**: Deploys to dev AKS cluster (auto-runs, no approval)
- **Promote-to-QA Job**: Pulls images from dev, pushes to qa ACR, deploys to qa AKS (waits for approval)
- **Promote-to-Prod Job**: Pulls images from qa, pushes to prod ACR, deploys to prod AKS (waits for approval)

**Deployment Flow**: build → dev → qa (approval) → prod (approval)

### capstone-Frontend Workflows

**File**: `.github/workflows/deploy.yml`

**Triggers**:
- Push to `main` or `develop` branches
- Manual trigger via workflow_dispatch

**What it does**:
- **Build Job**: Builds React app with dev nginx config, pushes to dev ACR
- **Deploy-Dev Job**: Deploys to dev AKS cluster (auto-runs, no approval)
- **Promote-to-QA Job**: Pulls image from dev, pushes to qa ACR, deploys to qa AKS (waits for approval)
- **Promote-to-Prod Job**: Pulls image from qa, pushes to prod ACR, deploys to prod AKS (waits for approval)

**Deployment Flow**: build → dev → qa (approval) → prod (approval)

### capstone-terraform Workflows

**File 1**: `.github/workflows/terraform.yml`

**Triggers**:
- Push to `main` branch (changes to envs/ or modules/)
- Pull requests to `main`
- Manual trigger with options to plan/apply/destroy

**What it does**:
- **Terraform-Dev Job**: Runs terraform for dev environment (auto-runs, no approval)
- **Terraform-QA Job**: Runs terraform for qa environment (waits for approval)
- **Terraform-Prod Job**: Runs terraform for prod environment (waits for approval)
- Each job runs: init, validate, plan, apply (on main branch)
- Can destroy infrastructure via manual trigger

**Deployment Flow**: dev → qa (approval) → prod (approval)

**File 2**: `.github/workflows/k8s-deploy.yml`

**Triggers**:
- Push to `main` branch (changes to k8s/)
- Manual trigger via workflow_dispatch

**What it does**:
- **Deploy-Dev Job**: Deploys K8s manifests to dev (auto-runs, no approval)
- **Deploy-QA Job**: Deploys K8s manifests to qa (waits for approval)
- **Deploy-Prod Job**: Deploys K8s manifests to prod (waits for approval)
- Creates namespaces, secrets, deployments, services, and ingress

**Deployment Flow**: dev → qa (approval) → prod (approval)

## Manual Deployment

### Deploy Infrastructure (Terraform)

1. Go to **capstone-terraform** repository
2. Click **Actions** → **Terraform Infrastructure**
3. Click **Run workflow**
4. Select:
   - Environment: dev/qa/prod
   - Action: plan/apply/destroy

### Deploy Application (Backend/Frontend)

1. Go to **capstone-Backend** or **capstone-Frontend**
2. Click **Actions** → **Build and Deploy**
3. Click **Run workflow**
4. Select branch: main

### Deploy Kubernetes Manifests

1. Go to **capstone-terraform** repository
2. Click **Actions** → **Deploy Kubernetes Manifests**
3. Click **Run workflow**
4. Select environment: dev/qa/prod

## Automated Deployment Flow

When you push code changes to `main`:

1. **Backend changes** → Triggers backend workflow:
   - Builds images and deploys to dev automatically
   - Waits for approval to promote to QA
   - After QA approval, waits for approval to promote to prod

2. **Frontend changes** → Triggers frontend workflow:
   - Builds image and deploys to dev automatically
   - Waits for approval to promote to QA
   - After QA approval, waits for approval to promote to prod

3. **Infrastructure changes** → Triggers terraform workflow:
   - Applies to dev automatically
   - Waits for approval to apply to QA
   - After QA approval, waits for approval to apply to prod

4. **K8s manifest changes** → Triggers k8s-deploy workflow:
   - Deploys to dev automatically
   - Waits for approval to deploy to QA
   - After QA approval, waits for approval to deploy to prod

**Note**: All workflows require manual approval to proceed from dev → qa and qa → prod if environment protection rules are configured.

## Image Tagging Strategy

Images are tagged with:
- `{environment}-{short-sha}`: Specific version (e.g., `dev-a1b2c3d`)
- `{environment}-latest`: Always points to latest for that environment

This allows for:
- Easy rollbacks to specific versions
- Automated deployments using `latest` tag
- Audit trail of what's deployed

## Environments and Approval Gates

The workflows are configured with sequential deployment and environment protection:

- **Dev**: Auto-deploys on push to `main` or `develop` (no approval required)
- **QA**: Deploys after dev completes (requires approval if configured)
- **Prod**: Deploys after QA completes (requires approval if configured)

### Setting Up Environment Protection Rules

To enable approval gates between environments, you need to configure GitHub environment protection rules:

#### 1. Create Environments in GitHub

For each repository (capstone-Backend, capstone-Frontend, capstone-terraform):

1. Go to repository **Settings** → **Environments**
2. Click **New environment**
3. Create three environments:
   - `dev`
   - `qa`
   - `prod`

#### 2. Configure Environment Protection Rules

For **QA environment**:
1. Click on the `qa` environment
2. Check **Required reviewers**
3. Add yourself or team members as required reviewers
4. Set **Wait timer** (optional): e.g., 0 minutes
5. Click **Save protection rules**

For **Prod environment**:
1. Click on the `prod` environment
2. Check **Required reviewers**
3. Add yourself or team members as required reviewers (can be different from QA)
4. Set **Wait timer** (optional): e.g., 5 minutes for additional safety
5. Click **Save protection rules**

For **Dev environment**:
- No protection rules needed - it will auto-deploy

#### 3. How Approvals Work

When you push to `main`:

1. **Build & Deploy to Dev**: Runs automatically, no approval needed
2. **Promote to QA**: Workflow pauses and waits for approval
   - Reviewer receives notification
   - Reviewer can approve or reject
   - On approval, deploys to QA
3. **Promote to Prod**: After QA succeeds, workflow pauses again
   - Reviewer receives notification
   - Reviewer can approve or reject
   - On approval, deploys to Prod

#### 4. Reviewing Deployments

To approve a deployment:

1. Go to repository → **Actions** tab
2. Click on the running workflow
3. You'll see a yellow banner saying "Review pending"
4. Click **Review deployments**
5. Select environments to approve (qa and/or prod)
6. Add optional comment
7. Click **Approve and deploy** or **Reject**

#### 5. Deployment Notifications

Configure notifications to get alerts when approval is needed:

1. Go to **Settings** → **Notifications**
2. Enable **Actions** notifications
3. Choose how you want to be notified (email, web, mobile)

## Rollback Procedure

If you need to rollback to a previous version:

```bash
# Find the previous image tag
kubectl get deployment backend-a -n gopal-app -o yaml | grep image:

# Rollback to specific version
kubectl set image deployment/backend-a \
  backend-a=gopaldevacr.azurecr.io/backend-a:dev-{previous-sha} \
  -n gopal-app

# Or use kubectl rollback
kubectl rollout undo deployment/backend-a -n gopal-app
```

## Monitoring Deployments

View deployment status:

```bash
# Check rollout status
kubectl rollout status deployment/backend-a -n gopal-app

# View pods
kubectl get pods -n gopal-app

# Check logs
kubectl logs -f deployment/backend-a -n gopal-app
```

## Troubleshooting

### Workflow fails with authentication error
- Verify `AZURE_CREDENTIALS` secret is correctly set
- Check Service Principal has necessary permissions

### Image push fails
- Ensure ACR registries exist
- Verify Service Principal has AcrPush role

### Deployment fails
- Check AKS cluster is running
- Verify namespace exists
- Check pod logs: `kubectl logs -n gopal-app {pod-name}`

### PostgreSQL connection fails
- Verify `POSTGRES_ADMIN_PASSWORD` secret matches actual password
- Check firewall rules allow AKS subnet
- Confirm SSL is enabled in deployment manifests
