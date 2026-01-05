#!/bin/bash
#==============================================================================
# Shutdown Environment Script - Supports dev, qa, prod
#==============================================================================
# Usage: ./shutdown-env.sh <environment>
#        ./shutdown-env.sh all
# Example: ./shutdown-env.sh dev
#          ./shutdown-env.sh all
#
# This script shuts down K8s workloads but preserves infrastructure:
# - Deletes ArgoCD applications
# - Removes monitoring stack
# - Deletes application deployments
# - Keeps AKS, ACR, PostgreSQL running (cost remains similar)
#
# To fully destroy infrastructure, use: terraform destroy
#==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Validate environment argument
ENV="${1:-}"
if [[ ! "$ENV" =~ ^(dev|qa|prod|all)$ ]]; then
    echo -e "${RED}Usage: $0 <environment>${NC}"
    echo -e "  Environments: dev, qa, prod, all"
    echo -e "  Example: $0 dev"
    echo -e "           $0 all"
    exit 1
fi

shutdown_environment() {
    local env=$1

    case $env in
        dev)
            RESOURCE_GROUP="rg-gopal-dev"
            AKS_CLUSTER="aks-gopal-dev"
            ;;
        qa)
            RESOURCE_GROUP="rg-gopal-qa"
            AKS_CLUSTER="aks-gopal-qa"
            ;;
        prod)
            RESOURCE_GROUP="rg-gopal-prod"
            AKS_CLUSTER="aks-gopal-prod"
            ;;
    esac

    echo -e "\n${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  Shutting down ${env^^} environment    ${NC}"
    echo -e "${YELLOW}========================================${NC}"

    # Check if resource group exists
    if ! az group show --name $RESOURCE_GROUP > /dev/null 2>&1; then
        echo -e "${YELLOW}Resource group $RESOURCE_GROUP not found. Skipping.${NC}"
        return 0
    fi

    # Connect to AKS
    echo -e "\n${YELLOW}Connecting to AKS...${NC}"
    az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER --overwrite-existing 2>/dev/null || {
        echo -e "${YELLOW}Could not connect to AKS. Cluster may not exist.${NC}"
        return 0
    }

    # Delete ArgoCD application
    echo -e "\n${YELLOW}Deleting ArgoCD application...${NC}"
    kubectl delete application gopal-app -n argocd --ignore-not-found 2>/dev/null || true

    # Uninstall Helm releases
    echo -e "\n${YELLOW}Removing monitoring stack...${NC}"
    helm uninstall loki -n monitoring 2>/dev/null || echo "Loki not installed"
    helm uninstall prometheus -n monitoring 2>/dev/null || echo "Prometheus not installed"

    # Delete ArgoCD
    echo -e "\n${YELLOW}Removing ArgoCD...${NC}"
    kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --ignore-not-found 2>/dev/null || true

    # Delete namespaces (this removes all resources in them)
    echo -e "\n${YELLOW}Deleting namespaces...${NC}"
    kubectl delete namespace gopal-app --ignore-not-found --wait=false 2>/dev/null || true
    kubectl delete namespace monitoring --ignore-not-found --wait=false 2>/dev/null || true
    kubectl delete namespace argocd --ignore-not-found --wait=false 2>/dev/null || true

    echo -e "${GREEN}${env^^} workloads shut down.${NC}"
}

# Main execution
echo -e "${RED}========================================${NC}"
echo -e "${RED}  SHUTDOWN SCRIPT                      ${NC}"
echo -e "${RED}========================================${NC}"
echo -e "${YELLOW}This will remove all K8s workloads.${NC}"
echo -e "${YELLOW}Infrastructure (AKS, ACR, DB) will remain.${NC}"
echo ""

# Verify Azure login
if ! az account show > /dev/null 2>&1; then
    echo -e "${RED}Not logged in to Azure. Running az login...${NC}"
    az login
fi

if [ "$ENV" == "all" ]; then
    echo -e "${RED}Shutting down ALL environments: dev, qa, prod${NC}"
    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Aborted."
        exit 0
    fi

    for e in dev qa prod; do
        shutdown_environment $e
    done
else
    shutdown_environment $ENV
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Shutdown Complete!                   ${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n${YELLOW}To restore, run:${NC}"
echo -e "  ./scripts/restore-env.sh $ENV"
echo -e "\n${YELLOW}To fully destroy infrastructure:${NC}"
echo -e "  cd envs/$ENV && terraform destroy"
