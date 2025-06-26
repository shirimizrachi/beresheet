"""
Storage Service Factory
Provides a unified interface for different storage providers (Azure, Cloudflare)
"""

import os
from typing import Optional, Tuple
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def get_storage_service(tenant_name: str = None):
    """
    Get the appropriate storage service based on configuration
    
    Args:
        tenant_name: Name of the tenant (used for container naming)
    
    Returns:
        Storage service instance (Azure or Cloudflare)
    """
    from residents_config  import get_storage_provider
    storage_provider = get_storage_provider()
    
    if storage_provider == 'cloudflare':
        from .cloudflare.cloudflare_storage_service import get_cloudflare_storage_service
        return get_cloudflare_storage_service(tenant_name)
    else:
        # Default to Azure
        from .azure.azure_storage_service import get_azure_storage_service
        return get_azure_storage_service(tenant_name)

# For backward compatibility, provide the same interface as the original azure_storage_service
class StorageServiceProxy:
    """
    Proxy class that provides the same interface as the original azure_storage_service
    but delegates to the configured storage provider
    """
    
    def __init__(self, tenant_name: str = None):
        self.tenant_name = tenant_name
        self._service = None
    
    @property
    def service(self):
        if self._service is None:
            self._service = get_storage_service(self.tenant_name)
        return self._service
    
    def upload_image(self, home_id: int, file_name: str, file_path: str, image_data: bytes,
                    content_type: Optional[str] = None, tenant_name: str = None) -> Tuple[bool, str]:
        return self.service.upload_image(home_id, file_name, file_path, image_data, content_type, tenant_name)
    
    def upload_event_image(self, home_id: int, event_id: str, image_data: bytes,
                          original_filename: str, content_type: Optional[str] = None, tenant_name: str = None) -> Tuple[bool, str]:
        return self.service.upload_event_image(home_id, event_id, image_data, original_filename, content_type, tenant_name)
    
    def upload_user_photo(self, home_id: int, user_id: str, image_data: bytes,
                         original_filename: str, content_type: Optional[str] = None, tenant_name: str = None) -> Tuple[bool, str]:
        return self.service.upload_user_photo(home_id, user_id, image_data, original_filename, content_type, tenant_name)
    
    def upload_event_instructor_photo(self, home_id: int, instructor_id: str, image_data: bytes,
                                    original_filename: str, content_type: Optional[str] = None, tenant_name: str = None) -> Tuple[bool, str]:
        return self.service.upload_event_instructor_photo(home_id, instructor_id, image_data, original_filename, content_type, tenant_name)
    
    def upload_request_media(self, home_id: int, request_id: str, message_id: str,
                           media_data: bytes, original_filename: str,
                           content_type: Optional[str] = None, tenant_name: str = None) -> Tuple[bool, str]:
        return self.service.upload_request_media(home_id, request_id, message_id, media_data, original_filename, content_type, tenant_name)
    
    def delete_image(self, blob_path: str, tenant_name: str = None) -> bool:
        return self.service.delete_image(blob_path, tenant_name)
    
    def get_image_url(self, blob_path: str, tenant_name: str = None) -> Optional[str]:
        return self.service.get_image_url(blob_path, tenant_name)

# Backward compatibility - default instance
azure_storage_service = StorageServiceProxy()

# Also provide a factory function for new code
def get_storage_service_instance(tenant_name: str = None):
    """
    Get a storage service instance for a specific tenant
    
    Args:
        tenant_name: Name of the tenant
    
    Returns:
        Storage service instance configured for the tenant
    """
    return StorageServiceProxy(tenant_name)