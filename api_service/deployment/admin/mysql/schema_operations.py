"""
MySQL specific schema and user operations
"""

from sqlalchemy import create_engine, text
from typing import Dict, Any
import logging

logger = logging.getLogger(__name__)

def create_schema_and_user_mysql(schema_name: str, admin_connection_string: str) -> Dict[str, Any]:
    """
    Create a new database schema and a user with full permissions on MySQL
    
    Args:
        schema_name: Name of the schema (database) to create
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
            # Check if database already exists
            check_schema_sql = text("""
                SELECT COUNT(*) as count
                FROM INFORMATION_SCHEMA.SCHEMATA
                WHERE SCHEMA_NAME = :schema_name
            """)
            result = conn.execute(check_schema_sql, {"schema_name": schema_name}).fetchone()
            
            if result.count > 0:
                return {
                    "status": "error",
                    "message": f"Database '{schema_name}' already exists"
                }
            
            # Create the database (MySQL uses database instead of schema)
            create_database_sql = text(f"CREATE DATABASE `{schema_name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
            conn.execute(create_database_sql)
            
            # Check if user already exists
            check_user_sql = text("""
                SELECT COUNT(*) as count
                FROM mysql.user
                WHERE User = :user_name
            """)
            user_result = conn.execute(check_user_sql, {"user_name": schema_name}).fetchone()
            
            if user_result.count == 0:
                # Create MySQL user
                create_user_sql = text(f"""
                    CREATE USER '{schema_name}'@'%' IDENTIFIED BY '{schema_name}2025!'
                """)
                conn.execute(create_user_sql)
                logger.info(f"Created user '{schema_name}'")
            else:
                logger.info(f"User '{schema_name}' already exists, skipping creation")
            
            # Grant full permissions on the database to the user
            grant_permissions_sql = text(f"""
                GRANT ALL PRIVILEGES ON `{schema_name}`.* TO '{schema_name}'@'%'
            """)
            conn.execute(grant_permissions_sql)
            
            # Flush privileges to ensure they take effect
            flush_privileges_sql = text("FLUSH PRIVILEGES")
            conn.execute(flush_privileges_sql)
            
            conn.commit()
            
            response = {
                "status": "success",
                "message": f"Database '{schema_name}' and user created successfully",
                "schema_name": schema_name,
                "user_name": schema_name,
                "password": f"{schema_name}2025!",
                "permissions": "Full permissions on database",
                "user_created": user_result.count == 0,  # True if we created a new user
                "connection_info": {
                    "database": schema_name,
                    "schema": schema_name,
                    "username": schema_name,
                    "password": f"{schema_name}2025!"
                }
            }
            
            logger.info(f"Successfully created MySQL database '{schema_name}' with user and full permissions")
            return response
            
    except Exception as e:
        logger.error(f"Error creating MySQL database '{schema_name}': {e}")
        return {
            "status": "error",
            "message": f"Error creating database: {str(e)}"
        }