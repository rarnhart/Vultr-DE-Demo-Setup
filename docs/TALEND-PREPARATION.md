# Preparing for Talend Dynamic Engine Installation

**CRITICAL:** These preparation steps MUST be completed BEFORE installing Talend Dynamic Engine. Failure to complete these steps will result in PVC creation failures that require uninstalling and reinstalling the Dynamic Engine Helm charts.

## Why This Is Required

Vultr block storage has a **10GB minimum volume size**. Talend Dynamic Engine requests PVCs with 1GB sizes by default, which will fail on Vultr and block the installation.

## Prerequisites

- Vultr Kubernetes cluster deployed via Terraform (scripts 01 and 02 completed)
- Gateway and certificates configured
- `kubectl` configured to access your cluster
- `jq` installed on your local machine

## Step-by-Step: Before Installing Dynamic Engine

### 1. Verify Cluster is Ready

Ensure your cluster deployment completed successfully:

```bash
./scripts/02-verify-cluster.sh
```

All components should show as ready.

### 2. Create Namespaces for Dynamic Engine and Environments

It's recommended to use custom Kubernentes Namespaces when setting this up, for easy reference.

These Namespaces will need to be part of the custom Helm values file(s) that you would include during Dynamic Engine and Environments install.

```bash
kubectl create namespace <your-de-namespace>
```

Example:
```bash
kubectl create namespace talend-production
```

### 3. Run PVC Fix Script (CRITICAL)

**This step is MANDATORY and must run BEFORE Helm install.**

Open TWO terminal windows:

**Terminal 1 - Start the PVC watcher:**
```bash
cd infra/scripts
./03-fix-talend-pvcs.sh <your-de-namespace>
```

The script will display:
```
╔════════════════════════════════════════════════════════════╗
║   Vultr PVC Fix for Talend (10GB Minimum)                 ║
║   Version: 1.0.0                                           ║
╚════════════════════════════════════════════════════════════╝
[i] Namespace: talend-production
[i] Watching for PVCs with size < 10GB...
[!] Start your Talend deployment in another terminal NOW
```

**Terminal 2 - Install Dynamic Engine:**
```bash
# Now run your Helm install command
helm install talend-de <chart> -n <your-de-namespace> -f values.yaml
```

### 4. Monitor the Fix Process

As Talend creates PVCs, Terminal 1 will show:

```
[!] Found PVC with size < 10GB: job-data
[i] Current size: 1Gi
[i] Deleting PVC: job-data
[i] Recreating PVC with 10GB size...
[✓] PVC job-data recreated with 10GB
```

Common PVCs that get fixed:
- `job-data`
- `job-custom-resources`
- `docker-registry`

### 5. When to Stop the Script

After you see:
```
[✓] Common Talend PVCs fixed!
[i] Fixed: job-data job-custom-resources docker-registry
[i] Continuing to watch... Press Ctrl+C when done
```

**Wait 30 seconds** to ensure no additional PVCs are created, then press `Ctrl+C` in Terminal 1.

### 6. Verify PVCs Are Bound

```bash
kubectl get pvc -n <your-de-namespace>
```

All PVCs should show:
- SIZE: `10Gi` (not 1Gi)
- STATUS: `Bound`

Example output:
```
NAME                   SIZE   STATUS
job-data               10Gi   Bound
job-custom-resources   10Gi   Bound
docker-registry        10Gi   Bound
```

## What Happens If You Skip This Step

**Problem:**
- Talend creates 1Gi PVCs
- Vultr rejects them (10GB minimum)
- PVCs remain in `Pending` state forever
- Dynamic Engine pods cannot start

**Fix Required:**
1. Uninstall Dynamic Engine Helm release
2. Delete all pending PVCs manually
3. Start over with the PVC fix script running FIRST

## Troubleshooting

### Script shows no output

**Verify namespace exists:**
```bash
kubectl get namespace <your-de-namespace>
```

**Verify jq is installed:**
```bash
which jq
```

If not installed:
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq
```

### PVCs still show 1Gi after script runs

The script may not have caught them during creation. Manually fix:

```bash
# Delete the pending PVC
kubectl delete pvc <pvc-name> -n <your-de-namespace>

# The script will recreate it with 10Gi
# Or manually recreate with 10Gi size
```

### Script exits with "command not found"

Ensure you're running bash (not sh):
```bash
bash ./03-fix-talend-pvcs.sh <your-de-namespace>
```

## Summary Checklist

Before installing Talend Dynamic Engine:

- [ ] Cluster deployed and verified (scripts 01-02 complete)
- [ ] Namespace created
- [ ] Terminal 1: PVC fix script running and watching
- [ ] Terminal 2: Ready to run Helm install
- [ ] After install: All PVCs show 10Gi and Bound status

**Only after these steps are complete** should you proceed with configuring routes, SSL certificates, and exposing services through the Gateway.
