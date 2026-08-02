#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

POLICY_DIR="./policies"

if [ ! -d "$POLICY_DIR" ]; then
    log_error "Error: Directory '$POLICY_DIR' does not exist."
    exit 1
fi

log_info "Applying Kubernetes Network Policies..."

for file in "$POLICY_DIR"/*.yaml "$POLICY_DIR"/*.yml; do
    if [ -f "$file" ]; then
        log_info "Applying $(basename "$file")..."
        kubectl apply -f "$file"
    fi
done

log_info " All policies have been applied."