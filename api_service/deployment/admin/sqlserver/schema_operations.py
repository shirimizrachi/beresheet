"""
SQL Server specific schema and user operations
"""

from sqlalchemy import create_engine, text
from typing import Dict, Any
import logging

logger = logging.getLogger(__name__)

def create_schema_and_user_sqlserver(schema_name: str, admin_connection_string: str) -> Dict[str, Any]:
    """
    Create a new database schema and a user with full permissions on SQL Server
    
    Args:
        schema_name: Name of the schema to create
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
            # Check if schema already exists
            check_schema_sql = text("""
                SELECT COUNT(*) as count
                FROM INFORMATION_SCHEMA.SCHEMATA
                WHERE SCHEMA_NAME = :schema_name
            """)
            result = conn.execute(check_schema_sql, {"schema_name": schema_name}).fetchone()
            
            if result.count > 0:
                return {
                    "status": "error",
                    "message": f"Schema '{schema_name}' already exists"
                }
            
            # Create the schema
            create_schema_sql = text(f"CREATE SCHEMA [{schema_name}]")
            conn.execute(create_schema_sql)
            
            # Check if login already exists
            check_login_sql = text("""
                SELECT COUNT(*) as count
                FROM sys.sql_logins
                WHERE name = :login_name
            """)
            login_result = conn.execute(check_login_sql, {"login_name": schema_name}).fetchone()
            
            if login_result.count == 0:
                # Create SQL Server login
                create_login_sql = text(f"""
                    CREATE LOGIN [{schema_name}]
                    WITH PASSWORD = '{schema_name}2025!',
                    DEFAULT_DATABASE = [residents],
                    CHECK_EXPIRATION = OFF,
                    CHECK_POLICY = OFF
                """)
                conn.execute(create_login_sql)
                logger.info(f"Created login '{schema_name}'")
            else:
                logger.info(f"Login '{schema_name}' already exists, skipping creation")
            
            # Create database user for the login
            create_user_sql = text(f"""
                CREATE USER [{schema_name}] FOR LOGIN [{schema_name}]
            """)
            conn.execute(create_user_sql)
            
            # Grant full permissions on the schema to the user
            grant_permissions_sql = text(f"""
                -- Grant schema ownership
                ALTER AUTHORIZATION ON SCHEMA::[{schema_name}] TO [{schema_name}];
                
                -- Grant additional permissions
                GRANT CREATE TABLE TO [{schema_name}];
                GRANT CREATE VIEW TO [{schema_name}];
                GRANT CREATE PROCEDURE TO [{schema_name}];
                GRANT CREATE FUNCTION TO [{schema_name}];
                
                -- Grant permissions on the schema
                GRANT CONTROL ON SCHEMA::[{schema_name}] TO [{schema_name}];
                GRANT ALTER ON SCHEMA::[{schema_name}] TO [{schema_name}];
                GRANT EXECUTE ON SCHEMA::[{schema_name}] TO [{schema_name}];
                GRANT INSERT ON SCHEMA::[{schema_name}] TO [{schema_name}];
                GRANT SELECT ON SCHEMA::[{schema_name}] TO [{schema_name}];
                GRANT UPDATE ON SCHEMA::[{schema_name}] TO [{schema_name}];
                GRANT DELETE ON SCHEMA::[{schema_name}] TO [{schema_name}];
                GRANT REFERENCES ON SCHEMA::[{schema_name}] TO [{schema_name}];
            """)
            conn.execute(grant_permissions_sql)
            
            conn.commit()
            
            response = {
                "status": "success",
                "message": f"Schema '{schema_name}' and user created successfully",
                "schema_name": schema_name,
                "user_name": schema_name,
                "password": f"{schema_name}2025!",
                "permissions": "Full permissions on schema",
                "login_created": login_result.count == 0,  # True if we created a new login
                "connection_info": {
                    "database": "residents",
                    "schema": schema_name,
                    "username": schema_name,
                    "password": f"{schema_name}2025!"
                }
            }
            
            logger.info(f"Successfully created SQL Server schema '{schema_name}' with user and full permissions")
            return response
            
    except Exception as e:
        logger.error(f"Error creating SQL Server schema '{schema_name}': {e}")
        return {
            "status": "error",
            "message": f"Error creating schema: {str(e)}"
        }