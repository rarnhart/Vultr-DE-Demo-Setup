#!/bin/bash
# Deployment Status Script
# Version: 1.0.0

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Deployment Status                                        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ -z "$KUBECONFIG" ]; then
    cd "${PROJECT_ROOT}/terraform"
    export KUBECONFIG=$(terraform output -raw kubeconfig_path 2>/dev/null)
fi

echo -e "${GREEN}=== CLUSTER ===${NC}"
kubectl get nodes
echo ""

echo -e "${GREEN}=== GATEWAY ===${NC}"
kubectl get gateway -n gateway-system
echo ""

echo -e "${GREEN}=== CERTIFICATES ===${NC}"
kubectl get certificate -n gateway-system
echo ""

echo -e "${GREEN}=== LOAD BALANCER ===${NC}"
kubectl get svc -n gateway-system
echo ""

echo -e "${GREEN}=== COMPONENT PODS ===${NC}"
kubectl get pods -A | grep -E "(cert-manager|envoy-gateway|gateway-system)" || echo "No pods found"
