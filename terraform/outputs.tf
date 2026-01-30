# =============================================================================
# Terraform Outputs
# Version: 1.0.0
# =============================================================================

# Cluster Information
output "cluster_id" {
  description = "VKE cluster ID"
  value       = vultr_kubernetes.main.id
}

output "cluster_name" {
  description = "VKE cluster name"
  value       = vultr_kubernetes.main.label
}

output "cluster_region" {
  description = "VKE cluster region"
  value       = vultr_kubernetes.main.region
}

output "cluster_version" {
  description = "Kubernetes version"
  value       = vultr_kubernetes.main.version
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = vultr_kubernetes.main.endpoint
}

# Kubeconfig
output "kubeconfig_path" {
  description = "Path to kubeconfig file"
  value       = local.kubeconfig_path
}

# Gateway Information
output "gateway_namespace" {
  description = "Gateway namespace"
  value       = "gateway-system"
}

output "gateway_name" {
  description = "Gateway name"
  value       = "main-gateway"
}

# Load Balancer IP
output "load_balancer_ip" {
  description = "Load balancer IP address (check after Gateway is ready)"
  value       = "Run: kubectl get gateway main-gateway -n gateway-system -o jsonpath='{.status.addresses[0].value}'"
}

# DNS Configuration
output "dns_instructions" {
  description = "DNS configuration instructions"
  value       = var.dns_provider == "manual" ? "Create DNS A record: *.${local.full_domain} → <LOAD_BALANCER_IP>" : "DNS records created automatically via Cloudflare"
}

# Certificate Information
output "certificates" {
  description = "Created certificates"
  value = [
    for subdomain in var.cert_subdomains :
    "${subdomain}.${local.full_domain}"
  ]
}

# Useful Commands
output "useful_commands" {
  description = "Helpful kubectl commands"
  value = {
    set_kubeconfig   = "export KUBECONFIG=${local.kubeconfig_path}"
    get_nodes        = "kubectl get nodes"
    get_gateway      = "kubectl get gateway -n gateway-system"
    get_certificates = "kubectl get certificate -n gateway-system"
    get_lb_ip        = "kubectl get svc -n envoy-gateway-system"
  }
}
