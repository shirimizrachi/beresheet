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
            
            database_exists = result.count > 0
            
            if not database_exists:
                # Create the database (MySQL uses database instead of schema)
                try:
                    create_database_sql = text(f"CREATE DATABASE `{schema_name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
                    conn.execute(create_database_sql)
                    logger.info(f"Created database '{schema_name}'")
                except Exception as e:
                    logger.error(f"Failed to create database '{schema_name}': {e}")
                    raise Exception(f"Database creation failed: {str(e)}")
            else:
                logger.info(f"Database '{schema_name}' already exists, skipping creation")
            
            # Check if user already exists
            check_user_sql = text("""
                SELECT COUNT(*) as count
                FROM mysql.user
                WHERE User = :user_name
            """)
            user_result = conn.execute(check_user_sql, {"user_name": schema_name}).fetchone()
            
            user_exists = user_result.count > 0
            
            if not user_exists:
                # Create MySQL user
                try:
                    create_user_sql = text(f"""
                        CREATE USER '{schema_name}'@'%' IDENTIFIED BY '{schema_name}2025!'
                    """)
                    conn.execute(create_user_sql)
                    logger.info(f"Created user '{schema_name}'")
                except Exception as e:
                    logger.error(f"Failed to create user '{schema_name}': {e}")
                    raise Exception(f"User creation failed: {str(e)}")
            else:
                logger.info(f"User '{schema_name}' already exists, skipping creation")
            
            # Grant full permissions on the database to the user
            try:
                grant_permissions_sql = text(f"""
                    GRANT ALL PRIVILEGES ON `{schema_name}`.* TO '{schema_name}'@'%'
                """)
                conn.execute(grant_permissions_sql)
                logger.info(f"Granted full permissions on database '{schema_name}' to user '{schema_name}'")
            except Exception as e:
                logger.error(f"Failed to grant permissions on database '{schema_name}': {e}")
                raise Exception(f"Permission granting failed: {str(e)}")
            
            # Flush privileges to ensure they take effect
            try:
                flush_privileges_sql = text("FLUSH PRIVILEGES")
                conn.execute(flush_privileges_sql)
                logger.info(f"Flushed privileges for user '{schema_name}'")
            except Exception as e:
                logger.error(f"Failed to flush privileges: {e}")
                raise Exception(f"Privilege flush failed: {str(e)}")
            
            # Commit all changes to ensure database is properly created before returning
            conn.commit()
            
            # Verify database was actually created
            verify_database_sql = text("""
                SELECT COUNT(*) as count
                FROM INFORMATION_SCHEMA.SCHEMATA
                WHERE SCHEMA_NAME = :schema_name
            """)
            verify_result = conn.execute(verify_database_sql, {"schema_name": schema_name}).fetchone()
            
            if verify_result.count == 0:
                logger.error(f"Database '{schema_name}' was not created successfully")
                return {
                    "status": "error",
                    "message": f"Database '{schema_name}' verification failed after creation"
                }
            
            response = {
                "status": "success",
                "message": f"Database '{schema_name}' and user setup completed successfully",
                "schema_name": schema_name,
                "user_name": schema_name,
                "password": f"{schema_name}2025!",
                "permissions": "Full permissions on database",
                "database_created": not database_exists,
                "user_created": not user_exists,
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

def delete_schema_and_user_mysql(schema_name: str, admin_connection_string: str) -> Dict[str, Any]:
    """
    Completely delete a MySQL database (schema) and the associated user
    
    Args:
        schema_name: Name of the database/schema to delete
        admin_connection_string: Admin connection string with elevated privileges
        
    Returns:
        Dictionary with status and details of deletion process
    """
    try:
        # Validate schema name (must be alphanumeric)
        if not schema_name.replace("_", "").replace("-", "").isalnum():
            return {
                "status": "error",
                "message": "Database name must be alphanumeric (with optional hyphens and underscores)"
            }
        
        admin_engine = create_engine(admin_connection_string)
        
        with admin_engine.connect() as conn:
            # Check if database exists
            check_database_sql = text("""
                SELECT COUNT(*) as count
                FROM INFORMATION_SCHEMA.SCHEMATA
                WHERE SCHEMA_NAME = :schema_name
            """)
            result = conn.execute(check_database_sql, {"schema_name": schema_name}).fetchone()
            
            database_exists = result.count > 0
            
            dropped_tables = []
            database_dropped = False
            
            if database_exists:
                # Step 1: Get list of tables before dropping database (for reporting)
                try:
                    get_tables_sql = text("""
                        SELECT TABLE_NAME
                        FROM INFORMATION_SCHEMA.TABLES
                        WHERE TABLE_SCHEMA = :schema_name
                    """)
                    tables = conn.execute(get_tables_sql, {"schema_name": schema_name}).fetchall()
                    dropped_tables = [table_row[0] for table_row in tables]
                    logger.info(f"Found {len(dropped_tables)} tables in database '{schema_name}'")
                    
                except Exception as e:
                    logger.warning(f"Could not get table list for database '{schema_name}': {e}")
                
                # Step 2: Drop the database (this automatically drops all tables)
                try:
                    drop_database_sql = text(f"DROP DATABASE `{schema_name}`")
                    conn.execute(drop_database_sql)
                    database_dropped = True
                    logger.info(f"Dropped database '{schema_name}' with {len(dropped_tables)} tables")
                except Exception as e:
                    logger.error(f"Failed to drop database '{schema_name}': {e}")
                    raise Exception(f"Database deletion failed: {str(e)}")
            else:
                logger.info(f"Database '{schema_name}' does not exist, proceeding with user cleanup")
            
            # Step 3: Drop user
            user_dropped = False
            try:
                check_user_sql = text("""
                    SELECT COUNT(*) as count
                    FROM mysql.user
                    WHERE User = :user_name
                """)
                user_result = conn.execute(check_user_sql, {"user_name": schema_name}).fetchone()
                
                if user_result.count > 0:
                    drop_user_sql = text(f"DROP USER '{schema_name}'@'%'")
                    conn.execute(drop_user_sql)
                    user_dropped = True
                    logger.info(f"Dropped user '{schema_name}'")
                else:
                    logger.info(f"User '{schema_name}' does not exist")
                    
            except Exception as e:
                logger.warning(f"Failed to drop user '{schema_name}': {e}")
            
            # Step 4: Flush privileges to ensure changes take effect
            try:
                flush_privileges_sql = text("FLUSH PRIVILEGES")
                conn.execute(flush_privileges_sql)
                logger.info(f"Flushed privileges after deleting user '{schema_name}'")
            except Exception as e:
                logger.warning(f"Failed to flush privileges: {e}")
            
            # Commit all changes
            conn.commit()
            
            # Verify database was actually deleted
            verify_database_sql = text("""
                SELECT COUNT(*) as count
                FROM INFORMATION_SCHEMA.SCHEMATA
                WHERE SCHEMA_NAME = :schema_name
            """)
            verify_result = conn.execute(verify_database_sql, {"schema_name": schema_name}).fetchone()
            
            if verify_result.count > 0:
                logger.error(f"Database '{schema_name}' still exists after deletion attempt")
                return {
                    "status": "error",
                    "message": f"Database '{schema_name}' deletion verification failed"
                }
            
            # Create appropriate response based on what was found and deleted
            if database_exists:
                response = {
                    "status": "success",
                    "message": f"Database '{schema_name}' and associated user deleted successfully",
                    "schema_name": schema_name,
                    "tables_dropped": len(dropped_tables),
                    "database_dropped": database_dropped,
                    "user_dropped": user_dropped,
                    "table_names": dropped_tables
                }
            else:
                # Database didn't exist, but we cleaned up user leftovers
                cleanup_message = f"Database '{schema_name}' did not exist"
                if user_dropped:
                    cleanup_message += ", but cleaned up leftover user"
                else:
                    cleanup_message += " and no user leftovers found"
                
                response = {
                    "status": "success",
                    "message": cleanup_message,
                    "schema_name": schema_name,
                    "tables_dropped": 0,
                    "database_dropped": False,
                    "user_dropped": user_dropped,
                    "table_names": []
                }
            
            logger.info(f"Successfully deleted MySQL database '{schema_name}' and all associated objects")
            return response
            
    except Exception as e:
        logger.error(f"Error deleting MySQL database '{schema_name}': {e}")
        return {
            "status": "error",
            "message": f"Error deleting database: {str(e)}"
        }