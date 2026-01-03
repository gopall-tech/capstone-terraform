# Terraform Infrastructure Deployment Guide

## Prerequisites

1. Azure CLI installed and logged in (`az login`)
2. Terraform 1.7.5+ installed
3. Azure subscription with Contributor access

## Step 1: Bootstrap Terraform State Storage

This creates the Azure Storage Account for storing Terraform state files.

```bash
cd bootstrap
terraform init
terraform plan
terraform apply
```

**Expected Output:**
- Resource Group: `rg-gopal-tfstate`
- Storage Account: `stgopaltfstate`
- Container: `tfstate-gopal`

**Save these outputs** - you'll need them for the environment deployments.

## Step 2: Deploy Development Environment

```bash
cd ../envs/dev
terraform init
terraform plan -var="postgres_admin_password=YourSecurePassword123!"
terraform apply -var="postgres_admin_password=YourSecurePassword123!"
```

**Expected Resources Created:**
- Resource Group: `rg-gopal-dev`
- AKS Cluster: `aks-gopal-dev` (2 nodes, Standard_DS2_v2)
- Container Registry: `gopaldevacr`
- PostgreSQL Server: `gopalpgdev`
- App Service: `app-gopal-ui-dev`
- API Management: `apim-gopal-dev`

**Deployment Time:** ~30-40 minutes (APIM takes the longest)

## Step 3: Deploy QA Environment

```bash
cd ../qa
terraform init
terraform plan -var="postgres_admin_password=YourSecurePassword123!"
terraform apply -var="postgres_admin_password=YourSecurePassword123!"
```

## Step 4: Deploy Production Environment

```bash
cd ../prod
terraform init
terraform plan -var="postgres_admin_password=YourSecurePassword123!"
terraform apply -var="postgres_admin_password=YourSecurePassword123!"
```

**Production uses optimized resources:**
- 1 node instead of 2
- Smaller VM size (Standard_B2s)

## Post-Deployment Steps

### Get Resource Information

```bash
# Get AKS credentials
az aks get-credentials --resource-group rg-gopal-dev --name aks-gopal-dev

# Get ACR login server
az acr list --resource-group rg-gopal-dev --query "[].loginServer" -o table

# Get PostgreSQL FQDN
az postgres flexible-server show --resource-group rg-gopal-dev --name gopalpgdev --query "fullyQualifiedDomainName" -o tsv

# Get App Service URL
az webapp show --resource-group rg-gopal-dev --name app-gopal-ui-dev --query "defaultHostName" -o tsv
```

### Initialize PostgreSQL Database

Connect to each PostgreSQL server and run the init script from the backend repository.

```bash
# Download psql client if not installed
# For Windows: https://www.postgresql.org/download/windows/

# Connect to dev database
psql "host=gopalpgdev.postgres.database.azure.com port=5432 dbname=gopalappdev user=gopalpgadmindev sslmode=require"

# When connected, run:
\i /path/to/capstone-Backend/db/init.sql
```

Repeat for QA (`gopalpgqa`) and Prod (`gopalpgprod`).

## Troubleshooting

### Issue: "Backend initialization required"

**Solution:** Make sure bootstrap was run first and note the storage account name.

### Issue: "Insufficient quota"

**Solution:** Request quota increase in Azure Portal or use smaller VM sizes.

### Issue: "Name already in use"

**Solution:** Some Azure resources require globally unique names (ACR, App Service). Edit `modules/environment/main.tf` to add a unique suffix.

## Cleanup

To destroy all resources (be careful!):

```bash
cd envs/dev
terraform destroy -var="postgres_admin_password=YourSecurePassword123!"

cd ../qa
terraform destroy -var="postgres_admin_password=YourSecurePassword123!"

cd ../prod
terraform destroy -var="postgres_admin_password=YourSecurePassword123!"

# Finally, destroy bootstrap (optional)
cd ../../bootstrap
terraform destroy
```
