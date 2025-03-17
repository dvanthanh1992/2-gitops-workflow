#!/bin/bash

# Load environment variables from local.env file
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

# Wait for ArgoCD pods to be ready, login to ArgoCD and add clusters
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

# Execute the goharbor shell script for applying the harbor module
apply_goharbor() {
    echo "🔹 Executing goharbor module..."
    bash goharbor/private-harbor.sh
}

# Execute the goharbor shell script in delete mode for removing the harbor module
delete_goharbor() {
    echo "🔹 Deleting goharbor module..."
    bash goharbor/private-harbor.sh delete
}

# Apply all YAML files in the given module (directory) recursively
apply_module() {
    local module_path=$1
    echo "🔹 Applying module: ${module_path}"
    find "$module_path" -type f -name "*.yaml" | while read -r file; do
        echo "Applying ${file}..."
        envsubst < "${file}" | kubectl apply -f -
    done
}

# Delete all YAML files in the given module (directory) recursively
delete_module() {
    local module_path=$1
    echo "🔹 Deleting module: ${module_path}"
    find "$module_path" -type f -name "*.yaml" | while read -r file; do
        echo "Deleting ${file}..."
        envsubst < "${file}" | kubectl delete -f -
    done
}

# Apply modules in the order: goharbor -> tekton -> argocd -> kargo
apply_all() {
    echo "-----------------------------------------------"
    echo "🔹 Installing Demo Application Project..."

    apply_goharbor
    sleep 5
    apply_module "tekton"
    sleep 5
    apply_module "argocd"
    sleep 5
    apply_module "kargo"

    echo "✅ Installation completed!"
    echo "-----------------------------------------------"
}

# Delete modules in the reverse order: kargo -> argocd -> tekton -> goharbor
delete_all() {
    echo "🗑️  Deleting Demo Applications Project..."
    echo "-----------------------------------------------"

    delete_module "kargo"
    delete_module "argocd"
    delete_module "tekton"

    echo "🔹 Deleting all ArgoCD Applications related to ${K8S_PROJECT_NAME}..."
    kubectl delete applicationset  --all -n argocd --force --grace-period=0
    kubectl delete applications    --all -n argocd --force --grace-period=0
    kubectl delete appprojects     --all -n argocd --force --grace-period=0

    echo "✅ Deletion completed!"
    echo "-----------------------------------------------"
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
