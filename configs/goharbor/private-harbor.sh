#!/bin/bash

set -euo pipefail

docker_login() {
    echo "🔧 Step 1: Logging into Harbor registry..."
    if ! docker login "$HARBOR_DNS" -u admin -p "$HARBOR_ADMIN_PASSWORD"; then
        echo "❌ Docker login failed." >&2
        exit 1
    fi
    echo "✅ Docker login successful!"
    echo "--------------------------------------------------------------------------"
}

create_harbor_project() {
    echo "🔧 Step 2: Checking if project '$K8S_PROJECT_NAME' exists..."
    HARBOR_API_URL="https://$HARBOR_DNS/api/v2.0"
    
    response=$(curl -s -u admin:"$HARBOR_ADMIN_PASSWORD" "$HARBOR_API_URL/projects?name=$K8S_PROJECT_NAME")

    if echo "$response" | grep -q '"project_id"'; then
        echo "✅ Project '$K8S_PROJECT_NAME' already exists. Skipping creation."
    else
        echo "🔧 Project '$K8S_PROJECT_NAME' does not exist. Creating now..."
        create_response=$(curl -s -o /dev/null -w "%{http_code}" -X POST -u admin:"$HARBOR_ADMIN_PASSWORD" "$HARBOR_API_URL/projects" \
            -H "Content-Type: application/json" \
            -d '{
                "project_name": "'$K8S_PROJECT_NAME'",
                "metadata": {
                    "public": "true",
                    "severity": "high",
                    "auto_scan": "true",
                    "prevent_vul": "true",
                    "reuse_sys_cve_allowlist": "true"
                }
            }')

        if [ "$create_response" -eq 201 ]; then
            echo "✅ Project '$K8S_PROJECT_NAME' created successfully!"
        else
            echo "❌ Failed to create project '$K8S_PROJECT_NAME'. HTTP Response: $create_response" >&2
            exit 1
        fi
    fi
}

docker_login
create_harbor_project
