#!/bin/bash
# Cleanup Script
# Version: 1.0.0
#
# Safely destroys all infrastructure created by Terraform
#
# Usage:
#   ./scripts/99-cleanup.sh

set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"

echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║   DESTROY Infrastructure                                   ║${NC}"
echo -e "${RED}║   This will DELETE all resources                           ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}WARNING: This will destroy:${NC}"
echo "  • Vultr Kubernetes cluster"
echo "  • Load Balancers"
echo "  • DNS records (if managed by Terraform)"
echo "  • All persistent data"
echo ""

read -p "Type 'destroy' to confirm: " confirm

if [ "$confirm" != "destroy" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo ""
echo -e "${BLUE}Running terraform destroy...${NC}"

cd "${TERRAFORM_DIR}"
terraform destroy -auto-approve

echo ""
echo -e "${BLUE}Cleanup complete${NC}"
