#!/bin/bash

set -euo pipefail

docker_login() {
    echo "🔧 Step 3: Logging into Harbor registry..."
    if ! docker login "$HARBOR_IP" -u admin -p "$HARBOR_ADMIN_PASSWORD"; then
        echo "❌ Docker login failed." >&2
        exit 1
    fi
    echo "✅ Docker login successful!"
    echo "--------------------------------------------------------------------------"
}

create_harbor_project() {
    echo "🔧 Step 4: Creating Harbor project '$HARBOR_PROJECT'..."
    HARBOR_API="https://$HARBOR_IP/api/v2.0"

    if curl -s -u admin:"$HARBOR_ADMIN_PASSWORD" "$HARBOR_API/projects" | jq -e ".[] | select(.name==\"$HARBOR_PROJECT\")" > /dev/null; then
        echo "✅ Project '$HARBOR_PROJECT' already exists."
    else
        curl -X POST -u admin:"$HARBOR_ADMIN_PASSWORD" "$HARBOR_API/projects" \
            -H "Content-Type: application/json" \
            -d "{\"project_name\": \"$HARBOR_PROJECT\", \"public\": true}" > /dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            echo "✅ Project '$HARBOR_PROJECT' created successfully!"
        else
            echo "❌ Failed to create project '$HARBOR_PROJECT'." >&2
            exit 1
        fi
    fi
}

docker_login
create_harbor_project

# echo "🎉 Harbor setup is complete! You can now push images to $HARBOR_IP/$HARBOR_PROJECT"
# echo "--------------------------------------------------------------------------"

# NAMESPACE="/kargo/"
# IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "$NAMESPACE")

# if [ -z "$IMAGES" ]; then
#     echo "❌ No images found for namespace $NAMESPACE."
#     exit 1
# fi

# echo "✅ Found images to push:"
# echo "$IMAGES"
# echo "--------------------------------------------------------------------------"
# echo "$IMAGES" | while read -r IMAGE; do
#     IMAGE_NAME=$(echo "$IMAGE" | sed -E "s|^.*/kargo/||")
#     FULL_IMAGE="$HARBOR_IP/kargo/$IMAGE_NAME"

#     echo "🚀 Pushing image: $FULL_IMAGE"
    
#     docker tag "$IMAGE" "$FULL_IMAGE"
#     docker push "$FULL_IMAGE"
    
#     if [ $? -eq 0 ]; then
#         echo "✅ Successfully pushed: $FULL_IMAGE"
#     else
#         echo "❌ Failed to push: $FULL_IMAGE"
#     fi
#     echo "--------------------------------------------------------------------------"
# done

# echo "🎉 Harbor setup is complete! You can now push images to $HARBOR_IP/$HARBOR_PROJECT"
# echo "--------------------------------------------------------------------------"