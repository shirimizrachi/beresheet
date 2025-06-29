"""
Create shared Cloudflare R2 Storage bucket for all tenants
This script creates a single bucket named "residents" that is shared across all tenants
with public access enabled via custom domain images.residentsapp.com
"""

import os
import sys
import json
import boto3
from botocore.exceptions import ClientError, NoCredentialsError
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def create_shared_residents_bucket() -> bool:
    """
    Create a shared Cloudflare R2 bucket for all tenants with public access
    
    Returns:
        bool: True if bucket was created or already exists, False if error occurred
    """
    try:
        # Import from residents_config
        from residents_config import get_cloudflare_shared_bucket_name
        
        # Get credentials from environment
        access_key_id = os.getenv('CLOUDFLARE_R2_ACCESS_KEY_ID')
        secret_access_key = os.getenv('CLOUDFLARE_R2_SECRET_ACCESS_KEY')
        account_id = os.getenv('CLOUDFLARE_ACCOUNT_ID')
        
        if not all([access_key_id, secret_access_key, account_id]):
            print("ERROR: CLOUDFLARE_R2_ACCESS_KEY_ID, CLOUDFLARE_R2_SECRET_ACCESS_KEY, and CLOUDFLARE_ACCOUNT_ID environment variables are required")
            return False
        
        # Get bucket name from configuration
        bucket_name = get_cloudflare_shared_bucket_name()
        
        print(f"Creating shared Cloudflare R2 bucket: {bucket_name}")
        print("Configuring for public access with custom domain: images.residentsapp.com")
        
        # Initialize S3-compatible client for R2
        endpoint_url = f"https://{account_id}.r2.cloudflarestorage.com"
        s3_client = boto3.client(
            's3',
            endpoint_url=endpoint_url,
            aws_access_key_id=access_key_id,
            aws_secret_access_key=secret_access_key,
            region_name='auto'  # R2 uses 'auto' as region
        )
        
        # Check if bucket already exists
        bucket_exists = False
        try:
            s3_client.head_bucket(Bucket=bucket_name)
            print(f"✓ Bucket already exists: {bucket_name}")
            bucket_exists = True
        except ClientError as e:
            error_code = e.response['Error']['Code']
            if error_code == '404':
                # Bucket doesn't exist, create it
                print(f"Creating new bucket: {bucket_name}")
            else:
                print(f"✗ Error checking bucket '{bucket_name}': {str(e)}")
                return False
        
        # Create the bucket if it doesn't exist
        if not bucket_exists:
            s3_client.create_bucket(Bucket=bucket_name)
            print(f"✓ Successfully created shared bucket: {bucket_name}")
        
        # Configure public read access policy for the bucket
        public_read_policy = {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Sid": "PublicReadGetObject",
                    "Effect": "Allow",
                    "Principal": "*",
                    "Action": "s3:GetObject",
                    "Resource": f"arn:aws:s3:::{bucket_name}/*"
                }
            ]
        }
        
        try:
            # Apply the public read policy
            s3_client.put_bucket_policy(
                Bucket=bucket_name,
                Policy=json.dumps(public_read_policy)
            )
            print(f"✓ Applied public read policy to bucket: {bucket_name}")
        except ClientError as e:
            print(f"⚠ Warning: Could not apply bucket policy: {str(e)}")
            print("You may need to configure this manually in Cloudflare dashboard")
        
        # Configure CORS for web access
        cors_configuration = {
            'CORSRules': [
                {
                    'AllowedHeaders': ['*'],
                    'AllowedMethods': ['GET', 'HEAD'],
                    'AllowedOrigins': ['*'],
                    'ExposeHeaders': ['ETag'],
                    'MaxAgeSeconds': 3000
                }
            ]
        }
        
        try:
            s3_client.put_bucket_cors(
                Bucket=bucket_name,
                CORSConfiguration=cors_configuration
            )
            print(f"✓ Applied CORS configuration to bucket: {bucket_name}")
        except ClientError as e:
            print(f"⚠ Warning: Could not apply CORS configuration: {str(e)}")
        
        print("\n" + "="*60)
        print("BUCKET CONFIGURATION COMPLETED")
        print("="*60)
        print(f"Bucket Name: {bucket_name}")
        print(f"Custom Domain: images.residentsapp.com")
        print(f"Public Access: ENABLED")
        print(f"Account ID: {account_id}")
        print("\n📋 NEXT STEPS:")
        print("="*60)
        
        print("\n1️⃣ CLOUDFLARE R2 DASHBOARD CONFIGURATION:")
        print("   • Go to https://dash.cloudflare.com")
        print("   • Navigate to R2 Object Storage")
        print(f"   • Click on bucket: {bucket_name}")
        print("   • Go to Settings > Public access")
        print("   • Click 'Connect Custom Domain'")
        print("   • Enter: images.residentsapp.com")
        print("   • Enable 'Allow Access' toggle")
        
        print("\n2️⃣ GODADDY DNS CONFIGURATION:")
        print("   Add this DNS record in your GoDaddy domain settings:")
        print("   ┌─────────────────────────────────────────┐")
        print("   │ Type: CNAME                             │")
        print("   │ Name: images                            │")
        print("   │ Value: [Get from Cloudflare after step 1] │")
        print("   │ TTL: 600 (10 minutes)                  │")
        print("   └─────────────────────────────────────────┘")
        
        print("\n3️⃣ TESTING:")
        print("   Run the test script to verify configuration:")
        print("   python tenants/schema/resources/test_public_bucket.py")
        
        print("\n📖 DETAILED INSTRUCTIONS:")
        print("   See: tenants/schema/resources/DNS_CONFIGURATION_GUIDE.md")
        
        print("\n⚠️  IMPORTANT NOTES:")
        print("   • DNS propagation can take up to 48 hours")
        print("   • Bucket is configured for PUBLIC READ access")
        print("   • All images will be publicly accessible")
        print("   • Don't store sensitive content in this bucket")
        
        print("="*60)
        
        return True
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        if error_code == 'BucketAlreadyExists':
            print(f"✓ Bucket already exists: {bucket_name}")
            return True
        elif error_code == 'BucketAlreadyOwnedByYou':
            print(f"✓ Bucket already owned by you: {bucket_name}")
            return True
        else:
            print(f"✗ Error creating bucket '{bucket_name}': {str(e)}")
            return False
        
    except NoCredentialsError:
        print("✗ Error: Cloudflare R2 credentials not found or invalid")
        return False
        
    except Exception as e:
        print(f"✗ Error creating bucket '{bucket_name}': {str(e)}")
        return False

def main():
    """Main function to handle command line execution"""
    success = create_shared_residents_bucket()
    
    if not success:
        sys.exit(1)
    
    print("Shared Cloudflare R2 bucket setup completed")

if __name__ == "__main__":
    main()