"""
Test script to verify Cloudflare R2 bucket public access configuration
This script tests uploading an image and verifying public access via custom domain
"""

import os
import sys
import requests
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def test_public_bucket_access():
    """Test that the bucket is properly configured for public access"""
    try:
        # Import storage service
        sys.path.append(os.path.join(os.path.dirname(__file__), '../../..'))
        from storage.cloudflare.cloudflare_storage_service import get_cloudflare_storage_service
        
        print("Testing Cloudflare R2 public bucket configuration...")
        print("=" * 60)
        
        # Initialize storage service
        storage_service = get_cloudflare_storage_service()
        
        # Test data
        test_data = b"Test image data for public access verification"
        home_id = 999999  # Test home ID
        tenant_name = "test"
        
        print(f"Bucket Name: {storage_service.bucket_name}")
        print(f"Custom Domain: {storage_service.custom_domain}")
        print(f"Account ID: {storage_service.account_id}")
        print()
        
        # Upload a test image
        print("1. Uploading test image...")
        success, url = storage_service.upload_image(
            home_id=home_id,
            file_name="test_public_access.jpg",
            file_path="test/",
            image_data=test_data,
            content_type="image/jpeg",
            tenant_name=tenant_name
        )
        
        if not success:
            print(f"✗ Upload failed: {url}")
            return False
        
        print(f"✓ Upload successful")
        print(f"Generated URL: {url}")
        print()
        
        # Test public access
        print("2. Testing public access...")
        try:
            response = requests.get(url, timeout=10)
            if response.status_code == 200:
                print("✓ Public access successful!")
                print(f"Response status: {response.status_code}")
                print(f"Content length: {len(response.content)} bytes")
                
                # Verify content matches
                if response.content == test_data:
                    print("✓ Content verification successful!")
                else:
                    print("⚠ Content doesn't match uploaded data")
                
            else:
                print(f"✗ Public access failed with status: {response.status_code}")
                return False
                
        except requests.exceptions.RequestException as e:
            print(f"✗ Request failed: {str(e)}")
            return False
        
        print()
        print("3. Cleaning up test data...")
        # Clean up test file
        cleanup_success = storage_service.delete_image(
            blob_path=f"images/{home_id}/test/test_public_access.jpg",
            tenant_name=tenant_name
        )
        
        if cleanup_success:
            print("✓ Test cleanup successful")
        else:
            print("⚠ Test cleanup failed (file may remain)")
        
        print()
        print("=" * 60)
        print("✅ PUBLIC BUCKET CONFIGURATION TEST PASSED!")
        print("=" * 60)
        return True
        
    except Exception as e:
        print(f"✗ Test failed with error: {str(e)}")
        return False

def main():
    """Main function to run the test"""
    success = test_public_bucket_access()
    
    if not success:
        print("\n❌ Test failed. Check configuration and try again.")
        sys.exit(1)
    
    print("\n🎉 All tests passed! Your bucket is properly configured for public access.")

if __name__ == "__main__":
    main()