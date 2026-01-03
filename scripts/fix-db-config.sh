#!/bin/bash

# Fix PostgreSQL configuration in all environments

set -e

ENV=${1:-all}

fix_environment() {
    local env=$1

    case $env in
        dev)
            DB_HOST="gopalpgdev.postgres.database.azure.com"
            DB_USER="gopalpgadmindev"
            DB_NAME="gopalappdev"
            RG="rg-gopal-dev"
            AKS="aks-gopal-dev"
            ;;
        qa)
            DB_HOST="gopalpgqa.postgres.database.azure.com"
            DB_USER="gopalpgadminqa"
            DB_NAME="gopalappqa"
            RG="rg-gopal-qa"
            AKS="aks-gopal-qa"
            ;;
        prod)
            DB_HOST="gopalpgprod.postgres.database.azure.com"
            DB_USER="gopalpgadminprod"
            DB_NAME="gopalappprod"
            RG="rg-gopal-prod"
            AKS="aks-gopal-prod"
            ;;
    esac

    echo "Fixing $env environment..."
    echo "  DB_HOST: $DB_HOST"
    echo "  DB_USER: $DB_USER"
    echo "  DB_NAME: $DB_NAME"

    # Get AKS credentials
    az aks get-credentials --resource-group $RG --name $AKS --overwrite-existing > /dev/null 2>&1

    # Update backend-a
    kubectl patch deployment backend-a -n gopal-app --type='json' \
        -p="[{\"op\": \"replace\", \"path\": \"/spec/template/spec/containers/0/env/2/value\", \"value\": \"$DB_HOST\"},
             {\"op\": \"replace\", \"path\": \"/spec/template/spec/containers/0/env/4/value\", \"value\": \"$DB_NAME\"},
             {\"op\": \"replace\", \"path\": \"/spec/template/spec/containers/0/env/5/value\", \"value\": \"$DB_USER\"}]"

    # Update backend-b
    kubectl patch deployment backend-b -n gopal-app --type='json' \
        -p="[{\"op\": \"replace\", \"path\": \"/spec/template/spec/containers/0/env/2/value\", \"value\": \"$DB_HOST\"},
             {\"op\": \"replace\", \"path\": \"/spec/template/spec/containers/0/env/4/value\", \"value\": \"$DB_NAME\"},
             {\"op\": \"replace\", \"path\": \"/spec/template/spec/containers/0/env/5/value\", \"value\": \"$DB_USER\"}]"

    echo "Waiting for rollouts..."
    kubectl rollout status deployment/backend-a -n gopal-app --timeout=120s
    kubectl rollout status deployment/backend-b -n gopal-app --timeout=120s

    echo "$env environment fixed!"
}

if [ "$ENV" == "all" ]; then
    fix_environment dev
    fix_environment qa
    fix_environment prod
else
    fix_environment $ENV
fi

echo "Database configuration fixed successfully!"
