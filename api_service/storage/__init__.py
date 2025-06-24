"""
Storage module for handling different storage providers
"""

from .storage_service import azure_storage_service, get_storage_service, get_storage_service_instance

__all__ = ['azure_storage_service', 'get_storage_service', 'get_storage_service_instance']