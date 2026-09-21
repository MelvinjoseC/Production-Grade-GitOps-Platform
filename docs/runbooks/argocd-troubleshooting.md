# ArgoCD Troubleshooting & Operations Runbook

## Overview
This runbook provides remediation procedures for common ArgoCD synchronization, lifecycle, and controller failures on the GitOps platform.

---

## 1. Application Stuck in "OutOfSync"

### Symptoms
- ArgoCD UI shows application status as `OutOfSync` despite git commit being merged.
- Git revision hash matches, but specific resources remain out of sync.

### Root Causes
- Mutating webhooks altering default values (e.g., storageclasses, admission controllers).
- Unmanaged annotations or labels injected by controllers in the cluster.
- Field collision or differences in default indentation/null fields.

### Resolution Steps
1. **Inspect Diffs via CLI**:
   ```bash
   argocd app diff <app-name>
   ```
2. **Hard Refresh the Application Cache**:
   ```bash
   argocd app get <app-name> --hard-refresh
   ```
3. **Configure `ignoreDifferences` in Application Manifest**:
   If an in-cluster controller modifies a metadata field:
   ```yaml
   spec:
     ignoreDifferences:
       - group: apps
         kind: Deployment
         jsonPointers:
           - /spec/replicas
   ```
4. **Force Sync with Prune**:
   ```bash
   argocd app sync <app-name> --force --prune
   ```

---

## 2. ArgoCD Application Controller Sync Timeout / CrashLoop

### Symptoms
- Application controller pod restarts frequently.
- Sync operations queue up and remain pending indefinitely.

### Diagnostic Commands
```bash
# Check controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=100 -f

# Check Redis cache connectivity
kubectl exec -it -n argocd deploy/argocd-redis -- redis-cli ping
```

### Remediation
- **Scale Redis**: Ensure Redis has sufficient memory; if OOMKilled, increase requests/limits in `argocd-install-values.yaml`.
- **Parallelism Adjustment**: Adjust controller status processors:
  ```yaml
  controller:
    args:
      statusProcessors: 30
      operationProcessors: 15
  ```

---

## 3. Webhook Latency / GitHub Sync Delay

### Symptoms
- Git commits take up to 3 minutes to be detected by ArgoCD.

### Root Cause
- ArgoCD polls Git every 3 minutes by default if webhooks are not configured.

### Remediation
Configure a GitHub webhook in your repository settings:
- **Payload URL**: `https://<argocd-host>/api/webhook`
- **Content type**: `application/json`
- **Secret**: Stored in `argocd-secret` under key `webhook.github.secret`.
