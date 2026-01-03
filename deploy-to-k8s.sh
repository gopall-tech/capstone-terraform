#!/bin/bash

# Deploy to Kubernetes for a specific environment
# Usage: ./deploy-to-k8s.sh <env> (dev|qa|prod)

set -e

ENV=$1

if [ -z "$ENV" ]; then
  echo "Usage: $0 <env>"
  echo "  env: dev, qa, or prod"
  exit 1
fi

# Environment-specific variables
case $ENV in
  dev)
    CONTEXT="aks-gopal-dev"
    ACR_LOGIN_SERVER="gopaldevacr.azurecr.io"
    POSTGRES_FQDN="gopalpgdev.postgres.database.azure.com"
    POSTGRES_ADMIN_LOGIN="gopalpgadmindev"
    ;;
  qa)
    CONTEXT="aks-gopal-qa"
    ACR_LOGIN_SERVER="gopalqaacr.azurecr.io"
    POSTGRES_FQDN="gopalpgqa.postgres.database.azure.com"
    POSTGRES_ADMIN_LOGIN="gopalpgadminqa"
    ;;
  prod)
    CONTEXT="aks-gopal-prod"
    ACR_LOGIN_SERVER="gopalprodacr.azurecr.io"
    POSTGRES_FQDN="gopalpgprod.postgres.database.azure.com"
    POSTGRES_ADMIN_LOGIN="gopalpgadminprod"
    ;;
  *)
    echo "Invalid environment: $ENV"
    exit 1
    ;;
esac

echo "Deploying to $ENV environment..."
echo "Context: $CONTEXT"
echo "ACR: $ACR_LOGIN_SERVER"

# Switch to the correct Kubernetes context
kubectl config use-context $CONTEXT

# Create namespace if it doesn't exist
kubectl create namespace gopal-app --dry-run=client -o yaml | kubectl apply -f -

# Create PostgreSQL secret
echo "Creating PostgreSQL secret..."
kubectl create secret generic postgres-secret \
  --from-literal=password='P@ssw0rd123!' \
  --namespace=gopal-app \
  --dry-run=client -o yaml | kubectl apply -f -

# Deploy backend-a
echo "Deploying backend-a..."
cat k8s/backend-a-deployment.yaml | \
  sed "s|\${ACR_LOGIN_SERVER}|${ACR_LOGIN_SERVER}|g" | \
  sed "s|\${ENV}|${ENV}|g" | \
  sed "s|\${POSTGRES_FQDN}|${POSTGRES_FQDN}|g" | \
  sed "s|\${POSTGRES_ADMIN_LOGIN}|${POSTGRES_ADMIN_LOGIN}|g" | \
  kubectl apply -f -

# Deploy backend-b
echo "Deploying backend-b..."
cat k8s/backend-b-deployment.yaml | \
  sed "s|\${ACR_LOGIN_SERVER}|${ACR_LOGIN_SERVER}|g" | \
  sed "s|\${ENV}|${ENV}|g" | \
  sed "s|\${POSTGRES_FQDN}|${POSTGRES_FQDN}|g" | \
  sed "s|\${POSTGRES_ADMIN_LOGIN}|${POSTGRES_ADMIN_LOGIN}|g" | \
  kubectl apply -f -

# Install NGINX Ingress Controller if not present
echo "Checking for NGINX Ingress Controller..."
if ! kubectl get namespace ingress-nginx >/dev/null 2>&1; then
  echo "Installing NGINX Ingress Controller..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
  echo "Waiting for NGINX Ingress Controller to be ready..."
  kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=120s
else
  echo "NGINX Ingress Controller already installed"
fi

# Deploy Ingress
echo "Deploying Ingress..."
kubectl apply -f k8s/ingress.yaml

# Wait for deployments to be ready
echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s \
  deployment/backend-a deployment/backend-b \
  --namespace=gopal-app

# Get the status
echo ""
echo "Deployment complete!"
echo ""
echo "Pods:"
kubectl get pods -n gopal-app
echo ""
echo "Services:"
kubectl get svc -n gopal-app
echo ""
echo "Ingress:"
kubectl get ingress -n gopal-app
echo ""
echo "External IP (LoadBalancer):"
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
echo ""
