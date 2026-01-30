# DNS Configuration
# Automatic Cloudflare DNS record creation (optional)

# Get Cloudflare zone
data "cloudflare_zone" "main" {
  count = var.dns_provider == "cloudflare" ? 1 : 0
  name  = var.domain
}

# Get load balancer IP using null_resource (avoids data source timing issues)
resource "null_resource" "get_lb_ip" {
  count = var.dns_provider == "cloudflare" ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      export KUBECONFIG="${local.kubeconfig_path}"
      
      echo "Waiting for load balancer IP..."
      for i in {1..30}; do
        LB_IP=$(kubectl get svc -n envoy-gateway-system -l "gateway.envoyproxy.io/owning-gateway-name=main-gateway" -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        if [ -n "$LB_IP" ]; then
          echo "$LB_IP" > ${path.module}/lb_ip.txt
          echo "✓ Load Balancer IP: $LB_IP"
          exit 0
        fi
        echo "Waiting for IP... attempt $i/30"
        sleep 10
      done
      echo "ERROR: Load balancer IP not assigned after 5 minutes"
      exit 1
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [null_resource.verify_gateway]
}

# Read the IP from file
data "local_file" "lb_ip" {
  count = var.dns_provider == "cloudflare" ? 1 : 0
  
  filename = "${path.module}/lb_ip.txt"
  
  depends_on = [null_resource.get_lb_ip]
}

# Create wildcard A record
resource "cloudflare_record" "wildcard" {
  count = var.dns_provider == "cloudflare" ? 1 : 0

  zone_id = data.cloudflare_zone.main[0].id
  name    = var.dns_subdomain != "" ? "*.${var.dns_subdomain}" : "*"
  type    = "A"
  content = trimspace(data.local_file.lb_ip[0].content)
  ttl     = 1
  proxied = false
  comment = "Managed by Terraform - Gateway API Load Balancer"

  depends_on = [data.local_file.lb_ip]
}

# Outputs
output "dns_record_created" {
  description = "Whether DNS record was automatically created"
  value       = var.dns_provider == "cloudflare"
}

output "dns_record_name" {
  description = "DNS record name (if automatically created)"
  value       = var.dns_provider == "cloudflare" ? cloudflare_record.wildcard[0].name : "Not managed by Terraform"
}

output "dns_record_value" {
  description = "DNS record IP (if automatically created)"
  value       = var.dns_provider == "cloudflare" ? cloudflare_record.wildcard[0].content : "Not managed by Terraform"
}
