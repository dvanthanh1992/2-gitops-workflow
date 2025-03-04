#!/bin/bash

HARBOR_URL="..."
PROJECT="..."
USERNAME="..."
PASSWORD="..."
REPOSITORIES=("backend-app" "frontend-app")

get_image_tags() {
    local REPO_NAME=$1
    curl -s -u "$USERNAME:$PASSWORD" -X GET "$HARBOR_URL/api/v2.0/projects/$PROJECT/repositories/$REPO_NAME/artifacts" -H "Accept: application/json" | jq -r '.[].tags[].name'
}

for REPO in "${REPOSITORIES[@]}"; do
    echo "🔍 Fetching tags for repository: $REPO"
    TAGS=$(get_image_tags "$REPO")

    if [ -z "$TAGS" ]; then
        echo "⚠️ No tags found for $REPO, skipping..."
        continue
    fi

    for TAG in $TAGS; do
        FULL_IMAGE="$HARBOR_URL/$PROJECT/$REPO:$TAG"
        echo "🚀 Pulling image: $FULL_IMAGE"

        microk8s ctr images pull --plain-http "$FULL_IMAGE"

        if [ $? -eq 0 ]; then
            echo "✅ Successfully pulled: $FULL_IMAGE"
        else
            echo "❌ Failed to pull: $FULL_IMAGE"
        fi

        echo "----------------------------------------------"
    done
done

echo "🎉 All images pulled successfully!"
