"""
Users data loading module for tenant initialization.
This module provides functions to load users data into tenant tables using the create_user_profile function from main.py.
"""

import csv
import os
import json
import asyncio
from pathlib import Path
from datetime import datetime, date
from typing import Optional
from fastapi import UploadFile
import logging

logger = logging.getLogger(__name__)

def get_service_provider_type_id_by_name(service_type_name: str, home_id: int) -> Optional[str]:
    """Get service provider type ID by name from the database"""
    try:
        import sys
        sys.path.append(str(Path(__file__).parent.parent))
        
        from modules.users import service_provider_type_db
        
        # Get all service provider types for this home
        all_types = service_provider_type_db.get_all_service_provider_types(home_id)
        
        # Find the type by name
        for service_type in all_types:
            if service_type.name == service_type_name:
                return service_type.id
        
        return None
    except Exception as e:
        logger.error(f"Error getting service provider type ID by name '{service_type_name}': {e}")
        return None

def load_users(tenant_name: str, home_id: int):
    """
    Load users data from CSV file and insert using the create_user_profile function from main.py
    
    Args:
        tenant_name: Name of the tenant to load users for
        home_id: Home ID for the tenant
        
    Returns:
        Boolean indicating success
    """
    
    try:
        # Import the user database directly from the users module
        import sys
        sys.path.append(str(Path(__file__).parent.parent))
        
        from modules.users import user_db
        
        # Import models for UserProfileCreate
        from modules.users.models import UserProfileCreate
        
        # Get the CSV file path
        script_dir = Path(__file__).parent
        csv_file_path = script_dir / "schema" / "demo" / "data" / "users.csv"
        images_dir = script_dir / "schema" / "demo" / "profile_images"
        
        if not csv_file_path.exists():
            logger.error(f"Users CSV file not found: {csv_file_path}")
            return False
        
        # Read users data from CSV
        users_data = []
        with open(csv_file_path, 'r', encoding='utf-8') as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                users_data.append(row)
        
        if not users_data:
            logger.warning("No users data found in CSV file")
            return False
        
        success_count = 0
        failed_count = 0
        
        for user_data in users_data:
            try:
                # Parse birthday - ensure it's None if empty or invalid
                birthday_date = None
                birthday_str = user_data.get('birthday', '').strip()
                if birthday_str and birthday_str != 'NULL':
                    try:
                        birthday_date = datetime.strptime(birthday_str, '%Y-%m-%d').date()
                    except ValueError:
                        logger.warning(f"Invalid birthday format for user {user_data['id']}: {birthday_str}")
                        birthday_date = None
                
                # Handle service provider type - need to map Hebrew names to IDs
                service_provider_type_name = user_data.get('service_provider_type')
                service_provider_type_id = None
                
                if service_provider_type_name and service_provider_type_name != 'NULL' and service_provider_type_name.strip():
                    # Get service provider type ID by name from the database
                    service_provider_type_id = get_service_provider_type_id_by_name(service_provider_type_name.strip(), home_id)
                    if not service_provider_type_id:
                        logger.warning(f"Service provider type '{service_provider_type_name}' not found for user {user_data['id']}")
                
                # Helper function to convert empty strings to None
                def clean_field(value):
                    if value == 'NULL' or not value or not value.strip():
                        return None
                    return value.strip()
                
                # Create UserProfileCreate object
                user_profile_create = UserProfileCreate(
                    home_id=home_id,
                    full_name=clean_field(user_data['full_name']),
                    phone_number=user_data['phone_number'],
                    role=clean_field(user_data['role']),
                    birthday=birthday_date,
                    apartment_number=clean_field(user_data['apartment_number']),
                    marital_status=clean_field(user_data['marital_status']),
                    gender=clean_field(user_data['gender']),
                    religious=clean_field(user_data['religious']),
                    native_language=clean_field(user_data['native_language']),
                    service_provider_type_name=service_provider_type_name.strip() if service_provider_type_name and service_provider_type_name != 'NULL' else None,
                    service_provider_type_id=service_provider_type_id
                )
                
                # Call the create_user_profile function from user_db
                new_user = user_db.create_user_profile(
                    firebase_id=user_data['firebase_id'],
                    user_data=user_profile_create,
                    home_id=home_id
                )
                
                if new_user:
                    # Handle image upload if image exists
                    if user_data.get('photo') and user_data['photo'] != 'NULL':
                        image_filename = user_data['photo']
                        image_path = images_dir / image_filename
                        if image_path.exists():
                            try:
                                # Read image data
                                with open(image_path, 'rb') as img_file:
                                    image_data = img_file.read()
                                
                                # Create UploadFile-like object that works with the upload function
                                class AsyncMockUploadFile:
                                    def __init__(self, filename, content, content_type):
                                        self.filename = filename
                                        self.content = content
                                        self.content_type = content_type
                                    
                                    async def read(self):
                                        return self.content
                                
                                # Determine content type
                                extension = image_path.suffix.lower()
                                if extension in ['.jpg', '.jpeg']:
                                    content_type = 'image/jpeg'
                                elif extension == '.png':
                                    content_type = 'image/png'
                                else:
                                    content_type = 'image/jpeg'  # Default
                                
                                # Create async upload file
                                async_image_file = AsyncMockUploadFile(image_filename, image_data, content_type)
                                
                                # Use the extracted photo upload function to upload to Azure Storage
                                async def upload_photo():
                                    return await user_db.upload_user_profile_photo(
                                        user_id=new_user.id,
                                        photo=async_image_file,
                                        home_id=home_id,
                                        tenant_name=tenant_name
                                    )
                                
                                # Run the async upload function using the event loop
                                try:
                                    loop = asyncio.get_event_loop()
                                    if loop.is_running():
                                        # If loop is running, we need to use a different approach
                                        import concurrent.futures
                                        with concurrent.futures.ThreadPoolExecutor() as executor:
                                            future = executor.submit(asyncio.run, upload_photo())
                                            photo_url = future.result()
                                    else:
                                        photo_url = loop.run_until_complete(upload_photo())
                                except RuntimeError:
                                    # No event loop exists, create a new one
                                    photo_url = asyncio.run(upload_photo())
                                
                                # Update user with the Azure Storage photo URL
                                from modules.users.models import UserProfileUpdate
                                user_update = UserProfileUpdate(photo=photo_url)
                                updated_user = user_db.update_user_profile(
                                    user_id=new_user.id,
                                    user_data=user_update,
                                    home_id=home_id
                                )
                                
                                if updated_user:
                                    logger.info(f"Successfully uploaded and updated user {new_user.id} with photo URL: {photo_url}")
                                else:
                                    logger.warning(f"Failed to update user {new_user.id} with photo URL")
                                    
                            except Exception as e:
                                logger.error(f"Error uploading photo for user {new_user.id}: {e}")
                                import traceback
                                logger.error(f"Full traceback: {traceback.format_exc()}")
                    
                    success_count += 1
                    logger.info(f"Successfully created user: {user_data['id']} - {user_data['full_name']} -> {new_user.id}")
                else:
                    failed_count += 1
                    logger.error(f"Failed to create user: {user_data['id']} - {user_data['full_name']}")
                    
            except Exception as e:
                failed_count += 1
                logger.error(f"Error creating user {user_data['id']}: {e}")
        
        logger.info(f"Users loading completed for tenant {tenant_name}: {success_count} successful, {failed_count} failed")
        return success_count > 0
        
    except Exception as e:
        logger.error(f"Error loading users data for tenant {tenant_name}: {e}")
        return False


def load_users_sync(tenant_name: str, home_id: int):
    """
    Synchronous wrapper for load_users function
    
    Args:
        tenant_name: Name of the tenant to load users for
        home_id: Home ID for the tenant
        
    Returns:
        Boolean indicating success
    """
    try:
        # Call the function directly since it's now synchronous
        return load_users(tenant_name, home_id)
    except Exception as e:
        logger.error(f"Error in sync wrapper for load_users: {e}")
        return False