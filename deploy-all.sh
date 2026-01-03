#!/bin/bash

# Automated deployment script for all environments
# Usage: ./deploy-all.sh

set -e

echo "================================================"
echo "Gopal's Capstone - Infrastructure Deployment"
echo "================================================"

# Check prerequisites
command -v az >/dev/null 2>&1 || { echo "Azure CLI not installed. Aborting."; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "Terraform not installed. Aborting."; exit 1; }

# Check Azure login
az account show >/dev/null 2>&1 || { echo "Not logged into Azure. Run 'az login' first."; exit 1; }

# Get password
read -sp "Enter PostgreSQL admin password (will be used for all environments): " DB_PASSWORD
echo

if [ -z "$DB_PASSWORD" ]; then
    echo "Password cannot be empty. Aborting."
    exit 1
fi

# Step 1: Bootstrap
echo ""
echo "Step 1/4: Bootstrapping Terraform state storage..."
cd bootstrap
terraform init
terraform apply -auto-approve
cd ..

# Step 2: Deploy Dev
echo ""
echo "Step 2/4: Deploying Dev environment..."
cd envs/dev
terraform init
terraform apply -auto-approve -var="postgres_admin_password=$DB_PASSWORD"
cd ../..

# Step 3: Deploy QA
echo ""
echo "Step 3/4: Deploying QA environment..."
cd envs/qa
terraform init
terraform apply -auto-approve -var="postgres_admin_password=$DB_PASSWORD"
cd ../..

# Step 4: Deploy Prod
echo ""
echo "Step 4/4: Deploying Prod environment..."
cd envs/prod
terraform init
terraform apply -auto-approve -var="postgres_admin_password=$DB_PASSWORD"
cd ../..

echo ""
echo "================================================"
echo "Deployment Complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "1. Initialize PostgreSQL databases (see DEPLOYMENT.md)"
echo "2. Configure Azure DevOps pipelines"
echo "3. Deploy backend and frontend services"
echo ""
