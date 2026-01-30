# Vultr Kubernetes with Gateway API v1.0.0

Vultr VKE cluster with Envoy Gateway, cert-manager, and automated SSL. The cluster is set up to demonstrate installation and use of the Qlik Talend Cloud Dynamic Engine.

## Quick Start

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit with your Vultr API key

cd ..
./scripts/01-deploy-terraform.sh
./scripts/02-verify-cluster.sh

# For Talend (two terminals):
./scripts/03-fix-talend-pvcs.sh <namespace>  # Terminal 1
helm install talend...                        # Terminal 2

./scripts/04-verify-certificates.sh
```

## ⚠️ CRITICAL: Vultr 10GB Minimum

**Vultr requires 10GB minimum volumes. Talend requests 1GB = FAILS.**

**Solution:** Run `./scripts/03-fix-talend-pvcs.sh <namespace>` BEFORE deploying Talend.

## What's Deployed

- VKE cluster (customizable nodes)
- Envoy Gateway + Gateway API
- cert-manager (Let's Encrypt)
- Metrics Server
- Vultr block storage (default, 10GB min)

## Scripts

1. `01-deploy-terraform.sh` - Deploy (~15-20 min)
2. `02-verify-cluster.sh` - Verify components
3. `03-fix-talend-pvcs.sh` - **Fix Talend PVCs** (10GB)
4. `04-verify-certificates.sh` - Monitor certs
5. `05-status.sh` - Quick status
6. `99-cleanup.sh` - Destroy

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
**Version 1.0.0** - Vultr Kubernetes with Gateway API
