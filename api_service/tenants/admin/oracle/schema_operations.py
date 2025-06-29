"""
Oracle specific schema and user operations
"""

import sys
import os
from sqlalchemy import create_engine, text
from typing import Dict, Any
import logging
from tenants.admin.schema_operations import SchemaOperationsBase

# Add the api_service directory to sys.path
script_dir = os.path.dirname(os.path.abspath(__file__))  # deployment/admin/oracle
admin_dir = os.path.dirname(script_dir)                 # deployment/admin
deployment_dir = os.path.dirname(admin_dir)             # deployment
api_service_dir = os.path.dirname(deployment_dir)       # api_service
sys.path.insert(0, api_service_dir)

# Import the abstract base class
sys.path.insert(0, admin_dir)

logger = logging.getLogger(__name__)

class OracleSchemaOperations(SchemaOperationsBase):
    """Oracle-specific schema operations implementation"""
    
    def create_schema_and_user(self, schema_name: str, admin_connection_string: str) -> Dict[str, Any]:
        """
        Create a new database schema and a user with full permissions on Oracle
        In Oracle, user = schema, so we create a user which automatically creates a schema
        
        Args:
            schema_name: Name of the schema/user to create
            admin_connection_string: Admin connection string with elevated privileges
            
        Returns:
            Dictionary with status and details of schema and user creation
        """
        try:
            # Validate schema name (must be alphanumeric)
            if not schema_name.replace("_", "").replace("-", "").isalnum():
                return {
                    "status": "error",
                    "message": "Schema name must be alphanumeric (with optional hyphens and underscores)"
                }
            
            admin_engine = create_engine(admin_connection_string)
            
            with admin_engine.connect() as conn:
                # Check if user/schema already exists
                check_user_sql = text("""
                    SELECT COUNT(*) as count
                    FROM ALL_USERS
                    WHERE username = :user_name
                """)
                result = conn.execute(check_user_sql, {"user_name": schema_name.upper()}).fetchone()
                
                user_exists = result.count > 0
                
                if not user_exists:
                    # Create user (in Oracle, user = schema)
                    try:
                        create_user_sql = text(f"""
                            CREATE USER {schema_name} IDENTIFIED BY "TenantApp2025!@#"
                            DEFAULT TABLESPACE DATA
                            TEMPORARY TABLESPACE TEMP
                            QUOTA UNLIMITED ON DATA
                        """)
                        conn.execute(create_user_sql)
                        logger.info(f"Created user/schema '{schema_name}'")
                    except Exception as e:
                        logger.error(f"Failed to create user/schema '{schema_name}': {e}")
                        raise Exception(f"User/schema creation failed: {str(e)}")
                else:
                    logger.info(f"User/schema '{schema_name}' already exists, skipping creation")
                
                # Grant database-level permissions
                try:
                    db_permissions = [
                        "CREATE SESSION", "CREATE TABLE", "CREATE VIEW", "CREATE PROCEDURE",
                        "CREATE SEQUENCE", "CREATE TRIGGER", "CREATE TYPE", "CREATE FUNCTION"
                    ]
                    
                    for permission in db_permissions:
                        try:
                            grant_sql = text(f"GRANT {permission} TO {schema_name}")
                            conn.execute(grant_sql)
                        except Exception as e:
                            logger.warning(f"Could not grant {permission} permission: {e}")
                    
                    logger.info(f"Granted database permissions to user '{schema_name}'")
                except Exception as e:
                    logger.error(f"Failed to grant permissions to user '{schema_name}': {e}")
                    raise Exception(f"Permission granting failed: {str(e)}")
                
                # Commit all changes
                conn.commit()
                
                # Verify user was actually created
                verify_user_sql = text("""
                    SELECT COUNT(*) as count
                    FROM ALL_USERS
                    WHERE username = :user_name
                """)
                verify_result = conn.execute(verify_user_sql, {"user_name": schema_name.upper()}).fetchone()
                
                if verify_result.count == 0:
                    logger.error(f"User/schema '{schema_name}' was not created successfully")
                    return {
                        "status": "error",
                        "message": f"User/schema '{schema_name}' verification failed after creation"
                    }
                
                response = {
                    "status": "success",
                    "message": f"Schema '{schema_name}' and user setup completed successfully",
                    "schema_name": schema_name,
                    "user_name": schema_name,
                    "password": "TenantApp2025!@#",
                    "permissions": "Full permissions on schema",
                    "schema_created": not user_exists,
                    "user_created": not user_exists,
                    "connection_info": {
                        "database": "oracle",  # Oracle doesn't use database concept like SQL Server
                        "schema": schema_name,
                        "username": schema_name,
                        "password": "TenantApp2025!@#"
                    }
                }
                
                logger.info(f"Successfully created Oracle schema '{schema_name}' with user and full permissions")
                return response
                
        except Exception as e:
            logger.error(f"Error creating Oracle schema '{schema_name}': {e}")
            return {
                "status": "error",
                "message": f"Error creating schema: {str(e)}"
            }

    def delete_schema_and_user(self, schema_name: str, admin_connection_string: str) -> Dict[str, Any]:
        """
        Completely delete an Oracle schema and the associated user
        In Oracle, dropping a user with CASCADE drops all objects in the schema
        
        Args:
            schema_name: Name of the schema/user to delete
            admin_connection_string: Admin connection string with elevated privileges
            
        Returns:
            Dictionary with status and details of deletion process
        """
        try:
            # Validate schema name (must be alphanumeric)
            if not schema_name.replace("_", "").replace("-", "").isalnum():
                return {
                    "status": "error",
                    "message": "Schema name must be alphanumeric (with optional hyphens and underscores)"
                }
            
            admin_engine = create_engine(admin_connection_string)
            
            with admin_engine.connect() as conn:
                # Check if user/schema exists
                check_user_sql = text("""
                    SELECT COUNT(*) as count
                    FROM ALL_USERS
                    WHERE username = :user_name
                """)
                result = conn.execute(check_user_sql, {"user_name": schema_name.upper()}).fetchone()
                
                user_exists = result.count > 0
                
                dropped_objects_count = 0
                user_dropped = False
                
                if user_exists:
                    # Get count of objects in the schema before dropping
                    try:
                        count_objects_sql = text("""
                            SELECT COUNT(*) as count
                            FROM ALL_OBJECTS
                            WHERE owner = :owner_name
                        """)
                        objects_result = conn.execute(count_objects_sql, {"owner_name": schema_name.upper()}).fetchone()
                        dropped_objects_count = objects_result.count
                        logger.info(f"Found {dropped_objects_count} objects in schema '{schema_name}'")
                    except Exception as e:
                        logger.warning(f"Could not count objects in schema '{schema_name}': {e}")
                    
                    # Drop the user with CASCADE (this drops all schema objects)
                    try:
                        drop_user_sql = text(f"DROP USER {schema_name} CASCADE")
                        conn.execute(drop_user_sql)
                        user_dropped = True
                        logger.info(f"Dropped user/schema '{schema_name}' with all objects")
                    except Exception as e:
                        logger.error(f"Failed to drop user/schema '{schema_name}': {e}")
                        raise Exception(f"User/schema deletion failed: {str(e)}")
                else:
                    logger.info(f"User/schema '{schema_name}' does not exist")
                
                # Commit all changes
                conn.commit()
                
                # Verify user was actually deleted
                verify_user_sql = text("""
                    SELECT COUNT(*) as count
                    FROM ALL_USERS
                    WHERE username = :user_name
                """)
                verify_result = conn.execute(verify_user_sql, {"user_name": schema_name.upper()}).fetchone()
                
                if verify_result.count > 0:
                    logger.error(f"User/schema '{schema_name}' still exists after deletion attempt")
                    return {
                        "status": "error",
                        "message": f"User/schema '{schema_name}' deletion verification failed"
                    }
                
                # Create appropriate response based on what was found and deleted
                if user_exists:
                    response = {
                        "status": "success",
                        "message": f"Schema '{schema_name}' and associated user deleted successfully",
                        "schema_name": schema_name,
                        "objects_dropped": dropped_objects_count,
                        "schema_dropped": user_dropped,
                        "user_dropped": user_dropped
                    }
                else:
                    response = {
                        "status": "success",
                        "message": f"Schema '{schema_name}' did not exist",
                        "schema_name": schema_name,
                        "objects_dropped": 0,
                        "schema_dropped": False,
                        "user_dropped": False
                    }
                
                logger.info(f"Successfully deleted Oracle schema '{schema_name}' and all associated objects")
                return response
                
        except Exception as e:
            logger.error(f"Error deleting Oracle schema '{schema_name}': {e}")
            return {
                "status": "error",
                "message": f"Error deleting schema: {str(e)}"
            }


# Backward compatibility functions (if any existing code expects these function names)
def create_schema_and_user_oracle(schema_name: str, admin_connection_string: str) -> Dict[str, Any]:
    """Backward compatibility function"""
    ops = OracleSchemaOperations()
    return ops.create_schema_and_user(schema_name, admin_connection_string)


def delete_schema_and_user_oracle(schema_name: str, admin_connection_string: str) -> Dict[str, Any]:
    """Backward compatibility function"""
    ops = OracleSchemaOperations()
    return ops.delete_schema_and_user(schema_name, admin_connection_string)