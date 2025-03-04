#!/bin/bash

set -e

K8S_VERSION="1.29"
CERT_MANAGER_CHART_VERSION="1.16.1"
ARGO_CD_CHART_VERSION="2.13.0"
ARGO_ROLLOUTS_CHART_VERSION="1.7.2"

NODE_TYPE="$1"

METALLB_MGMT_IP="192.168.145.110-192.168.145.125"
METALLB_RS_IP="192.168.145.126-192.168.145.140"

echo "📌 Installing MicroK8s version: $K8S_VERSION"
echo "-----------------------------------"
apt-get update -y
apt-get install -y snapd

echo "-----------------------------------"
snap install microk8s --classic --channel="${K8S_VERSION}"
echo "✅ Installed MicroK8s!"
echo "-----------------------------------"

echo "🔧 Configuring MicroK8s..."
echo "-----------------------------------"

if [[ "$NODE_TYPE" =~ "mgmt"  ]]; then
    METALLB_RANGE="$METALLB_MGMT_IP"
    echo "🚀 Detected Management Node: Using MetalLB range $METALLB_RANGE"
else
    METALLB_RANGE="$METALLB_RS_IP"
    echo "🛠 Detected Resources Node: Using MetalLB range $METALLB_RANGE"
fi

microk8s enable rbac ingress hostpath-storage metallb:"$METALLB_RANGE"

echo "🎉 MicroK8s setup completed!"
echo "-----------------------------------"
