# Envoy Gateway Installation
# Provides Gateway API implementation

# Envoy Gateway namespace
resource "null_resource" "create_envoy_gateway_namespace" {
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      export KUBECONFIG="${local.kubeconfig_path}"
      
      echo "Creating envoy-gateway-system namespace..."
      kubectl create namespace envoy-gateway-system --dry-run=client -o yaml | kubectl apply -f -
      kubectl label namespace envoy-gateway-system app.kubernetes.io/name=envoy-gateway app.kubernetes.io/managed-by=terraform --overwrite
      echo "✓ envoy-gateway-system namespace ready"
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [
    null_resource.verify_cluster,
    time_sleep.wait_for_cluster,
    null_resource.install_gateway_api_crds
  ]
}

# Envoy Gateway Helm release
resource "null_resource" "install_envoy_gateway" {
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      export KUBECONFIG="${local.kubeconfig_path}"
      
      echo "Installing Envoy Gateway from OCI registry..."
      helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
        --namespace envoy-gateway-system \
        --version ${var.envoy_gateway_version} \
        --set config.envoyGateway.gateway.controllerName=gateway.envoyproxy.io/gatewayclass-controller \
        --wait \
        --timeout 10m
      
      echo "✓ Envoy Gateway installed"
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [
    null_resource.create_envoy_gateway_namespace,
    null_resource.add_helm_repos
  ]
}

# Wait for Envoy Gateway to be deployed
resource "time_sleep" "wait_for_envoy_gateway" {
  create_duration = "60s"

  depends_on = [null_resource.install_envoy_gateway]
}

# Verify Envoy Gateway is ready
resource "null_resource" "verify_envoy_gateway" {
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      export KUBECONFIG="${local.kubeconfig_path}"
      
      echo "Verifying Envoy Gateway deployment..."
      ${local.kubectl_retry} kubectl wait --for=condition=available --timeout=300s \
        deployment/envoy-gateway -n envoy-gateway-system
      
      echo "✓ Envoy Gateway is ready"
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [time_sleep.wait_for_envoy_gateway]
}

# Create GatewayClass
resource "null_resource" "create_gateway_class" {
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      export KUBECONFIG="${local.kubeconfig_path}"
      
      echo "Creating GatewayClass..."
      cat <<YAML | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
YAML
      
      echo "✓ GatewayClass created"
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [null_resource.verify_envoy_gateway]
}

# Verify GatewayClass is accepted
resource "null_resource" "verify_gatewayclass" {
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      export KUBECONFIG="${local.kubeconfig_path}"
      
      echo "Verifying GatewayClass..."
      for i in {1..30}; do
        status=$(kubectl get gatewayclass eg -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}' 2>/dev/null || echo "")
        if [ "$status" = "True" ]; then
          echo "✓ GatewayClass is accepted"
          exit 0
        fi
        echo "Waiting for GatewayClass to be accepted... ($i/30)"
        sleep 2
      done
      
      echo "ERROR: GatewayClass not accepted"
      kubectl describe gatewayclass eg
      exit 1
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [null_resource.create_gateway_class]
}
