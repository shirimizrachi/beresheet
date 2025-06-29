# Cloudflare R2 Public Bucket with Custom Domain Configuration

## Overview
This guide explains how to configure your Cloudflare R2 bucket for public access using the custom domain `images.residentsapp.com` and the required DNS settings in GoDaddy.

## Cloudflare R2 Configuration

### 1. Enable Public Access
The bucket creation script automatically configures:
- ✅ Public read policy for all objects
- ✅ CORS configuration for web access
- ✅ Custom domain support

### 2. Cloudflare Dashboard Configuration
After running the bucket creation script, you need to configure the custom domain in your Cloudflare dashboard:

1. **Log into Cloudflare Dashboard**
   - Go to https://dash.cloudflare.com
   - Select your account

2. **Navigate to R2 Object Storage**
   - Click on "R2 Object Storage" in the sidebar
   - Find your bucket (`residents-images` by default)

3. **Configure Custom Domain**
   - Click on your bucket name
   - Go to "Settings" tab
   - Scroll down to "Public access"
   - Click "Connect Custom Domain"
   - Enter: `images.residentsapp.com`
   - Click "Connect Domain"

4. **Enable Public Access**
   - In the same "Public access" section
   - Toggle "Allow Access" to ON
   - Confirm the action

## GoDaddy DNS Configuration

### Required DNS Records
You need to add the following DNS records in your GoDaddy domain management:

#### Option 1: CNAME Record (Recommended)
```
Type: CNAME
Name: images
Value: [CLOUDFLARE_CNAME_TARGET]
TTL: 600 (10 minutes)
```

#### Option 2: A Record (Alternative)
```
Type: A
Name: images
Value: [CLOUDFLARE_IP_ADDRESS]
TTL: 600 (10 minutes)
```

### Step-by-Step GoDaddy Configuration

1. **Access GoDaddy DNS Management**
   - Log into your GoDaddy account
   - Go to "My Products"
   - Find `residentsapp.com` domain
   - Click "DNS" or "Manage DNS"

2. **Add DNS Record**
   - Click "Add" or "Add Record"
   - Select record type (CNAME or A)
   - Enter the details from above
   - Save the record

3. **Get Cloudflare Target Values**
   After configuring the custom domain in Cloudflare R2:
   - Cloudflare will provide the CNAME target or IP address
   - Copy this value and use it in your GoDaddy DNS record
   - The target typically looks like: `[bucket-name].r2.dev.workers.dev`

### DNS Propagation
- DNS changes can take 24-48 hours to fully propagate
- You can check propagation status using tools like:
  - https://dnschecker.org
  - https://whatsmydns.net

## Testing the Configuration

### 1. Verify DNS Resolution
```bash
# Test DNS resolution
nslookup images.residentsapp.com

# Test with dig (Linux/Mac)
dig images.residentsapp.com
```

### 2. Test Image Access
Once configured, images will be accessible via:
```
https://images.residentsapp.com/[tenant_name]/images/[home_id]/[path]/[filename]
```

Example:
```
https://images.residentsapp.com/demo/images/1/events/images/event123.jpg
```

### 3. Verify in Browser
- Open the URL in a browser
- Image should load without authentication
- Check browser developer tools for any CORS issues

## Environment Variables

### Required Environment Variables
Ensure these are set in your `.env` file:

```env
# Cloudflare R2 Credentials
CLOUDFLARE_R2_ACCESS_KEY_ID=your_access_key
CLOUDFLARE_R2_SECRET_ACCESS_KEY=your_secret_key
CLOUDFLARE_ACCOUNT_ID=your_account_id

# Custom Domain (optional - defaults to images.residentsapp.com)
CLOUDFLARE_R2_CUSTOM_DOMAIN=images.residentsapp.com

# Bucket Name (optional - defaults to residents-images)
CLOUDFLARE_SHARED_BUCKET_NAME=residents-images
```

## Troubleshooting

### Common Issues

1. **403 Forbidden Error**
   - Check bucket policy is properly applied
   - Verify public access is enabled in Cloudflare dashboard

2. **DNS Not Resolving**
   - Wait for DNS propagation (up to 48 hours)
   - Verify DNS records are correctly configured
   - Check for typos in domain name

3. **CORS Errors**
   - CORS is automatically configured by the script
   - Verify CORS settings in Cloudflare R2 dashboard

4. **SSL Certificate Issues**
   - Cloudflare automatically provides SSL certificates
   - May take a few minutes to provision after domain setup

### Support Resources
- Cloudflare R2 Documentation: https://developers.cloudflare.com/r2/
- GoDaddy DNS Help: https://www.godaddy.com/help/dns-management
- DNS Propagation Checker: https://dnschecker.org

## Security Considerations

### Public Access Warning
- The bucket is configured for PUBLIC READ access
- Anyone with the URL can access the images
- Do not store sensitive or private images in this bucket
- Consider implementing access controls at the application level if needed

### Best Practices
- Use descriptive but not sensitive file names
- Implement rate limiting at the application level
- Monitor bucket usage and costs
- Regularly audit public content