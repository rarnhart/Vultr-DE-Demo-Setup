# Switching from Staging to Production Let's Encrypt

This guide covers switching your certificates from Let's Encrypt staging to production.

## Prerequisites

- Cluster deployed with staging certificates working
- DNS configured and propagated
- Gateway receiving traffic

## Steps

### Step 1: Update terraform.tfvars

Edit `terraform/terraform.tfvars`:

```hcl
letsencrypt_server = "https://acme-v02.api.letsencrypt.org/directory"
```

### Step 2: Force Terraform to recreate the ClusterIssuer

```bash
cd terraform
terraform taint null_resource.create_letsencrypt_issuer
terraform apply
```

Wait for completion.

### Step 3: Force Terraform to recreate the Certificate

```bash
terraform taint null_resource.create_certificate
terraform apply
```

Wait for completion.

### Step 4: Delete the old staging secret to force reissue

```bash
kubectl delete secret gateway-tls -n gateway-system
```

### Step 5: Wait and verify (2-5 minutes)

Watch certificate become ready:

```bash
kubectl get certificate gateway-tls -n gateway-system -w
```

Press Ctrl+C when you see `READY: True`

Verify production issuer:

```bash
echo | openssl s_client -connect app.lab.tallturtle.network:443 -servername app.lab.tallturtle.network 2>/dev/null | openssl x509 -noout -issuer
```

**Expected output:**
```
issuer=C=US, O=Let's Encrypt, CN=R3
```

(Or CN=R10 or CN=R11 - all are valid production issuers)

**If you see `(STAGING)` in the output, the certificate is still staging.**

## Troubleshooting

### Certificate not updating

Check certificate request status:
```bash
kubectl get certificaterequest -n gateway-system
kubectl describe certificaterequest -n gateway-system
```

### ClusterIssuer not found

Verify ClusterIssuer exists:
```bash
kubectl get clusterissuer letsencrypt-prod
kubectl describe clusterissuer letsencrypt-prod
```

Should show `Server: https://acme-v02.api.letsencrypt.org/directory` (not staging URL)

### Challenges not appearing

Check for challenges:
```bash
kubectl get challenges -n gateway-system
```

If no challenges appear, check cert-manager logs:
```bash
kubectl logs -n cert-manager deployment/cert-manager --tail=100
```

## Complete - 4 commands total

1. `terraform taint null_resource.create_letsencrypt_issuer && terraform apply`
2. `terraform taint null_resource.create_certificate && terraform apply`
3. `kubectl delete secret gateway-tls -n gateway-system`
4. Wait 2-5 minutes and verify

---

**Time estimate:** 5-10 minutes total (most of it waiting for certificate issuance)
