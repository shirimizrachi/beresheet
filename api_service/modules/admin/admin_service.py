"""
Admin service class for tenant management operations
"""

import logging
import importlib.util
import sys
from pathlib import Path
from typing import List, Optional
from sqlalchemy import text, create_engine

from tenant_config import (
    TenantConfig,
    TenantCreate,
    TenantUpdate,
    tenant_config_db,
    get_tenant_connection_string
)
from database_utils import get_tenant_engine
from storage.storage_service import azure_storage_service
from deployment.load_events import load_events_sync
from deployment.load_users import load_users_sync
from deployment.load_event_instructor import load_event_instructor_sync
from deployment.load_rooms import load_rooms_sync
from deployment.load_service_provider_types import load_service_provider_types_sync
from deployment.load_home_notification import load_home_notification_sync

# Set up logging
logger = logging.getLogger(__name__)


class AdminService:
    """
    Service class for admin operations including tenant management,
    schema creation, table creation, and data initialization
    """

    def __init__(self):
        pass

    async def create_schema_and_user(self, schema_name: str):
        """
        Create a new database schema and a user with full permissions
        Uses the abstract factory pattern to automatically select the correct implementation
        """
        try:
            # Get admin database connection with elevated privileges for schema creation
            from residents_config import get_admin_connection_string, DATABASE_ENGINE
            from deployment.admin.schema_operations import create_schema_and_user
            
            admin_connection_string = get_admin_connection_string()
            database_engine = DATABASE_ENGINE
            
            # Use the abstract factory function that automatically selects the correct implementation
            result = create_schema_and_user(schema_name, admin_connection_string)
            
            logger.info(f"Successfully created schema '{schema_name}' using {database_engine} implementation")
            return result
                
        except Exception as e:
            logger.error(f"Error creating schema '{schema_name}': {e}")
            raise

    async def create_storage_container_for_tenant(self, tenant_name: str):
        """
        Create storage container for a tenant (Azure Blob or Cloudflare R2 based on environment)
        """
        # Get storage provider from residents_config
        from residents_config import get_storage_provider
        
        try:
            storage_type = get_storage_provider()
            
            if storage_type == 'cloudflare':
                # Use Cloudflare R2 bucket creation
                from deployment.schema.resources.create_bucket_cloudflare import create_cloudflare_bucket
                
                success = create_cloudflare_bucket(tenant_name)
                storage_name = "Cloudflare R2 bucket"
                
            else:
                # Default to Azure Blob Storage
                from deployment.schema.resources.create_blob_container import create_blob_container
                
                success = create_blob_container(tenant_name)
                storage_name = "Azure blob container"
            
            if success:
                response = {
                    "status": "success",
                    "message": f"{storage_name} created successfully for tenant '{tenant_name}'",
                    "container_name": f"{tenant_name}-images",
                    "tenant_name": tenant_name,
                    "storage_type": storage_type
                }
                logger.info(f"Successfully created {storage_name} for tenant '{tenant_name}'")
                return response
            else:
                response = {
                    "status": "failed",
                    "message": f"Failed to create {storage_name} for tenant '{tenant_name}'",
                    "container_name": f"{tenant_name}-images",
                    "tenant_name": tenant_name,
                    "storage_type": storage_type
                }
                logger.error(f"Failed to create {storage_name} for tenant '{tenant_name}'")
                return response
                
        except Exception as e:
            error_message = f"Error creating storage container for tenant '{tenant_name}': {str(e)}"
            logger.error(error_message)
            return {
                "status": "error",
                "message": error_message,
                "container_name": f"{tenant_name}-images",
                "tenant_name": tenant_name,
                "storage_type": storage_type,
                "error": str(e)
            }

    async def create_tables_for_tenant(self, tenant_name: str, drop_if_exists: bool = True):
        """
        Create all tables for a specific tenant using the API engine system
        """
        try:
            # Get tenant configuration
            tenant = tenant_config_db.load_tenant_config_from_db(tenant_name)
            if not tenant:
                raise Exception(f"Tenant '{tenant_name}' not found")
            
            # Get tenant connection string and engine
            connection_string = get_tenant_connection_string(tenant)
            engine = get_tenant_engine(connection_string, tenant_name)
            
            if not engine:
                raise Exception(f"Could not create database engine for tenant '{tenant_name}'")
            
            # List of table creation modules to execute
            table_scripts = [
                "create_users_table",
                "create_service_provider_types_table",
                "create_event_instructor_table",
                "create_events_table",
                "create_rooms_table",
                "create_event_gallery_table",
                "create_events_registration_table",
                "create_home_notification_table",
                "create_user_notification_table",
                "create_requests_table"
            ]
            
            created_tables = []
            failed_tables = []
            
            # Base path for table scripts
            tables_path = Path(__file__).parent.parent.parent / "deployment" / "schema" / "tables"
            
            for script_name in table_scripts:
                try:
                    script_path = tables_path / f"{script_name}.py"
                    
                    if not script_path.exists():
                        logger.warning(f"Table script not found: {script_path}")
                        failed_tables.append(f"{script_name} (file not found)")
                        continue
                    
                    # Load the module dynamically
                    spec = importlib.util.spec_from_file_location(script_name, script_path)
                    module = importlib.util.module_from_spec(spec)
                    
                    # Add the module to sys.modules temporarily
                    sys.modules[script_name] = module
                    spec.loader.exec_module(module)
                    
                    # Get the main creation function (assumes it follows naming convention)
                    function_name = script_name.replace("create_", "create_").replace("_table", "_table")
                    if hasattr(module, function_name):
                        # Call the function with engine, schema, and drop flag
                        success = module.__dict__[function_name](engine, tenant.database_schema, drop_if_exists)
                        if success:
                            created_tables.append(script_name.replace("create_", "").replace("_table", ""))
                            logger.info(f"Successfully created table using {script_name}")
                        else:
                            failed_tables.append(script_name)
                            logger.error(f"Failed to create table using {script_name}")
                    else:
                        logger.error(f"Function {function_name} not found in {script_name}")
                        failed_tables.append(f"{script_name} (function not found)")
                    
                    # Clean up module from sys.modules
                    del sys.modules[script_name]
                    
                except Exception as e:
                    logger.error(f"Error executing table script {script_name}: {e}")
                    failed_tables.append(f"{script_name} ({str(e)})")
            
            # Prepare response
            response = {
                "tenant_name": tenant_name,
                "schema": tenant.database_schema,
                "created_tables": created_tables,
                "failed_tables": failed_tables,
                "total_attempted": len(table_scripts),
                "total_created": len(created_tables),
                "total_failed": len(failed_tables)
            }
            
            if failed_tables:
                response["status"] = "partial_success"
                response["message"] = f"Created {len(created_tables)} tables successfully, {len(failed_tables)} failed"
            else:
                response["status"] = "success"
                response["message"] = f"All {len(created_tables)} tables created successfully"
            
            logger.info(f"Table creation completed for tenant '{tenant_name}': {response['message']}")
            return response
            
        except Exception as e:
            logger.error(f"Error creating tables for tenant '{tenant_name}': {e}")
            raise

    async def init_data_for_tenant(self, tenant_name: str):
        """
        Initialize demo data for a tenant including service provider types, users, 
        home notifications, rooms, event instructors, events with images
        """
        try:
            # Get tenant configuration
            tenant = tenant_config_db.load_tenant_config_from_db(tenant_name)
            if not tenant:
                raise Exception(f"Tenant '{tenant_name}' not found")
            
            # Load service provider types first (since users may reference them)
            service_types_success = load_service_provider_types_sync(tenant_name, tenant.id)
            
            # Load users data (since events and notifications may reference users)
            users_success = load_users_sync(tenant_name, tenant.id)
            
            # Load home notifications (since they are created by users)
            notifications_success = load_home_notification_sync(tenant_name, tenant.id)
            
            # Load rooms data first (since events may reference rooms)
            rooms_success = load_rooms_sync(tenant_name, tenant.id)
            
            # Load event instructors data first (since events may reference instructors)
            instructors_success = load_event_instructor_sync(tenant_name, tenant.id)
            
            # Load events data using the new function (after rooms and instructors are loaded)
            events_success = load_events_sync(tenant_name, tenant.id)
            
            # Determine overall success
            overall_success = service_types_success and users_success and notifications_success and rooms_success and instructors_success and events_success
            
            # Prepare data types list
            successful_data_types = []
            failed_data_types = []
            
            if service_types_success:
                successful_data_types.append("service_provider_types")
            else:
                failed_data_types.append("service_provider_types")
            
            if users_success:
                successful_data_types.extend(["users", "users_images"])
            else:
                failed_data_types.extend(["users", "users_images"])
                
            if notifications_success:
                successful_data_types.append("home_notifications")
            else:
                failed_data_types.append("home_notifications")
                
            if rooms_success:
                successful_data_types.append("rooms")
            else:
                failed_data_types.append("rooms")
                
            if instructors_success:
                successful_data_types.extend(["event_instructors", "instructor_images"])
            else:
                failed_data_types.extend(["event_instructors", "instructor_images"])
                
            if events_success:
                successful_data_types.extend(["events", "events_images"])
            else:
                failed_data_types.extend(["events", "events_images"])
            
            if overall_success:
                response = {
                    "status": "success",
                    "message": f"Demo data initialized successfully for tenant '{tenant_name}'",
                    "tenant_name": tenant_name,
                    "tenant_id": tenant.id,
                    "successful_data_types": successful_data_types,
                    "failed_data_types": failed_data_types
                }
                logger.info(f"Demo data initialization completed for tenant '{tenant_name}'")
                return response
            elif service_types_success or users_success or notifications_success or rooms_success or instructors_success or events_success:
                response = {
                    "status": "partial_success",
                    "message": f"Demo data partially initialized for tenant '{tenant_name}'",
                    "tenant_name": tenant_name,
                    "tenant_id": tenant.id,
                    "successful_data_types": successful_data_types,
                    "failed_data_types": failed_data_types
                }
                logger.warning(f"Demo data initialization partially completed for tenant '{tenant_name}'")
                return response
            else:
                response = {
                    "status": "failed",
                    "message": f"Failed to initialize demo data for tenant '{tenant_name}'",
                    "tenant_name": tenant_name,
                    "tenant_id": tenant.id,
                    "successful_data_types": successful_data_types,
                    "failed_data_types": failed_data_types
                }
                logger.error(f"Demo data initialization failed for tenant '{tenant_name}'")
                return response
                
        except Exception as e:
            logger.error(f"Error initializing demo data for tenant '{tenant_name}': {e}")
            raise

    def upload_users_profile_photos(self, engine, schema_name: str, home_id: int = 1):
        """
        Upload profile photos for users from demo_data/users-profile directory using provided engine
        """
        
        # Get the directory where this script is located
        script_dir = Path(__file__).parent.parent.parent
        photos_dir = script_dir / "deployment" / "schema" / "demo" / "profile_images"
        
        if not photos_dir.exists():
            logger.warning(f"Photos directory does not exist: {photos_dir}")
            return False
        
        try:
            with engine.connect() as conn:
                # Get all photo files
                photo_files = list(photos_dir.glob("*.jpg")) + list(photos_dir.glob("*.jpeg")) + list(photos_dir.glob("*.png"))
                
                if not photo_files:
                    logger.warning("No photo files found in profile_images directory")
                    return False
                
                logger.info(f"Found {len(photo_files)} photo files")
                
                success_count = 0
                failed_count = 0
                
                for photo_file in photo_files:
                    # Extract user_id from filename (remove extension)
                    user_id = photo_file.stem
                    
                    try:
                        # Check if user exists in database
                        check_user_sql = text(f"""
                            SELECT COUNT(*) as count FROM [{schema_name}].[users] WHERE id = :user_id
                        """)
                        result = conn.execute(check_user_sql, {"user_id": user_id}).fetchone()
                        
                        if result.count == 0:
                            logger.warning(f"User '{user_id}' not found in database, skipping photo: {photo_file.name}")
                            failed_count += 1
                            continue
                        
                        # Read the photo file
                        with open(photo_file, 'rb') as f:
                            image_data = f.read()
                        
                        # Determine content type
                        extension = photo_file.suffix.lower()
                        if extension in ['.jpg', '.jpeg']:
                            content_type = 'image/jpeg'
                        elif extension == '.png':
                            content_type = 'image/png'
                        else:
                            content_type = 'image/jpeg'  # Default
                        
                        # Get tenant name from schema_name for Azure Storage
                        # We need to get the tenant name from the schema to use for container naming
                        from tenant_config import get_all_tenants
                        tenant_name = None
                        tenants = get_all_tenants()
                        for tenant in tenants:
                            if tenant.database_schema == schema_name and tenant.id == home_id:
                                tenant_name = tenant.name
                                break
                        
                        if not tenant_name:
                            logger.warning(f"Could not find tenant name for schema '{schema_name}' and home_id '{home_id}', using schema name as fallback")
                            tenant_name = schema_name
                        
                        # Upload to Azure Storage with tenant name
                        success, result_message = azure_storage_service.upload_user_photo(
                            home_id=home_id,
                            user_id=user_id,
                            image_data=image_data,
                            original_filename=photo_file.name,
                            content_type=content_type,
                            tenant_name=tenant_name
                        )
                        
                        if success:
                            # Update user's photo URL in database
                            update_user_sql = text(f"""
                                UPDATE [{schema_name}].[users]
                                SET photo = :photo_url, updated_at = GETDATE()
                                WHERE id = :user_id
                            """)
                            conn.execute(update_user_sql, {
                                "photo_url": result_message,
                                "user_id": user_id
                            })
                            conn.commit()
                            
                            logger.info(f"Successfully uploaded photo for user '{user_id}': {photo_file.name}")
                            success_count += 1
                        else:
                            logger.error(f"Failed to upload photo for user '{user_id}': {result_message}")
                            failed_count += 1
                            
                    except Exception as e:
                        logger.error(f"Error processing photo for user '{user_id}': {e}")
                        failed_count += 1
                
                logger.info(f"Profile photo upload completed: {success_count} successful, {failed_count} failed")
                
                return success_count > 0
                
        except Exception as e:
            logger.error(f"Error connecting to database or uploading photos: {e}")
            return False


# Global singleton instance
admin_service = AdminService()