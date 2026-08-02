#!/bin/bash
set -euo pipefail

echo "==================================================="
echo "Multi tier multi namespace Kubernetes networking"
echo "==================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Wait for Docker to be ready
wait_for_docker() {
    log_info "Waiting for Docker to be ready..."
    local max_attempts=30
    local attempt=0
    while ! docker info &>/dev/null; do
        attempt=$((attempt + 1))
        if [ $attempt -ge $max_attempts ]; then
            log_error "Docker failed to start after $max_attempts attempts"
            exit 1
        fi
        sleep 2
    done
    log_info "Docker is ready!"
}

create_cluster(){
  log_info "Creating kind cluster..."

  if kind get clusters 2>/dev/null | grep -q "sre-lab"; then
    log_warn "Cluster 'sre-lab' already exists. Skipping creation."
    return 0
  fi

  kind create cluster --name multi-tier-multi-ns --config kind_config.yaml
  log_info "Kind cluster created successfully!"
}

# Install Cilium CNI
install_cilium() {
    log_info "Installing Cilium CNI..."
    
    # Skip installation if Cilium is already present in the cluster
    if kubectl get daemonset cilium -n kube-system &>/dev/null; then
        log_warn "Cilium is already installed. Skipping installation."
        log_info "Waiting for Cilium to be ready..."
        cilium status --wait
        return 0
    fi
    
    # Install Cilium with settings optimized for kind
    # Let the CLI pick the default compatible version
    cilium install \
        --set ipam.mode=kubernetes \
        --set kubeProxyReplacement=false \
        --set socketLB.enabled=false \
        --set externalIPs.enabled=true \
        --set hostPort.enabled=true \
        --set nodePort.enabled=true
    
    log_info "Waiting for Cilium to be ready..."
    cilium status --wait
    log_info "Cilium installed successfully!"
}

deploy_application(){
    log_info "Deploying workloads"

    # Create namespaces
    kubectl apply -f client-ns.yaml
    kubectl apply -f core-ns.yaml

    # Deploy httpbin backend
    kubectl apply -f manifests/httpbin.yaml

    # Deploy nginx frontend
    kubectl apply -f manifests/nginx.yaml

    # Deploy netshoot debug pod
    kubectl apply -f manifests/netshoot.yaml

    # Deploy redis and redis-client pod
    kubectl apply -f manifests/redis.yaml
    kubectl apply -f manifests/redis-client.yaml

    log_info "Waiting for all pods to be ready..."
    kubectl -n client wait --for=condition=ready pod --all --timeout=120s
    kubectl -n core wait --for=condition=ready pod --all --timeout=240s

    log_info "Application deployed successfully!"
}

# Print cluster status
print_status() {
    echo ""
    echo "=========================================="
    echo "  Cluster Ready!"
    echo "=========================================="
    echo ""
    echo "Useful commands:"
    echo "  kubectl get pods -n <namespace>        # View application pods"
    echo "  kubectl get svc -n <namespace>         # View services"
    echo "  cilium status                       # Check Cilium status"
    echo "  cilium connectivity test            # Run connectivity tests"
    echo ""
    echo "Debug pod access:"
    echo "  kubectl exec -it -n client netshoot -- bash"
    echo ""
    echo "=========================================="
}

# Main execution
main() {
    wait_for_docker
    create_cluster
    install_cilium
    deploy_application
    print_status
}

main "$@"
