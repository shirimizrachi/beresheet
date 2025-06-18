"""
Azure Storage Service for handling image uploads
Shared service for uploading images to Azure Blob Storage
"""

import os
import uuid
import io
from datetime import datetime, timedelta
from typing import Optional, Tuple
from azure.storage.blob import BlobServiceClient, BlobClient, generate_blob_sas, BlobSasPermissions
from azure.core.exceptions import AzureError
import mimetypes
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()


class AzureStorageService:
    def __init__(self):
        """Initialize Azure Storage Service with connection string from environment"""
        self.connection_string = os.getenv('AZURE_STORAGE_CONNECTION_STRING')
        self.container_name = os.getenv('AZURE_STORAGE_CONTAINER_NAME', 'beresheet-images')
        
        if not self.connection_string:
            raise ValueError("AZURE_STORAGE_CONNECTION_STRING environment variable is required")
        
        try:
            self.blob_service_client = BlobServiceClient.from_connection_string(self.connection_string)
            # Extract account key for SAS generation
            self.account_key = self._extract_account_key()
            self.account_name = self._extract_account_name()
            # Ensure container exists
            self._ensure_container_exists()
        except Exception as e:
            raise ValueError(f"Failed to initialize Azure Storage Service: {str(e)}")
    
    def _extract_account_key(self) -> str:
        """Extract account key from connection string"""
        for part in self.connection_string.split(';'):
            if part.startswith('AccountKey='):
                return part.split('=', 1)[1]
        raise ValueError("AccountKey not found in connection string")
    
    def _extract_account_name(self) -> str:
        """Extract account name from connection string"""
        for part in self.connection_string.split(';'):
            if part.startswith('AccountName='):
                return part.split('=', 1)[1]
        raise ValueError("AccountName not found in connection string")
    
    def _ensure_container_exists(self):
        """Ensure the storage container exists"""
        try:
            container_client = self.blob_service_client.get_container_client(self.container_name)
            container_client.create_container()
        except Exception:
            # Container might already exist, which is fine
            pass
    
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
    
    def _generate_sas_url(self, blob_path: str) -> str:
        """Generate a SAS URL for a blob with 1 year expiration"""
        try:
            # Set expiration to 1 year from now
            expiry_time = datetime.utcnow() + timedelta(days=365)
            
            # Generate SAS token
            sas_token = generate_blob_sas(
                account_name=self.account_name,
                container_name=self.container_name,
                blob_name=blob_path,
                account_key=self.account_key,
                permission=BlobSasPermissions(read=True),
                expiry=expiry_time
            )
            
            # Construct the full SAS URL
            base_url = f"https://{self.account_name}.blob.core.windows.net/{self.container_name}/{blob_path}"
            sas_url = f"{base_url}?{sas_token}"
            
            return sas_url
            
        except Exception as e:
            print(f"Error generating SAS URL: {e}")
            # Fallback to public URL (though it might not work)
            return f"https://{self.account_name}.blob.core.windows.net/{self.container_name}/{blob_path}"
    
    def upload_image(self, home_id: int, file_name: str, file_path: str, image_data: bytes,
                    content_type: Optional[str] = None) -> Tuple[bool, str]:
        """
        Upload an image to Azure Storage (generic method)
        
        Args:
            home_id: The home ID for organizing files
            file_name: The desired filename (including extension)
            file_path: The relative path within the home folder (e.g., "events/images/")
            image_data: The image data as bytes
            content_type: MIME content type of the image
        
        Returns:
            Tuple of (success: bool, url_or_error_message: str)
        """
        try:
            # Validate image
            if not self._validate_image(content_type, len(image_data)):
                return False, "Invalid image file or file too large (max 10MB)"
            
            # Clean file_path (remove leading/trailing slashes, ensure it ends with /)
            file_path = file_path.strip('/')
            if file_path and not file_path.endswith('/'):
                file_path += '/'
            
            # Create blob path: /[homeId]/[file_path][file_name]
            blob_path = f"{home_id}/{file_path}{file_name}"
            
            # Determine content type
            if not content_type:
                content_type = self._get_content_type(file_name)
            
            # Upload to Azure Storage
            blob_client = self.blob_service_client.get_blob_client(
                container=self.container_name,
                blob=blob_path
            )
            
            blob_client.upload_blob(
                image_data,
                content_type=content_type,
                overwrite=True
            )
            
            # Generate SAS URL with 1 year expiration
            sas_url = self._generate_sas_url(blob_path)
            
            return True, sas_url
            
        except AzureError as e:
            return False, f"Azure Storage error: {str(e)}"
        except Exception as e:
            return False, f"Unexpected error: {str(e)}"

    def upload_event_image(self, home_id: int, event_id: str, image_data: bytes,
                          original_filename: str, content_type: Optional[str] = None) -> Tuple[bool, str]:
        """
        Upload an event image to Azure Storage
        
        Args:
            home_id: The home ID for organizing files
            event_id: The event ID to use as filename
            image_data: The image data as bytes
            original_filename: Original filename (for extension detection)
            content_type: MIME content type of the image
        
        Returns:
            Tuple of (success: bool, url_or_error_message: str)
        """
        # Get file extension from original filename
        file_extension = os.path.splitext(original_filename)[1].lower()
        if not file_extension:
            file_extension = '.jpg'  # Default extension
        
        # Use event_id as filename
        file_name = f"{event_id}{file_extension}"
        
        return self.upload_image(home_id, file_name, "events/images/", image_data, content_type)
    
    def upload_user_photo(self, home_id: int, user_id: str, image_data: bytes,
                         original_filename: str, content_type: Optional[str] = None) -> Tuple[bool, str]:
        """
        Upload a user photo to Azure Storage
        
        Args:
            home_id: The home ID for organizing files
            user_id: The user ID
            image_data: The image data as bytes
            original_filename: Original filename (for extension detection)
            content_type: MIME content type of the image
        
        Returns:
            Tuple of (success: bool, url_or_error_message: str)
        """
        # Get file extension from original filename
        file_extension = os.path.splitext(original_filename)[1].lower()
        if not file_extension:
            file_extension = '.jpg'  # Default extension
        
        # Use user_id as filename
        file_name = f"{user_id}{file_extension}"
        
        return self.upload_image(home_id, file_name, "users/photos/", image_data, content_type)
    
    def upload_event_instructor_photo(self, home_id: int, instructor_id: int, image_data: bytes,
                                    original_filename: str, content_type: Optional[str] = None) -> Tuple[bool, str]:
        """
        Upload an event instructor photo to Azure Storage
        
        Args:
            home_id: The home ID for organizing files
            instructor_id: The instructor ID
            image_data: The image data as bytes
            original_filename: Original filename (for extension detection)
            content_type: MIME content type of the image
        
        Returns:
            Tuple of (success: bool, url_or_error_message: str)
        """
        # Get file extension from original filename
        file_extension = os.path.splitext(original_filename)[1].lower()
        if not file_extension:
            file_extension = '.jpg'  # Default extension
        
        # Use instructor_id as filename
        file_name = f"instructor_{instructor_id}{file_extension}"
        
        return self.upload_image(home_id, file_name, "instructors/photos/", image_data, content_type)
    
    def delete_image(self, blob_path: str) -> bool:
        """
        Delete an image from Azure Storage
        
        Args:
            blob_path: The path of the blob to delete
        
        Returns:
            bool: True if successful, False otherwise
        """
        try:
            blob_client = self.blob_service_client.get_blob_client(
                container=self.container_name,
                blob=blob_path
            )
            blob_client.delete_blob()
            return True
        except Exception:
            return False
    
    def get_image_url(self, blob_path: str) -> Optional[str]:
        """
        Get the SAS URL for an image
        
        Args:
            blob_path: The path of the blob
        
        Returns:
            str: The SAS URL or None if not found
        """
        try:
            # Check if blob exists
            blob_client = self.blob_service_client.get_blob_client(
                container=self.container_name,
                blob=blob_path
            )
            if blob_client.exists():
                return self._generate_sas_url(blob_path)
            return None
        except Exception:
            return None
    
    def upload_request_media(self, home_id: int, request_id: str, message_id: str,
                           media_data: bytes, original_filename: str,
                           content_type: Optional[str] = None) -> Tuple[bool, str]:
        """
        Upload media (image, video, or audio) for a service request message
        
        Args:
            home_id: The home ID for organizing files
            request_id: The request ID
            message_id: The message ID
            media_data: The media data as bytes
            original_filename: Original filename (for extension detection)
            content_type: MIME content type of the media
        
        Returns:
            Tuple of (success: bool, url_or_error_message: str)
        """
        try:
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
            
            # Create blob path: /[homeId]/requests/[request_id]/[message_id].ext
            blob_path = f"{home_id}/requests/{request_id}/{file_name}"
            
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
            
            # Upload to Azure Storage
            blob_client = self.blob_service_client.get_blob_client(
                container=self.container_name,
                blob=blob_path
            )
            
            blob_client.upload_blob(
                media_data,
                content_type=content_type,
                overwrite=True
            )
            
            # Generate SAS URL with 1 year expiration
            sas_url = self._generate_sas_url(blob_path)
            
            return True, sas_url
            
        except AzureError as e:
            return False, f"Azure Storage error: {str(e)}"
        except Exception as e:
            return False, f"Unexpected error: {str(e)}"

# Create global instance
azure_storage_service = AzureStorageService()