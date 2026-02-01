# Vultr Kubernetes for Talend Cloud Dynamic Engine

Setup of a Vultr VKE cluster with Envoy Gateway, cert-manager, and automated SSL certificates designed to demonstrate deployment and operation of Qlik Talend Cloud Dynamic Engine.

## Purpose

This infrastructure-as-code package simplifies the setup and teardown of a complete Kubernetes environment for exposing Web services through Talend Dynamic Engine. By automating the deployment of core infrastructure components (Gateway API, SSL certificates, load balancing), developers can focus on Talend capabilities rather than Kubernetes configuration.

**What this enables:**
- Deploy Talend Routes, Data Services, RESTful Web Services that are designed in Talend Studio
- Expose Web services through Envoy Gateway with automatic SSL configuration
- Demonstrate Talend Dynamic Engine configuration and capabilities
- Rapid environment provisioning for testing and development
- Quick teardown of the infrastructure to assist in reducing cost

**What this eliminates:**
- Manual Kubernetes cluster setup
- Gateway API and ingress configuration
- Certificate management complexity
- Load balancer provisioning


## Quick Start

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit with your Vultr API key

cd ..
./scripts/01-deploy-terraform.sh
./scripts/02-verify-cluster.sh
```

### Before Installing Talend Dynamic Engine Environments

**⚠️ STOP - Read this before deploying Talend:** See [**Talend Preparation Guide**](docs/TALEND-PREPARATION.md)

The PVC fix script MUST run BEFORE installing Dynamic Engine Environments or you'll need to uninstall and start over.

```bash
# Terminal 1 - MUST be running first
./scripts/03-fix-talend-pvcs.sh <namespace>

# Terminal 2 - Only after script is watching
# Here's where you would run the Helm install commands provided in the readme.txt file from the Helm download package from TMC or API
# helm install dynamic-engine oci://ghcr.io/xxxx --version ${DYNAMIC_ENGINE_VERSION} -f c-m-xx-values.yaml -f de-custom-values.yaml
#helm install dynamic-engine-environment-xx oci://ghcr.io/xx/xx --version ${DYNAMIC_ENGINE_VERSION} -f xx-values.yaml -f dee-custom-values.yaml
```

Continue after Talend is installed:

```bash
./scripts/04-verify-certificates.sh
```

## ⚠️ CRITICAL: Vultr 10GB Minimum for Talend

**Vultr requires 10GB minimum volumes. Talend Dynamic Engine Environments requests 1GB = Installation FAILS.**

**You MUST run the PVC fix script BEFORE installing Dynamic Engine Environments.**

See the complete guide: [**Talend Preparation (REQUIRED)**](docs/TALEND-PREPARATION.md)

Skipping this step requires uninstalling Dynamic Engine Environment and starting over.

## What's Deployed

- VKE cluster (customizable nodes)
- Envoy Gateway + Gateway API
- cert-manager (Let's Encrypt)
- Metrics Server
- Vultr block storage (default, 10GB min)

## Scripts

1. `01-deploy-terraform.sh` - Deploy cluster (~15-20 min)
2. `02-verify-cluster.sh` - Verify all components ready
3. `03-fix-talend-pvcs.sh` - **REQUIRED before Talend Dynamic Engine Environment install** - Fixes PVCs for 10GB minimum (see [Talend Prep Guide](docs/TALEND-PREPARATION.md))
4. `04-verify-certificates.sh` - Monitor certificate issuance
5. `05-status.sh` - Quick cluster status
6. `99-cleanup.sh` - Destroy all resources

## DNS Setup

**Cloudflare (automatic):**
```hcl
dns_provider = "cloudflare"
cloudflare_api_token = "your-token"
```

**Manual:**
1. Deploy cluster
2. Get LB IP: `kubectl get svc -n envoy-gateway-system`
3. Create DNS A record: `*.yourdomain.com → <LB_IP>`
4. Wait 5-15 min for certs

See `docs/MANUAL_DNS.md`

---
**Version 1.0.0** - Vultr Kubernetes for Talend Cloud Dynamic Engine
