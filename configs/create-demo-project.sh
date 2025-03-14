#!/bin/bash

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

argocd_add_cluster() {
    echo "⏳ Waiting for all pods in argocd namespace to be ready..."
    kubectl wait --for=condition=Ready --all pods -n argocd --timeout=300s
    argocd login "$ARGO_DNS" --insecure --skip-test-tls \
        --grpc-web --username admin --password "$ARGO_ADMIN_PASSWORD"

    for kubeConfigFile in /root/0-kargo/kube-config/*; do
        export KUBECONFIG="$kubeConfigFile"
        currentContext=$(kubectl config current-context)
        echo "Adding cluster with context: $currentContext from file: $kubeConfigFile"
        argocd cluster add "$currentContext" -y --name "$(basename "$kubeConfigFile")"
    done
}

apply_all() {
    echo "-----------------------------------------------"
    echo "🔹 Installing ArgoCD Application Project..."

    for file in argocd/*.yaml; do
        echo "Applying ${file}..."
        envsubst < "${file}" | kubectl apply -f -
    done

    echo "✅ Installation completed!"
    echo "-----------------------------------------------"
}

delete_all() {
    echo "🗑️  Deleting ArgoCD Applications..."
    echo "-----------------------------------------------"

    for file in argocd/*.yaml; do
        echo "Deleting ${file}..."
        envsubst < "${file}" | kubectl delete -f -
    done

    echo "✅ Deletion completed!"
    echo "-----------------------------------------------"
}

usage() {
    echo "Usage: $0 {apply|delete}"
    exit 1
}

main() {
    if [ "$#" -ne 1 ]; then
        usage
    fi

    ACTION=$1
    load_env

    case "$ACTION" in
        apply)
            argocd_add_cluster
            load_env
            apply_all
            ;;
        delete)
            delete_all
            ;;
        *)
            echo "❌ Invalid action: $ACTION"
            usage
            ;;
    esac
}

main "$@"
