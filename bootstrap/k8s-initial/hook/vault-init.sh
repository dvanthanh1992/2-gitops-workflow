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
    else
        echo "🔑 Initializing Vault..."
        vault operator init -key-shares=1 -key-threshold=1 | tee ../../../$VAULT_TOKEN_FILE
        
        export UNSEAL_KEY=$(grep "Unseal Key 1:" ../../../$VAULT_TOKEN_FILE | awk '{print $4}')
        export VAULT_ROOT_TOKEN=$(grep "Initial Root Token:" ../../../$VAULT_TOKEN_FILE | awk '{print $4}')
        export VAULT_ROOT_TOKEN_BASE_64=$(echo -n "$VAULT_ROOT_TOKEN" | base64)

        echo "🔓 Unsealing Vault..."
        vault operator unseal "$UNSEAL_KEY"
        echo "🔐 Logging in to Vault..."
        vault login "$VAULT_ROOT_TOKEN"
    fi
}

put_to_vault() {
    if [[ -f ../../../$VAULT_TOKEN_FILE ]]; then
        echo "🔍 Found $VAULT_TOKEN_FILE file. Extracting root token..."
        export VAULT_ROOT_TOKEN=$(grep "Initial Root Token:" ../../../$VAULT_TOKEN_FILE | awk '{print $4}')
        export VAULT_ROOT_TOKEN_BASE_64=$(echo -n "$VAULT_ROOT_TOKEN" | base64)
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

    vault kv put "$VAULT_KV/$VAULT_KV_PATH" \
        $(awk -F= '!/^#/ && NF {printf "%s=%s ", $1, $2}' ../../../local.env)

    echo "✅ Environment variables have been saved to Vault at '$VAULT_KV/$VAULT_KV_PATH'."
}

wait_for_vault
vault_init
put_to_vault
