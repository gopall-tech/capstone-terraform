#!/bin/bash

# Simplified APIM Configuration Script

set -e

ENV=${1:-dev}

case $ENV in
    dev)
        APIM_NAME="apim-gopal-dev"
        RESOURCE_GROUP="rg-gopal-dev"
        BACKEND_URL="http://20.28.60.126"
        ;;
    qa)
        APIM_NAME="apim-gopal-qa"
        RESOURCE_GROUP="rg-gopal-qa"
        az aks get-credentials --resource-group rg-gopal-qa --name aks-gopal-qa --overwrite-existing > /dev/null 2>&1
        BACKEND_URL="http://$(kubectl get ingress gopal-ingress -n gopal-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
        ;;
    prod)
        APIM_NAME="apim-gopal-prod"
        RESOURCE_GROUP="rg-gopal-prod"
        az aks get-credentials --resource-group rg-gopal-prod --name aks-gopal-prod --overwrite-existing > /dev/null 2>&1
        BACKEND_URL="http://$(kubectl get ingress gopal-ingress -n gopal-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
        ;;
esac

echo "Configuring APIM for $ENV environment"
echo "APIM: $APIM_NAME"
echo "Backend URL: $BACKEND_URL"

# Create Backend A API
echo "Creating Backend A API..."
az apim api create \
    --resource-group $RESOURCE_GROUP \
    --service-name $APIM_NAME \
    --api-id backend-a \
    --path "backend-a" \
    --display-name "Backend A Service" \
    --protocols https http \
    --service-url "${BACKEND_URL}/api/a" \
    --subscription-required false 2>/dev/null || echo "Backend A API already exists"

# Create Backend B API
echo "Creating Backend B API..."
az apim api create \
    --resource-group $RESOURCE_GROUP \
    --service-name $APIM_NAME \
    --api-id backend-b \
    --path "backend-b" \
    --display-name "Backend B Service" \
    --protocols https http \
    --service-url "${BACKEND_URL}/api/b" \
    --subscription-required false 2>/dev/null || echo "Backend B API already exists"

# Add wildcard operations
echo "Adding operations..."
az apim api operation create \
    --resource-group $RESOURCE_GROUP \
    --service-name $APIM_NAME \
    --api-id backend-a \
    --url-template "/*" \
    --method "*" \
    --display-name "All operations" \
    --operation-id all-ops-a 2>/dev/null || echo "Operations already exist"

az apim api operation create \
    --resource-group $RESOURCE_GROUP \
    --service-name $APIM_NAME \
    --api-id backend-b \
    --url-template "/*" \
    --method "*" \
    --display-name "All operations" \
    --operation-id all-ops-b 2>/dev/null || echo "Operations already exist"

# Get APIM URL
APIM_URL=$(az apim show --resource-group $RESOURCE_GROUP --name $APIM_NAME --query 'gatewayUrl' -o tsv)

echo ""
echo "=== APIM Configuration Complete ==="
echo "Gateway URL: $APIM_URL"
echo ""
echo "Test URLs:"
echo "  Backend A Health: ${APIM_URL}/backend-a/health"
echo "  Backend B Health: ${APIM_URL}/backend-b/health"
echo ""
echo "Direct AKS URLs:"
echo "  Backend A: ${BACKEND_URL}/api/a/health"
echo "  Backend B: ${BACKEND_URL}/api/b/health"
