"""
Abstract base class for schema operations
Factory pattern that determines implementation based on DATABASE_ENGINE
"""

import sys
import os
from abc import ABC, abstractmethod
from typing import Dict, Any

# Add the api_service directory to sys.path
script_dir = os.path.dirname(os.path.abspath(__file__))  # deployment/admin
deployment_dir = os.path.dirname(script_dir)            # deployment
api_service_dir = os.path.dirname(deployment_dir)       # api_service
sys.path.insert(0, api_service_dir)

from dotenv import load_dotenv
load_dotenv()

import os
DATABASE_ENGINE = os.getenv("DATABASE_ENGINE")

class SchemaOperationsBase(ABC):
    """Abstract base class for schema operations"""
    
    @abstractmethod
    def create_schema_and_user(self, schema_name: str, admin_connection_string: str) -> Dict[str, Any]:
        """
        Create a new database schema and a user with full permissions
        
        Args:
            schema_name: Name of the schema to create
            admin_connection_string: Admin connection string with elevated privileges
            
        Returns:
            Dictionary with status and details of schema and user creation
        """
        pass
    
    @abstractmethod
    def delete_schema_and_user(self, schema_name: str, admin_connection_string: str) -> Dict[str, Any]:
        """
        Completely delete a database schema, all its tables, and the associated user
        
        Args:
            schema_name: Name of the schema to delete
            admin_connection_string: Admin connection string with elevated privileges
            
        Returns:
            Dictionary with status and details of deletion process
        """
        pass


def get_schema_operations() -> SchemaOperationsBase:
    """Factory function to get the appropriate schema operations implementation"""
    if DATABASE_ENGINE == "oracle":
        from deployment.admin.oracle.schema_operations import OracleSchemaOperations
        return OracleSchemaOperations()
    elif DATABASE_ENGINE == "sqlserver":
        from deployment.admin.sqlserver.schema_operations import SqlServerSchemaOperations
        return SqlServerSchemaOperations()
    else:
        raise ValueError(f"Unsupported DATABASE_ENGINE: {DATABASE_ENGINE}")


# Convenience functions for backward compatibility and ease of use
def create_schema_and_user(schema_name: str, admin_connection_string: str) -> Dict[str, Any]:
    """
    Create a new database schema and a user with full permissions
    
    Args:
        schema_name: Name of the schema to create
        admin_connection_string: Admin connection string with elevated privileges
        
    Returns:
        Dictionary with status and details of schema and user creation
    """
    ops = get_schema_operations()
    return ops.create_schema_and_user(schema_name, admin_connection_string)


def delete_schema_and_user(schema_name: str, admin_connection_string: str) -> Dict[str, Any]:
    """
    Completely delete a database schema, all its tables, and the associated user
    
    Args:
        schema_name: Name of the schema to delete
        admin_connection_string: Admin connection string with elevated privileges
        
    Returns:
        Dictionary with status and details of deletion process
    """
    ops = get_schema_operations()
    return ops.delete_schema_and_user(schema_name, admin_connection_string)