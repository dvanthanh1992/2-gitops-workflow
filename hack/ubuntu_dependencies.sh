#!/bin/bash

set -e

TERRAFORM_VERSION="1.11.2"
PACKER_VERSION="1.11.2"
VAULT_VERSION="1.19.0"
HELMFILE_VERSION="0.171.0"
UBUNTU_VERSION=$(lsb_release -cs)

echo "🔹 Updating package list..."a
sudo apt-get update -y

echo "🔹 Installing required packages..."
sudo apt-get install -y curl wget unzip tar python3 python3-pip python3-apt \
    apt-transport-https ca-certificates software-properties-common git gh \
    direnv sshpass vim rsync openssh-client jq yq xorriso apache2-utils

echo "🔹 Adding Docker repository..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu $UBUNTU_VERSION stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-compose-plugin

# Install Terraform
echo "🔹 Installing Terraform $TERRAFORM_VERSION..."
curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" -o "/tmp/terraform.zip"
sudo unzip -o "/tmp/terraform.zip" -d /usr/local/bin/
rm "/tmp/terraform.zip"

# Install Packer
echo "🔹 Installing Packer $PACKER_VERSION..."
curl -fsSL "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip" -o "/tmp/packer.zip"
sudo unzip -o "/tmp/packer.zip" -d /usr/local/bin/
rm "/tmp/packer.zip"

# Install Vault
echo "🔹 Installing Vault $VAULT_VERSION..."
curl -fsSL "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip" -o "/tmp/vault.zip"
sudo unzip -o "/tmp/vault.zip" -d /usr/local/bin/
rm "/tmp/vault.zip"

# Install AWS CLI
echo "🔹 Installing AWS CLI..."
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -o "/tmp/awscliv2.zip" -d /tmp
sudo /tmp/aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
rm -rf /tmp/awscliv2.zip /tmp/aws

# Install kubectl
echo "🔹 Installing kubectl..."
KUBECTL_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt) && \
    curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    -o /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl

# Install Helm
echo "🔹 Installing Helm..."
curl "https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3" | bash

# Install Helmfile
echo "🔹 Installing Helmfile $HELMFILE_VERSION..."
curl -fsSL "https://github.com/helmfile/helmfile/releases/download/v0.171.0/helmfile_0.171.0_linux_amd64.tar.gz" \
    -o /tmp/helmfile.tar.gz && \
    tar -xzf /tmp/helmfile.tar.gz -C /tmp && \
    mv /tmp/helmfile /usr/local/bin/ && chmod +x /usr/local/bin/helmfile
helm plugin install https://github.com/databus23/helm-diff

# Install ArgoCD CLI
echo "🔹 Installing ArgoCD CLI..."
curl -fsSL "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64" \
    -o /usr/local/bin/argocd && chmod +x /usr/local/bin/argocd

# Install Tekton CLI
apt update;sudo apt install -y gnupg
mkdir -p /etc/apt/keyrings/
gpg --no-default-keyring --keyring /etc/apt/keyrings/tektoncd.gpg --keyserver keyserver.ubuntu.com --recv-keys 3EFE0E0A2F2F60AA
"deb [signed-by=/etc/apt/keyrings/tektoncd.gpg] http://ppa.launchpad.net/tektoncd/cli/ubuntu eoan main"|sudo tee /etc/apt/sources.list.d/tektoncd-ubuntu-cli.list
apt update && sudo apt install -y tektoncd-cli

echo "✅ All dependencies installed successfully!"
