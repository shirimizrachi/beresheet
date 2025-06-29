#!/bin/bash

# Oracle Cloud Kubernetes Infrastructure Setup Script
# This script sets up cert-manager, NGINX Ingress Controller, and SSL certificates
# Optimized for Oracle Cloud's Always Free tier

set -e

# Configuration
CERT_MANAGER_VERSION="v1.13.0"
NGINX_INGRESS_VERSION="4.8.3"
EMAIL="ranmizrachi@gmail.com"
API_DOMAIN="api.residentsapp.com"
WWW_DOMAIN="www.residentsapp.com"

# Docker Registry Configuration
OCI_REGION="il-jerusalem-1"
OCI_TENANCY_NAMESPACE="axsfrwfafaxr"
DOCKER_REGISTRY="${OCI_REGION}.ocir.io"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Check if kubectl is available and connected
check_kubernetes() {
    print_header "Checking Kubernetes Connection"
    
    if ! command -v kubectl >/dev/null 2>&1; then
        print_error "kubectl is not installed"
        exit 1
    fi
    
    print_status "Testing Kubernetes connection..."
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "kubectl is not connected to a cluster or cluster is unreachable"
        print_warning "Please check your kubeconfig and ensure the cluster is accessible"
        print_warning "You may need to:"
        echo "  1. Set up your kubeconfig: export KUBECONFIG=/path/to/your/kubeconfig"
        echo "  2. Authenticate with your cloud provider"
        echo "  3. Check if the cluster is running"
        exit 1
    fi
    
    CLUSTER_NAME=$(kubectl config current-context)
    print_status "Connected to cluster: $CLUSTER_NAME"
    
    # Test basic operations
    print_status "Verifying cluster access..."
    if ! kubectl get nodes >/dev/null 2>&1; then
        print_error "Cannot access cluster nodes. Please check your permissions."
        exit 1
    fi
    
    print_status "Cluster connection verified successfully"
}

# Install cert-manager
install_cert_manager() {
    print_header "Installing cert-manager"
    
    # Add Jetstack Helm repository
    if ! helm repo list | grep -q jetstack; then
        print_status "Adding Jetstack Helm repository..."
        helm repo add jetstack https://charts.jetstack.io
    fi
    
    helm repo update
    
    # Check if cert-manager is already installed
    if helm list -A | grep -q cert-manager; then
        print_warning "cert-manager is already installed, checking if upgrade is needed..."
        
        # Get current version
        CURRENT_VERSION=$(helm list -A | grep cert-manager | awk '{print $10}' || echo "unknown")
        print_status "Current cert-manager version: $CURRENT_VERSION"
        
        if [ "$CURRENT_VERSION" != "$CERT_MANAGER_VERSION" ]; then
            print_status "Upgrading cert-manager to version $CERT_MANAGER_VERSION..."
            helm upgrade cert-manager jetstack/cert-manager \
                --namespace cert-manager \
                --version $CERT_MANAGER_VERSION \
                --set installCRDs=true \
                --set nodeSelector."kubernetes\.io/arch"=arm64
        else
            print_status "cert-manager is already at the desired version"
        fi
    else
        print_status "Installing cert-manager..."
        if ! helm install cert-manager jetstack/cert-manager \
            --namespace cert-manager \
            --create-namespace \
            --version $CERT_MANAGER_VERSION \
            --set installCRDs=true \
            --set nodeSelector."kubernetes\.io/arch"=arm64; then
            print_error "Failed to install cert-manager"
            print_warning "This might be because cert-manager is already installed but not visible to Helm"
            print_status "Checking if cert-manager pods exist..."
            if kubectl get pods -n cert-manager 2>/dev/null | grep -q cert-manager; then
                print_status "cert-manager pods found, continuing with existing installation"
            else
                print_error "cert-manager installation failed and no existing installation found"
                exit 1
            fi
        fi
    fi
    
    # Wait for cert-manager to be ready
    print_status "Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager
    kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-webhook -n cert-manager
    kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
    
    print_status "cert-manager installed successfully"
}

# Install NGINX Ingress Controller with Oracle Cloud Load Balancer
install_nginx_ingress() {
    print_header "Installing NGINX Ingress Controller"
    
    # Add NGINX Ingress Helm repository
    if ! helm repo list | grep -q ingress-nginx; then
        print_status "Adding NGINX Ingress Helm repository..."
        helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    fi
    
    helm repo update
    
    # Check if nginx-ingress is already installed
    if helm list -A | grep -q ingress-nginx; then
        print_warning "NGINX Ingress Controller is already installed, checking configuration..."
        
        # Get current version
        CURRENT_NGINX_VERSION=$(helm list -A | grep ingress-nginx | awk '{print $10}' || echo "unknown")
        print_status "Current NGINX Ingress version: $CURRENT_NGINX_VERSION"
        
        if [ "$CURRENT_NGINX_VERSION" != "$NGINX_INGRESS_VERSION" ]; then
            print_status "Upgrading NGINX Ingress Controller to version $NGINX_INGRESS_VERSION..."
            helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
                --namespace ingress-nginx \
                --version $NGINX_INGRESS_VERSION \
                --set controller.service.type=LoadBalancer \
                --set controller.service.annotations."service\.beta\.kubernetes\.io/oci-load-balancer-shape"="flexible" \
                --set controller.service.annotations."service\.beta\.kubernetes\.io/oci-load-balancer-shape-flex-min"="10" \
                --set controller.service.annotations."service\.beta\.kubernetes\.io/oci-load-balancer-shape-flex-max"="10" \
                --set controller.service.annotations."service\.beta\.kubernetes\.io/oci-load-balancer-ssl-ports"="443" \
                --set controller.service.annotations."service\.beta\.kubernetes\.io/oci-load-balancer-security-list-management-mode"="All" \
                --set controller.nodeSelector."kubernetes\.io/arch"=arm64 \
                --set controller.admissionWebhooks.patch.nodeSelector."kubernetes\.io/arch"=arm64 \
                --set defaultBackend.nodeSelector."kubernetes\.io/arch"=arm64
        else
            print_status "NGINX Ingress Controller is already at the desired version"
        fi
    else
        print_status "Installing NGINX Ingress Controller with Oracle Cloud Load Balancer..."
        if ! helm install ingress-nginx ingress-nginx/ingress-nginx \
            --namespace ingress-nginx \
            --create-namespace \
            --version $NGINX_INGRESS_VERSION \
            --set controller.service.type=LoadBalancer \
            --set controller.service.annotations."service\.beta\.kubernetes\.io/oci-load-balancer-shape"="flexible" \
            --set controller.service.annotations."service\.beta\.kubernetes\.io/oci-load-balancer-shape-flex-min"="10" \
            --set controller.service.annotations."service\.beta\.kubernetes\.io/oci-load-balancer-shape-flex-max"="10" \
            --set controller.service.annotations."service\.beta\.kubernetes\.io/oci-load-balancer-ssl-ports"="443" \
            --set controller.service.annotations."service\.beta\.kubernetes\.io/oci-load-balancer-security-list-management-mode"="All" \
            --set controller.nodeSelector."kubernetes\.io/arch"=arm64 \
            --set controller.admissionWebhooks.patch.nodeSelector."kubernetes\.io/arch"=arm64 \
            --set defaultBackend.nodeSelector."kubernetes\.io/arch"=arm64; then
            print_error "Failed to install NGINX Ingress Controller"
            print_warning "This might be because ingress-nginx is already installed but not visible to Helm"
            print_status "Checking if ingress-nginx pods exist..."
            if kubectl get pods -n ingress-nginx 2>/dev/null | grep -q ingress-nginx; then
                print_status "ingress-nginx pods found, continuing with existing installation"
            else
                print_error "NGINX Ingress installation failed and no existing installation found"
                exit 1
            fi
        fi
    fi
    
    # Wait for NGINX Ingress Controller to be ready
    print_status "Waiting for NGINX Ingress Controller to be ready..."
    kubectl wait --for=condition=Available --timeout=300s deployment/ingress-nginx-controller -n ingress-nginx
    
    # Wait for Load Balancer to get external IP
    print_status "Waiting for Load Balancer to get external IP..."
    timeout=300
    while [ $timeout -gt 0 ]; do
        EXTERNAL_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        if [ -n "$EXTERNAL_IP" ]; then
            print_status "Load Balancer external IP: $EXTERNAL_IP"
            break
        fi
        echo -n "."
        sleep 5
        timeout=$((timeout - 5))
    done
    
    if [ -z "$EXTERNAL_IP" ]; then
        print_warning "Load Balancer IP not ready yet. Check 'kubectl get svc -n ingress-nginx' later."
    else
        print_status "NGINX Ingress Controller installed successfully"
        print_warning "Make sure to point your DNS records to IP: $EXTERNAL_IP"
        print_warning "  - $API_DOMAIN -> $EXTERNAL_IP"
        print_warning "  - $WWW_DOMAIN -> $EXTERNAL_IP"
    fi
}

# Create SSL ClusterIssuers
create_ssl_issuers() {
    print_header "Creating Let's Encrypt ClusterIssuers"
    
    # Update the email in the SSL setup file
    sed -i.bak "s/admin@residentsapp.com/$EMAIL/g" setup-ssl.yaml
    
    # Apply SSL configuration
    print_status "Creating Let's Encrypt ClusterIssuers..."
    kubectl apply -f setup-ssl.yaml
    
    # Wait for ClusterIssuers to be ready
    print_status "Waiting for ClusterIssuers to be ready..."
    timeout=60
    while [ $timeout -gt 0 ]; do
        if kubectl get clusterissuer letsencrypt-prod -o jsonpath='{.status.conditions[0].status}' 2>/dev/null | grep -q "True"; then
            print_status "Let's Encrypt production ClusterIssuer is ready"
            break
        fi
        echo -n "."
        sleep 2
        timeout=$((timeout - 2))
    done
    
    print_status "SSL ClusterIssuers created successfully"
}

# Create application namespace
create_app_namespace() {
    print_header "Creating Application Namespace"
    
    # Create residents namespace if it doesn't exist
    if ! kubectl get namespace residents >/dev/null 2>&1; then
        print_status "Creating residents namespace..."
        kubectl create namespace residents
        print_status "Residents namespace created successfully"
    else
        print_status "Residents namespace already exists"
    fi
}

# Create Docker registry secret for OCIR
create_docker_registry_secret() {
    print_header "Creating Docker Registry Secret"
    
    # Check if .env file exists in parent directory (from api_service perspective)
    ENV_FILE="../.env"
    if [ ! -f "$ENV_FILE" ]; then
        print_warning ".env file not found at $ENV_FILE"
        print_warning "Please ensure the .env file exists with OCI_USERNAME and OCI_AUTH_TOKEN"
        print_status "Skipping Docker registry secret creation"
        return 0
    fi
    
    # Load environment variables from .env file
    print_status "Loading OCIR credentials from $ENV_FILE..."
    
    # Extract OCI credentials from .env file
    OCI_USERNAME=$(grep "^OCI_USERNAME=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '\r' | tr -d '"')
    OCI_AUTH_TOKEN=$(grep "^OCI_AUTH_TOKEN=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '\r' | tr -d '"')
    
    if [ -z "$OCI_USERNAME" ] || [ -z "$OCI_AUTH_TOKEN" ]; then
        print_warning "OCI_USERNAME or OCI_AUTH_TOKEN not found in .env file"
        print_warning "Please add the following to your .env file:"
        echo "  OCI_USERNAME=your-tenancy-namespace/your-username"
        echo "  OCI_AUTH_TOKEN=your-auth-token"
        print_status "Skipping Docker registry secret creation"
        return 0
    fi
    
    print_status "Found OCI credentials for user: $OCI_USERNAME"
    
    # Create docker registry secret in residents namespace
    print_status "Creating Docker registry secret 'ocirsecret' in residents namespace..."
    
    # Delete existing secret if it exists
    kubectl delete secret ocirsecret -n residents 2>/dev/null || true
    
    # Create the docker registry secret
    kubectl create secret docker-registry ocirsecret \
        --namespace=residents \
        --docker-server="$DOCKER_REGISTRY" \
        --docker-username="$OCI_USERNAME" \
        --docker-password="$OCI_AUTH_TOKEN" \
        --docker-email="$EMAIL"
    
    if [ $? -eq 0 ]; then
        print_status "Docker registry secret 'ocirsecret' created successfully"
        
        # Verify the secret
        if kubectl get secret ocirsecret -n residents >/dev/null 2>&1; then
            print_status "Secret verification successful"
        else
            print_warning "Secret created but verification failed"
        fi
    else
        print_error "Failed to create Docker registry secret"
        return 1
    fi
    
    # Also create the secret in the default namespace for fallback
    print_status "Creating Docker registry secret in default namespace as fallback..."
    kubectl delete secret ocirsecret -n default 2>/dev/null || true
    kubectl create secret docker-registry ocirsecret \
        --namespace=default \
        --docker-server="$DOCKER_REGISTRY" \
        --docker-username="$OCI_USERNAME" \
        --docker-password="$OCI_AUTH_TOKEN" \
        --docker-email="$EMAIL" || print_warning "Failed to create secret in default namespace"
}

# Configure additional load balancer settings
configure_load_balancer() {
    print_header "Configuring Additional Load Balancer Settings"
    
    # Apply additional load balancer configuration if it exists
    if [ -f "setup-load-balancer.yaml" ]; then
        print_status "Applying additional load balancer configuration..."
        kubectl apply -f setup-load-balancer.yaml
        
        print_status "Waiting for load balancer metrics service to be ready..."
        kubectl wait --for=condition=Ready --timeout=60s pod -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx || true
        
        print_status "Additional load balancer configuration applied successfully"
    else
        print_warning "setup-load-balancer.yaml not found, skipping additional configuration"
    fi
}

# Verify installation
verify_installation() {
    print_header "Verifying Installation"
    
    # Check cert-manager
    print_status "Checking cert-manager..."
    kubectl get pods -n cert-manager
    
    # Check NGINX Ingress
    print_status "Checking NGINX Ingress Controller..."
    kubectl get pods -n ingress-nginx
    kubectl get svc -n ingress-nginx
    
    # Check ClusterIssuers
    print_status "Checking ClusterIssuers..."
    kubectl get clusterissuer
    
    # Check residents namespace and secrets
    print_status "Checking residents namespace..."
    kubectl get namespace residents
    
    print_status "Checking Docker registry secrets..."
    kubectl get secrets -n residents | grep ocirsecret || print_warning "ocirsecret not found in residents namespace"
    
    print_status "Installation verification completed"
}

# Display next steps
show_next_steps() {
    print_header "Next Steps"
    
    EXTERNAL_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "PENDING")
    
    echo "1. Point your DNS records to the Load Balancer IP:"
    echo "   API Domain: $API_DOMAIN -> $EXTERNAL_IP"
    echo "   WWW Domain: $WWW_DOMAIN -> $EXTERNAL_IP"
    echo ""
    echo "2. Verify Docker registry secret:"
    echo "   kubectl get secrets -n residents | grep ocirsecret"
    echo ""
    echo "3. Deploy your application using Helm:"
    echo "   helm upgrade --install residents-api ./helmchart \\"
    echo "     -f production-values.yaml \\"
    echo "     --namespace residents \\"
    echo "     --create-namespace"
    echo ""
    echo "4. Check SSL certificate status:"
    echo "   kubectl get certificate -n residents"
    echo "   kubectl describe certificate residents-api-tls -n residents"
    echo ""
    echo "5. Test your deployment:"
    echo "   curl https://$API_DOMAIN/api/health"
    echo "   curl https://$WWW_DOMAIN/api/health"
    echo ""
    print_status "Infrastructure setup completed!"
    print_status "Your application can now pull images from OCIR: $DOCKER_REGISTRY"
}

# Main execution
main() {
    print_header "Oracle Cloud Kubernetes Infrastructure Setup"
    print_status "Setting up SSL and Load Balancer for Always Free tier"
    
    check_kubernetes
    install_cert_manager
    install_nginx_ingress
    create_app_namespace
    create_docker_registry_secret
    configure_load_balancer
    create_ssl_issuers
    verify_installation
    show_next_steps
}

# Check if Helm is installed
if ! command -v helm >/dev/null 2>&1; then
    print_error "Helm is not installed. Please install Helm first:"
    echo "https://helm.sh/docs/intro/install/"
    exit 1
fi

# Run main function
main "$@"