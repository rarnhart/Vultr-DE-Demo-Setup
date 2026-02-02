# Preparing for Talend Dynamic Engine Environment Installation

**⚠️ CRITICAL:** Complete these preparation steps **BEFORE** installing Talend Dynamic Engine Environments. Skipping these steps will result in PVC creation failures that require uninstalling and reinstalling the Dynamic Engine Environments Helm charts.

## Why This Is Required

Vultr block storage has a **10GB minimum volume size**. Talend Dynamic Engine Environments request PVCs with 1GB sizes by default, which Vultr will reject and block the installation.

## Prerequisites

- Vultr Kubernetes cluster deployed via Terraform (scripts 01 and 02 completed)
- Gateway and certificates configured
- `kubectl` configured to access your cluster
- `jq` installed on your local machine

## Step-by-Step: Before Installing Dynamic Engine

### 1. Verify Cluster Is Ready

Ensure your cluster deployment completed successfully:

```bash
./scripts/02-verify-cluster.sh
```

All components should show as ready.

### 2. Create Namespaces for Dynamic Engine and Environments

Use custom Kubernetes namespaces when setting up for easy reference and resource organization.

Include these namespaces in the custom Helm values file(s) during Dynamic Engine and Environment installation.

```bash
kubectl create namespace <your-de-namespace>
```

Example:
```bash
kubectl create namespace talend-demonstration
```
### If Using a Custom Container Registry

If you plan to use a custom container registry for Data Services and Routes, have the required configuration values ready to add to the Helm custom values. The required values are:

- Container registry URL
- Path (image registry path/repository)
- Username and password to connect to the container registry
- The `secretName` allows you to name the Secret that stores your registry connection information

```yaml
configuration:
  registry:
    url: example.azurecr.io
    path: tester-app/time-api
    username: username
    password: password
    secretName: de-demo-acr-registry
```


### 3. Run PVC Fix Script (CRITICAL)

**This step is MANDATORY and must run BEFORE Helm install.**

Open **two** terminal windows:

#### Terminal 1 - Start the PVC Watcher

```bash
cd infra/scripts
./03-fix-talend-pvcs.sh <your-de-namespace>
```

The script will display:
```
╔════════════════════════════════════════════════════════════╗
║   Vultr PVC Fix for Talend (10GB Minimum)                  ║
║   Version: 1.0.0                                           ║
╚════════════════════════════════════════════════════════════╝
[i] Namespace: talend-production
[i] Watching for PVCs with size < 10GB...
[!] Start your Talend deployment in another terminal NOW
```

#### Terminal 2 - Install Dynamic Engine

Access the Helm files from TMC or API and apply them as described in the `readme.txt` file that accompanies them.

**Using Custom Kubernetes Namespaces (Recommended)**

Custom namespaces provide easy recognition of resources within the Kubernetes cluster. You specify these during creation of Dynamic Engines and Dynamic Engine Environments.

**For Dynamic Engine Installation:**

Create a `de-custom-values.yaml` file to include with the Helm installation command. This instructs the installation to use the specified namespace `vltr-de-demo` rather than a randomly generated one.

Here's an example of custom values for a Dynamic Engine:

```yaml
global:
  namespace:
    create: false
    name: vltr-de-demo
```

**For Dynamic Engine Environment Installation:**

Create a `dee-custom-values.yaml` file to include with the Helm installation command. These settings apply across the entire Dynamic Engine Environment you're creating, so configurations for autoscaling, probe definitions, and other items will apply to all Jobs, Routes, and Data Services deployed to this Dynamic Engine Environment.

If you need different settings, consider creating additional Dynamic Engine Environments. Remember, Dynamic Engines support one or more Dynamic Engine Environments.

Here's an example of custom values for a Dynamic Engine Environment:

```yaml
global:
  namespace:
    create: false
    name: vltr-de-demo-env
dynamicEngine:
  namespace:
    name: vltr-de-demo      # Must match a namespace of a Dynamic Engine
configuration:
  persistence:
    defaultStorageClassName: vultr-vfs-storage  # StorageClass provided by Vultr
  dataServiceRouteDeployment:
    autoscaling:
      enabled: true
      minReplicas: 4
      maxReplicas: 4
    httpRoute:
      # AutoDeploy indicates whether an HTTPRoute is automatically deployed with the Service
      # If true, you must provide the Gateway name and its namespace
      # If false, the Service will still be created, but you'll need to define HTTPRoutes manually
      autoDeploy: true
      # The name of the Gateway the HTTPRoute refers to
      gatewayName: main-gateway
      # The namespace where the Gateway is located
      gatewayNamespace: gateway-system
    additionalValues:
      deployment:
        startupProbe:
          path: /health
          initialDelaySeconds: 20
          periodSeconds: 8
          timeoutSeconds: 1
          failureThreshold: 6
```

**Include the custom values files when running the Helm commands:**

```bash
helm install de-...-engine \
  --version ${DYNAMIC_ENGINE_VERSION} \
  -f c-m-x-values.yaml \
  -f de-custom-values.yaml
```

**Installation Order:**

1. Install the Dynamic Engine first
2. Wait for its status to be green/ready in TMC
3. Install Dynamic Engine Environment(s)
4. Always ensure the target Dynamic Engine is green/ready before installing an Environment

**Remember:** Before installing future Dynamic Engine Environments, ensure the `./03-fix-talend-pvcs.sh` script is running. Use the new Dynamic Engine Environment's namespace as input.

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
- PVCs remain in `Pending` state indefinitely
- Dynamic Engine pods cannot start

**Fix Required:**
1. Uninstall the Dynamic Engine Helm release
2. Delete all pending PVCs manually
3. Start over with the PVC fix script running FIRST

## Troubleshooting

### Script Shows No Output

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

### PVCs Still Show 1Gi After Script Runs

The script may not have caught them during creation. Manually fix:

```bash
# Delete the pending PVC
kubectl delete pvc <pvc-name> -n <your-de-namespace>

# The script will recreate it with 10Gi
# Or manually recreate with 10Gi size
```

### Script Exits with "Command Not Found"

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

**Only after completing these steps** should you proceed with configuring routes, SSL certificates, and exposing services through the Gateway.

You can find [Official Talend Dynamic Engine documentation](https://help.qlik.com/talend/en-US/dynamic-engine-configuration-guide/Cloud/set-up-dynamic-engine-on-registered-kubernetes-cluster)
