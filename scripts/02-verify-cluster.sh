#!/bin/bash
# Cluster Verification Script
# Version: 1.0.0
#
# Verifies that all cluster components are deployed and healthy:
# - Cluster nodes ready
# - Gateway API deployed
# - cert-manager running
# - Envoy Gateway operational
# - Vultr block storage available
# - Metrics Server functional
#
# Usage:
#   ./scripts/02-verify-cluster.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Cluster Verification                                     ║${NC}"
echo -e "${BLUE}║   Version: 1.0.0                                           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# Check KUBECONFIG is set
check_kubeconfig() {
    print_info "Checking kubectl configuration..."
    
    if [ -z "$KUBECONFIG" ]; then
        print_warning "KUBECONFIG not set. Attempting to get from Terraform..."
        cd "${PROJECT_ROOT}/terraform"
        local kubeconfig_path=$(terraform output -raw kubeconfig_path 2>/dev/null)
        
        if [ -z "$kubeconfig_path" ]; then
            print_error "Could not determine kubeconfig path"
            print_info "Please set KUBECONFIG manually:"
            echo "  export KUBECONFIG=\$(cd terraform && terraform output -raw kubeconfig_path)"
            exit 1
        fi
        
        export KUBECONFIG="$kubeconfig_path"
        print_info "KUBECONFIG set to: $kubeconfig_path"
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to cluster"
        exit 1
    fi
    
    print_status "kubectl configured and connected"
    echo ""
}

# Verify cluster nodes
verify_nodes() {
    print_info "Verifying cluster nodes..."
    
    local node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    local ready_count=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready" || echo "0")
    
    if [ "$node_count" -eq 0 ]; then
        print_error "No nodes found in cluster"
        return 1
    fi
    
    if [ "$ready_count" -eq "$node_count" ]; then
        print_status "All $node_count nodes are Ready"
        kubectl get nodes
    else
        print_warning "$ready_count/$node_count nodes are Ready"
        kubectl get nodes
        return 1
    fi
    
    echo ""
}

# Verify namespaces
verify_namespaces() {
    print_info "Verifying namespaces..."
    
    local expected_ns=("cert-manager" "envoy-gateway-system" "gateway-system")
    local missing=0
    
    for ns in "${expected_ns[@]}"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            print_status "Namespace: $ns"
        else
            print_warning "Namespace missing: $ns"
            missing=1
        fi
    done
    
    echo ""
    
    if [ $missing -eq 1 ]; then
        return 1
    fi
}

# Verify cert-manager
verify_certmanager() {
    print_info "Verifying cert-manager..."
    
    local ready=$(kubectl get pods -n cert-manager --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    local total=$(kubectl get pods -n cert-manager --no-headers 2>/dev/null | wc -l || echo "0")
    
    if [ "$ready" -eq "$total" ] && [ "$total" -gt 0 ]; then
        print_status "cert-manager: $ready/$total pods Running"
    else
        print_warning "cert-manager: $ready/$total pods Running (waiting...)"
        kubectl get pods -n cert-manager
        return 1
    fi
    
    # Check Gateway API support enabled
    if kubectl logs -n cert-manager deployment/cert-manager --tail=100 2>/dev/null | grep -q "gateway-shim"; then
        if kubectl logs -n cert-manager deployment/cert-manager --tail=100 2>/dev/null | grep -q "controller as it's disabled"; then
            print_error "Gateway API support is DISABLED in cert-manager"
            return 1
        else
            print_status "Gateway API support: ENABLED"
        fi
    fi
    
    # Check ClusterIssuer
    if kubectl get clusterissuer letsencrypt-prod &> /dev/null; then
        local ready_issuer=$(kubectl get clusterissuer letsencrypt-prod -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        if [ "$ready_issuer" == "True" ]; then
            print_status "ClusterIssuer: letsencrypt-prod is Ready"
        else
            print_warning "ClusterIssuer: letsencrypt-prod exists but not Ready yet"
        fi
    else
        print_warning "ClusterIssuer: letsencrypt-prod not found"
    fi
    
    echo ""
}

# Verify Envoy Gateway
verify_envoy_gateway() {
    print_info "Verifying Envoy Gateway..."
    
    local ready=$(kubectl get pods -n envoy-gateway-system --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    local total=$(kubectl get pods -n envoy-gateway-system --no-headers 2>/dev/null | wc -l || echo "0")
    
    if [ "$ready" -eq "$total" ] && [ "$total" -gt 0 ]; then
        print_status "Envoy Gateway: $ready/$total pods Running"
    else
        print_warning "Envoy Gateway: $ready/$total pods Running (waiting...)"
        kubectl get pods -n envoy-gateway-system
        return 1
    fi
    
    echo ""
}

# Verify Gateway
verify_gateway() {
    print_info "Verifying Gateway API..."
    
    if ! kubectl get gateway main-gateway -n gateway-system &> /dev/null; then
        print_warning "Gateway 'main-gateway' not found in gateway-system namespace"
        print_info "This is normal if deployment just started"
        return 1
    fi
    
    local programmed=$(kubectl get gateway main-gateway -n gateway-system -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
    
    if [ "$programmed" == "True" ]; then
        print_status "Gateway: main-gateway is Programmed"
        
        local lb_ip=$(kubectl get gateway main-gateway -n gateway-system -o jsonpath='{.status.addresses[0].value}' 2>/dev/null)
        if [ -n "$lb_ip" ]; then
            print_status "Load Balancer IP: ${lb_ip}"
        fi
        
        # Check listeners
        local http_listener=$(kubectl get gateway main-gateway -n gateway-system -o jsonpath='{.status.listeners[?(@.name=="http")].conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
        local https_listener=$(kubectl get gateway main-gateway -n gateway-system -o jsonpath='{.status.listeners[?(@.name=="https")].conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
        
        if [ "$http_listener" == "True" ]; then
            print_status "HTTP listener (80): Programmed"
        else
            print_warning "HTTP listener (80): Not programmed"
        fi
        
        if [ "$https_listener" == "True" ]; then
            print_status "HTTPS listener (443): Programmed"
        else
            print_warning "HTTPS listener (443): Not programmed"
        fi
    else
        print_warning "Gateway: main-gateway is NOT Programmed yet"
        print_info "This is normal during initial deployment. It may take a few minutes."
        kubectl describe gateway main-gateway -n gateway-system 2>/dev/null | grep -A10 "Conditions:" || true
    fi
    
    echo ""
}

# Verify Vultr Block Storage
verify_vultr_storage() {
    print_info "Verifying Vultr block storage..."
    
    # Check for vultr-block-storage StorageClass
    if kubectl get storageclass vultr-block-storage &> /dev/null; then
        print_status "StorageClass: vultr-block-storage available"
        
        # Check if it's the default
        local is_default=$(kubectl get storageclass vultr-block-storage -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}' 2>/dev/null || echo "false")
        if [ "$is_default" == "true" ]; then
            print_status "vultr-block-storage is set as default StorageClass"
        else
            print_warning "vultr-block-storage exists but is not default"
        fi
    else
        print_error "vultr-block-storage StorageClass not found"
        kubectl get storageclass
    fi
    
    echo ""
}

# Verify Metrics Server
verify_metrics_server() {
    print_info "Verifying Metrics Server..."
    
    local ready=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=metrics-server --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    
    if [ "$ready" -gt 0 ]; then
        print_status "Metrics Server: Running"
        
        # Test metrics availability (may take a minute after deployment)
        sleep 2
        if timeout 5 kubectl top nodes &> /dev/null; then
            print_status "Metrics available: kubectl top nodes works"
        else
            print_warning "Metrics not available yet (wait ~1 minute after deployment)"
        fi
    else
        print_warning "Metrics Server: Not running"
    fi
    
    echo ""
}

# Overall status
show_overall_status() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    print_status "Cluster Verification Complete"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    print_info "Next steps:"
    echo "  1. Configure DNS (if dns_provider = manual)"
    echo "     See: terraform/docs/MANUAL_DNS.md"
    echo "  2. Run: ./scripts/03-verify-certificates.sh"
    echo "  3. Check status: ./scripts/04-status.sh"
    echo ""
}

# Main execution
main() {
    local failed=0
    
    check_kubeconfig
    
    verify_nodes || failed=1
    verify_namespaces || failed=1
    verify_certmanager || failed=1
    verify_envoy_gateway || failed=1
    verify_gateway || failed=1
    verify_vultr_storage || true  # Optional component
    verify_metrics_server || true  # May take time to start
    
    show_overall_status
    
    if [ $failed -eq 1 ]; then
        print_warning "Some components are not ready yet"
        print_info "This is normal during initial deployment"
        print_info "Wait 2-3 minutes and run this script again"
        exit 1
    fi
    
    print_status "All core components verified successfully!"
}

main
