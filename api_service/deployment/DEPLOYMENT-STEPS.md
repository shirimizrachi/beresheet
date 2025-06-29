# Step-by-Step Deployment Guide for Residents API

This guide provides complete step-by-step instructions to deploy your Residents API to Oracle Cloud Kubernetes with SSL certificates and domain name www.residentsapp.com.

## 📋 **Prerequisites**

Before starting, ensure you have:
- ✅ Oracle Cloud Infrastructure (OCI) account with Always Free tier
- ✅ Oracle Container Engine for Kubernetes (OKE) cluster running
- ✅ Domain `residentsapp.com` registered with GoDaddy
- ✅ Oracle ATP database set up
- ✅ Cloudflare R2 storage configured
- ✅ `kubectl` configured to connect to your OKE cluster
- ✅ `helm` 3.x installed
- ✅ `docker` installed with buildx support

## 🚀 **Step 1: Deploy Infrastructure (cert-manager + NGINX Ingress + SSL)**

### 1.1 Navigate to deployment directory
```bash
cd api_service/deployment
```

### 1.2 Make scripts executable (Linux/Mac)
```bash
chmod +x setup-infrastructure.sh
chmod +x build-and-push.sh
```

### 1.3 Run infrastructure setup
```bash
# This installs cert-manager, NGINX Ingress Controller, and Let's Encrypt
./setup-infrastructure.sh
```

**What this does:**
- Installs cert-manager for SSL certificate management
- Installs NGINX Ingress Controller with Oracle Cloud Load Balancer
- Creates Let's Encrypt ClusterIssuers for automatic SSL certificates
- Configures everything for ARM64 (Ampere A1) nodes

### 1.4 Get the Load Balancer IP
```bash
# Wait for external IP (may take 5-10 minutes)
kubectl get svc ingress-nginx-controller -n ingress-nginx --watch

# When ready, get the IP
EXTERNAL_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Load Balancer IP: $EXTERNAL_IP"
```

**Save this IP - you'll need it for DNS configuration!**

## 🌐 **Step 2: Configure DNS in GoDaddy**

### 2.1 Login to GoDaddy
1. Go to [GoDaddy DNS Management](https://dcc.godaddy.com/manage/dns)
2. Select your domain `residentsapp.com`

### 2.2 Add/Update DNS Records
Replace `<LOAD_BALANCER_IP>` with the IP from Step 1.4:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | @ | `<LOAD_BALANCER_IP>` | 600 |
| A | www | `<LOAD_BALANCER_IP>` | 600 |
| A | api | `<LOAD_BALANCER_IP>` | 600 |

### 2.3 Verify DNS Propagation
```bash
# Test DNS resolution (may take 5-15 minutes)
nslookup www.residentsapp.com
nslookup api.residentsapp.com
nslookup residentsapp.com

# Should all return your Load Balancer IP
```

## 🐳 **Step 3: Build and Push Docker Image to OCIR**

### 3.1 Set up OCIR Authentication
```bash
# Set your Oracle Cloud details
export OCI_REGION="il-jerusalem-1"
export OCI_TENANCY_NAMESPACE="axsfrwfafaxr"
export OCI_USERNAME="your-oci-username"  # Replace with your OCI username
export OCI_AUTH_TOKEN="your-oci-auth-token"  # Replace with your OCI auth token

# Login to OCIR
docker login ${OCI_REGION}.ocir.io -u ${OCI_TENANCY_NAMESPACE}/${OCI_USERNAME} -p ${OCI_AUTH_TOKEN}
```

### 3.2 Build and Push Image
```bash
# Method 1: Use the automated script
./build-and-push.sh

# Method 2: Manual commands
docker buildx build --platform linux/arm64 -t ${OCI_REGION}.ocir.io/${OCI_TENANCY_NAMESPACE}/residents:latest .
docker push ${OCI_REGION}.ocir.io/${OCI_TENANCY_NAMESPACE}/residents:latest
```

### 3.3 Create Kubernetes Image Pull Secret
```bash
# Create secret for pulling images from OCIR
kubectl create secret docker-registry ocirsecret \
  --docker-server=${OCI_REGION}.ocir.io \
  --docker-username=${OCI_TENANCY_NAMESPACE}/${OCI_USERNAME} \
  --docker-password=${OCI_AUTH_TOKEN} \
  --docker-email=ranmizrachi@gmail.com
```

## ⚙️ **Step 4: Configure Production Values**

### 4.1 Update production.yaml with your credentials
```bash
# Edit the production values file
nano production.yaml  # or use your preferred editor
```

**Update these values in `production.yaml`:**

```yaml
# Image configuration
image:
  repository: "iad.ocir.io/YOUR_TENANCY_NAMESPACE/residents-api"  # Your actual OCIR repo

# Secrets - CRITICAL: Replace with your actual values
secrets:
  oracleCredentials:
    username: "your_actual_oracle_username"
    password: "your_actual_oracle_password"
  
  cloudflareCredentials:
    accessKeyId: "your_actual_cloudflare_access_key"
    secretAccessKey: "your_actual_cloudflare_secret_key"
    accountId: "your_actual_cloudflare_account_id"
  
  appSecrets:
    jwtSecret: "your_strong_random_jwt_secret_32_chars_min"
```

### 4.2 Generate JWT Secret
```bash
# Generate a secure JWT secret
openssl rand -hex 32
# Or use: python -c "import secrets; print(secrets.token_hex(32))"
```

## 🚀 **Step 5: Deploy Your Service**

### 5.1 Deploy Application
```bash
# Deploy using Helm
helm upgrade --install residents-api ./helmchart \
  -f production.yaml \
  --namespace residents-api \
  --create-namespace
```

### 5.2 Monitor Deployment
```bash
# Watch pods start up
kubectl get pods -n residents-api --watch

# Check deployment status
kubectl get all -n residents-api
```

### 5.3 Wait for SSL Certificate
```bash
# Monitor certificate issuance (can take 5-10 minutes)
kubectl get certificate -n residents-api --watch

# Check certificate details
kubectl describe certificate residents-api-tls -n residents-api
```

## ✅ **Step 6: Verify Deployment**

### 6.1 Check All Components
```bash
# Check infrastructure
kubectl get pods -n cert-manager
kubectl get pods -n ingress-nginx
kubectl get pods -n residents-api

# Check services and ingress
kubectl get svc -n residents-api
kubectl get ingress -n residents-api

# Check SSL certificate
kubectl get certificate -n residents-api
```

### 6.2 Test Your API
```bash
# Test HTTP (should redirect to HTTPS)
curl -I http://www.residentsapp.com/api/health

# Test HTTPS
curl -I https://www.residentsapp.com/api/health

# Test API endpoint
curl https://www.residentsapp.com/api/health
```

### 6.3 Expected Response
```json
{
  "status": "healthy",
  "events_count": 0
}
```

## 🔧 **Troubleshooting Common Issues**

### SSL Certificate Pending
```bash
# Check certificate challenges
kubectl get challenges -n residents-api
kubectl describe challenges -n residents-api

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

### Pods Not Starting
```bash
# Check pod logs
kubectl logs -n residents-api deployment/residents-api

# Check events
kubectl get events -n residents-api --sort-by=.metadata.creationTimestamp
```

### DNS Issues
```bash
# Verify DNS from multiple locations
dig www.residentsapp.com @8.8.8.8
dig www.residentsapp.com @1.1.1.1

# Check ingress status
kubectl describe ingress residents-api -n residents-api
```

### Image Pull Issues
```bash
# Check image pull secret
kubectl get secret ocirsecret -o yaml

# Verify OCIR authentication
docker pull ${OCI_REGION}.ocir.io/${OCI_TENANCY_NAMESPACE}/residents-api:latest
```

## 📊 **Post-Deployment Monitoring**

### View Application Logs
```bash
# Real-time logs
kubectl logs -f -n residents-api deployment/residents-api

# Recent logs
kubectl logs --tail=100 -n residents-api deployment/residents-api
```

### Monitor Resource Usage
```bash
# Check resource usage
kubectl top pods -n residents-api
kubectl top nodes

# Check HPA status
kubectl get hpa -n residents-api
```

### SSL Certificate Monitoring
```bash
# Check certificate expiry
kubectl get certificate residents-api-tls -n residents-api -o yaml

# Monitor certificate renewal
kubectl logs -n cert-manager deployment/cert-manager | grep residents-api
```

## 🔄 **Updating Your Application**

### Deploy New Version
```bash
# Build new image with version tag
docker buildx build --platform linux/arm64 -t ${OCI_REGION}.ocir.io/${OCI_TENANCY_NAMESPACE}/residents-api:v1.1.0 .
docker push ${OCI_REGION}.ocir.io/${OCI_TENANCY_NAMESPACE}/residents-api:v1.1.0

# Update deployment
helm upgrade residents-api ./helmchart \
  -f production.yaml \
  --set image.tag=v1.1.0 \
  --namespace residents-api
```

## 🎯 **Success Indicators**

Your deployment is successful when:
- ✅ `kubectl get pods -n residents-api` shows all pods `Running`
- ✅ `kubectl get certificate -n residents-api` shows certificate `Ready: True`
- ✅ `curl -I https://www.residentsapp.com/api/health` returns `200 OK`
- ✅ Browser shows valid SSL certificate for www.residentsapp.com
- ✅ No SSL warnings in browser

## 📞 **Getting Help**

If you encounter issues:
1. **Check logs**: `kubectl logs -n residents-api deployment/residents-api`
2. **Check events**: `kubectl get events -n residents-api`
3. **Verify DNS**: Use online DNS checker tools
4. **Test locally**: Ensure your app works locally first
5. **Check Oracle Cloud Console**: Verify load balancer status

Your Residents API should now be live at https://www.residentsapp.com with automatic SSL certificates!