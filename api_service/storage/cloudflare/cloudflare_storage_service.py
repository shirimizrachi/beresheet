"""
Cloudflare R2 Storage Service for handling image uploads
Shared service for uploading images to Cloudflare R2 Storage
"""

import os
import uuid
import io
from datetime import datetime, timedelta
from typing import Optional, Tuple
import boto3
from botocore.exceptions import ClientError, NoCredentialsError
import mimetypes
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()


class CloudflareStorageService:
    def __init__(self, tenant_name: str = None):
        """Initialize Cloudflare R2 Storage Service with credentials from environment"""
        self.access_key_id = os.getenv('CLOUDFLARE_R2_ACCESS_KEY_ID')
        self.secret_access_key = os.getenv('CLOUDFLARE_R2_SECRET_ACCESS_KEY')
        self.account_id = os.getenv('CLOUDFLARE_ACCOUNT_ID')
        self.custom_domain = os.getenv('CLOUDFLARE_R2_CUSTOM_DOMAIN')  # Optional custom domain
        self.tenant_name = tenant_name
        
        # Use a default bucket name - actual bucket will be determined by tenant_name in method calls
        self.bucket_name = os.getenv('CLOUDFLARE_R2_BUCKET_NAME', 'default-bucket')
        
        if not all([self.access_key_id, self.secret_access_key, self.account_id]):
            raise ValueError("CLOUDFLARE_R2_ACCESS_KEY_ID, CLOUDFLARE_R2_SECRET_ACCESS_KEY, and CLOUDFLARE_ACCOUNT_ID environment variables are required")
        
        try:
            # Cloudflare R2 endpoint
            self.endpoint_url = f"https://{self.account_id}.r2.cloudflarestorage.com"
            
            # Initialize S3-compatible client for R2
            self.s3_client = boto3.client(
                's3',
                endpoint_url=self.endpoint_url,
                aws_access_key_id=self.access_key_id,
                aws_secret_access_key=self.secret_access_key,
                region_name='auto'  # R2 uses 'auto' as region
            )
            
            # Test connection
            self._test_connection()
            
        except Exception as e:
            raise ValueError(f"Failed to initialize Cloudflare R2 Storage Service: {str(e)}")
    
    def _test_connection(self):
        """Test the connection to Cloudflare R2"""
        try:
            # Test with default bucket, actual buckets will be tested when used
            self.s3_client.head_bucket(Bucket=self.bucket_name)
        except ClientError as e:
            # Don't fail initialization if default bucket doesn't exist
            # Tenant-specific buckets will be tested when used
            pass
    
    def get_container_name(self, tenant_name: str = None) -> str:
        """Get container name for a tenant (now just returns 'images' since we use separate buckets per tenant)"""
        # Since we now use separate buckets per tenant, we just use 'images' as the container/prefix
        return "images"
    
    def _get_content_type(self, filename: str) -> str:
        """Get content type based on file extension"""
        content_type, _ = mimetypes.guess_type(filename)
        if content_type and content_type.startswith('image/'):
            return content_type
        return 'image/jpeg'  # Default to JPEG for images
    
    def _validate_image(self, content_type: Optional[str], file_size: int) -> bool:
        """Validate that the uploaded file is an image and within size limits"""
        # Check content type
        if not content_type or not content_type.startswith('image/'):
            return False
        
        # Check file size (limit to 10MB)
        max_size = 10 * 1024 * 1024  # 10MB
        if file_size > max_size:
            return False
        
        return True
    
    def _generate_presigned_url(self, object_key: str, bucket_name: str = None, expiry_seconds: int = 604800) -> str:
        """Generate a presigned URL for an object with 1 week expiration by default (Cloudflare R2 maximum)"""
        try:
            # Use provided bucket_name or fall back to instance bucket_name
            effective_bucket_name = bucket_name or self.bucket_name
            
            # Generate presigned URL
            presigned_url = self.s3_client.generate_presigned_url(
                'get_object',
                Params={'Bucket': effective_bucket_name, 'Key': object_key},
                ExpiresIn=expiry_seconds
            )
            
            # If custom domain is configured, replace the endpoint URL
            if self.custom_domain:
                # Replace the R2 endpoint with custom domain
                presigned_url = presigned_url.replace(
                    f"{self.account_id}.r2.cloudflarestorage.com/{effective_bucket_name}/",
                    f"{self.custom_domain}/"
                )
            
            return presigned_url
            
        except Exception as e:
            print(f"Error generating presigned URL: {e}")
            # Fallback to public URL (though it might not work without proper configuration)
            if self.custom_domain:
                return f"https://{self.custom_domain}/{object_key}"
            else:
                return f"{self.endpoint_url}/{effective_bucket_name}/{object_key}"
    
    def upload_image(self, home_id: int, file_name: str, file_path: str, image_data: bytes,
                    content_type: Optional[str] = None, tenant_name: str = None) -> Tuple[bool, str]:
        """
        Upload an image to Cloudflare R2 Storage (generic method)
        
        Args:
            home_id: The home ID for organizing files
            file_name: The desired filename (including extension)
            file_path: The relative path within the home folder (e.g., "events/images/")
            image_data: The image data as bytes
            content_type: MIME content type of the image
            tenant_name: Name of the tenant (used for bucket naming)
        
        Returns:
            Tuple of (success: bool, url_or_error_message: str)
        """
        try:
            # Validate image
            if not self._validate_image(content_type, len(image_data)):
                return False, "Invalid image file or file too large (max 10MB)"
            
            # Determine bucket name from tenant_name (required for Cloudflare)
            if tenant_name:
                bucket_name = f"{tenant_name}-images"
            else:
                raise ValueError("tenant_name is required for Cloudflare storage operations")
            
            # Get container name for tenant (now just returns 'images' since we use separate buckets)
            container_name = self.get_container_name(tenant_name)
            
            # Clean file_path (remove leading/trailing slashes, ensure it ends with /)
            file_path = file_path.strip('/')
            if file_path and not file_path.endswith('/'):
                file_path += '/'
            
            # Create object key: [container_name]/[homeId]/[file_path][file_name]
            object_key = f"{container_name}/{home_id}/{file_path}{file_name}"
            
            # Determine content type
            if not content_type:
                content_type = self._get_content_type(file_name)
            
            # Upload to Cloudflare R2
            self.s3_client.put_object(
                Bucket=bucket_name,
                Key=object_key,
                Body=image_data,
                ContentType=content_type
            )
            
            # Generate presigned URL with 1 week expiration (Cloudflare R2 maximum)
            presigned_url = self._generate_presigned_url(object_key, bucket_name)
            
            return True, presigned_url
            
        except ClientError as e:
            return False, f"Cloudflare R2 error: {str(e)}"
        except Exception as e:
            return False, f"Unexpected error: {str(e)}"

    def upload_event_image(self, home_id: int, event_id: str, image_data: bytes,
                          original_filename: str, content_type: Optional[str] = None, tenant_name: str = None) -> Tuple[bool, str]:
        """
        Upload an event image to Cloudflare R2 Storage
        
        Args:
            home_id: The home ID for organizing files
            event_id: The event ID to use as filename
            image_data: The image data as bytes
            original_filename: Original filename (for extension detection)
            content_type: MIME content type of the image
            tenant_name: Name of the tenant (used for container naming)
        
        Returns:
            Tuple of (success: bool, url_or_error_message: str)
        """
        # Get file extension from original filename
        file_extension = os.path.splitext(original_filename)[1].lower()
        if not file_extension:
            file_extension = '.jpg'  # Default extension
        
        # Use event_id as filename
        file_name = f"{event_id}{file_extension}"
        
        return self.upload_image(home_id, file_name, "events/images/", image_data, content_type, tenant_name)
    
    def upload_user_photo(self, home_id: int, user_id: str, image_data: bytes,
                         original_filename: str, content_type: Optional[str] = None, tenant_name: str = None) -> Tuple[bool, str]:
        """
        Upload a user photo to Cloudflare R2 Storage
        
        Args:
            home_id: The home ID for organizing files
            user_id: The user ID
            image_data: The image data as bytes
            original_filename: Original filename (for extension detection)
            content_type: MIME content type of the image
            tenant_name: Name of the tenant (used for container naming)
        
        Returns:
            Tuple of (success: bool, url_or_error_message: str)
        """
        # Get file extension from original filename
        file_extension = os.path.splitext(original_filename)[1].lower()
        if not file_extension:
            file_extension = '.jpg'  # Default extension
        
        # Use user_id as filename
        file_name = f"{user_id}{file_extension}"
        
        return self.upload_image(home_id, file_name, "users/photos/", image_data, content_type, tenant_name)
    
    def upload_event_instructor_photo(self, home_id: int, instructor_id: str, image_data: bytes,
                                    original_filename: str, content_type: Optional[str] = None, tenant_name: str = None) -> Tuple[bool, str]:
        """
        Upload an event instructor photo to Cloudflare R2 Storage
        
        Args:
            home_id: The home ID for organizing files
            instructor_id: The instructor ID
            image_data: The image data as bytes
            original_filename: Original filename (for extension detection)
            content_type: MIME content type of the image
            tenant_name: Name of the tenant (used for container naming)
        
        Returns:
            Tuple of (success: bool, url_or_error_message: str)
        """
        # Get file extension from original filename
        file_extension = os.path.splitext(original_filename)[1].lower()
        if not file_extension:
            file_extension = '.jpg'  # Default extension
        
        # Use instructor_id as filename
        file_name = f"instructor_{instructor_id}{file_extension}"
        
        return self.upload_image(home_id, file_name, "instructors/photos/", image_data, content_type, tenant_name)
    
    def delete_image(self, blob_path: str, tenant_name: str = None) -> bool:
        """
        Delete an image from Cloudflare R2 Storage
        
        Args:
            blob_path: The path of the object to delete (should include container name)
            tenant_name: Name of the tenant (used for container naming)
        
        Returns:
            bool: True if successful, False otherwise
        """
        try:
            # If blob_path doesn't include container name, add it
            if tenant_name and not blob_path.startswith(self.get_container_name(tenant_name)):
                container_name = self.get_container_name(tenant_name)
                object_key = f"{container_name}/{blob_path}"
            else:
                object_key = blob_path
            
            self.s3_client.delete_object(Bucket=self.bucket_name, Key=object_key)
            return True
        except Exception:
            return False
    
    def get_image_url(self, blob_path: str, tenant_name: str = None) -> Optional[str]:
        """
        Get the presigned URL for an image
        
        Args:
            blob_path: The path of the object (should include container name)
            tenant_name: Name of the tenant (used for container naming)
        
        Returns:
            str: The presigned URL or None if not found
        """
        try:
            # If blob_path doesn't include container name, add it
            if tenant_name and not blob_path.startswith(self.get_container_name(tenant_name)):
                container_name = self.get_container_name(tenant_name)
                object_key = f"{container_name}/{blob_path}"
            else:
                object_key = blob_path
            
            # Check if object exists
            try:
                self.s3_client.head_object(Bucket=self.bucket_name, Key=object_key)
                return self._generate_presigned_url(object_key)
            except ClientError as e:
                if e.response['Error']['Code'] == '404':
                    return None
                raise
        except Exception:
            return None
    
    def upload_request_media(self, home_id: int, request_id: str, message_id: str,
                           media_data: bytes, original_filename: str,
                           content_type: Optional[str] = None, tenant_name: str = None) -> Tuple[bool, str]:
        """
        Upload media (image, video, or audio) for a service request message
        
        Args:
            home_id: The home ID for organizing files
            request_id: The request ID
            message_id: The message ID
            media_data: The media data as bytes
            original_filename: Original filename (for extension detection)
            content_type: MIME content type of the media
            tenant_name: Name of the tenant (used for container naming)
        
        Returns:
            Tuple of (success: bool, url_or_error_message: str)
        """
        try:
            # Determine bucket name from tenant_name (required for Cloudflare)
            if tenant_name:
                bucket_name = f"{tenant_name}-images"
            else:
                raise ValueError("tenant_name is required for Cloudflare storage operations")
            
            # Get container name for tenant
            container_name = self.get_container_name(tenant_name)
            
            # Get file extension from original filename
            file_extension = os.path.splitext(original_filename)[1].lower()
            if not file_extension:
                # Determine extension from content type
                if content_type:
                    if content_type.startswith('image/'):
                        file_extension = '.jpg'
                    elif content_type.startswith('video/'):
                        file_extension = '.mp4'
                    elif content_type.startswith('audio/'):
                        file_extension = '.m4a'
                    else:
                        file_extension = '.bin'
                else:
                    file_extension = '.bin'
            
            # Create filename with message_id and extension
            file_name = f"{message_id}{file_extension}"
            
            # Create object key: [container_name]/[homeId]/requests/[request_id]/[message_id].ext
            object_key = f"{container_name}/{home_id}/requests/{request_id}/{file_name}"
            
            # Determine content type if not provided
            if not content_type:
                content_type, _ = mimetypes.guess_type(original_filename)
                if not content_type:
                    content_type = 'application/octet-stream'
            
            # For images, validate using existing method
            if content_type.startswith('image/'):
                if not self._validate_image(content_type, len(media_data)):
                    return False, "Invalid image file or file too large (max 10MB)"
            
            # For videos and audio, we trust the client-side validation
            # (duration and size should be validated on the client)
            
            # Upload to Cloudflare R2
            self.s3_client.put_object(
                Bucket=bucket_name,
                Key=object_key,
                Body=media_data,
                ContentType=content_type
            )
            
            # Generate presigned URL with 1 week expiration (Cloudflare R2 maximum)
            presigned_url = self._generate_presigned_url(object_key, bucket_name)
            
            return True, presigned_url
            
        except ClientError as e:
            return False, f"Cloudflare R2 error: {str(e)}"
        except Exception as e:
            return False, f"Unexpected error: {str(e)}"

# Global instance factory function
def get_cloudflare_storage_service(tenant_name: str = None) -> CloudflareStorageService:
    """
    Get a CloudflareStorageService instance for a specific tenant
    
    Args:
        tenant_name: Name of the tenant (optional, can be provided in method calls)
    
    Returns:
        CloudflareStorageService instance configured for the tenant
    """
    return CloudflareStorageService(tenant_name)

# Backward compatibility - default instance (deprecated)
# Note: This will fail if no CLOUDFLARE_R2_BUCKET_NAME is set in environment
try:
    cloudflare_storage_service = CloudflareStorageService()
except ValueError:
    # If no default bucket is configured, this will be None
    cloudflare_storage_service = None