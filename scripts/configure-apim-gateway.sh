#!/bin/bash
#==============================================================================
# Configure APIM as the ONLY Gateway to Backend Services
#==============================================================================
# This script configures Azure API Management to route all traffic to the
# backend services. APIM becomes the single entry point for all API calls.
#
# Usage: ./configure-apim-gateway.sh <environment>
# Example: ./configure-apim-gateway.sh dev
#
# Prerequisites:
# - Azure CLI installed and logged in
# - LoadBalancer services created for backend-a-lb, backend-b-lb, frontend-lb
#==============================================================================

set -e

ENV=${1:-dev}

# Environment-specific configuration
case $ENV in
    dev)
        RG="rg-gopal-dev"
        APIM="apim-gopal-dev"
        BACKEND_A_IP="20.53.27.57"
        BACKEND_B_IP="20.28.69.86"
        FRONTEND_IP="20.28.62.62"
        ;;
    qa)
        RG="rg-gopal-qa"
        APIM="apim-gopal-qa"
        BACKEND_A_IP="20.53.27.223"
        BACKEND_B_IP="20.248.113.232"
        FRONTEND_IP="20.248.125.65"
        ;;
    prod)
        RG="rg-gopal-prod"
        APIM="apim-gopal-prod"
        BACKEND_A_IP="20.28.53.29"
        BACKEND_B_IP="20.28.53.78"
        FRONTEND_IP="20.28.52.196"
        ;;
    *)
        echo "Usage: $0 <dev|qa|prod>"
        exit 1
        ;;
esac

echo "=========================================="
echo "Configuring APIM Gateway for $ENV"
echo "=========================================="
echo "Resource Group: $RG"
echo "APIM Instance: $APIM"
echo "Backend-A IP: $BACKEND_A_IP"
echo "Backend-B IP: $BACKEND_B_IP"
echo "Frontend IP: $FRONTEND_IP"
echo ""

# Delete existing APIs (clean slate)
echo "Cleaning up existing APIs..."
az apim api delete --resource-group $RG --service-name $APIM --api-id backend-api --yes 2>/dev/null || true
az apim api delete --resource-group $RG --service-name $APIM --api-id backend-a-api --yes 2>/dev/null || true
az apim api delete --resource-group $RG --service-name $APIM --api-id backend-b-api --yes 2>/dev/null || true
az apim api delete --resource-group $RG --service-name $APIM --api-id frontend-api --yes 2>/dev/null || true

echo ""
echo "Creating Backend-A API..."
az apim api create \
    --resource-group $RG \
    --service-name $APIM \
    --api-id backend-a-api \
    --path "api/a" \
    --display-name "Backend A API" \
    --service-url "http://$BACKEND_A_IP" \
    --protocols http https \
    --subscription-required false

# Add wildcard operation for Backend-A
az apim api operation create \
    --resource-group $RG \
    --service-name $APIM \
    --api-id backend-a-api \
    --operation-id "backend-a-all" \
    --display-name "All Backend A Operations" \
    --method "*" \
    --url-template "/*"

echo ""
echo "Creating Backend-B API..."
az apim api create \
    --resource-group $RG \
    --service-name $APIM \
    --api-id backend-b-api \
    --path "api/b" \
    --display-name "Backend B API" \
    --service-url "http://$BACKEND_B_IP" \
    --protocols http https \
    --subscription-required false

# Add wildcard operation for Backend-B
az apim api operation create \
    --resource-group $RG \
    --service-name $APIM \
    --api-id backend-b-api \
    --operation-id "backend-b-all" \
    --display-name "All Backend B Operations" \
    --method "*" \
    --url-template "/*"

echo ""
echo "Creating Frontend API..."
az apim api create \
    --resource-group $RG \
    --service-name $APIM \
    --api-id frontend-api \
    --path "" \
    --display-name "Frontend" \
    --service-url "http://$FRONTEND_IP" \
    --protocols http https \
    --subscription-required false

# Add wildcard operation for Frontend
az apim api operation create \
    --resource-group $RG \
    --service-name $APIM \
    --api-id frontend-api \
    --operation-id "frontend-all" \
    --display-name "All Frontend Routes" \
    --method "*" \
    --url-template "/*"

echo ""
echo "=========================================="
echo "APIM Gateway Configuration Complete!"
echo "=========================================="
echo ""
echo "Access your application at:"
echo "  APIM Gateway: https://$APIM.azure-api.net"
echo "  Frontend: https://$APIM.azure-api.net/"
echo "  Backend-A: https://$APIM.azure-api.net/api/a"
echo "  Backend-B: https://$APIM.azure-api.net/api/b"
echo ""
