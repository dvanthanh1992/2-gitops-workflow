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
    echo "🔧 Step 2: Creating Harbor project '$K8S_PROJECT_NAME'..."
    HARBOR_API_URL="https://$HARBOR_DNS/api/v2.0"

    if curl -s -u admin:$HARBOR_ADMIN_PASSWORD "$HARBOR_DNS/projects" | grep '"project_id"'; then
        echo "✅ Project '$K8S_PROJECT_NAME' already exists."
    else
        curl -X POST -u admin:"$HARBOR_ADMIN_PASSWORD" "$HARBOR_API_URL/projects" \
            -H "Content-Type: application/json" \
            -d '{
                "project_name": "'$K8S_PROJECT_NAME'",
                "metadata": {
                    "public": "true"
                }
            }'
 
        if [ $? -eq 0 ]; then
            echo "✅ Project '$K8S_PROJECT_NAME' created successfully!"
        else
            echo "❌ Failed to create project '$K8S_PROJECT_NAME'." >&2
            exit 1
        fi
    fi
}

docker_login
create_harbor_project
