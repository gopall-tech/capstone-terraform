#!/bin/bash
#==============================================================================
# Restore Dev Environment Script
#==============================================================================
# This script restores the complete dev environment including:
# - AKS cluster connection
# - Monitoring stack (Prometheus, Grafana, Loki)
# - ArgoCD for GitOps
# - Application deployments
#
# Prerequisites:
# - Azure CLI logged in (az login)
# - kubectl installed
# - helm installed
# - Terraform state exists in Azure Storage
#==============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
RESOURCE_GROUP="rg-gopal-dev"
AKS_CLUSTER="aks-gopal-dev"
ACR_NAME="gopaldevacr"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-P@ssw0rd123!}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Gopal Dev Environment Restore Script ${NC}"
echo -e "${GREEN}========================================${NC}"

#------------------------------------------------------------------------------
# Step 1: Verify Azure Login
#------------------------------------------------------------------------------
echo -e "\n${YELLOW}[1/8] Verifying Azure login...${NC}"
if ! az account show > /dev/null 2>&1; then
    echo -e "${RED}Not logged in to Azure. Running az login...${NC}"
    az login
fi
echo -e "${GREEN}Azure login verified.${NC}"

#------------------------------------------------------------------------------
# Step 2: Apply Terraform (if infrastructure destroyed)
#------------------------------------------------------------------------------
echo -e "\n${YELLOW}[2/8] Checking infrastructure...${NC}"
if ! az group show --name $RESOURCE_GROUP > /dev/null 2>&1; then
    echo -e "${YELLOW}Resource group not found. Running Terraform apply...${NC}"
    cd "$(dirname "$0")/../envs/dev"
    terraform init
    terraform apply -auto-approve
    cd -
else
    echo -e "${GREEN}Infrastructure exists.${NC}"
fi

#------------------------------------------------------------------------------
# Step 3: Connect to AKS
#------------------------------------------------------------------------------
echo -e "\n${YELLOW}[3/8] Connecting to AKS cluster...${NC}"
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER --overwrite-existing
echo -e "${GREEN}Connected to AKS.${NC}"

#------------------------------------------------------------------------------
# Step 4: Login to ACR
#------------------------------------------------------------------------------
echo -e "\n${YELLOW}[4/8] Logging into Azure Container Registry...${NC}"
az acr login --name $ACR_NAME
echo -e "${GREEN}ACR login successful.${NC}"

#------------------------------------------------------------------------------
# Step 5: Create namespaces and secrets
#------------------------------------------------------------------------------
echo -e "\n${YELLOW}[5/8] Setting up namespaces and secrets...${NC}"

# Create namespaces
kubectl create namespace gopal-app --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Create postgres secret
kubectl create secret generic postgres-secret \
    --namespace gopal-app \
    --from-literal=password="$POSTGRES_PASSWORD" \
    --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}Namespaces and secrets configured.${NC}"

#------------------------------------------------------------------------------
# Step 6: Install Monitoring Stack
#------------------------------------------------------------------------------
echo -e "\n${YELLOW}[6/8] Installing monitoring stack...${NC}"

# Add Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus stack
SCRIPT_DIR="$(dirname "$0")"
if ! helm status prometheus -n monitoring > /dev/null 2>&1; then
    echo "Installing Prometheus stack..."
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --values "$SCRIPT_DIR/../k8s/monitoring/prometheus-values.yaml" \
        --wait --timeout 5m
else
    echo "Prometheus already installed, upgrading..."
    helm upgrade prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --values "$SCRIPT_DIR/../k8s/monitoring/prometheus-values.yaml"
fi

# Install Loki stack
if ! helm status loki -n monitoring > /dev/null 2>&1; then
    echo "Installing Loki stack..."
    helm install loki grafana/loki-stack \
        --namespace monitoring \
        --values "$SCRIPT_DIR/../k8s/monitoring/loki-values.yaml" \
        --wait --timeout 5m
else
    echo "Loki already installed, upgrading..."
    helm upgrade loki grafana/loki-stack \
        --namespace monitoring \
        --values "$SCRIPT_DIR/../k8s/monitoring/loki-values.yaml"
fi

# Apply ServiceMonitors
kubectl apply -f "$SCRIPT_DIR/../k8s/monitoring/service-monitors.yaml"

echo -e "${GREEN}Monitoring stack installed.${NC}"

#------------------------------------------------------------------------------
# Step 7: Install ArgoCD
#------------------------------------------------------------------------------
echo -e "\n${YELLOW}[7/8] Installing ArgoCD...${NC}"

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo "Waiting for ArgoCD server to be ready..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# Patch for LoadBalancer access
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Enable insecure mode (HTTP)
kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true"}}' 2>/dev/null || \
kubectl create configmap argocd-cmd-params-cm -n argocd --from-literal=server.insecure=true

# Restart ArgoCD server to apply config
kubectl rollout restart deployment argocd-server -n argocd
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=120s

# Apply ArgoCD project and application
kubectl apply -f "$SCRIPT_DIR/../k8s/argocd/"

echo -e "${GREEN}ArgoCD installed.${NC}"

#------------------------------------------------------------------------------
# Step 8: Deploy Applications (if not using ArgoCD auto-sync)
#------------------------------------------------------------------------------
echo -e "\n${YELLOW}[8/8] Deploying applications...${NC}"

# Apply K8s manifests directly (ArgoCD will also sync these)
kubectl apply -f "$SCRIPT_DIR/../k8s/backend-a-deployment.yaml"
kubectl apply -f "$SCRIPT_DIR/../k8s/backend-b-deployment.yaml"
kubectl apply -f "$SCRIPT_DIR/../k8s/frontend-deployment.yaml"
kubectl apply -f "$SCRIPT_DIR/../k8s/services-loadbalancer.yaml"

# Wait for deployments
echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available deployment/backend-a -n gopal-app --timeout=120s
kubectl wait --for=condition=available deployment/backend-b -n gopal-app --timeout=120s
kubectl wait --for=condition=available deployment/frontend -n gopal-app --timeout=120s

echo -e "${GREEN}Applications deployed.${NC}"

#------------------------------------------------------------------------------
# Summary
#------------------------------------------------------------------------------
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Restore Complete!                    ${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${YELLOW}Service Endpoints:${NC}"

# Get external IPs
GRAFANA_IP=$(kubectl get svc prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
ARGOCD_IP=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
FRONTEND_IP=$(kubectl get svc frontend-lb -n gopal-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")

echo -e "  Grafana:  http://$GRAFANA_IP (admin / GrafanaAdmin123!)"
echo -e "  ArgoCD:   http://$ARGOCD_IP"
echo -e "  Frontend: http://$FRONTEND_IP"

# Get ArgoCD password
ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "check manually")
echo -e "  ArgoCD Password: $ARGOCD_PWD"

echo -e "\n${YELLOW}Pods Status:${NC}"
kubectl get pods -n gopal-app
kubectl get pods -n monitoring
kubectl get pods -n argocd

echo -e "\n${GREEN}Done! Environment restored successfully.${NC}"
