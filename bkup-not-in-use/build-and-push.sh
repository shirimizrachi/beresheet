#!/bin/bash

# Build and Push Script for Oracle Cloud Infrastructure Registry (OCIR)
# This script builds the Docker image for ARM64 and pushes it to OCIR

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Load environment variables from .env file
ENV_FILE="../.env"
if [ -f "$ENV_FILE" ]; then
    print_status "Loading environment variables from $ENV_FILE"
    # Export variables from .env file, handling Windows line endings
    set -a
    while IFS= read -r line || [ -n "$line" ]; do
        # Remove carriage return characters and skip empty lines and comments
        line=$(echo "$line" | tr -d '\r')
        if [[ ! -z "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
            export "$line"
        fi
    done < "$ENV_FILE"
    set +a
else
    print_error ".env file not found at $ENV_FILE"
    exit 1
fi

# Configuration - Update these variables
OCI_REGION="${OCI_REGION:-il-jerusalem-1}"  # Default to il-jerusalem-1, can be overridden
OCI_TENANCY_NAMESPACE="${OCI_TENANCY_NAMESPACE:-axsfrwfafaxr}"
IMAGE_NAME="residents"
IMAGE_TAG="${IMAGE_TAG:-latest}"
BUILD_WEB="${BUILD_WEB:-false}"  # Set to true to build Flutter web apps

# Check if required variables are set
if [ -z "$OCI_TENANCY_NAMESPACE" ]; then
    print_error "OCI_TENANCY_NAMESPACE environment variable is required"
    echo "Set it with: export OCI_TENANCY_NAMESPACE=your-tenancy-namespace"
    exit 1
fi

# Construct full image name
FULL_IMAGE_NAME="${OCI_REGION}.ocir.io/${OCI_TENANCY_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}"

print_status "Building Docker image for ARM64 architecture..."
print_status "Image: ${FULL_IMAGE_NAME}"

# Check if buildx is available
if ! docker buildx version > /dev/null 2>&1; then
    print_error "Docker buildx is required for building ARM64 images"
    print_status "Install buildx: https://docs.docker.com/buildx/working-with-buildx/"
    exit 1
fi

# Create buildx builder if it doesn't exist
if ! docker buildx inspect arm64-builder > /dev/null 2>&1; then
    print_status "Creating buildx builder for ARM64..."
    docker buildx create --name arm64-builder --platform linux/arm64 --use
fi

# Build Flutter web applications if requested
if [ "$BUILD_WEB" = "true" ]; then
    print_status "Building Flutter web applications for production..."
    
    # Go to Flutter project root (two levels up from api_service/deployment)
    cd ../../
    
    # Check if Flutter is installed
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter is not installed or not in PATH"
        exit 1
    fi
    
    # Build web-tenant application directly to api_service directory
    print_status "Building web-tenant application..."
    flutter build web --web-renderer html \
        --dart-define=BUILD_TYPE=tenant \
        --dart-define=ENVIRONMENT=production \
        --output api_service/web-tenant
    
    if [ $? -eq 0 ]; then
        print_status "web-tenant build completed successfully!"
    else
        print_error "web-tenant build failed!"
        exit 1
    fi
    
    # Build web-admin application directly to api_service directory
    print_status "Building web-admin application..."
    flutter build web --web-renderer html \
        --dart-define=BUILD_TYPE=admin \
        --dart-define=ENVIRONMENT=production \
        --output api_service/web-admin
    
    if [ $? -eq 0 ]; then
        print_status "web-admin build completed successfully!"
    else
        print_error "web-admin build failed!"
        exit 1
    fi
    
    # Go back to api_service directory
    cd api_service
else
    print_status "Skipping Flutter web build (BUILD_WEB=false) - using existing build output"
    cd ..  # Change to api_service directory
fi

# Build the image
print_status "Building image..."
docker buildx build \
    --platform linux/arm64 \
    --tag "${FULL_IMAGE_NAME}" \
    --load \
    .

if [ $? -eq 0 ]; then
    print_status "Build completed successfully!"
else
    print_error "Build failed!"
    exit 1
fi

# Login to OCIR
print_status "Logging in to OCIR..."
if [ -z "$OCI_USERNAME" ] || [ -z "$OCI_AUTH_TOKEN" ]; then
    print_error "OCI_USERNAME and OCI_AUTH_TOKEN must be set in .env file"
    exit 1
fi

echo "$OCI_AUTH_TOKEN" | docker login "${OCI_REGION}.ocir.io" -u "$OCI_USERNAME" --password-stdin

if [ $? -eq 0 ]; then
    print_status "Login to OCIR successful!"
else
    print_error "Login to OCIR failed!"
    exit 1
fi

# Push to OCIR
print_status "Pushing image to OCIR..."
docker push "${FULL_IMAGE_NAME}"

if [ $? -eq 0 ]; then
    print_status "Push completed successfully!"
    print_status "Image available at: ${FULL_IMAGE_NAME}"
else
    print_error "Push failed!"
    print_warning "Check your OCI credentials in the .env file and network connectivity"
    exit 1
fi

print_status "Done! You can now deploy using:"
echo "helm upgrade --install residents-api ./helmchart \\"
echo "  --set image.repository=${OCI_REGION}.ocir.io/${OCI_TENANCY_NAMESPACE}/${IMAGE_NAME} \\"
echo "  --set image.tag=${IMAGE_TAG} \\"
echo "  -f production-values.yaml \\"
echo "  --namespace residents \\"
echo "  --create-namespace"