# Disaster Recovery & Cluster Rebuilding Runbook

## Overview
Because this platform utilizes declarative Infrastructure as Code (**Terraform**) and declarative Application GitOps (**ArgoCD**), complete cluster recreation can be achieved with minimal Recovery Time Objective (RTO < 30 minutes) and zero configuration drift (RPO = 0).

---

## 1. Disaster Recovery Objectives
- **RTO (Recovery Time Objective)**: < 30 minutes (time required to provision AWS EKS, VPC, and sync ArgoCD).
- **RPO (Recovery Point Objective)**: Near zero for configurations; stateful log data protected via S3 versioning and EBS snapshots.

---

## 2. Complete Cluster Reconstruction Procedure

### Phase 1: Re-provision Cloud Infrastructure
In the event of total cluster termination or region migration:

1. **Initialize Terraform with Remote Backend**:
   ```bash
   cd terraform
   terraform init
   ```
2. **Review & Execute Plan**:
   ```bash
   terraform plan -out=tfplan
   terraform apply tfplan
   ```
   *Terraform recreates the VPC, VPC Endpoints, EKS Control Plane, KMS keys, Node Groups, and IAM IRSA roles in ~15 minutes.*

3. **Update Local Kubeconfig**:
   ```bash
   aws eks update-kubeconfig --region us-west-2 --name gitops-eks-prod
   ```

---

### Phase 2: Bootstrap ArgoCD & AppProjects
1. **Install ArgoCD Core**:
   ```bash
   helm repo add argo https://argoproj.github.io/argo-helm
   helm repo update
   kubectl create namespace argocd
   helm install argocd argo/argo-cd \
     --namespace argocd \
     -f ../gitops/bootstrap/argocd-install-values.yaml
   ```

2. **Deploy AppProjects (Multi-Tenancy Boundaries)**:
   ```bash
   kubectl apply -f ../gitops/bootstrap/appprojects.yaml
   ```

3. **Deploy Root Application (App-of-Apps)**:
   ```bash
   kubectl apply -f ../gitops/bootstrap/root-application.yaml
   ```

---

### Phase 3: Validation & Auto-Healing
Once the root application is applied:
1. ArgoCD reads Git and immediately launches child applications:
   - Ingress NGINX & Cert-Manager
   - External Secrets Operator
   - Kube-Prometheus & Loki Stacks
   - Cluster Autoscaler & Metrics Server
   - Progressive Delivery Rollouts
2. External Secrets Operator contacts AWS Secrets Manager via IRSA and reinstates all database credentials and API keys.
3. StorageClasses recreate dynamic GP3 encrypted volumes.
4. Verify cluster health:
   ```bash
   kubectl get pods -A
   kubectl get applications -n argocd
   ```
