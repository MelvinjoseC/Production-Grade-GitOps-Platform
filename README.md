# Production-Grade GitOps Platform on AWS EKS

[![Terraform](https://img.shields.io/badge/IaC-Terraform-blueviolet?style=for-the-badge&logo=terraform)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-EKS-blue?style=for-the-badge&logo=kubernetes)](https://aws.amazon.com/eks/)
[![GitOps](https://img.shields.io/badge/GitOps-ArgoCD-orange?style=for-the-badge&logo=argo)](https://argoproj.github.io/cd/)
[![Helm](https://img.shields.io/badge/Packaging-Helm-navy?style=for-the-badge&logo=helm)](https://helm.sh/)
[![Monitoring](https://img.shields.io/badge/Observability-Prometheus--Loki--Grafana-red?style=for-the-badge&logo=grafana)](https://grafana.com/)

This repository implements a production-grade, enterprise-ready **GitOps Infrastructure and Observability Platform**. It provides a fully automated workflow to provision cloud resources on AWS and deploy a Kubernetes monitoring and logging stack using declarative GitOps patterns.

---

## 🏗️ Architecture Overview

The platform uses a layered architecture separating core cloud infrastructure (managed by **Terraform**) from Kubernetes applications and configurations (managed by **ArgoCD**).

```mermaid
graph TD
    subgraph AWS Cloud
        subgraph VPC
            subgraph Public Subnets
                IGW[Internet Gateway]
                NAT[NAT Gateway]
                ALB[AWS Load Balancer / NLB]
            end
            subgraph Private Subnets
                subgraph EKS Cluster
                    direction TB
                    CP[Control Plane]
                    SG[System Node Group]
                    WG[Workload Node Group]
                end
            end
        end
        S3[S3 Bucket - Loki Log Store]
        KMS[KMS Key - Secret Encryption]
    end

    Git[Git Repository] -->|Polls Changes| ArgoCD[ArgoCD Controller]
    ArgoCD -->|App-of-Apps Sync| App1[Ingress NGINX]
    ArgoCD -->|App-of-Apps Sync| App2[Prometheus Operator]
    ArgoCD -->|App-of-Apps Sync| App3[Loki Stack]
    
    ALB -->|Routes Ingress| App1
    App3 -->|IAM IRSA Role| S3
    CP -->|Envelope Encryption| KMS
```

### Core Features
* **IaC Foundations**: Highly available VPC spanning 3 Availability Zones, NAT Gateways, and private subnets hosting EKS nodes.
* **EKS Hardening**: Envelope encryption of K8s Secrets using **AWS KMS**, metadata service protection via **IMDSv2**, secure session access via **AWS SSM**, and isolated private worker subnets.
* **Identity Integration (IRSA)**: Integrates AWS IAM with Kubernetes Service Accounts via OIDC, eliminating long-lived credentials for the EBS CSI Driver, Loki S3 access, and Cluster Autoscaler.
* **GitOps App-of-Apps Pattern**: Uses a root ArgoCD application to manage lifecycle operations (pruning, self-healing, and syncing) for cluster-wide workloads.
* **Observability (PLG Stack)**: Automated deployment of Prometheus (metrics), Loki (centralized logs aggregated in S3 with systemd journal scraping), and Grafana dashboards.
* **Progressive Delivery & Auto-scaling**: Built-in Horizontal Pod Autoscaler (HPA) via Metrics Server, node auto-scaling via Cluster Autoscaler, and Canary/Blue-Green progressive deployments via Argo Rollouts.
* **Cost Controls**: Built-in AWS Budgets with custom alerts to track EKS platform expenditures and avoid billing surprises.

---

## 📁 Repository Structure

```
.
├── .github/workflows/                 # CI/CD Workflows
│   └── lint.yml                       # GitHub Actions workflow for Terraform/Helm validation
├── terraform/                         # Terraform Infrastructure Code
│   ├── providers.tf                   # Version constraints, provider configs, & EKS auth
│   ├── variables.tf                   # Configurable input variables with safety validations
│   ├── outputs.tf                     # Exported cluster/network outputs
│   ├── vpc.tf                         # VPC, subnets, gateways, and routing
│   ├── eks.tf                         # EKS Cluster, Node Groups (enforcing IMDSv2), KMS, OIDC
│   ├── irsa.tf                        # IAM Roles for Service Accounts (EBS, Loki, & Autoscaler)
│   ├── budgets.tf                     # AWS Budgets for cost control
│   └── terraform.tfvars.example       # Example tfvars configuration template
└── gitops/                            # ArgoCD GitOps Configurations
    ├── bootstrap/                     # Initial bootstrapping resources
    │   ├── argocd-install-values.yaml # Helm configuration overrides for ArgoCD HA
    │   └── root-application.yaml      # ArgoCD App-of-Apps root declaration
    └── infrastructure/                # Platform infrastructure apps
        ├── Chart.yaml                 # Umbrella Helm chart
        ├── values.yaml                # Global config values (domains, roles, buckets)
        └── templates/                 # ArgoCD Application declarations
            ├── ingress-nginx.yaml     # NGINX Ingress Controller App (HA-hardened)
            ├── kube-prometheus.yaml   # Prometheus Operator & Grafana App (Dashboard Provider)
            ├── loki-stack.yaml        # Loki & Promtail Logging App (Journal Scraping)
            ├── cert-manager.yaml      # Cert-Manager Certificate controller
            ├── cluster-issuer.yaml    # Let's Encrypt CA ClusterIssuer
            ├── external-dns.yaml      # External-DNS integration
            ├── metrics-server.yaml    # Metrics Server for resource utilization (HPA)
            ├── cluster-autoscaler.yaml # Cluster Autoscaler for AWS scaling
            └── argo-rollouts.yaml     # Argo Rollouts engine for Progressive Delivery
```

---

## 🚀 Step-by-Step Deployment Guide

### Prerequisites
Before you begin, ensure you have the following installed and configured locally:
- [AWS CLI](https://aws.amazon.com/cli/) (authenticated with Admin credentials)
- [Terraform](https://developer.hashicorp.com/terraform/downloads) (>= 1.5.0)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)

### Step 1: Provision Infrastructure with Terraform
Navigate to the terraform directory, initialize providers, and apply configs:
```bash
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
```
*This step takes ~15 minutes. It outputs the cluster name, S3 bucket names, and IAM Roles needed in the next steps.*

### Step 2: Configure Local Kubectl
Connect your local terminal to the newly provisioned EKS cluster:
```bash
aws eks update-kubeconfig --region us-west-2 --name gitops-eks-prod
```
Verify the cluster nodes are healthy:
```bash
kubectl get nodes
```

### Step 3: Install & Configure ArgoCD
Add the ArgoCD Helm repository, configure values, and install it to the cluster:
```bash
# Add repo
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD via Helm
kubectl create namespace argocd
helm install argocd argo/argo-cd \
  --namespace argocd \
  -f ../gitops/bootstrap/argocd-install-values.yaml
```

### Step 4: Bootstrap the GitOps Pipeline
1. Create a Git repository and push this codebase to your GitHub/GitLab account.
2. Open [gitops/bootstrap/root-application.yaml](gitops/bootstrap/root-application.yaml) and update the `repoURL` to point to your new repo.
3. Open [gitops/infrastructure/values.yaml](gitops/infrastructure/values.yaml) and update the `global.repoURL`, `lokiStack.aws.s3Bucket`, and `lokiStack.aws.roleArn` using the outputs generated by Terraform in **Step 1**.
4. Commit and push these modifications to your repository.
5. Deploy the root application to EKS:
```bash
kubectl apply -f ../gitops/bootstrap/root-application.yaml
```

*ArgoCD will immediately scan the Git repository, discover the child apps (Ingress NGINX, Prometheus/Grafana, Loki), and deploy them in the correct dependency order.*

---

## 📊 Verification & Observability

### Accessing the ArgoCD Dashboard
Retrieve the auto-generated admin password and port-forward to the server service:
```bash
# Get the admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode; echo

# Port-forward to local
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
Visit `https://localhost:8080` in your browser and log in with username `admin` and the password retrieved above.

### Exposing and Accessing Grafana
Port-forward to the Grafana service to access dashboard metrics and logs:
```bash
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
```
1. Open `http://localhost:3000` in your web browser. (Credentials: User: `admin` / Password: `admin` - as configured in Helm values).
2. Go to **Explore** in the side menu.
3. Choose **Loki** from the datasource dropdown to query aggregated log streams shipped by Promtail.
4. Go to **Dashboards** to view pre-built dashboards for Kubernetes node capacity, pod memory utilization, and network traffic.

---

## 🔒 Enterprise Production Hardening Guidelines
To transition this structure to an enterprise-wide setting, consider implementing:
* **State Management**: Migrate Terraform's local state file to an S3 backend configured with DynamoDB table state locking.
* **Private EKS Networking**: Disable EKS public endpoint access (`endpoint_public_access = false`) and access the control plane via AWS Client VPN or Transit Gateway.
* **SSO Authentication**: Configure Dex inside ArgoCD to integrate with Okta, Active Directory, or GitHub teams for Role-Based Access Control (RBAC).
* **Automated DNS & Certificates**: Install `external-dns` to automatically create Route53 records and `cert-manager` to provision Let's Encrypt certificates automatically for ingress resources.
