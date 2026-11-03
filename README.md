# Production-Grade GitOps Platform on AWS EKS

[![Terraform](https://img.shields.io/badge/IaC-Terraform-blueviolet?style=for-the-badge&logo=terraform)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-EKS_1.30-blue?style=for-the-badge&logo=kubernetes)](https://aws.amazon.com/eks/)
[![GitOps](https://img.shields.io/badge/GitOps-ArgoCD-orange?style=for-the-badge&logo=argo)](https://argoproj.github.io/cd/)
[![Helm](https://img.shields.io/badge/Packaging-Helm-navy?style=for-the-badge&logo=helm)](https://helm.sh/)
[![Observability](https://img.shields.io/badge/Observability-Prometheus--Loki--Grafana-red?style=for-the-badge&logo=grafana)](https://grafana.com/)
[![Security](https://img.shields.io/badge/Security-Trivy_|_Checkov_|_Gitleaks_|_ESO-brightgreen?style=for-the-badge&logo=shield)](https://github.com/aquasecurity/trivy)

This repository implements an enterprise-ready, production-grade **GitOps Infrastructure and Observability Platform on AWS EKS**. It adheres to zero-trust security standards, multi-tenant ArgoCD project governance, envelope encryption, automated secrets synchronization, progressive delivery canary rollouts, and comprehensive DevSecOps validation.

---

## 🏗️ Architecture Overview

The platform cleanly decouples core cloud infrastructure (managed by **Terraform**) from Kubernetes runtime applications and observability stacks (managed by **ArgoCD**).

```mermaid
graph TD
    subgraph AWS Cloud
        subgraph VPC ["AWS VPC (3 Availability Zones)"]
            subgraph PublicSubnets ["Public Subnets"]
                IGW[Internet Gateway]
                NAT[NAT Gateways]
                ALB[AWS Load Balancer / NLB]
            end
            subgraph PrivateSubnets ["Private Subnets"]
                subgraph EKS ["EKS Cluster (v1.30)"]
                    direction TB
                    CP[Control Plane - Dedicated SG & Access Entries]
                    SG[System Node Group - IMDSv2]
                    WG[Workload Node Group - IMDSv2]
                end
                VPCE[VPC Endpoints: S3, ECR, STS, Logs]
            end
        end
        S3[S3 Bucket - Loki Log Store + Lifecycle]
        KMS[KMS Key - Secret, EBS, CloudWatch & S3 Encryption]
        SM[AWS Secrets Manager]
    end

    Git[Git Repository] -->|Polls Changes| ArgoCD[ArgoCD Controller]
    ArgoCD -->|AppProject: core-infrastructure| InfraApps[Platform Services]
    ArgoCD -->|AppProject: workloads| WorkloadApps[Business Microservices]
    
    InfraApps --> ESO[External Secrets Operator]
    InfraApps --> Ingress[Ingress NGINX]
    InfraApps --> Prom[Prometheus Operator]
    InfraApps --> Loki[Loki + Promtail]
    WorkloadApps --> Rollout[Argo Rollouts Canary + PDB + HPA]

    ESO -->|IRSA AssumeRole| SM
    Loki -->|IRSA AssumeRole| S3
    CP -->|Envelope Encryption| KMS
    ALB -->|Routes Ingress| Ingress
```

### Enterprise Feature Highlights
* **Modern EKS Authentication**: Native **EKS Access Entries** (`aws_eks_access_entry`) with `API_AND_CONFIG_MAP` mode, completely deprecating fragile and error-prone `aws-auth` ConfigMap configurations.
* **Full-Stack KMS CMK Encryption**: Customer Managed KMS Key encryption enforced across EKS secrets envelope encryption, default EBS volumes, CloudWatch log groups, and S3 remote storage.
* **Storage Cost Governance & S3 Lifecycles**: Automated S3 lifecycle rules configured on remote state and Loki log stores with automatic transitioning to `STANDARD_IA` and expiration of noncurrent versions.
* **Private Networking & Cost Optimization**: AWS VPC Endpoints provisioned for S3 (Gateway), ECR API, ECR Docker registry, STS, and CloudWatch Logs to eliminate data traversal costs through NAT Gateways.
* **EKS Security Hardening**: Dedicated, least-privilege Security Groups for the control plane and worker nodes, enforced **IMDSv2**, and node session access via **AWS SSM**.
* **Zero-Trust Network Policies**: Hardened Kubernetes `NetworkPolicy` resources enforcing default-deny ingress/egress boundaries for both platform services and application workload namespaces (`apps`).
* **Pod Security Standards (PSA)**: Automated namespace admission control labels enforcing `restricted` security profiles for application workloads and `baseline` for platform services.
* **Least-Privilege External Secrets Management**: Automated synchronization from **AWS Secrets Manager** via **External Secrets Operator (ESO)** and IRSA tokens, scoped strictly to `/gitops/*` path prefixes.
* **ArgoCD Multi-Tenancy & RBAC**: Custom `AppProject` definitions separating cluster-scoped `core-infrastructure` from isolated, namespace-restricted `workloads`.
* **Resilient Progressive Delivery**: Built-in **Argo Rollouts** canary engine featuring automated Prometheus analysis templates (`AnalysisTemplate`) with scoped ingress metrics, p99 latency thresholds, PodDisruptionBudgets (`PDB`), HorizontalPodAutoscalers (`HPA`), and multi-AZ topology spread constraints.
* **Production Observability Matrix**: Prometheus Operator, custom `PrometheusRule` alerting definitions (NodeNotReady, Disk/Memory pressure, ESO failure, Rollout degradation), automated Loki log aggregation in S3, and pre-packaged Grafana dashboard ConfigMaps loaded dynamically via sidecar.
* **DevSecOps & Schema Verification**: Automated `Makefile` task runner, `.pre-commit-config.yaml` git hooks, and comprehensive DevSecOps CI matrix with **Kubeconform** (Kubernetes JSON schema validation), **Trivy**, **Checkov**, **Gitleaks**, and **yamllint**.

---

## 📁 Repository Structure

```
.
├── .editorconfig                          # Indentation and formatting standards
├── .gitignore                             # Ignored files, state caches, and secrets
├── .pre-commit-config.yaml                # Pre-commit git hooks
├── Makefile                               # Developer automation task runner
├── README.md                              # Platform documentation & guides
├── .github/workflows/
│   └── ci.yml                             # Consolidated CI (Kubeconform, Checkov, Trivy, Gitleaks, Helm, Terraform)
├── docs/runbooks/                         # Operational Runbooks & Playbooks
│   ├── argocd-troubleshooting.md          # Diagnosing OutOfSync & sync timeouts
│   ├── disaster-recovery.md               # Complete cluster reconstruction guide
│   └── secrets-management.md              # AWS Secrets Manager & ESO workflows
├── terraform/                             # Cloud Infrastructure as Code
│   ├── providers.tf                       # Provider configurations & version constraints
│   ├── variables.tf                       # Input variables with safety validation & prefix controls
│   ├── outputs.tf                         # VPC, cluster, KMS, and IRSA role outputs
│   ├── vpc.tf                             # VPC, subnets, route tables, and VPC Endpoints
│   ├── eks.tf                             # EKS cluster, Access Entries, hardened SGs, KMS policy, EBS encryption
│   ├── irsa.tf                            # IAM Roles with least-privilege scoping (EBS CSI, Loki, Autoscaler, ESO)
│   ├── state-storage.tf                   # S3 state bucket with KMS encryption, DynamoDB lock table, & lifecycle
│   ├── vpc-flow-logs.tf                   # CloudWatch VPC Flow Logs with KMS CMK encryption
│   ├── budgets.tf                         # AWS Budget cost tracking and alert thresholds
│   └── terraform.tfvars.example           # Production variable template
└── gitops/                                # ArgoCD GitOps Configurations
    ├── bootstrap/                         # Bootstrap configurations
    │   ├── appprojects.yaml               # Multi-tenant AppProjects (infrastructure & workloads)
    │   ├── argocd-install-values.yaml     # Production HA values for ArgoCD Helm chart
    │   └── root-application.yaml          # App-of-Apps root application
    ├── infrastructure/                    # Platform Helm Umbrella Chart
    │   ├── Chart.yaml                     # Umbrella chart metadata
    │   ├── values.yaml                    # Global parameter overrides and service toggles
    │   └── templates/                     # Platform service declarations
    │       ├── argo-rollouts.yaml         # Argo Rollouts progressive delivery controller
    │       ├── cert-manager.yaml          # Cert-Manager TLS certificate manager
    │       ├── cluster-autoscaler.yaml    # AWS Cluster Autoscaler with IRSA
    │       ├── cluster-issuer.yaml        # Let's Encrypt production ClusterIssuer
    │       ├── external-dns.yaml          # Route53 External-DNS controller
    │       ├── external-secrets.yaml      # External Secrets Operator & ClusterSecretStore
    │       ├── grafana-dashboards.yaml    # Curated Grafana dashboard ConfigMaps
    │       ├── ingress-nginx.yaml         # High-availability NGINX Ingress Controller
    │       ├── kube-prometheus.yaml       # Kube-Prometheus stack (Prometheus, Grafana, Alertmanager)
    │       ├── loki-stack.yaml            # Loki log storage (S3 backend) & Promtail DaemonSet
    │       ├── metrics-server.yaml        # Metrics Server for pod autoscaling (HPA)
    │       ├── network-policies.yaml      # Zero-trust namespace isolation policies (including workload apps)
    │       ├── pod-security-standards.yaml # PSA namespace admission enforcement across all namespaces
    │       ├── prometheus-rules.yaml      # Actionable Prometheus alerting rules
    │       ├── sample-app.yaml            # ArgoCD Application deploying the reference workload
    │       └── storage-classes.yaml       # GP3 encrypted StorageClasses with volume expansion
    └── applications/
        └── sample-workload/               # Golden-path progressive delivery reference app
            ├── analysis-template.yaml     # Scoped Prometheus error-rate & p99 latency analysis
            ├── hpa.yaml                   # Horizontal Pod Autoscaler for elastic scaling
            ├── ingress.yaml               # Ingress routing
            ├── kustomization.yaml         # Kustomize manifest
            ├── pdb.yaml                   # Pod Disruption Budget for node maintenance
            ├── rollout.yaml               # Canary Rollout (20% -> 50% -> 80% -> 100%) + multi-AZ topology
            └── service.yaml               # Stable & Canary cluster services
```

---

## 🚀 Step-by-Step Deployment Guide

### Prerequisites
- [AWS CLI v2](https://aws.amazon.com/cli/) (authenticated with admin permissions)
- [Terraform](https://developer.hashicorp.com/terraform/downloads) (>= 1.5.0)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/) (>= 3.14.0)

---

### Step 1: Provision Cloud Infrastructure with Terraform
```bash
cd terraform
terraform init
terraform plan -var-file=terraform.tfvars.example -out=tfplan
terraform apply tfplan
```
*Outputs cluster name, KMS key ARN, VPC Endpoints, and IRSA role ARNs required for the GitOps layer.*

---

### Step 2: Configure Local Kubectl
```bash
aws eks update-kubeconfig --region us-west-2 --name gitops-eks-prod
kubectl get nodes -o wide
```

---

### Step 3: Install ArgoCD HA Engine
```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

kubectl create namespace argocd
helm install argocd argo/argo-cd \
  --namespace argocd \
  -f ../gitops/bootstrap/argocd-install-values.yaml
```

---

### Step 4: Bootstrap Multi-Tenancy & GitOps Root Application
1. Update `gitops/bootstrap/root-application.yaml` and `gitops/infrastructure/values.yaml` with your repository URL and Terraform outputs (IRSA ARNs and S3 bucket names).
2. Apply the multi-tenant `AppProject` boundaries:
   ```bash
   kubectl apply -f ../gitops/bootstrap/appprojects.yaml
   ```
3. Deploy the root application:
   ```bash
   kubectl apply -f ../gitops/bootstrap/root-application.yaml
   ```

*ArgoCD will automatically discover all child platform services and the reference canary workload, synchronizing them to the cluster in dependency order.*

---

## 🛠️ Developer Tooling & Verification

A `Makefile` is included to streamline local development and validation:

| Command | Description |
| :--- | :--- |
| `make fmt` | Recursively format all Terraform code |
| `make lint` | Run Terraform format verification and Helm chart linting |
| `make k8s-validate` | Validate Kubernetes manifests against JSON schemas via Kubeconform |
| `make tf-init` | Initialize Terraform providers |
| `make tf-validate` | Validate syntax and references across Terraform code |
| `make tf-plan` | Generate an execution plan against `terraform.tfvars.example` |
| `make test` | Run full pre-flight CI validation locally |

---

## 📖 Operational Runbooks
Detailed incident response and maintenance runbooks are provided:
* [ArgoCD Troubleshooting Runbook](docs/runbooks/argocd-troubleshooting.md)
* [Secrets Management with External Secrets Operator](docs/runbooks/secrets-management.md)
* [Disaster Recovery & Cluster Reconstruction Guide](docs/runbooks/disaster-recovery.md)
