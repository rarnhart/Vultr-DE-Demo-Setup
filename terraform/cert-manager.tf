# cert-manager Installation and Configuration
# Manages SSL/TLS certificates using Let's Encrypt with HTTP-01 validation

# cert-manager namespace
resource "null_resource" "create_cert_manager_namespace" {
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      export KUBECONFIG="${local.kubeconfig_path}"
      
      echo "Creating cert-manager namespace..."
      kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -
      kubectl label namespace cert-manager app.kubernetes.io/name=cert-manager app.kubernetes.io/managed-by=terraform --overwrite
      echo "✓ cert-manager namespace ready"
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [
    null_resource.verify_cluster,
    time_sleep.wait_for_cluster,
    null_resource.install_gateway_api_crds
  ]
}

# cert-manager Helm release
resource "null_resource" "install_cert_manager" {
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      export KUBECONFIG="${local.kubeconfig_path}"
      
      echo "Adding cert-manager helm repo..."
      helm repo add jetstack https://charts.jetstack.io || true
      helm repo update
      
      echo "Installing cert-manager..."
      helm upgrade --install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --version ${var.cert_manager_version} \
        --set crds.enabled=true \
        --set crds.keep=true \
        --set featureGates="ExperimentalGatewayAPISupport=true" \
        --set config.enableGatewayAPI=true \
        --wait \
        --timeout 10m
      
      echo "✓ cert-manager installed"
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [
    null_resource.create_cert_manager_namespace,
    null_resource.add_helm_repos
  ]
}

# Wait for cert-manager to be fully deployed
resource "time_sleep" "wait_for_cert_manager" {
  create_duration = "60s"

  depends_on = [null_resource.install_cert_manager]
}

# Verify cert-manager is ready
resource "null_resource" "verify_cert_manager" {
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      export KUBECONFIG="${local.kubeconfig_path}"
      
      echo "Verifying cert-manager deployment..."
      ${local.kubectl_retry} kubectl wait --for=condition=available --timeout=300s \
        deployment/cert-manager -n cert-manager
      
      echo "Verifying cert-manager webhook..."
      ${local.kubectl_retry} kubectl wait --for=condition=available --timeout=300s \
        deployment/cert-manager-webhook -n cert-manager
      
      echo "✓ cert-manager is ready"
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [time_sleep.wait_for_cert_manager]
}

# ClusterIssuer for Let's Encrypt with HTTP-01 validation
resource "null_resource" "create_letsencrypt_issuer" {
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      export KUBECONFIG="${local.kubeconfig_path}"
      
      echo "Creating Let's Encrypt ClusterIssuer..."
      cat <<YAML | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: ${var.letsencrypt_server}
    email: ${var.letsencrypt_email}
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
    - http01:
        gatewayHTTPRoute:
          parentRefs:
          - name: main-gateway
            namespace: gateway-system
            kind: Gateway
            sectionName: http
YAML
      
      echo "✓ ClusterIssuer created"
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [
    null_resource.verify_cert_manager
  ]
}
