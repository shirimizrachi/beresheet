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
from fastapi import UploadFile
import logging

logger = logging.getLogger(__name__)

async def load_users(tenant_name: str, home_id: int):
    """
    Load users data from CSV file and insert using the create_user_profile function from main.py
    
    Args:
        tenant_name: Name of the tenant to load users for
        home_id: Home ID for the tenant
        
    Returns:
        Boolean indicating success
    """
    
    try:
        # Import the create_user_profile function from main.py
        import sys
        import importlib.util
        
        # Get path to main.py
        main_path = Path(__file__).parent.parent / "main.py"
        
        # Load main.py as a module to access create_user_profile function
        spec = importlib.util.spec_from_file_location("main", main_path)
        main_module = importlib.util.module_from_spec(spec)
        sys.modules["main_temp"] = main_module
        spec.loader.exec_module(main_module)
        
        # Import models for UserProfileCreate
        from models import UserProfileCreate
        
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
                # Parse birthday
                birthday_date = None
                if user_data.get('birthday'):
                    try:
                        birthday_date = datetime.strptime(user_data['birthday'], '%Y-%m-%d').date()
                    except ValueError:
                        logger.warning(f"Invalid birthday format for user {user_data['id']}: {user_data['birthday']}")
                
                # Handle service provider type
                service_provider_type = user_data.get('service_provider_type')
                if service_provider_type == 'NULL':
                    service_provider_type = None
                
                # Create UserProfileCreate object
                user_profile_create = UserProfileCreate(
                    full_name=user_data['full_name'],
                    phone_number=user_data['phone_number'],
                    role=user_data['role'],
                    birthday=birthday_date,
                    apartment_number=user_data['apartment_number'],
                    marital_status=user_data['marital_status'],
                    gender=user_data['gender'],
                    religious=user_data['religious'],
                    native_language=user_data['native_language'],
                    service_provider_type_id=service_provider_type
                )
                
                # Call the create_user_profile function from main.py
                new_user = await main_module.create_user_profile(
                    user=user_profile_create,
                    current_user_id='default-manager-user',  # Use default manager as creator
                    home_id=home_id,
                    firebase_id=user_data['firebase_id']
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
                                
                                # Create UploadFile-like object
                                class MockUploadFile:
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
                                
                                image_file = MockUploadFile(image_filename, image_data, content_type)
                                
                                # Update user with photo using update_user_profile function
                                updated_user = await main_module.update_user_profile(
                                    user_id=new_user.id,
                                    full_name=None,
                                    phone_number=None,
                                    role=None,
                                    birthday=None,
                                    apartment_number=None,
                                    marital_status=None,
                                    gender=None,
                                    religious=None,
                                    native_language=None,
                                    service_provider_type_id=None,
                                    photo=image_file,
                                    home_id=home_id
                                )
                                
                                if updated_user:
                                    logger.info(f"Successfully uploaded image for user {new_user.id}")
                                else:
                                    logger.warning(f"Failed to update user {new_user.id} with image")
                                    
                            except Exception as e:
                                logger.warning(f"Error processing image for user {new_user.id}: {e}")
                    
                    success_count += 1
                    logger.info(f"Successfully created user: {user_data['id']} - {user_data['full_name']} -> {new_user.id}")
                else:
                    failed_count += 1
                    logger.error(f"Failed to create user: {user_data['id']} - {user_data['full_name']}")
                    
            except Exception as e:
                failed_count += 1
                logger.error(f"Error creating user {user_data['id']}: {e}")
        
        # Clean up module
        if "main_temp" in sys.modules:
            del sys.modules["main_temp"]
        
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
        # Run the async function
        return asyncio.run(load_users(tenant_name, home_id))
    except Exception as e:
        logger.error(f"Error in sync wrapper for load_users: {e}")
        return False