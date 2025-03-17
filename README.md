# Kubernetes Native CI/CD Pipeline Repository

This repository provides a full-stack automation solution for deploying and managing a native Kubernetes CI/CD pipeline triggered by GitHub webhooks. The system leverages industry-standard tools such as Hashicorp Terraform & Vault, Helm/Helmfile, Tekton, ArgoCD, Kargo and Harbor to streamline the process from code commit to production deployment.

---

## Repository Structure

- **bootstrap/**
  - **k8s-initial/**
    - **helmfile.yaml**: Main Helmfile to deploy critical Kubernetes services.
    - **cert-manager.helmfile.yaml**: Helmfile for installing and configuring cert-manager.
    - **hook/**: Contains shell scripts for initialization tasks.
      - **aws-dns-check.sh**: Validates AWS DNS settings.
      - **cert-manager.sh**: Bootstraps cert-manager.
      - **vault-init.sh**: Initializes HashiCorp Vault.
    - **values/**: Contains Go templated YAML files for configuring various components.
      - **argocd.yaml.gotmpl**: Template for ArgoCD configuration.
      - **harbor.yaml.gotmpl**: Template for Harbor registry settings.
      - **hashicorp-vault.yaml.gotmpl**: Template for Vault configurations.
      - **kargo.yaml.gotmpl**: Template for Kargo project settings.
  - **start.sh**: Script to initiate the bootstrap process.
  - **terraform-vcenter/**
    - **main.tf**, **terraform.auto.tfvars**, **variables.tf**: Terraform configuration files for provisioning the infrastructure.
    - **files/**
      - **microk8s.sh**: Script to set up a microk8s cluster.

- **configs/**
  - **argocd/**
    - **appproject-demo.yaml**: Demo configuration for an ArgoCD application project.
    - **appset-demo.yaml**: Demo configuration for an ArgoCD application set.
  - **goharbor/**
    - **private-harbor.sh**: Script to set up a private Harbor registry.
  - **kargo/**
    - Contains demo configurations for project setups and promotion/stage deployments.
      - **project-demo.yaml**
      - **promotiontask-backend.yaml**
      - **promotiontask-frontend.yaml**
      - **stage-backend.yaml**
      - **stage-frontend.yaml**
  - **tekton/**
    - **pipeline/**
      - **dev-ci-pipeline.yaml**: Defines the CI pipeline for development.
    - **task/**
      - **git-clone.yaml**: Task for cloning the repository.
      - **extract-version.yaml**: Task for extracting version information.
      - **kaniko.yaml**: Task for building container images with Kaniko.
      - **pylint.yaml**: Task for running code linting.
      - **prepare-telegram-message.yaml**: Task to prepare notifications.
      - **send-to-telegram.yaml**: Task to send Telegram messages.
    - **tekton-external-secret.yaml**: Manages external secrets for Tekton.
    - **triggers/**
      - **triggers-github-listener.yaml**: Listens for GitHub webhook events.
      - **triggers-service-account.yaml**: Configures service account for triggers.
      - **triggers-template-application.yaml**: Defines the template for triggered applications.

- **Dockerfile**
  - Provides the Docker configuration for containerizing this automation solution.

- **hack/**
  - **ubuntu_dependencies.sh**: Script to install necessary dependencies on Ubuntu systems.

- **system/**
  - Contains system-level Kubernetes manifests.
  - **cert-manager/**
    - **aws-route53-secret.yaml**: Sets up AWS Route53 secrets.
    - **create-certificate.yaml**: Certificate creation manifest.
  - **hashicorp-vault/**
    - **vault-secret-store.yaml**: Configuration for Vault secret storage.
  - **tekton/**
    - **tekton-dashboard.yaml**: Deploys the Tekton dashboard.
    - **tekton-interceptors.yaml**: Manifests for Tekton interceptors.
    - **tekton-pipelines.yaml**: Core Tekton pipeline components.
    - **tekton-triggers.yaml**: Manifests for Tekton triggers.

---

## Pipeline Overview

This solution implements a CI/CD pipeline with the following high-level workflow:

1. **GitHub Webhook Trigger**  
   GitHub sends a webhook event (e.g., on code commits or pull requests) to the system, triggering the pipeline.

2. **Tekton Trigger Listener**  
   Tekton triggers (defined in `configs/tekton/triggers/`) capture the webhook event and start the pipeline execution.

3. **Pipeline Execution via Tekton**  
   The Tekton pipeline (`configs/tekton/pipeline/dev-ci-pipeline.yaml`) executes a series of tasks:
   - **Git Clone**: Clones the repository to fetch the latest code.
   - **Extract Version**: Retrieves version information from the source code.
   - **Image Build**: Uses Kaniko (via `kaniko.yaml`) to build container images.
   - **Push to Harbor Private**: Pushes the built container images to the private Harbor registry.
   - **Notification**: Prepares and sends notifications (using tasks like `prepare-telegram-message.yaml` and `send-to-telegram.yaml`).
   - **ArgoCD + Kargo**: Take over the continuous deployment (CD) process. They manage deployments across multiple Kubernetes clusters and environments, supporting matrix deployments and multi-environment promotions.
---