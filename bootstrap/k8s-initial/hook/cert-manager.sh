#!/bin/bash

set -euo pipefail

apply_k8s_cert_manager() {
    
    echo "🔄 Creating AWS Route 53 Secret & Applying Certificate..."
    envsubst < ../../system/cert-manager/aws-route53-secret.yaml | kubectl apply -f -
    echo "✅ Applied AWS Route 53 ClusterIssuer"

    echo "🔄 Applying Certificate..."
    envsubst < ../../system/cert-manager/create-certificate.yaml | kubectl apply -f -
    echo "✅ Applied Certificate"
}

apply_k8s_cert_manager
