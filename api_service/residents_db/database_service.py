"""
Database Service Factory
Provides a unified interface for different database providers (Azure SQL Server, MySQL)
"""

import os
from typing import Dict, Any
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def get_database_service():
    """
    Get the appropriate database service based on configuration
    
    Returns:
        Database service instance (Azure SQL Server or MySQL)
    """
    # Use environment variable directly to avoid circular import
    DATABASE_ENGINE = os.getenv("DATABASE_ENGINE")
    
    if DATABASE_ENGINE == 'oracle':
        from .oracle.oracle_database_service import get_oracle_database_service
        return get_oracle_database_service()
    else:
        # Default to Azure SQL Server
        from .azure.azure_database_service import get_azure_database_service
        return get_azure_database_service()

# For backward compatibility, provide the same interface as the original residents_config 
class DatabaseServiceProxy:
    """
    Proxy class that provides the same interface as the original residents_config 
    but delegates to the configured database provider
    """
    
    def __init__(self):
        self._service = None
    
    @property
    def service(self):
        if self._service is None:
            self._service = get_database_service()
        return self._service
    
    def get_connection_string(self):
        """Get the active connection string based on DATABASE_TYPE"""
        return self.service.get_connection_string()
    
    def get_admin_connection_string(self):
        """Get the admin connection string with elevated privileges based on DATABASE_TYPE"""
        return self.service.get_admin_connection_string()
    
    def get_master_connection_string(self):
        """Get the master/system database connection string for database creation operations"""
        return self.service.get_master_connection_string()
    
    def get_server_info(self):
        """Get server information based on DATABASE_ENGINE and DATABASE_TYPE"""
        return self.service.get_server_info()
    
    def get_home_index_connection_string(self):
        """Get the home index connection string based on DATABASE_TYPE"""
        return self.service.get_home_index_connection_string()
    
    def get_home_index_server_info(self):
        """Get home index server information based on DATABASE_ENGINE and DATABASE_TYPE"""
        return self.service.get_home_index_server_info()
    
    def get_tenant_connection_string(self, tenant_name: str):
        """Get connection string for a tenant using tenant-specific credentials"""
        return self.service.get_tenant_connection_string(tenant_name)

# Backward compatibility - default instance
database_service = DatabaseServiceProxy()

# Export all the functions for backward compatibility
def get_connection_string():
    return database_service.get_connection_string()

def get_admin_connection_string():
    return database_service.get_admin_connection_string()

def get_master_connection_string():
    return database_service.get_master_connection_string()

def get_server_info():
    return database_service.get_server_info()

def get_home_index_connection_string():
    return database_service.get_home_index_connection_string()

def get_home_index_server_info():
    return database_service.get_home_index_server_info()

def get_tenant_connection_string(tenant_name: str):
    return database_service.get_tenant_connection_string(tenant_name)

# Also provide a factory function for new code
def get_database_service_instance():
    """
    Get a database service instance
    
    Returns:
        Database service instance configured for the current environment
    """
    return DatabaseServiceProxy()