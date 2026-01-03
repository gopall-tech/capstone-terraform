# Capstone Terraform Infrastructure

This repository contains Infrastructure as Code (Terraform) and Kubernetes deployment configurations for the capstone project.

## What's in This Repo

This repo is the **infrastructure foundation** for the entire capstone project:

- **Terraform Modules**: Reusable infrastructure components
- **Environment Configs**: Separate configs for dev, qa, and prod
- **Kubernetes Manifests**: Deployment yamls for all services
- **CI/CD Workflows**: GitHub Actions for infrastructure and K8s deployments
- **Scripts**: Utility scripts for APIM configuration and database fixes

## Repository Structure

```
capstone-terraform/
├── bootstrap/
│   └── main.tf               # Terraform state storage setup
├── modules/
│   ├── aks/                  # Azure Kubernetes Service module
│   ├── acr/                  # Azure Container Registry module
│   ├── postgres/             # PostgreSQL Flexible Server module
│   └── apim/                 # API Management module
├── envs/
│   ├── dev/
│   │   ├── main.tf           # Dev environment config
│   │   ├── terraform.tf      # Backend and providers
│   │   └── variables.tf      # Dev-specific variables
│   ├── qa/                   # QA environment
│   └── prod/                 # Prod environment
├── k8s/
│   ├── backend-a-deployment.yaml
│   ├── backend-b-deployment.yaml
│   ├── frontend-deployment.yaml
│   ├── ingress.yaml
│   └── services.yaml
├── scripts/
│   ├── configure-apim-simple.sh
│   ├── fix-db-config.sh
│   └── deploy-to-k8s.sh
├── .github/
│   └── workflows/
│       ├── terraform.yml     # Infrastructure CI/CD
│       └── k8s-deploy.yml    # Kubernetes deployment CI/CD
├── GITHUB_ACTIONS_SETUP.md   # Complete CI/CD documentation
├── TESTING_VALIDATION.md     # Testing and validation guide
└── DEPLOYMENT_RUNBOOK.md     # Operational procedures
```

## How This Fits in the Overall Project

This is **1 of 3 repositories** that make up the complete capstone project:

### 1. [capstone-Backend](https://github.com/gopall-tech/capstone-Backend)
**What it contains**: Backend microservices (Node.js/Express)
- Two REST API services (backend-a and backend-b)
- **This repo deploys these services to K8s**

### 2. [capstone-Frontend](https://github.com/gopall-tech/capstone-Frontend)
**What it contains**: Frontend web application (React)
- User interface for uploading files
- **This repo deploys the frontend to K8s**

### 3. [capstone-terraform](https://github.com/gopall-tech/capstone-terraform) (THIS REPO)
**What it contains**: Infrastructure as Code and deployment configs
- **Provisions ALL Azure resources**:
  - Azure Kubernetes Service (AKS)
  - Azure Container Registry (ACR)
  - PostgreSQL Flexible Server
  - API Management (APIM)
  - Virtual Networks, Subnets, NSGs
- **Contains K8s deployment manifests** for frontend and backends
- **Manages deployments** across dev, qa, and prod

**Complete Architecture:**
```
┌────────────────────────────────────────────────────┐
│           THIS REPO (capstone-terraform)           │
│  Provisions & Manages Everything Below             │
└──────────────┬────────────────────────────────────┬┘
               │                                    │
         Terraform Provisions                K8s Deploys
               │                                    │
               ▼                                    ▼
    ┌──────────────────┐              ┌──────────────────┐
    │  Azure Resources │              │ K8s Workloads    │
    │  - AKS Clusters  │              │ - Frontend       │
    │  - ACR Registries│              │ - Backend-A      │
    │  - PostgreSQL    │              │ - Backend-B      │
    │  - APIM          │              │ - Ingress        │
    │  - VNets         │              └──────────────────┘
    └──────────────────┘
```

## Infrastructure Modules

### AKS Module (`modules/aks/`)
Creates Azure Kubernetes Service cluster with:
- System node pool (2 nodes, Standard_D2s_v3)
- Automatic upgrades enabled
- Azure CNI networking
- Integration with ACR

### ACR Module (`modules/acr/`)
Creates Azure Container Registry with:
- SKU: Basic
- Admin account enabled
- Stores Docker images for frontend and backends

### PostgreSQL Module (`modules/postgres/`)
Creates PostgreSQL Flexible Server with:
- Version: 15
- SKU: B_Standard_B1ms (1 vCore, 2GB RAM)
- Storage: 32GB
- SSL enforcement enabled
- Firewall rules for AKS pods

### APIM Module (`modules/apim/`)
Creates API Management instance with:
- SKU: Developer
- Gateway for API routing
- Rate limiting and policies
- Integration with backends

## Environments

### Dev Environment
**Resource Group**: `rg-gopal-dev`
**Resources**:
- AKS: `aks-gopal-dev`
- ACR: `gopaldevacr`
- PostgreSQL: `gopalpgdev` (gopalpgdev.postgres.database.azure.com)
- APIM: `apim-gopal-dev`
- **Ingress**: http://20.28.60.126

### QA Environment
**Resource Group**: `rg-gopal-qa`
**Resources**:
- AKS: `aks-gopal-qa`
- ACR: `gopalqaacr`
- PostgreSQL: `gopalpgqa` (gopalpgqa.postgres.database.azure.com)
- APIM: `apim-gopal-qa`
- **Ingress**: http://20.28.46.94

### Prod Environment
**Resource Group**: `rg-gopal-prod`
**Resources**:
- AKS: `aks-gopal-prod`
- ACR: `gopalprodacr`
- PostgreSQL: `gopalpgprod` (gopalpgprod.postgres.database.azure.com)
- APIM: `apim-gopal-prod`
- **Ingress**: http://20.53.16.223

## CI/CD Pipelines

### Terraform Workflow (`.github/workflows/terraform.yml`)

Automates infrastructure provisioning:

**Flow:**
1. **Terraform-Dev**: Runs terraform for dev (automatic)
2. **Terraform-QA**: Runs terraform for qa (requires approval)
3. **Terraform-Prod**: Runs terraform for prod (requires approval)

**Actions**: init, validate, plan, apply
**Triggers**: Push to `main` (envs/ or modules/ changes), manual workflow

### K8s Deploy Workflow (`.github/workflows/k8s-deploy.yml`)

Automates Kubernetes deployments:

**Flow:**
1. **Deploy-Dev**: Deploys all K8s manifests to dev (automatic)
2. **Deploy-QA**: Deploys to qa (requires approval)
3. **Deploy-Prod**: Deploys to prod (requires approval)

**Deploys**: backend-a, backend-b, frontend, services, ingress
**Triggers**: Push to `main` (k8s/ changes), manual workflow

### Required GitHub Secrets
- `AZURE_CREDENTIALS`: Service Principal JSON
- `POSTGRES_ADMIN_PASSWORD`: P@ssw0rd123!

## Kubernetes Deployments

### Backend A Deployment
- **File**: `k8s/backend-a-deployment.yaml`
- **Replicas**: 2
- **Image**: `${ACR_LOGIN_SERVER}/backend-a:${ENV}`
- **Port**: 3000
- **Environment Variables**: DB connection details
- **Health Checks**: Liveness and readiness probes

### Backend B Deployment
- **File**: `k8s/backend-b-deployment.yaml`
- **Replicas**: 2
- **Image**: `${ACR_LOGIN_SERVER}/backend-b:${ENV}`
- **Port**: 3000
- **Environment Variables**: DB connection details
- **Health Checks**: Liveness and readiness probes

### Frontend Deployment
- **File**: `k8s/frontend-deployment.yaml`
- **Replicas**: 2
- **Image**: `${ACR_LOGIN_SERVER}/frontend:${ENV}`
- **Port**: 80
- **Serves**: React app via nginx

### Ingress
- **File**: `k8s/ingress.yaml`
- **Class**: nginx
- **Routes**:
  - `/api/a/*` → backend-a service
  - `/api/b/*` → backend-b service
  - `/` → frontend service

## Getting Started

### 1. Bootstrap Terraform State Storage

```bash
cd bootstrap
terraform init
terraform apply
```

### 2. Deploy Infrastructure (Dev)

```bash
cd envs/dev
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### 3. Deploy Kubernetes Manifests

```bash
# Get AKS credentials
az aks get-credentials --resource-group rg-gopal-dev --name aks-gopal-dev

# Deploy all services
cd ../../k8s
./scripts/deploy-to-k8s.sh dev
```

### 4. Verify Deployment

```bash
kubectl get pods -n gopal-app
kubectl get svc -n gopal-app
kubectl get ingress -n gopal-app

# Test endpoints
curl http://20.28.60.126/api/a/
curl http://20.28.60.126/
```

## Making Infrastructure Changes

### Update Terraform Resources

1. **Make changes** to modules or env configs
2. **Commit and push** to `main`
   ```bash
   git add .
   git commit -m "Update infrastructure"
   git push origin main
   ```
3. **Automatic plan/apply** for dev
4. **Approve** qa and prod deployments

### Update Kubernetes Manifests

1. **Make changes** to k8s/ yaml files
2. **Commit and push** to `main`
3. **Automatic deployment** to dev
4. **Approve** qa and prod deployments

## Utility Scripts

### Configure APIM (`scripts/configure-apim-simple.sh`)
```bash
bash scripts/configure-apim-simple.sh dev
bash scripts/configure-apim-simple.sh qa
bash scripts/configure-apim-simple.sh prod
```

Creates API definitions in APIM for backend-a and backend-b.

### Fix Database Config (`scripts/fix-db-config.sh`)
```bash
bash scripts/fix-db-config.sh dev
bash scripts/fix-db-config.sh qa
bash scripts/fix-db-config.sh prod
```

Updates K8s deployments with correct PostgreSQL connection strings.

## Current Status

### ✅ All Environments Operational

**Dev**: http://20.28.60.126
- Frontend: ✅ Running
- Backend-A: ✅ Running & DB Connected
- Backend-B: ✅ Running & DB Connected

**QA**: http://20.28.46.94
- Frontend: ✅ Running
- Backend-A: ✅ Running & DB Connected
- Backend-B: ✅ Running & DB Connected

**Prod**: http://20.53.16.223
- Frontend: ✅ Running
- Backend-A: ✅ Running & DB Connected
- Backend-B: ✅ Running & DB Connected

## PostgreSQL Configuration

Each environment has a PostgreSQL Flexible Server:

### Dev Database
- **Host**: gopalpgdev.postgres.database.azure.com
- **User**: gopalpgadmindev
- **Database**: gopalappdev
- **Password**: (in Kubernetes secret)

### QA Database
- **Host**: gopalpgqa.postgres.database.azure.com
- **User**: gopalpgadminqa
- **Database**: gopalappqa

### Prod Database
- **Host**: gopalpgprod.postgres.database.azure.com
- **User**: gopalpgadminprod
- **Database**: gopalappprod

## Documentation

This repo contains comprehensive documentation:

### [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md)
Complete guide to:
- GitHub Actions setup
- Required secrets
- Environment protection rules
- Approval workflows
- Image tagging strategy

### [TESTING_VALIDATION.md](TESTING_VALIDATION.md)
Comprehensive testing procedures:
- Infrastructure validation
- Application testing
- End-to-end testing
- Performance testing
- Security validation
- Troubleshooting guide

### [DEPLOYMENT_RUNBOOK.md](DEPLOYMENT_RUNBOOK.md)
Operational procedures:
- Deployment procedures
- Monitoring and debugging
- Emergency procedures
- Maintenance tasks
- Rollback procedures

## Monitoring & Troubleshooting

### View Infrastructure
```bash
# List all resources
az resource list --query "[?contains(resourceGroup, 'gopal')]" -o table

# Check AKS status
az aks show --resource-group rg-gopal-dev --name aks-gopal-dev

# Check PostgreSQL status
az postgres flexible-server show --resource-group rg-gopal-dev --name gopalpgdev
```

### View Kubernetes Resources
```bash
# Get credentials
az aks get-credentials --resource-group rg-gopal-dev --name aks-gopal-dev

# Check all pods
kubectl get pods -n gopal-app

# Check services
kubectl get svc -n gopal-app

# Check ingress
kubectl get ingress -n gopal-app

# View logs
kubectl logs -f -n gopal-app -l app=backend-a
```

### Common Operations
```bash
# Restart service
kubectl rollout restart deployment/backend-a -n gopal-app

# Scale service
kubectl scale deployment backend-a --replicas=3 -n gopal-app

# Update image
kubectl set image deployment/backend-a backend-a=gopaldevacr.azurecr.io/backend-a:new-tag -n gopal-app
```

## Destroy Infrastructure

**⚠️ WARNING: This will delete all resources!**

```bash
# Destroy dev environment
cd envs/dev
terraform destroy -auto-approve

# Destroy qa environment
cd ../qa
terraform destroy -auto-approve

# Destroy prod environment
cd ../prod
terraform destroy -auto-approve
```

## Related Documentation

- **Backend Services**: See [capstone-Backend](https://github.com/gopall-tech/capstone-Backend)
- **Frontend App**: See [capstone-Frontend](https://github.com/gopall-tech/capstone-Frontend)
- **Project Overview**: See PROJECT_SUMMARY.md (in project root)

## Support

- **Infrastructure issues**: Check this repository's issues
- **Deployment failures**: Check GitHub Actions workflow logs
- **K8s issues**: Use kubectl commands to debug pods/services
- **Database issues**: Check PostgreSQL firewall rules and connection strings

## Architecture Diagram

```
                    ┌──────────────────────┐
                    │   GitHub (3 repos)   │
                    │  - Backend           │
                    │  - Frontend          │
                    │  - Terraform (this)  │
                    └──────────┬───────────┘
                               │
                               │ GitHub Actions CI/CD
                               ▼
        ┌──────────────────────────────────────────────┐
        │          Azure Subscription                   │
        │  ┌────────────────────────────────────────┐  │
        │  │  Dev Environment (rg-gopal-dev)        │  │
        │  │                                         │  │
        │  │  ┌──────────┐  ┌──────────┐            │  │
        │  │  │   ACR    │  │   AKS    │            │  │
        │  │  │ Images:  │  │  ┌────┐  │            │  │
        │  │  │ -frontend│  │  │Pods│  │            │  │
        │  │  │ -back-a  │  │  │ F  │  │            │  │
        │  │  │ -back-b  │  │  │ A  │  │            │  │
        │  │  └──────────┘  │  │ B  │  │            │  │
        │  │                │  └────┘  │            │  │
        │  │                └─────┬────┘            │  │
        │  │                      │                  │  │
        │  │                      ▼                  │  │
        │  │                ┌──────────┐             │  │
        │  │                │   APIM   │◄────────────┼──┼─ ONLY Gateway to Backends
        │  │                │ Gateway  │             │  │  (rate limiting, auth, policies)
        │  │                └────┬─────┘             │  │
        │  │                     │                   │  │
        │  │            ┌────────┴────────┐          │  │
        │  │            ▼                 ▼          │  │
        │  │       ┌─────────┐      ┌─────────┐     │  │
        │  │       │Backend-A│      │Backend-B│     │  │
        │  │       │ (AKS)   │      │ (AKS)   │     │  │
        │  │       └────┬────┘      └────┬────┘     │  │
        │  │            │                 │          │  │
        │  │            └────────┬────────┘          │  │
        │  │                     ▼                   │  │
        │  │                ┌──────────┐             │  │
        │  │                │PostgreSQL│             │  │
        │  │                └──────────┘             │  │
        │  └────────────────────────────────────────┘  │
        │                                               │
        │  [QA and Prod environments have same setup]  │
        └───────────────────────────────────────────────┘
```

**Request Flow:**
```
Internet Traffic → APIM Gateway → Backend Services (in AKS) → PostgreSQL
```

**Key Point**: APIM is the ONLY entry point to backend services, providing centralized API management, security, rate limiting, and monitoring.
