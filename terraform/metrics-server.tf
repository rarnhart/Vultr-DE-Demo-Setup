# Metrics Server Installation
# Provides pod and node metrics for HPA (Horizontal Pod Autoscaling)

# Metrics Server Helm release
resource "null_resource" "install_metrics_server" {
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      export KUBECONFIG="${local.kubeconfig_path}"
      
      echo "Adding metrics-server helm repo..."
      helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ || true
      helm repo update
      
      echo "Installing metrics-server..."
      helm upgrade --install metrics-server metrics-server/metrics-server \
        --namespace kube-system \
        --version ${var.metrics_server_version} \
        --wait \
        --timeout 5m
      
      echo "✓ metrics-server installed"
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [
    null_resource.verify_cluster,
    null_resource.add_helm_repos
  ]
}

# Wait for metrics-server to be deployed
resource "time_sleep" "wait_for_metrics_server" {
  create_duration = "30s"

  depends_on = [null_resource.install_metrics_server]
}

# Verify metrics-server
resource "null_resource" "verify_metrics_server" {
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      export KUBECONFIG="${local.kubeconfig_path}"
      
      echo "Verifying metrics-server..."
      ${local.kubectl_retry} kubectl wait --for=condition=available --timeout=300s \
        deployment/metrics-server -n kube-system
      
      echo "✓ metrics-server is ready"
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [time_sleep.wait_for_metrics_server]
}
