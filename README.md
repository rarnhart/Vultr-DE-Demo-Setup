# Vultr Kubernetes for Talend Cloud Dynamic Engine

**Version 1.0.0**

Sets up a Vultr VKE cluster with Envoy Gateway, cert-manager, and automated SSL certificates to demonstrate deployment and operation of Qlik Talend Cloud Dynamic Engine.

## Purpose

This infrastructure-as-code package simplifies the setup and teardown of a complete Kubernetes environment for exposing web services through Talend Dynamic Engine. By automating the deployment of core infrastructure components (Gateway API, SSL certificates, load balancing), you can focus on Talend capabilities rather than Kubernetes configuration.

### What This Enables

- Deploy Talend Routes, Data Services, and RESTful web services that you design in Talend Studio
- Expose web services through Envoy Gateway with automatic SSL configuration
- Demonstrate Talend Dynamic Engine configuration and capabilities
- Rapidly provision environments for testing and development
- Quickly tear down infrastructure to reduce costs

### What This Eliminates

- Manual Kubernetes cluster setup
- Gateway API and ingress configuration
- Certificate management complexity
- Load balancer provisioning

## Conceptual Deployment Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                            INTERNET                             │
└────────────────────────────────┬────────────────────────────────┘
                                 │
                                 │ HTTPS (Let's Encrypt)
                                 │
                    ┌────────────▼────────────┐
                    │   Vultr Load Balancer   │
                    │  (Automatically created)│
                    └────────────┬────────────┘
                                 │
              ┌──────────────────▼──────────────────┐
              │        Envoy Gateway                │
              │   Listeners: HTTP(80) HTTPS(443)    │
              │   TLS: gateway-tls secret           │
              └──────────────────┬──────────────────┘
                                 │
              ┌──────────────────▼──────────────────┐
              │      Gateway (main-gateway)         │
              │   namespace: gateway-system         │
              └──────────────────┬──────────────────┘
                                 │
              ┌──────────────────▼──────────────────┐
              │          HTTPRoute                  │
              │  (Dynamic Engine may create this)   │
              │  Hostname: api.lab.example.com      │
              │  Backend: talend-service:80         │
              └──────────────────┬──────────────────┘
                                 │
              ┌──────────────────▼──────────────────┐
              │   Kubernetes Service                │
              │   talend-service:80 → 8080          │
              └──────────────────┬──────────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │  Talend Dynamic Engine  │
                    │  Data Services / Routes │
                    └─────────────────────────┘
```

## Quick Start

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Vultr API key

cd ..
./scripts/01-deploy-terraform.sh
./scripts/02-verify-cluster.sh
```

## Before Installing Talend Dynamic Engine Environments

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

### ⚠️ CRITICAL: PVC Fix Requirement

**See the Talend Preparation Guide for complete details.**

You **MUST** run the PVC fix script **BEFORE** installing Dynamic Engine Environments, or you'll need to uninstall and start over.

**Why this is required:**

Vultr's `vultr-vfs-storage` StorageClass requires a 10GB minimum for volume-size requests. Talend Dynamic Engine Environments request 1GB for some volumes, which causes installation to stall and fail because the PersistentVolume will not be created.

**Installation sequence:**

```bash
# Terminal 1 - Start this FIRST and keep it running
./scripts/03-fix-talend-pvcs.sh <namespace>

# Terminal 2 - Only start after the script above is watching for PVCs
# Run the Helm commands provided in the readme.txt file from the Helm download package from TMC or API
helm install dynamic-engine oci://ghcr.io/xxxx \
  --version ${DYNAMIC_ENGINE_VERSION} \
  -f c-m-xx-values.yaml \
  -f de-custom-values.yaml

helm install dynamic-engine-environment-xx oci://ghcr.io/xx/xx \
  --version ${DYNAMIC_ENGINE_VERSION} \
  -f xx-values.yaml \
  -f dee-custom-values.yaml
```

**⚠️ WARNING:** Skipping the PVC fix step results in errors and requires uninstalling Dynamic Engine Environment and starting over.

After Talend installation completes, verify certificates:

```bash
./scripts/04-verify-certificates.sh
```

## What's Deployed

- VKE cluster (customizable nodes)
- Envoy Gateway + Gateway API
- cert-manager (Let's Encrypt)
- Metrics Server
- Vultr block storage (default, 10GB minimum)

## Scripts

- `01-deploy-terraform.sh` - Deploy the cluster (~15-20 minutes)
- `02-verify-cluster.sh` - Verify all components are ready
- `03-fix-talend-pvcs.sh` - **REQUIRED** before Talend Dynamic Engine Environment install - Fixes PVCs for 10GB minimum (see Talend Prep Guide)
- `04-verify-certificates.sh` - Monitor certificate issuance
- `05-status.sh` - Quick cluster status check
- `99-cleanup.sh` - Destroy all resources

## DNS Setup

### Automatic (Cloudflare)

```hcl
dns_provider = "cloudflare"
cloudflare_api_token = "your-token"
```

### Manual Setup

1. Deploy the cluster
2. Get the Load Balancer IP:
   ```bash
   kubectl get svc -n envoy-gateway-system
   ```
3. Create a DNS A record: `*.yourdomain.com` → `<LB_IP>`
4. Wait 5-15 minutes for certificates to issue

See `docs/MANUAL_DNS.md` for detailed instructions.
