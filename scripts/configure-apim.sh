#!/bin/bash

# APIM Configuration Script
# This script configures Azure API Management with backend APIs

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== APIM Configuration Script ===${NC}"

# Check if environment parameter is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Environment parameter required${NC}"
    echo "Usage: $0 <environment>"
    echo "Example: $0 dev"
    exit 1
fi

ENV=$1

# Set environment-specific variables
case $ENV in
    dev)
        APIM_NAME="apim-gopal-dev"
        RESOURCE_GROUP="rg-gopal-dev"
        BACKEND_URL="http://20.28.60.126"
        ;;
    qa)
        APIM_NAME="apim-gopal-qa"
        RESOURCE_GROUP="rg-gopal-qa"
        # Get QA ingress IP
        az aks get-credentials --resource-group rg-gopal-qa --name aks-gopal-qa --overwrite-existing > /dev/null 2>&1
        BACKEND_URL="http://$(kubectl get ingress gopal-ingress -n gopal-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
        ;;
    prod)
        APIM_NAME="apim-gopal-prod"
        RESOURCE_GROUP="rg-gopal-prod"
        # Get Prod ingress IP
        az aks get-credentials --resource-group rg-gopal-prod --name aks-gopal-prod --overwrite-existing > /dev/null 2>&1
        BACKEND_URL="http://$(kubectl get ingress gopal-ingress -n gopal-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
        ;;
    *)
        echo -e "${RED}Invalid environment: $ENV${NC}"
        echo "Valid values: dev, qa, prod"
        exit 1
        ;;
esac

echo -e "${YELLOW}Environment: $ENV${NC}"
echo -e "${YELLOW}APIM Name: $APIM_NAME${NC}"
echo -e "${YELLOW}Resource Group: $RESOURCE_GROUP${NC}"
echo -e "${YELLOW}Backend URL: $BACKEND_URL${NC}"

# Create Backend A API
echo -e "\n${GREEN}Creating Backend A API...${NC}"
az apim api create \
    --resource-group $RESOURCE_GROUP \
    --service-name $APIM_NAME \
    --api-id backend-a-api \
    --path "/api/a" \
    --display-name "Backend A API" \
    --protocols https http \
    --service-url "${BACKEND_URL}/api/a" \
    --subscription-required false \
    || echo -e "${YELLOW}Backend A API may already exist${NC}"

# Create Backend B API
echo -e "\n${GREEN}Creating Backend B API...${NC}"
az apim api create \
    --resource-group $RESOURCE_GROUP \
    --service-name $APIM_NAME \
    --api-id backend-b-api \
    --path "/api/b" \
    --display-name "Backend B API" \
    --protocols https http \
    --service-url "${BACKEND_URL}/api/b" \
    --subscription-required false \
    || echo -e "${YELLOW}Backend B API may already exist${NC}"

# Add operations to Backend A API
echo -e "\n${GREEN}Adding operations to Backend A API...${NC}"

# Health check
az apim api operation create \
    --resource-group $RESOURCE_GROUP \
    --service-name $APIM_NAME \
    --api-id backend-a-api \
    --url-template "/health" \
    --method GET \
    --display-name "Health Check" \
    --operation-id get-health \
    || echo -e "${YELLOW}Operation may already exist${NC}"

# Get all users
az apim api operation create \
    --resource-group $RESOURCE_GROUP \
    --service-name $APIM_NAME \
    --api-id backend-a-api \
    --url-template "/users" \
    --method GET \
    --display-name "Get All Users" \
    --operation-id get-users \
    || echo -e "${YELLOW}Operation may already exist${NC}"

# Get user by ID
az apim api operation create \
    --resource-group $RESOURCE_GROUP \
    --service-name $APIM_NAME \
    --api-id backend-a-api \
    --url-template "/users/{id}" \
    --method GET \
    --display-name "Get User by ID" \
    --operation-id get-user-by-id \
    --template-parameters name=id description="User ID" type=string required=true \
    || echo -e "${YELLOW}Operation may already exist${NC}"

# Create user
az apim api operation create \
    --resource-group $RESOURCE_GROUP \
    --service-name $APIM_NAME \
    --api-id backend-a-api \
    --url-template "/users" \
    --method POST \
    --display-name "Create User" \
    --operation-id create-user \
    || echo -e "${YELLOW}Operation may already exist${NC}"

# Add operations to Backend B API
echo -e "\n${GREEN}Adding operations to Backend B API...${NC}"

# Health check
az apim api operation create \
    --resource-group $RESOURCE_GROUP \
    --service-name $APIM_NAME \
    --api-id backend-b-api \
    --url-template "/health" \
    --method GET \
    --display-name "Health Check" \
    --operation-id get-health-b \
    || echo -e "${YELLOW}Operation may already exist${NC}"

# Get all products
az apim api operation create \
    --resource-group $RESOURCE_GROUP \
    --service-name $APIM_NAME \
    --api-id backend-b-api \
    --url-template "/products" \
    --method GET \
    --display-name "Get All Products" \
    --operation-id get-products \
    || echo -e "${YELLOW}Operation may already exist${NC}"

# Get product by ID
az apim api operation create \
    --resource-group $RESOURCE_GROUP \
    --service-name $APIM_NAME \
    --api-id backend-b-api \
    --url-template "/products/{id}" \
    --method GET \
    --display-name "Get Product by ID" \
    --operation-id get-product-by-id \
    --template-parameters name=id description="Product ID" type=string required=true \
    || echo -e "${YELLOW}Operation may already exist${NC}"

# Create product
az apim api operation create \
    --resource-group $RESOURCE_GROUP \
    --service-name $APIM_NAME \
    --api-id backend-b-api \
    --url-template "/products" \
    --method POST \
    --display-name "Create Product" \
    --operation-id create-product \
    || echo -e "${YELLOW}Operation may already exist${NC}"

# Add rate limiting policy
echo -e "\n${GREEN}Adding rate limiting policy...${NC}"
cat > /tmp/apim-policy.xml <<'EOF'
<policies>
    <inbound>
        <base />
        <rate-limit calls="100" renewal-period="60" />
        <cors allow-credentials="true">
            <allowed-origins>
                <origin>*</origin>
            </allowed-origins>
            <allowed-methods>
                <method>GET</method>
                <method>POST</method>
                <method>PUT</method>
                <method>DELETE</method>
                <method>OPTIONS</method>
            </allowed-methods>
            <allowed-headers>
                <header>*</header>
            </allowed-headers>
        </cors>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
EOF

az apim api policy create \
    --resource-group $RESOURCE_GROUP \
    --service-name $APIM_NAME \
    --api-id backend-a-api \
    --xml-file /tmp/apim-policy.xml \
    || echo -e "${YELLOW}Policy may already exist${NC}"

az apim api policy create \
    --resource-group $RESOURCE_GROUP \
    --service-name $APIM_NAME \
    --api-id backend-b-api \
    --xml-file /tmp/apim-policy.xml \
    || echo -e "${YELLOW}Policy may already exist${NC}"

# Get APIM gateway URL
APIM_URL=$(az apim show --resource-group $RESOURCE_GROUP --name $APIM_NAME --query 'gatewayUrl' -o tsv)

echo -e "\n${GREEN}=== APIM Configuration Complete ===${NC}"
echo -e "${YELLOW}APIM Gateway URL: $APIM_URL${NC}"
echo -e "${YELLOW}Backend A API: ${APIM_URL}/api/a${NC}"
echo -e "${YELLOW}Backend B API: ${APIM_URL}/api/b${NC}"
echo -e "\n${GREEN}Test endpoints:${NC}"
echo -e "  curl ${APIM_URL}/api/a/health"
echo -e "  curl ${APIM_URL}/api/b/health"
