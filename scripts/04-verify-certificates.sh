#!/bin/bash
# Certificate Verification Script
# Version: 1.0.0
#
# Monitors cert-manager certificate provisioning and HTTP-01 challenges.
# Helps troubleshoot DNS propagation delays.
#
# Usage:
#   ./scripts/03-verify-certificates.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Certificate Verification                                 ║${NC}"
echo -e "${BLUE}║   Version: 1.0.0                                           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_info() { echo -e "${BLUE}[i]${NC} $1"; }

# Check KUBECONFIG
if [ -z "$KUBECONFIG" ]; then
    cd "${PROJECT_ROOT}/terraform"
    export KUBECONFIG=$(terraform output -raw kubeconfig_path 2>/dev/null)
fi

print_info "Checking certificates..."
echo ""
kubectl get certificate -n gateway-system

echo ""
print_info "Checking challenges (if any)..."
kubectl get challenges -n gateway-system 2>/dev/null || print_status "No active challenges"

echo ""
print_warning "Note: DNS propagation may take 5-15 minutes for cluster DNS"
print_info "Challenges auto-retry every 30 seconds"
