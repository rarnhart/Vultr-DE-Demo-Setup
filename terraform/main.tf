# =============================================================================
# Vultr Kubernetes Cluster with Envoy Gateway API
# Version: 1.0.0
# =============================================================================

# Local variables for domain construction and retry logic
locals {
  kubeconfig_path = "${path.module}/kubeconfig-${vultr_kubernetes.main.id}.yaml"
  
  # Construct full domain based on subdomain configuration
  full_domain = var.dns_subdomain != "" ? "${var.dns_subdomain}.${var.domain}" : var.domain
  
  # Kubectl retry helper script
  kubectl_retry = <<-EOT
    #!/bin/bash
    set -e
    
    export KUBECONFIG="${local.kubeconfig_path}"
    
    command="$@"
    max_attempts=${var.kubectl_retry_attempts}
    delay=${var.kubectl_retry_delay}
    attempt=1
    
    while [ $attempt -le $max_attempts ]; do
      echo "Attempt $attempt of $max_attempts: $command"
      if eval "$command"; then
        echo "✓ Command succeeded"
        exit 0
      else
        if [ $attempt -lt $max_attempts ]; then
          echo "⚠ Command failed, retrying in $delay seconds..."
          sleep $delay
        fi
      fi
      attempt=$((attempt + 1))
    done
    
    echo "✗ Command failed after $max_attempts attempts"
    exit 1
  EOT
}

# Vultr Kubernetes Engine (VKE) Cluster
resource "vultr_kubernetes" "main" {
  region  = var.region
  label   = var.cluster_name
  version = var.kubernetes_version

  node_pools {
    node_quantity = var.node_count
    plan          = var.node_size
    label         = var.node_pool_name
    auto_scaler   = var.enable_autoscaling
    min_nodes     = var.enable_autoscaling ? var.min_nodes : var.node_count
    max_nodes     = var.enable_autoscaling ? var.max_nodes : var.node_count
  }

  enable_firewall = true
}

# Write kubeconfig to file for kubectl commands
resource "local_file" "kubeconfig" {
  content  = base64decode(vultr_kubernetes.main.kube_config)
  filename = local.kubeconfig_path
  
  file_permission = "0600"
}

# Wait for cluster to be fully ready
resource "time_sleep" "wait_for_cluster" {
  create_duration = "90s"

  depends_on = [
    vultr_kubernetes.main,
    local_file.kubeconfig
  ]
}

# Verify cluster is accessible
resource "null_resource" "verify_cluster" {
  provisioner "local-exec" {
    command = <<-EOT
      ${local.kubectl_retry} kubectl get nodes
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [time_sleep.wait_for_cluster]
}

# Set Vultr Block Storage as default StorageClass
resource "null_resource" "set_default_storageclass" {
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      export KUBECONFIG="${local.kubeconfig_path}"
      
      echo "Waiting for Vultr StorageClasses..."
      for i in {1..30}; do
        if kubectl get storageclass vultr-block-storage &>/dev/null; then
          echo "✓ vultr-block-storage StorageClass found"
          break
        fi
        echo "Waiting for StorageClasses... ($i/30)"
        sleep 2
      done
      
      # Set vultr-block-storage as default
      kubectl patch storageclass vultr-block-storage \
        -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
      
      echo "✓ vultr-block-storage set as default"
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [null_resource.verify_cluster]
}

# Add Helm repositories
resource "null_resource" "add_helm_repos" {
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      echo "Adding Helm repositories..."
      helm repo add envoyproxy https://gateway.envoyproxy.io/helm-charts || true
      helm repo add jetstack https://charts.jetstack.io || true
      helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ || true
      helm repo update
      echo "✓ Helm repositories added"
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [
    null_resource.set_default_storageclass
  ]
}

# Install Gateway API CRDs (required for cert-manager and Envoy Gateway)
resource "null_resource" "install_gateway_api_crds" {
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      export KUBECONFIG="${local.kubeconfig_path}"
      
      echo "Installing Gateway API CRDs..."
      kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
      
      echo "Waiting for CRDs to be established..."
      sleep 5
      
      required_crds=(
        "gatewayclasses.gateway.networking.k8s.io"
        "gateways.gateway.networking.k8s.io"
        "httproutes.gateway.networking.k8s.io"
        "grpcroutes.gateway.networking.k8s.io"
      )
      
      for crd in "$${required_crds[@]}"; do
        kubectl wait --for condition=established --timeout=60s crd/$crd
        echo "✓ CRD ready: $crd"
      done
      
      echo "✓ Gateway API CRDs installed"
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [
    null_resource.add_helm_repos
  ]
}
