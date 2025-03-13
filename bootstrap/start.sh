#!/bin/bash

set -euo pipefail

load_env() {
    if [ -f "../../local.env" ]; then
        while IFS= read -r line; do
            if [[ ! "$line" =~ ^# && "$line" =~ = ]]; then
                export "$line"
            fi
        done < "../../local.env"
        echo "✅ Loaded environment variables"
        echo "✅ KUBECONFIG=$KUBECONFIG"
    else
        echo "⚠️  local.env file not found. Skipping environment loading."
    fi
}

check_aws_dns(){
    echo "🚀 Running check AWS Route 53 DNS"
    bash k8s-initial/hook/aws-dns-check.sh
}

helm_manage(){
    export AWS_ACCESS_KEY_ID_BASE_64=$(echo -n "$AWS_ACCESS_KEY_ID" | base64)
    export AWS_SECRET_ACCESS_KEY_BASE_64=$(echo -n "$AWS_SECRET_ACCESS_KEY" | base64)
    export ARGO_ADMIN_PASSWORD_HASH=$(htpasswd -nbBC 10 "" "$ARGO_ADMIN_PASSWORD" | tr -d ':\n' | sed 's/$2y/$2a/')
    export KARGO_ADMIN_PASSWORD_HASH=$(htpasswd -nbBC 10 "" "$KARGO_ADMIN_PASSWORD" | tr -d ':\n' | sed 's/$2y/$2a/')
    export KARGO_ADMIN_TOKEN_SIGNING_KEY=$(openssl rand -base64 29 | tr -d "=+/")

    echo "🚀 Running helmfile $1"
    helmfile "$1" -f k8s-initial/helmfile.yaml
}

# Check if at least one argument is provided
if [ "$#" -eq 0 ]; then
    echo "❌ No argument provided. Use 'apply', 'sync', or 'delete'."
    exit 1
fi

# Validate argument value
if [ "$1" != "apply" ] && [ "$1" != "sync" ] && [ "$1" != "delete" ]; then
    echo "❌ Invalid argument. Use 'apply', 'sync', or 'delete'."
    exit 1
fi

load_env
check_aws_dns
helm_manage "$1"
