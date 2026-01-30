#!/bin/bash
# Vultr Kubernetes Deployment Script
# Version: 1.0.0
# 
# This script orchestrates the Terraform deployment of a Vultr Kubernetes cluster
# with Envoy Gateway, cert-manager, and Metrics Server.
#
# Prerequisites:
# - terraform installed (>= 1.0)
# - kubectl installed (>= 1.28)  
# - helm installed (>= 3.0)
# - terraform/terraform.tfvars configured (see terraform/terraform.tfvars.example)
#
# Usage:
#   ./scripts/01-deploy-terraform.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Vultr Kubernetes Deployment - Terraform                 ║${NC}"
echo -e "${BLUE}║   Version: 1.0.0                                           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to print status messages
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

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    local missing=0
    
    if ! command -v terraform &> /dev/null; then
        print_error "terraform not found. Please install Terraform >= 1.0"
        missing=1
    else
        print_status "terraform found: $(terraform version | head -n1)"
    fi
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl >= 1.28"
        missing=1
    else
        print_status "kubectl found: $(kubectl version --client --short 2>/dev/null || kubectl version --client 2>&1 | head -n1)"
    fi
    
    if ! command -v helm &> /dev/null; then
        print_error "helm not found. Please install Helm >= 3.0"
        missing=1
    else
        print_status "helm found: $(helm version --short)"
    fi
    
    if [ $missing -eq 1 ]; then
        print_error "Missing required tools. Please install them and try again."
        exit 1
    fi
    
    echo ""
}

# Check terraform.tfvars exists
check_tfvars() {
    print_info "Checking Terraform configuration..."
    
    if [ ! -f "${TERRAFORM_DIR}/terraform.tfvars" ]; then
        print_error "terraform.tfvars not found!"
        print_info "Please create terraform.tfvars from terraform.tfvars.example:"
        echo ""
        echo "  cd terraform"
        echo "  cp terraform.tfvars.example terraform.tfvars"
        echo "  # Edit terraform.tfvars with your settings"
        echo ""
        print_info "Required variables:"
        echo "  - vultr_api_key      (Vultr API token)"
        echo "  - domain             (Your domain, e.g., example.com)"
        echo "  - cert_subdomains    (Subdomains for SSL, e.g., [\"app\", \"api\"])"
        echo "  - letsencrypt_email  (Email for Let's Encrypt)"
        echo ""
        exit 1
    fi
    
    print_status "terraform.tfvars found"
    echo ""
}

# Run terraform init
terraform_init() {
    print_info "Initializing Terraform..."
    
    cd "${TERRAFORM_DIR}"
    
    if terraform init; then
        print_status "Terraform initialized successfully"
    else
        print_error "Terraform init failed"
        exit 1
    fi
    
    echo ""
}

# Run terraform validate
terraform_validate() {
    print_info "Validating Terraform configuration..."
    
    cd "${TERRAFORM_DIR}"
    
    if terraform validate; then
        print_status "Terraform configuration is valid"
    else
        print_error "Terraform validation failed"
        exit 1
    fi
    
    echo ""
}

# Run terraform plan
terraform_plan() {
    print_info "Running Terraform plan..."
    print_warning "Review the plan carefully before proceeding"
    echo ""
    
    cd "${TERRAFORM_DIR}"
    
    if terraform plan -out=tfplan; then
        print_status "Terraform plan completed successfully"
        echo ""
        print_info "Plan saved to: ${TERRAFORM_DIR}/tfplan"
    else
        print_error "Terraform plan failed"
        exit 1
    fi
    
    echo ""
}

# Run terraform apply
terraform_apply() {
    print_warning "About to deploy infrastructure to Vultr"
    print_info "This will create billable resources"
    echo ""
    read -p "Do you want to proceed? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_info "Deployment cancelled"
        exit 0
    fi
    
    echo ""
    print_info "Deploying infrastructure (this will take 15-20 minutes)..."
    
    cd "${TERRAFORM_DIR}"
    
    if terraform apply tfplan; then
        print_status "Infrastructure deployed successfully!"
    else
        print_error "Terraform apply failed"
        exit 1
    fi
    
    echo ""
}

# Save kubeconfig
save_kubeconfig() {
    print_info "Configuring kubectl..."
    
    cd "${TERRAFORM_DIR}"
    
    local kubeconfig_path=$(terraform output -raw kubeconfig_path 2>/dev/null)
    
    if [ -z "$kubeconfig_path" ]; then
        print_warning "Could not get kubeconfig path from Terraform output"
        print_info "You can set it manually later with:"
        echo "  export KUBECONFIG=\$(cd terraform && terraform output -raw kubeconfig_path)"
    else
        export KUBECONFIG="$kubeconfig_path"
        print_status "KUBECONFIG set to: ${kubeconfig_path}"
        print_info "Add this to your shell:"
        echo "  export KUBECONFIG=${kubeconfig_path}"
    fi
    
    echo ""
}

# Show deployment summary
show_summary() {
    print_status "Deployment Summary"
    echo ""
    
    cd "${TERRAFORM_DIR}"
    
    echo -e "${BLUE}Cluster Information:${NC}"
    local cluster_name=$(terraform output -raw cluster_name 2>/dev/null)
    local cluster_region=$(terraform output -raw cluster_region 2>/dev/null)
    local cluster_version=$(terraform output -raw cluster_version 2>/dev/null)
    
    [ -n "$cluster_name" ] && echo "  Name: $cluster_name"
    [ -n "$cluster_region" ] && echo "  Region: $cluster_region"
    [ -n "$cluster_version" ] && echo "  Version: $cluster_version"
    echo ""
    
    echo -e "${BLUE}Load Balancer:${NC}"
    local lb_ip=$(terraform output -raw load_balancer_ip 2>/dev/null)
    [ -n "$lb_ip" ] && echo "  IP: $lb_ip" || echo "  IP: Waiting for assignment..."
    echo ""
    
    echo -e "${BLUE}DNS Configuration:${NC}"
    local dns_provider=$(terraform output -raw dns_provider 2>/dev/null)
    local dns_created=$(terraform output -raw dns_record_created 2>/dev/null)
    
    if [ "$dns_provider" == "cloudflare" ]; then
        if [ "$dns_created" == "true" ]; then
            print_status "DNS records created automatically in Cloudflare"
        else
            print_warning "Cloudflare configured but records not created yet"
        fi
    else
        print_info "DNS provider: Manual configuration required"
        print_info "See: terraform/docs/MANUAL_DNS.md"
    fi
    
    echo ""
    print_info "Next steps:"
    echo "  1. Run: ./scripts/02-verify-cluster.sh"
    echo "  2. Configure DNS (if dns_provider = manual)"
    echo "  3. Run: ./scripts/03-verify-certificates.sh"
    echo "  4. Check status: ./scripts/04-status.sh"
    echo ""
}

# Main execution
main() {
    check_prerequisites
    check_tfvars
    terraform_init
    terraform_validate
    terraform_plan
    terraform_apply
    save_kubeconfig
    show_summary
    
    print_status "Deployment script completed!"
    print_info "Infrastructure is ready. Please proceed with verification scripts."
}

# Run main
main
