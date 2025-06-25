"""
Create Cloudflare R2 Storage bucket for tenant
This script creates a bucket with the naming convention: [tenant-name]-images
"""

import os
import sys
import boto3
from botocore.exceptions import ClientError, NoCredentialsError
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def create_cloudflare_bucket(tenant_name: str) -> bool:
    """
    Create a Cloudflare R2 bucket for the specified tenant
    
    Args:
        tenant_name: Name of the tenant (used for bucket naming)
    
    Returns:
        bool: True if bucket was created or already exists, False if error occurred
    """
    try:
        # Get credentials from environment
        access_key_id = os.getenv('CLOUDFLARE_R2_ACCESS_KEY_ID')
        secret_access_key = os.getenv('CLOUDFLARE_R2_SECRET_ACCESS_KEY')
        account_id = os.getenv('CLOUDFLARE_ACCOUNT_ID')
        
        if not all([access_key_id, secret_access_key, account_id]):
            print("ERROR: CLOUDFLARE_R2_ACCESS_KEY_ID, CLOUDFLARE_R2_SECRET_ACCESS_KEY, and CLOUDFLARE_ACCOUNT_ID environment variables are required")
            return False
        
        # Generate bucket name
        bucket_name = f"{tenant_name}-images"
        
        print(f"Creating Cloudflare R2 bucket: {bucket_name}")
        
        # Initialize S3-compatible client for R2
        endpoint_url = f"https://{account_id}.r2.cloudflarestorage.com"
        s3_client = boto3.client(
            's3',
            endpoint_url=endpoint_url,
            aws_access_key_id=access_key_id,
            aws_secret_access_key=secret_access_key,
            region_name='auto'  # R2 uses 'auto' as region
        )
        
        # Create the bucket
        s3_client.create_bucket(Bucket=bucket_name)
        
        print(f"✓ Successfully created bucket: {bucket_name}")
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
    if len(sys.argv) != 2:
        print("Usage: python create_bucket_cloudflare.py <tenant_name>")
        print("Example: python create_bucket_cloudflare.py demo")
        sys.exit(1)
    
    tenant_name = sys.argv[1]
    
    # Validate tenant name (basic validation)
    if not tenant_name or not tenant_name.replace('-', '').replace('_', '').isalnum():
        print("ERROR: Tenant name must contain only alphanumeric characters, hyphens, and underscores")
        sys.exit(1)
    
    success = create_cloudflare_bucket(tenant_name)
    
    if not success:
        sys.exit(1)
    
    print(f"Cloudflare R2 bucket setup completed for tenant: {tenant_name}")

if __name__ == "__main__":
    main()