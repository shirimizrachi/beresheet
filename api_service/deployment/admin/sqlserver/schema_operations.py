"""
SQL Server specific schema and user operations
"""

import sys
import os
from sqlalchemy import create_engine, text
from typing import Dict, Any
import logging
from deployment.admin.schema_operations import SchemaOperationsBase

# Add the api_service directory to sys.path
script_dir = os.path.dirname(os.path.abspath(__file__))  # deployment/admin/sqlserver
admin_dir = os.path.dirname(script_dir)                 # deployment/admin
deployment_dir = os.path.dirname(admin_dir)             # deployment
api_service_dir = os.path.dirname(deployment_dir)       # api_service
sys.path.insert(0, api_service_dir)

# Import the abstract base class
sys.path.insert(0, admin_dir)

logger = logging.getLogger(__name__)

class SqlServerSchemaOperations(SchemaOperationsBase):
    """SQL Server-specific schema operations implementation"""
    
    def create_schema_and_user(self, schema_name: str, admin_connection_string: str) -> Dict[str, Any]:
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
                
                schema_exists = result.count > 0
                
                if not schema_exists:
                    # Create the schema
                    try:
                        create_schema_sql = text(f"CREATE SCHEMA [{schema_name}]")
                        conn.execute(create_schema_sql)
                        logger.info(f"Created schema '{schema_name}'")
                    except Exception as e:
                        logger.error(f"Failed to create schema '{schema_name}': {e}")
                        raise Exception(f"Schema creation failed: {str(e)}")
                else:
                    logger.info(f"Schema '{schema_name}' already exists, skipping creation")
                
                # Check if login already exists
                check_login_sql = text("""
                    SELECT COUNT(*) as count
                    FROM sys.sql_logins
                    WHERE name = :login_name
                """)
                login_result = conn.execute(check_login_sql, {"login_name": schema_name}).fetchone()
                
                login_exists = login_result.count > 0
                
                if not login_exists:
                    # Create SQL Server login
                    try:
                        create_login_sql = text(f"""
                            CREATE LOGIN [{schema_name}]
                            WITH PASSWORD = 'TenantApp2025!@#',
                            DEFAULT_DATABASE = [residents],
                            CHECK_EXPIRATION = OFF,
                            CHECK_POLICY = OFF
                        """)
                        conn.execute(create_login_sql)
                        logger.info(f"Created login '{schema_name}'")
                    except Exception as e:
                        logger.error(f"Failed to create login '{schema_name}': {e}")
                        raise Exception(f"Login creation failed: {str(e)}")
                else:
                    logger.info(f"Login '{schema_name}' already exists, skipping creation")
                
                # Check if database user already exists
                check_user_sql = text("""
                    SELECT COUNT(*) as count
                    FROM sys.database_principals
                    WHERE name = :user_name AND type IN ('S', 'U')
                """)
                user_result = conn.execute(check_user_sql, {"user_name": schema_name}).fetchone()
                
                user_exists = user_result.count > 0
                
                if not user_exists:
                    # Create database user for the login
                    try:
                        create_user_sql = text(f"""
                            CREATE USER [{schema_name}] FOR LOGIN [{schema_name}]
                        """)
                        conn.execute(create_user_sql)
                        logger.info(f"Created database user '{schema_name}'")
                    except Exception as e:
                        logger.error(f"Failed to create database user '{schema_name}': {e}")
                        raise Exception(f"User creation failed: {str(e)}")
                else:
                    logger.info(f"Database user '{schema_name}' already exists, skipping creation")
                
                # Grant full permissions on the schema to the user AND admin user
                try:
                    # First, get the current admin user name
                    get_admin_user_sql = text("SELECT ORIGINAL_LOGIN() as admin_user")
                    admin_user_result = conn.execute(get_admin_user_sql).fetchone()
                    admin_user = admin_user_result.admin_user if admin_user_result else "home"
                    
                    grant_permissions_sql = text(f"""
                        -- Grant schema ownership to schema user
                        ALTER AUTHORIZATION ON SCHEMA::[{schema_name}] TO [{schema_name}];
                        
                        -- Grant additional permissions to schema user
                        GRANT CREATE TABLE TO [{schema_name}];
                        GRANT CREATE VIEW TO [{schema_name}];
                        GRANT CREATE PROCEDURE TO [{schema_name}];
                        GRANT CREATE FUNCTION TO [{schema_name}];
                        
                        -- Grant permissions on the schema to schema user
                        GRANT CONTROL ON SCHEMA::[{schema_name}] TO [{schema_name}];
                        GRANT ALTER ON SCHEMA::[{schema_name}] TO [{schema_name}];
                        GRANT EXECUTE ON SCHEMA::[{schema_name}] TO [{schema_name}];
                        GRANT INSERT ON SCHEMA::[{schema_name}] TO [{schema_name}];
                        GRANT SELECT ON SCHEMA::[{schema_name}] TO [{schema_name}];
                        GRANT UPDATE ON SCHEMA::[{schema_name}] TO [{schema_name}];
                        GRANT DELETE ON SCHEMA::[{schema_name}] TO [{schema_name}];
                        GRANT REFERENCES ON SCHEMA::[{schema_name}] TO [{schema_name}];
                        
                        -- ALSO grant permissions to admin user so admin connection can create tables
                        GRANT CONTROL ON SCHEMA::[{schema_name}] TO [{admin_user}];
                        GRANT ALTER ON SCHEMA::[{schema_name}] TO [{admin_user}];
                        GRANT EXECUTE ON SCHEMA::[{schema_name}] TO [{admin_user}];
                        GRANT INSERT ON SCHEMA::[{schema_name}] TO [{admin_user}];
                        GRANT SELECT ON SCHEMA::[{schema_name}] TO [{admin_user}];
                        GRANT UPDATE ON SCHEMA::[{schema_name}] TO [{admin_user}];
                        GRANT DELETE ON SCHEMA::[{schema_name}] TO [{admin_user}];
                        GRANT REFERENCES ON SCHEMA::[{schema_name}] TO [{admin_user}];
                    """)
                    conn.execute(grant_permissions_sql)
                    logger.info(f"Granted full permissions on schema '{schema_name}' to user '{schema_name}' and admin user '{admin_user}'")
                except Exception as e:
                    logger.error(f"Failed to grant permissions on schema '{schema_name}': {e}")
                    raise Exception(f"Permission granting failed: {str(e)}")
                
                # Commit all changes to ensure schema is properly created before returning
                conn.commit()
                
                # Verify schema was actually created
                verify_schema_sql = text("""
                    SELECT COUNT(*) as count
                    FROM INFORMATION_SCHEMA.SCHEMATA
                    WHERE SCHEMA_NAME = :schema_name
                """)
                verify_result = conn.execute(verify_schema_sql, {"schema_name": schema_name}).fetchone()
                
                if verify_result.count == 0:
                    logger.error(f"Schema '{schema_name}' was not created successfully")
                    return {
                        "status": "error",
                        "message": f"Schema '{schema_name}' verification failed after creation"
                    }
                
                response = {
                    "status": "success",
                    "message": f"Schema '{schema_name}' and user setup completed successfully",
                    "schema_name": schema_name,
                    "user_name": schema_name,
                    "password": "TenantApp2025!@#",
                    "permissions": "Full permissions on schema",
                    "schema_created": not schema_exists,
                    "login_created": not login_exists,
                    "user_created": not user_exists,
                    "connection_info": {
                        "database": "residents",
                        "schema": schema_name,
                        "username": schema_name,
                        "password": "TenantApp2025!@#"
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

    def delete_schema_and_user(self, schema_name: str, admin_connection_string: str) -> Dict[str, Any]:
        """
        Completely delete a SQL Server schema, all its tables, and the associated user and login
        
        Args:
            schema_name: Name of the schema to delete
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
                # Check if schema exists
                check_schema_sql = text("""
                    SELECT COUNT(*) as count
                    FROM INFORMATION_SCHEMA.SCHEMATA
                    WHERE SCHEMA_NAME = :schema_name
                """)
                result = conn.execute(check_schema_sql, {"schema_name": schema_name}).fetchone()
                
                schema_exists = result.count > 0
                
                dropped_tables = []
                schema_dropped = False
                
                if schema_exists:
                    # Step 1: Drop all tables in the schema
                    try:
                        # Get all tables in the schema
                        get_tables_sql = text("""
                            SELECT TABLE_NAME
                            FROM INFORMATION_SCHEMA.TABLES
                            WHERE TABLE_SCHEMA = :schema_name
                        """)
                        tables = conn.execute(get_tables_sql, {"schema_name": schema_name}).fetchall()
                        
                        for table_row in tables:
                            table_name = table_row[0]
                            try:
                                drop_table_sql = text(f"DROP TABLE [{schema_name}].[{table_name}]")
                                conn.execute(drop_table_sql)
                                dropped_tables.append(table_name)
                                logger.info(f"Dropped table [{schema_name}].[{table_name}]")
                            except Exception as e:
                                logger.warning(f"Failed to drop table [{schema_name}].[{table_name}]: {e}")
                        
                        logger.info(f"Dropped {len(dropped_tables)} tables from schema '{schema_name}'")
                        
                    except Exception as e:
                        logger.error(f"Error dropping tables from schema '{schema_name}': {e}")
                        # Continue with schema deletion even if table dropping fails
                    
                    # Step 2: Drop all remaining schema objects (constraints, functions, procedures, etc.)
                    try:
                        # Drop all default constraints in the schema
                        drop_defaults_sql = text(f"""
                            DECLARE @sql NVARCHAR(MAX) = ''
                            SELECT @sql = @sql + 'ALTER TABLE [{schema_name}].[' + t.name + '] DROP CONSTRAINT [' + d.name + '];' + CHAR(13)
                            FROM sys.default_constraints d
                            INNER JOIN sys.tables t ON d.parent_object_id = t.object_id
                            INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
                            WHERE s.name = '{schema_name}'
                            EXEC sp_executesql @sql
                        """)
                        conn.execute(drop_defaults_sql)
                        logger.info(f"Dropped default constraints in schema '{schema_name}'")
                    except Exception as e:
                        logger.warning(f"Could not drop default constraints in schema '{schema_name}': {e}")
                    
                    try:
                        # Drop all check constraints in the schema
                        drop_checks_sql = text(f"""
                            DECLARE @sql NVARCHAR(MAX) = ''
                            SELECT @sql = @sql + 'ALTER TABLE [{schema_name}].[' + t.name + '] DROP CONSTRAINT [' + cc.name + '];' + CHAR(13)
                            FROM sys.check_constraints cc
                            INNER JOIN sys.tables t ON cc.parent_object_id = t.object_id
                            INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
                            WHERE s.name = '{schema_name}'
                            EXEC sp_executesql @sql
                        """)
                        conn.execute(drop_checks_sql)
                        logger.info(f"Dropped check constraints in schema '{schema_name}'")
                    except Exception as e:
                        logger.warning(f"Could not drop check constraints in schema '{schema_name}': {e}")
                    
                    try:
                        # Drop all foreign key constraints in the schema
                        drop_fks_sql = text(f"""
                            DECLARE @sql NVARCHAR(MAX) = ''
                            SELECT @sql = @sql + 'ALTER TABLE [{schema_name}].[' + t.name + '] DROP CONSTRAINT [' + fk.name + '];' + CHAR(13)
                            FROM sys.foreign_keys fk
                            INNER JOIN sys.tables t ON fk.parent_object_id = t.object_id
                            INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
                            WHERE s.name = '{schema_name}'
                            EXEC sp_executesql @sql
                        """)
                        conn.execute(drop_fks_sql)
                        logger.info(f"Dropped foreign key constraints in schema '{schema_name}'")
                    except Exception as e:
                        logger.warning(f"Could not drop foreign key constraints in schema '{schema_name}': {e}")
                    
                    try:
                        # Drop all views in the schema
                        drop_views_sql = text(f"""
                            DECLARE @sql NVARCHAR(MAX) = ''
                            SELECT @sql = @sql + 'DROP VIEW [{schema_name}].[' + v.name + '];' + CHAR(13)
                            FROM sys.views v
                            INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
                            WHERE s.name = '{schema_name}'
                            EXEC sp_executesql @sql
                        """)
                        conn.execute(drop_views_sql)
                        logger.info(f"Dropped views in schema '{schema_name}'")
                    except Exception as e:
                        logger.warning(f"Could not drop views in schema '{schema_name}': {e}")
                    
                    try:
                        # Drop all functions in the schema
                        drop_functions_sql = text(f"""
                            DECLARE @sql NVARCHAR(MAX) = ''
                            SELECT @sql = @sql + 'DROP FUNCTION [{schema_name}].[' + o.name + '];' + CHAR(13)
                            FROM sys.objects o
                            INNER JOIN sys.schemas s ON o.schema_id = s.schema_id
                            WHERE s.name = '{schema_name}' AND o.type IN ('FN', 'IF', 'TF')
                            EXEC sp_executesql @sql
                        """)
                        conn.execute(drop_functions_sql)
                        logger.info(f"Dropped functions in schema '{schema_name}'")
                    except Exception as e:
                        logger.warning(f"Could not drop functions in schema '{schema_name}': {e}")
                    
                    try:
                        # Drop all procedures in the schema
                        drop_procedures_sql = text(f"""
                            DECLARE @sql NVARCHAR(MAX) = ''
                            SELECT @sql = @sql + 'DROP PROCEDURE [{schema_name}].[' + p.name + '];' + CHAR(13)
                            FROM sys.procedures p
                            INNER JOIN sys.schemas s ON p.schema_id = s.schema_id
                            WHERE s.name = '{schema_name}'
                            EXEC sp_executesql @sql
                        """)
                        conn.execute(drop_procedures_sql)
                        logger.info(f"Dropped procedures in schema '{schema_name}'")
                    except Exception as e:
                        logger.warning(f"Could not drop procedures in schema '{schema_name}': {e}")
                    
                    # Step 3: Drop the schema
                    try:
                        drop_schema_sql = text(f"DROP SCHEMA [{schema_name}]")
                        conn.execute(drop_schema_sql)
                        schema_dropped = True
                        logger.info(f"Dropped schema '{schema_name}'")
                    except Exception as e:
                        logger.error(f"Failed to drop schema '{schema_name}': {e}")
                        raise Exception(f"Schema deletion failed: {str(e)}")
                else:
                    logger.info(f"Schema '{schema_name}' does not exist, proceeding with login and user cleanup")
                
                # Step 4: Drop database user
                user_dropped = False
                try:
                    check_user_sql = text("""
                        SELECT COUNT(*) as count
                        FROM sys.database_principals
                        WHERE name = :user_name AND type IN ('S', 'U')
                    """)
                    user_result = conn.execute(check_user_sql, {"user_name": schema_name}).fetchone()
                    
                    if user_result.count > 0:
                        drop_user_sql = text(f"DROP USER [{schema_name}]")
                        conn.execute(drop_user_sql)
                        user_dropped = True
                        logger.info(f"Dropped database user '{schema_name}'")
                    else:
                        logger.info(f"Database user '{schema_name}' does not exist")
                        
                except Exception as e:
                    logger.warning(f"Failed to drop database user '{schema_name}': {e}")
                    # Continue with login deletion even if user deletion fails
                
                # Step 5: Drop login
                login_dropped = False
                try:
                    check_login_sql = text("""
                        SELECT COUNT(*) as count
                        FROM sys.sql_logins
                        WHERE name = :login_name
                    """)
                    login_result = conn.execute(check_login_sql, {"login_name": schema_name}).fetchone()
                    
                    if login_result.count > 0:
                        drop_login_sql = text(f"DROP LOGIN [{schema_name}]")
                        conn.execute(drop_login_sql)
                        login_dropped = True
                        logger.info(f"Dropped login '{schema_name}'")
                    else:
                        logger.info(f"Login '{schema_name}' does not exist")
                        
                except Exception as e:
                    logger.warning(f"Failed to drop login '{schema_name}': {e}")
                
                # Commit all changes
                conn.commit()
                
                # Verify schema was actually deleted
                verify_schema_sql = text("""
                    SELECT COUNT(*) as count
                    FROM INFORMATION_SCHEMA.SCHEMATA
                    WHERE SCHEMA_NAME = :schema_name
                """)
                verify_result = conn.execute(verify_schema_sql, {"schema_name": schema_name}).fetchone()
                
                if verify_result.count > 0:
                    logger.error(f"Schema '{schema_name}' still exists after deletion attempt")
                    return {
                        "status": "error",
                        "message": f"Schema '{schema_name}' deletion verification failed"
                    }
                
                # Create appropriate response based on what was found and deleted
                if schema_exists:
                    response = {
                        "status": "success",
                        "message": f"Schema '{schema_name}' and associated user/login deleted successfully",
                        "schema_name": schema_name,
                        "tables_dropped": len(dropped_tables),
                        "schema_dropped": schema_dropped,
                        "user_dropped": user_dropped,
                        "login_dropped": login_dropped
                    }
                else:
                    # Schema didn't exist, but we cleaned up user/login leftovers
                    cleanup_message = f"Schema '{schema_name}' did not exist"
                    if user_dropped or login_dropped:
                        cleanup_message += f", but cleaned up leftovers: "
                        cleanup_parts = []
                        if user_dropped:
                            cleanup_parts.append("user")
                        if login_dropped:
                            cleanup_parts.append("login")
                        cleanup_message += " and ".join(cleanup_parts)
                    else:
                        cleanup_message += " and no user/login leftovers found"
                    
                    response = {
                        "status": "success",
                        "message": cleanup_message,
                        "schema_name": schema_name,
                        "tables_dropped": 0,
                        "schema_dropped": False,
                        "user_dropped": user_dropped,
                        "login_dropped": login_dropped
                    }
                
                logger.info(f"Successfully deleted SQL Server schema '{schema_name}' and all associated objects")
                return response
                
        except Exception as e:
            logger.error(f"Error deleting SQL Server schema '{schema_name}': {e}")
            return {
                "status": "error",
                "message": f"Error deleting schema: {str(e)}"
            }


# Backward compatibility functions
def create_schema_and_user_sqlserver(schema_name: str, admin_connection_string: str) -> Dict[str, Any]:
    """Backward compatibility function"""
    ops = SqlServerSchemaOperations()
    return ops.create_schema_and_user(schema_name, admin_connection_string)


def delete_schema_and_user_sqlserver(schema_name: str, admin_connection_string: str) -> Dict[str, Any]:
    """Backward compatibility function"""
    ops = SqlServerSchemaOperations()
    return ops.delete_schema_and_user(schema_name, admin_connection_string)