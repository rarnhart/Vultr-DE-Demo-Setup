# Manual DNS Configuration

For non-Cloudflare DNS providers.

## Steps

1. **Get load balancer IP:**
```bash
terraform output load_balancer_ip
```

2. **Add A record in your DNS provider:**
- Type: A
- Name: `*` or `*.lab`
- Value: [Load Balancer IP]

3. **Verify:**
```bash
dig app.example.com
```

4. **Check certificate:**
```bash
kubectl get certificate -n gateway-system
```

## Provider Examples

**AWS Route53:** Add A record in hosted zone  
**Google DNS:** Use `gcloud dns record-sets create`  
**Azure DNS:** Use `az network dns record-set`  
**Other DNS providers:** Refer to your provider's documentation for adding A records

DNS propagation: 1-5 minutes
Certificate ready: 2-3 minutes after DNS resolves
