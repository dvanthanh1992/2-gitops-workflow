#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

apply_k8s_cert_manager() {
    echo "🔄 Creating AWS Route 53 Secret & Applying Certificate..."
    envsubst < $SCRIPT_DIR/aws-route53-secret.yaml | kubectl apply -f -
    echo "✅ Applied AWS Route 53 ClusterIssuer"

    echo "🔄 Applying Certificate..."
    envsubst < $SCRIPT_DIR/create-certificate.yaml | kubectl apply -f -
    echo "✅ Applied Certificate"
}

apply_k8s_cert_manager
