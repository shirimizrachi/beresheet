"""
Main configuration for residents system
Contains common configurations and imports database/storage providers
"""

import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Master Admin Configuration
MASTER_ADMIN_EMAIL = os.getenv("MASTER_ADMIN_EMAIL", "ranmizrachi@gmail.com")
MASTER_ADMIN_PASSWORD = os.getenv("MASTER_ADMIN_PASSWORD", "ranmizrachi")

# Database Configuration
DATABASE_ENGINE = os.getenv("DATABASE_ENGINE")  # "sqlserver" or "oracle"
DATABASE_TYPE = os.getenv("DATABASE_TYPE", "local")  # "local", "azure", or "cloud"
DATABASE_NAME = os.getenv("DATABASE_NAME", "residents")
SCHEMA_NAME = os.getenv("SCHEMA_NAME", "home")
USER_NAME = os.getenv("USER_NAME", "home")
USER_PASSWORD = os.getenv("USER_PASSWORD")

# Storage Configuration (handled by separate storage service)
STORAGE_PROVIDER = os.getenv("STORAGE_PROVIDER")  # "azure" or "cloudflare"
CLOUDFLARE_SHARED_BUCKET_NAME = os.getenv("CLOUDFLARE_SHARED_BUCKET_NAME", "residents-images")

# Home Index Configuration (common to all implementations)
home_index_NAME = os.getenv("home_index_NAME", "home_index")
HOME_INDEX_USER_NAME = os.getenv("HOME_INDEX_USER_NAME", "home_index")
HOME_INDEX_USER_PASSWORD = os.getenv("HOME_INDEX_USER_PASSWORD")

# Additional configuration constants for compatibility
ADMIN_SCHEMA = SCHEMA_NAME
ADMIN_DATABASE = DATABASE_NAME

# Import database functions from the database service
from residents_db.database_service import (
    get_connection_string,
    get_admin_connection_string,
    get_master_connection_string,
    get_server_info,
    get_home_index_connection_string,
    get_home_index_server_info
)

def get_storage_provider():
    """
    Get the configured storage provider
    
    Returns:
        str: Storage provider type ('azure' or 'cloudflare')
    """
    return STORAGE_PROVIDER

def get_cloudflare_shared_bucket_name():
    """
    Get the shared Cloudflare bucket name
    
    Returns:
        str: Cloudflare shared bucket name
    """
    return CLOUDFLARE_SHARED_BUCKET_NAME

# Set ADMIN_CONNECTION_STRING for compatibility
ADMIN_CONNECTION_STRING = get_connection_string()