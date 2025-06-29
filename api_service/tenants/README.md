# Residents API Deployment Guide for Oracle Cloud Kubernetes (OKE)

This guide provides step-by-step instructions for deploying the Residents API to Oracle Cloud's free ARM-based Kubernetes cluster with Let's Encrypt SSL certificates.

## Prerequisites

1. **Oracle Cloud Infrastructure (OCI) Account** with Always Free tier
2. **Oracle Container Engine for Kubernetes (OKE)** cluster set up
3. **Oracle Cloud Infrastructure Registry (OCIR)** access
4. **Domain configured** (residentsapp.com) with DNS pointing to OKE cluster
5. **kubectl** configured to connect to your OKE cluster
6. **Helm 3.x** installed
7. **Docker** installed for building images

## Architecture Overview

- **Kubernetes**: Oracle Cloud Kubernetes (OKE) with ARM64 Ampere A1 nodes
- **Container Registry**: Oracle Cloud Infrastructure Registry (OCIR)
- **Load Balancer**: Oracle Cloud Network Load Balancer (Always Free)
- **SSL Certificates**: Let's Encrypt with cert-manager
- **Database**: Oracle Autonomous Transaction Processing (ATP)
- **Storage**: Cloudflare R2

## Step 1: Build and Push Docker Image to OCIR

### 1.1 Set up OCIR Authentication

```bash
# Replace with your region and tenancy information
export OCI_REGION="iad"  # or your region (iad, phx, fra, etc.)
export OCI_TENANCY_NAMESPACE="your-tenancy-namespace"
export OCI_USERNAME="your-username"
export OCI_AUTH_TOKEN="your-auth-token"

# Login to OCIR
docker login ${OCI_REGION}.ocir.io -u ${OCI_TENANCY_NAMESPACE}/${OCI_USERNAME} -p ${OCI_AUTH_TOKEN}
```

### 1.2 Build and Push Image

```bash
# Navigate to api_service directory
cd api_service

# Build ARM64 image for Oracle Cloud Ampere A1
docker buildx build --platform linux/arm64 -t ${OCI_REGION}.ocir.io/${OCI_TENANCY_NAMESPACE}/residents-api:latest .

# Push to OCIR
docker push ${OCI_REGION}.ocir.io/${OCI_TENANCY_NAMESPACE}/residents-api:latest
```

## Step 2: Create Kubernetes Image Pull Secret

```bash
# Create secret for pulling images from OCIR
kubectl create secret docker-registry ocirsecret \
  --docker-server=${OCI_REGION}.ocir.io \
  --docker-username=${OCI_TENANCY_NAMESPACE}/${OCI_USERNAME} \
  --docker-password=${OCI_AUTH_TOKEN} \
  --docker-email=your-email@example.com
```

## Step 3: Install and Configure cert-manager for Let's Encrypt

### 3.1 Install cert-manager

```bash
# Add cert-manager Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.0 \
  --set installCRDs=true
```

### 3.2 Create Let's Encrypt ClusterIssuer

```yaml
# Save as letsencrypt-clusterissuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@residentsapp.com  # Replace with your email
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

Apply the ClusterIssuer:
```bash
kubectl apply -f letsencrypt-clusterissuer.yaml
```

## Step 4: Install NGINX Ingress Controller

```bash
# Install NGINX Ingress Controller for Oracle Cloud
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/oci-load-balancer-shape"="flexible" \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/oci-load-balancer-shape-flex-min"="10" \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/oci-load-balancer-shape-flex-max"="10"
```

Get the external IP:
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

## Step 5: Configure DNS

Point your domain `api.residentsapp.com` to the external IP address from the load balancer.

## Step 6: Configure Helm Values

### 6.1 Create Production Values File

Create `production-values.yaml`:

```yaml
# Image configuration
image:
  repository: "iad.ocir.io/your-tenancy-namespace/residents-api"  # Update with your OCIR details
  tag: "latest"

# Ingress configuration
ingress:
  hosts:
    - host: api.residentsapp.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: residents-api-tls
      hosts:
        - api.residentsapp.com

# Environment variables - UPDATE THESE WITH YOUR ACTUAL VALUES
env:
  API_BASE_URL: "https://api.residentsapp.com"
  CORS_ORIGINS: "https://residentsapp.com,https://www.residentsapp.com"

# Secrets - UPDATE THESE WITH YOUR ACTUAL CREDENTIALS
secrets:
  oracleCredentials:
    username: "your-oracle-username"
    password: "your-oracle-atp-password"
  
  cloudflareCredentials:
    accessKeyId: "your-cloudflare-r2-access-key"
    secretAccessKey: "your-cloudflare-r2-secret-key"
    accountId: "your-cloudflare-account-id"
  
  appSecrets:
    jwtSecret: "your-random-jwt-secret-key"

# Resource configuration for OKE free tier
resources:
  limits:
    cpu: 1500m
    memory: 4Gi
  requests:
    cpu: 500m
    memory: 1Gi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 4
```

## Step 7: Deploy the Application

```bash
# Deploy using Helm
helm install residents-api ./deployment/helmchart \
  -f production-values.yaml \
  --namespace residents-api \
  --create-namespace
```

## Step 8: Verify Deployment

### 8.1 Check Pods
```bash
kubectl get pods -n residents-api
```

### 8.2 Check Services
```bash
kubectl get svc -n residents-api
```

### 8.3 Check Ingress
```bash
kubectl get ingress -n residents-api
```

### 8.4 Check SSL Certificate
```bash
kubectl get certificate -n residents-api
kubectl describe certificate residents-api-tls -n residents-api
```

### 8.5 Test API
```bash
curl https://api.residentsapp.com/api/health
```

## Step 9: Environment Variables Configuration

Your application uses the following environment variables:

### Oracle ATP Database
- `ORACLE_USER`: Your Oracle ATP username
- `ORACLE_ATP_PASSWORD`: Your Oracle ATP password
- `ORACLE_DATABASE_NAME`: "residents"
- `ORACLE_SERVICE_LEVEL`: "residents_medium"

### Cloudflare R2 Storage
- `CLOUDFLARE_R2_ACCESS_KEY_ID`: Your Cloudflare R2 access key
- `CLOUDFLARE_R2_SECRET_ACCESS_KEY`: Your Cloudflare R2 secret key
- `CLOUDFLARE_ACCOUNT_ID`: Your Cloudflare account ID
- `CLOUDFLARE_R2_BUCKET_NAME`: "residents-storage"

### Application Configuration
- `JWT_SECRET_KEY`: Random secret for JWT signing
- `API_BASE_URL`: "https://api.residentsapp.com"
- `CORS_ORIGINS`: Allowed CORS origins

## Troubleshooting

### Check Pod Logs
```bash
kubectl logs -n residents-api deployment/residents-api
```

### Check Events
```bash
kubectl get events -n residents-api --sort-by=.metadata.creationTimestamp
```

### SSL Certificate Issues
```bash
kubectl describe certificate residents-api-tls -n residents-api
kubectl logs -n cert-manager deployment/cert-manager
```

### Ingress Issues
```bash
kubectl describe ingress residents-api -n residents-api
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

## Updating the Application

```bash
# Build and push new image
docker buildx build --platform linux/arm64 -t ${OCI_REGION}.ocir.io/${OCI_TENANCY_NAMESPACE}/residents-api:v1.1.0 .
docker push ${OCI_REGION}.ocir.io/${OCI_TENANCY_NAMESPACE}/residents-api:v1.1.0

# Update Helm deployment
helm upgrade residents-api ./deployment/helmchart \
  -f production-values.yaml \
  --set image.tag=v1.1.0 \
  --namespace residents-api
```

## Cost Optimization

The configuration is optimized for Oracle Cloud's Always Free tier:
- Uses ARM64 Ampere A1 instances
- Configured for 4 OCPUs and 24GB RAM total
- Network Load Balancer in always free limits
- HPA configured to scale between 2-4 replicas

## Security Notes

1. Store sensitive values in Kubernetes secrets
2. Use RBAC for service accounts
3. Enable network policies if needed
4. Regular security updates for base images
5. Monitor resource usage to stay within free tier limits

## Manual Steps Summary

1. ✅ **OCIR Setup**: Configure authentication and push Docker image
2. ✅ **Kubernetes Secrets**: Create image pull secret for OCIR
3. ✅ **cert-manager**: Install and configure Let's Encrypt ClusterIssuer
4. ✅ **NGINX Ingress**: Install ingress controller with OCI load balancer
5. ✅ **DNS Configuration**: Point domain to load balancer IP
6. ✅ **Environment Variables**: Update production-values.yaml with your credentials
7. ✅ **Deploy Application**: Use Helm to deploy the application
8. ✅ **Verify**: Test all components are working

All Kubernetes manifests and Helm templates are provided and configured for Oracle Cloud's free tier ARM64 environment.