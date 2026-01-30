# =============================================================================
# Vultr Kubernetes Terraform Variables
# Version: 1.0.0
# =============================================================================

# Vultr Configuration
variable "vultr_api_key" {
  description = "Vultr API token - REQUIRED, must be set in terraform.tfvars"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Vultr region for the cluster (e.g., ord, ewr, sjc)"
  type        = string
  default     = "ord"
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "vultr-k8s-cluster"
}

# Kubernetes Version
variable "kubernetes_version" {
  description = "Kubernetes version for the cluster (use Vultr format like v1.31.0+1)"
  type        = string
  default     = "v1.31.0+1"
}

# Node Configuration
variable "node_pool_name" {
  description = "Name of the default node pool"
  type        = string
  default     = "default-pool"
}

variable "node_size" {
  description = "Vultr plan for nodes (e.g., vc2-4c-8gb)"
  type        = string
  default     = "vc2-4c-8gb"
  # Common sizes:
  # vc2-2c-4gb    - $24/month  - Light workloads
  # vc2-4c-8gb    - $48/month  - Recommended for Talend
  # vc2-8c-16gb   - $96/month  - Heavy workloads
}

variable "node_count" {
  description = "Number of nodes in the cluster"
  type        = number
  default     = 3
}

variable "enable_autoscaling" {
  description = "Enable node autoscaling"
  type        = bool
  default     = false
}

variable "min_nodes" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 3
}

variable "max_nodes" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 5
}

# Domain and DNS Configuration
variable "domain" {
  description = "Root domain for certificate management (e.g., tallturtle.network)"
  type        = string
}

variable "dns_subdomain" {
  description = "Subdomain for wildcard DNS and certificates (e.g., 'lab' for *.lab.domain.com, empty for *.domain.com)"
  type        = string
  default     = ""
}

variable "cert_subdomains" {
  description = "List of subdomains for SSL certificates (e.g., ['app', 'api', 'web'])"
  type        = list(string)
  default     = ["app", "api"]
}

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt certificate notifications"
  type        = string
}

variable "letsencrypt_server" {
  description = "Let's Encrypt server URL (production or staging)"
  type        = string
  default     = "https://acme-v02.api.letsencrypt.org/directory"
}

# DNS Provider Configuration
variable "dns_provider" {
  description = "DNS provider: cloudflare or manual"
  type        = string
  default     = "manual"

  validation {
    condition     = contains(["cloudflare", "manual"], var.dns_provider)
    error_message = "DNS provider must be either 'cloudflare' or 'manual'"
  }
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token (only required if dns_provider = cloudflare)"
  type        = string
  default     = ""
  sensitive   = true
}

# Component Versions
variable "cert_manager_version" {
  description = "cert-manager Helm chart version"
  type        = string
  default     = "v1.16.1"
}

variable "envoy_gateway_version" {
  description = "Envoy Gateway Helm chart version"
  type        = string
  default     = "v1.2.3"
}

variable "metrics_server_version" {
  description = "Metrics Server Helm chart version"
  type        = string
  default     = "3.12.2"
}

# Reliability Configuration
variable "kubectl_retry_attempts" {
  description = "Number of retry attempts for kubectl commands"
  type        = number
  default     = 3
}

variable "kubectl_retry_delay" {
  description = "Delay in seconds between kubectl retry attempts"
  type        = number
  default     = 10
}

# Resource Tagging
variable "tags" {
  description = "Tags to apply to Vultr resources"
  type        = list(string)
  default     = []
}
