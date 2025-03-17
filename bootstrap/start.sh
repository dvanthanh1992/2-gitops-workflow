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

tekton_manage(){
    if [ "$1" = "sync" ]; then
        echo "🚀 Running kubectl apply for Tekton resources"
        kubectl apply -f ../system/tekton/tekton-pipelines.yaml
        kubectl apply -f ../system/tekton/tekton-dashboard.yaml
        kubectl apply -f ../system/tekton/tekton-triggers.yaml
        kubectl apply -f ../system/tekton/tekton-interceptors.yaml
    else
        echo "🚀 Running kubectl delete for Tekton resources"
        kubectl delete -f ../system/tekton/tekton-interceptors.yaml
        kubectl delete -f ../system/tekton/tekton-triggers.yaml
        kubectl delete -f ../system/tekton/tekton-pipelines.yaml
    fi
}

usage() {
    echo "Usage: $0 {sync|delete}"
    exit 1
}

main() {
    if [ "$#" -ne 1 ]; then
        usage
    fi

    ACTION=$1
    load_env

    case "$ACTION" in
        sync)
            check_aws_dns
            helm_manage "$1"
            tekton_manage "$1"
            ;;
        delete)
            tekton_manage "$1"
            helm_manage "$1"
            ;;
        *)
            echo "❌ Invalid action: $ACTION"
            usage
            ;;
    esac
}

main "$@"
