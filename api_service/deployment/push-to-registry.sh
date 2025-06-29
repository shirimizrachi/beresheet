#!/bin/bash

# Docker Build and Push Script for Oracle Cloud Infrastructure Registry (OCIR)
# This script builds the Docker image for ARM64 and pushes it to OCIR
# Prerequisites: Flutter web apps should be built first using build-flutter-production.bat

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

# Check if Flutter web builds exist
print_status "Checking for Flutter web build outputs..."
if [ ! -d "../web-tenant" ] || [ ! -d "../web-admin" ]; then
    print_warning "Flutter web builds not found!"
    print_warning "Please run build-flutter-production.bat first to build the Flutter web applications."
    print_warning "Expected directories:"
    echo "  - api_service/web-tenant"
    echo "  - api_service/web-admin"
    exit 1
fi

# Change to api_service directory for Docker build
cd ..

# Build the image
print_status "Building Docker image..."
docker buildx build \
    --platform linux/arm64 \
    --tag "${FULL_IMAGE_NAME}" \
    --load \
    .

if [ $? -eq 0 ]; then
    print_status "Docker build completed successfully!"
else
    print_error "Docker build failed!"
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