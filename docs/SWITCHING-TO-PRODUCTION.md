# Switching from Let's Encrypt Staging to Production

This guide covers switching your certificates from Let's Encrypt staging to production.

## ⚠️ Important: Let's Encrypt Rate Limits

Let's Encrypt production has **strict rate limits** to prevent abuse:

- **50 certificates per registered domain per week**
- **5 duplicate certificates per week** (same set of domains)
- **Failed validation limit**: 5 failures per account, per hostname, per hour

**Rate limit violations result in HTTP 429 errors** that can block certificate issuance for up to a week.

### Recommendation: Use Staging for Testing

**Always use Let's Encrypt staging for:**
- Initial setup and testing
- Development environments
- Testing configuration changes
- Verifying DNS propagation
- Any scenario where you might need to recreate certificates multiple times

**Only switch to production when:**
- Staging certificates work correctly
- DNS is fully configured and stable
- You've validated the complete certificate flow
- You're ready for end users to access the service

The staging environment has much higher rate limits and is designed for testing. See [Let's Encrypt Rate Limits Documentation](https://letsencrypt.org/docs/rate-limits/) for complete details.

## Prerequisites

- Cluster deployed with staging certificates working
- DNS configured and propagated
- Gateway receiving traffic successfully
- Staging certificates validated and ready

## Step-by-Step Migration

### Step 1: Update terraform.tfvars

Edit `terraform/terraform.tfvars`:

```hcl
letsencrypt_server = "https://acme-v02.api.letsencrypt.org/directory"
```

### Step 2: Recreate the ClusterIssuer

Force Terraform to recreate the ClusterIssuer with production settings:

```bash
cd terraform
terraform taint null_resource.create_letsencrypt_issuer
terraform apply
```

Wait for completion.

### Step 3: Recreate the Certificate

Force Terraform to recreate the Certificate resource:

```bash
terraform taint null_resource.create_certificate
terraform apply
```

Wait for completion.

### Step 4: Delete the Old Staging Secret

Force certificate reissue by deleting the existing secret:

```bash
kubectl delete secret gateway-tls -n gateway-system
```

### Step 5: Verify Certificate Issuance (2-5 Minutes)

Watch the certificate become ready:

```bash
kubectl get certificate gateway-tls -n gateway-system -w
```

Press `Ctrl+C` when you see `READY: True`.

Verify production issuer:

```bash
echo | openssl s_client -connect app.lab.tallturtle.network:443 \
  -servername app.lab.tallturtle.network 2>/dev/null | \
  openssl x509 -noout -issuer
```

**Expected output:**
```
issuer=C=US, O=Let's Encrypt, CN=R3
```

Valid production certificate issuers include `CN=R3`, `CN=R10`, or `CN=R11`.

**If you see `(STAGING)` in the output, the certificate is still using the staging issuer.**

## Troubleshooting

### Certificate Not Updating

Check certificate request status:
```bash
kubectl get certificaterequest -n gateway-system
kubectl describe certificaterequest -n gateway-system
```

Look for error messages in the `Status` section.

### ClusterIssuer Not Found

Verify the ClusterIssuer exists and uses the production URL:
```bash
kubectl get clusterissuer letsencrypt-prod
kubectl describe clusterissuer letsencrypt-prod
```

The output should show `Server: https://acme-v02.api.letsencrypt.org/directory` (not the staging URL).

### Challenges Not Appearing

Check for active challenges:
```bash
kubectl get challenges -n gateway-system
```

If no challenges appear, check cert-manager logs:
```bash
kubectl logs -n cert-manager deployment/cert-manager --tail=100
```

### Rate Limit Errors (HTTP 429)

If you encounter rate limit errors:

1. **Immediate action**: Switch back to staging until the rate limit window expires
2. **Wait period**: Most limits reset after one week
3. **Prevention**: Ensure all configuration is correct before switching to production
4. **Monitoring**: Check [Let's Encrypt Rate Limit Status](https://letsencrypt.status.io/)

You can verify rate limit status for your domain:
```bash
# Check current rate limit usage (requires curl and jq)
curl -s "https://crt.sh/?q=%.yourdomain.com&output=json" | \
  jq -r '.[].issuer_name' | grep "Let's Encrypt" | sort | uniq -c
```

## Quick Reference: Complete Migration

Four commands to switch from staging to production:

1. Update `terraform.tfvars` with production URL
2. `terraform taint null_resource.create_letsencrypt_issuer && terraform apply`
3. `terraform taint null_resource.create_certificate && terraform apply`
4. `kubectl delete secret gateway-tls -n gateway-system`

Then wait 2-5 minutes and verify the certificate.

---

**Time estimate:** 5-10 minutes total (mostly waiting for certificate issuance)

**Important:** This process consumes one of your weekly certificate requests. Ensure staging certificates work correctly before migrating to production.
