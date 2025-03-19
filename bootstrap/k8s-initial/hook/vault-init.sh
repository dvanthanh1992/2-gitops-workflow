#!/bin/bash

set -euo pipefail

echo "📌 Current directory: $(pwd)"

wait_for_vault() {
    echo "$VAULT_ADDR"
    echo "⏳ Waiting for Vault to respond..."

    while true; do
        status_output="$(vault status 2>&1 || true)"
        if echo "$status_output" | grep -q "Version"; then
            echo "✅ Vault is up and responding!"
            break
        else
            echo "🔄 Vault is not responding yet. Retrying in 10 seconds..."
            sleep 10
        fi
    done
}

vault_init() {
    echo "🔄 Checking Vault status..."
    if [[ "$(vault status | grep 'Initialized' | awk '{print $2}')" == "true" ]]; then
        echo "✅ Vault is already initialized. Skipping initialization."
        if [[ -f ../../$VAULT_TOKEN_FILE ]]; then
            export VAULT_UNSEAL_KEY=$(grep "Unseal Key 1:" ../../$VAULT_TOKEN_FILE | awk '{print $4}')
            export VAULT_ROOT_TOKEN=$(grep "Initial Root Token:" ../../$VAULT_TOKEN_FILE | awk '{print $4}')
        else
            echo "⚠️ Token file not found. Attempting to use existing VAULT_ROOT_TOKEN environment variable."
            if [[ -z "${VAULT_ROOT_TOKEN:-}" ]]; then
                echo "❌ VAULT_ROOT_TOKEN is not set. Exiting."
                exit 1
            fi
        fi
        export VAULT_UNSEAL_KEY_BASE_64=$(echo -n "$VAULT_UNSEAL_KEY" | base64)
        export VAULT_ROOT_TOKEN_BASE_64=$(echo -n "$VAULT_ROOT_TOKEN" | base64)
    else
        echo "🔑 Initializing Vault..."
        vault operator init -key-shares=1 -key-threshold=1 | tee ../../$VAULT_TOKEN_FILE
        
        export VAULT_UNSEAL_KEY=$(grep "Unseal Key 1:" ../../$VAULT_TOKEN_FILE | awk '{print $4}')
        export VAULT_ROOT_TOKEN=$(grep "Initial Root Token:" ../../$VAULT_TOKEN_FILE | awk '{print $4}')
        
        export VAULT_UNSEAL_KEY_BASE_64=$(echo -n "$VAULT_UNSEAL_KEY" | base64)
        export VAULT_ROOT_TOKEN_BASE_64=$(echo -n "$VAULT_ROOT_TOKEN" | base64)

        echo "🔓 Unsealing Vault..."
        vault operator unseal "$VAULT_UNSEAL_KEY"
        echo "🔐 Logging in to Vault..."
        vault login "$VAULT_ROOT_TOKEN"
    fi
}

put_to_vault() {
    if [[ -f ../../$VAULT_TOKEN_FILE ]]; then
        echo "🔍 Found $VAULT_TOKEN_FILE file. Extracting root token..."
    else
        echo "⚠️ $VAULT_TOKEN_FILE file not found. Using existing VAULT_ROOT_TOKEN variable."
    fi
    vault login "$VAULT_ROOT_TOKEN"
    if vault secrets list | grep -q "^$VAULT_KV/"; then
        echo "✅ Vault KV path '$VAULT_KV' already exists. Skipping creation."
    else
        echo "⚠️ Vault KV path '$VAULT_KV' does not exist. Creating..."
        vault secrets enable -path="$VAULT_KV" kv-v2
    fi

    echo "📄 Reading variables from test.env..."
    local_env_vars=$(awk -F= '!/^#/ && NF {printf "%s=%s ", $1, $2}' ../../test.env)

    echo "🔧 Generating raw Docker config JSON..."
    HARBOR_CONFIG_JSON=$(cat <<EOF
{
  "auths": {
    "$HARBOR_DNS": {
      "username": "admin",
      "password": "$HARBOR_ADMIN_PASSWORD",
      "auth": "$(echo -n "admin:$HARBOR_ADMIN_PASSWORD" | base64)"
    }
  }
}
EOF
)
    echo "⬆️ Storing environment variables and raw Harbor config in Vault..."
    vault kv put "$VAULT_KV/$VAULT_KV_PATH" $local_env_vars \
        HARBOR_CONFIG_JSON="$HARBOR_CONFIG_JSON" \
        VAULT_ROOT_TOKEN_BASE_64="$VAULT_ROOT_TOKEN_BASE_64" \
        VAULT_UNSEAL_KEY_BASE_64="$VAULT_UNSEAL_KEY_BASE_64"

    echo "✅ Environment variables and raw Harbor config have been saved to Vault at '$VAULT_KV/$VAULT_KV_PATH'."
}

apply_k8s_hashicorp-vault() {
    echo "🔄 Applying K8s Vault Secret..."
    envsubst < ../../system/hashicorp-vault/vault-secret-store.yaml | kubectl apply -f -
    echo "✅ Applying K8s Vault Secret..."
}

wait_for_vault
vault_init
put_to_vault
apply_k8s_hashicorp-vault
