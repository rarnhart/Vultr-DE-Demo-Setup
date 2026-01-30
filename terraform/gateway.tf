# Gateway Configuration
# Creates the main Gateway resource with HTTPS listener and TLS certificate

# Gateway namespace
resource "null_resource" "create_gateway_namespace" {
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      export KUBECONFIG="${local.kubeconfig_path}"
      
      echo "Creating gateway-system namespace..."
      kubectl create namespace gateway-system --dry-run=client -o yaml | kubectl apply -f -
      kubectl label namespace gateway-system app.kubernetes.io/name=gateway app.kubernetes.io/managed-by=terraform --overwrite
      echo "✓ gateway-system namespace ready"
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [
    null_resource.verify_cluster,
    time_sleep.wait_for_cluster
  ]
}

# Main Gateway resource
resource "null_resource" "create_gateway" {
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      export KUBECONFIG="${local.kubeconfig_path}"
      
      echo "Creating Gateway..."
      cat <<YAML | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: main-gateway
  namespace: gateway-system
spec:
  gatewayClassName: eg
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces:
        from: All
  - name: https
    protocol: HTTPS
    port: 443
    tls:
      mode: Terminate
      certificateRefs:
      - name: gateway-tls
        kind: Secret
    allowedRoutes:
      namespaces:
        from: All
YAML
      
      echo "✓ Gateway created"
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [
    null_resource.verify_gatewayclass,
    null_resource.create_letsencrypt_issuer,
    null_resource.create_gateway_namespace
  ]
}

# Certificate configuration - specific subdomains (HTTP-01 validation)
resource "null_resource" "create_certificate" {
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      export KUBECONFIG="${local.kubeconfig_path}"
      
      echo "Creating Certificate..."
      kubectl apply -f - <<YAML
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: gateway-tls
  namespace: gateway-system
spec:
  secretName: gateway-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
%{ for subdomain in var.cert_subdomains }
  - ${subdomain}.${local.full_domain}
%{ endfor }
YAML
      
      echo "✓ Certificate created"
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [
    null_resource.create_letsencrypt_issuer,
    null_resource.create_gateway_namespace
  ]
}

# Wait for Gateway to be ready
resource "time_sleep" "wait_for_gateway" {
  create_duration = "90s"

  depends_on = [null_resource.create_gateway]
}

# Verify Gateway is ready and get load balancer IP
resource "null_resource" "verify_gateway" {
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      export KUBECONFIG="${local.kubeconfig_path}"
      
      echo "Waiting for Gateway to be ready..."
      
      max_attempts=60
      attempt=1
      
      while [ $attempt -le $max_attempts ]; do
        programmed=$(kubectl get gateway main-gateway -n gateway-system -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null || echo "")
        accepted=$(kubectl get gateway main-gateway -n gateway-system -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}' 2>/dev/null || echo "")
        
        if [ "$programmed" = "True" ] && [ "$accepted" = "True" ]; then
          echo "✓ Gateway is ready"
          
          lb_ip=$(kubectl get gateway main-gateway -n gateway-system -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || echo "")
          if [ -n "$lb_ip" ]; then
            echo "✓ Load Balancer IP: $lb_ip"
            echo ""
            echo "================================================"
            echo "DNS Configuration:"
            echo "================================================"
%{if var.dns_provider == "cloudflare"~}
            echo "Terraform will create DNS records automatically"
%{else~}
            echo "Manually create DNS A record:"
            echo "  Name: *.${local.full_domain}"
            echo "  Value: $lb_ip"
            echo "  Proxy: DNS Only (grey cloud)"
%{endif~}
            echo "================================================"
          fi
          exit 0
        fi
        
        echo "Attempt $attempt of $max_attempts: Programmed=$programmed, Accepted=$accepted"
        sleep 10
        attempt=$((attempt + 1))
      done
      
      echo "ERROR: Gateway not ready"
      kubectl describe gateway main-gateway -n gateway-system
      exit 1
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [time_sleep.wait_for_gateway]
}
