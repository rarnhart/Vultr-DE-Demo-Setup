#!/bin/bash
# Fix Talend PVCs for Vultr 10GB Minimum
# Version: 1.0.0
# Compatible with bash 3.x

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

if [ $# -ne 1 ]; then
    print_error "Usage: $0 <namespace>"
    echo ""
    echo "Example: $0 talend-namespace"
    exit 1
fi

NAMESPACE="$1"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Vultr PVC Fix for Talend (10GB Minimum)                 ║${NC}"
echo -e "${BLUE}║   Version: 1.0.0                                           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

print_info "Namespace: ${NAMESPACE}"
print_info "Watching for PVCs with size < 10GB..."
print_warning "Start your Talend deployment in another terminal NOW"
echo ""

# Track fixed PVCs in a simple space-separated list
FIXED_PVCS=""

while true; do
    PVCS=$(kubectl get pvc -n "${NAMESPACE}" -o json 2>/dev/null | \
           jq -r '.items[] | select(.spec.resources.requests.storage | test("^[1-9]Gi$")) | .metadata.name' 2>/dev/null || true)
    
    if [ -n "$PVCS" ]; then
        for PVC in $PVCS; do
            # Skip if already fixed
            if echo " $FIXED_PVCS " | grep -q " $PVC "; then
                continue
            fi
            
            print_warning "Found PVC with size < 10GB: ${PVC}"
            
            CURRENT_SIZE=$(kubectl get pvc "${PVC}" -n "${NAMESPACE}" -o jsonpath='{.spec.resources.requests.storage}')
            print_info "Current size: ${CURRENT_SIZE}"
            
            PVC_JSON=$(kubectl get pvc "${PVC}" -n "${NAMESPACE}" -o json)
            
            print_info "Deleting PVC: ${PVC}"
            kubectl delete pvc "${PVC}" -n "${NAMESPACE}" --wait=false 2>/dev/null || true
            
            sleep 2
            
            print_info "Recreating PVC with 10GB size..."
            
            echo "$PVC_JSON" | \
            jq '.spec.resources.requests.storage = "10Gi" | del(.metadata.uid, .metadata.resourceVersion, .metadata.creationTimestamp, .metadata.managedFields, .status)' | \
            kubectl apply -f - 2>/dev/null || {
                print_error "Failed to recreate PVC: ${PVC}"
                continue
            }
            
            print_status "PVC ${PVC} recreated with 10GB"
            
            # Add to fixed list
            FIXED_PVCS="$FIXED_PVCS $PVC"
            
            echo ""
        done
    fi
    
    # Check if we've fixed common Talend PVCs
    FIXED_COUNT=0
    for COMMON_PVC in "job-data" "job-custom-resources" "docker-registry"; do
        if echo " $FIXED_PVCS " | grep -q " $COMMON_PVC "; then
            FIXED_COUNT=$((FIXED_COUNT + 1))
        fi
    done
    
    if [ $FIXED_COUNT -eq 3 ] && [ -n "$FIXED_PVCS" ]; then
        echo ""
        print_status "Common Talend PVCs fixed!"
        print_info "Fixed:$FIXED_PVCS"
        print_info "Continuing to watch... Press Ctrl+C when done"
        echo ""
    fi
    
    sleep 2
done
