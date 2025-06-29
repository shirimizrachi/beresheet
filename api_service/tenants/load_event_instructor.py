"""
Event instructor data loading module for tenant initialization.
This module provides functions to load event instructor data into tenant tables using the create_event_instructor function from main.py.
"""

import csv
import os
import json
import asyncio
from pathlib import Path
from datetime import datetime
from fastapi import UploadFile
import logging

logger = logging.getLogger(__name__)

def load_event_instructor(tenant_name: str, home_id: int):
    """
    Load event instructor data from CSV file and insert using the create_event_instructor function from main.py
    
    Args:
        tenant_name: Name of the tenant to load event instructors for
        home_id: Home ID for the tenant
        
    Returns:
        Boolean indicating success
    """
    
    try:
        # Import the necessary modules
        import sys
        sys.path.append(str(Path(__file__).parent.parent))
        
        # Import the event instructor database functions
        from modules.events.event_instructor import event_instructor_db
        from modules.events.models import EventInstructorCreate
        
        # Get the CSV file path
        script_dir = Path(__file__).parent
        csv_file_path = script_dir / "schema" / "demo" / "data" / "event_instructor.csv"
        images_dir = script_dir / "schema" / "demo" / "instructor_images"
        
        if not csv_file_path.exists():
            logger.error(f"Event instructor CSV file not found: {csv_file_path}")
            return False
        
        # Read event instructor data from CSV
        instructors_data = []
        with open(csv_file_path, 'r', encoding='utf-8') as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                instructors_data.append(row)
        
        if not instructors_data:
            logger.warning("No event instructor data found in CSV file")
            return False
        
        success_count = 0
        failed_count = 0
        
        for instructor_data in instructors_data:
            try:
                # Prepare image file using instructor ID
                image_file = None
                instructor_id = instructor_data['id']
                
                # Try to find image with instructor ID as filename
                image_filename = f"{instructor_id}.jpg"
                image_path = images_dir / image_filename
                
                if image_path.exists():
                    try:
                        logger.info(f"Loading image for instructor {instructor_id}: {image_filename}")
                        # Read image data
                        with open(image_path, 'rb') as img_file:
                            image_data = img_file.read()
                        
                        # Create UploadFile-like object
                        class MockUploadFile:
                            def __init__(self, filename, content, content_type):
                                self.filename = filename
                                self.content = content
                                self.content_type = content_type
                            
                            def read(self):
                                return self.content
                        
                        # Use JPEG as default content type
                        image_file = MockUploadFile(image_filename, image_data, 'image/jpeg')
                        
                    except Exception as e:
                        logger.warning(f"Error reading image file {image_filename}: {e}")
                else:
                    logger.info(f"Image file not found for instructor {instructor_id}: {image_path}")
                    logger.info(f"Instructor {instructor_id} will be created without photo")
                
                # Create EventInstructorCreate object
                instructor_create = EventInstructorCreate(
                    name=instructor_data['name'],
                    description=instructor_data['description']
                )
                
                # Call the create_event_instructor function from instructor database
                new_instructor = event_instructor_db.create_event_instructor(
                    instructor_data=instructor_create,
                    home_id=home_id
                )
                
                if new_instructor:
                    # If we have an image file, upload it using the photo upload function
                    if image_file:
                        try:
                            # Import the photo upload function from events database
                            from modules.events.events import event_db
                            from modules.events.models import EventInstructorUpdate
                            
                            # Create a proper UploadFile-like object that works with the upload function
                            class AsyncMockUploadFile:
                                def __init__(self, filename, content, content_type):
                                    self.filename = filename
                                    self.content = content
                                    self.content_type = content_type
                                
                                async def read(self):
                                    return self.content
                            
                            # Create async upload file
                            async_image_file = AsyncMockUploadFile(image_filename, image_data, 'image/jpeg')
                            
                            # Use the extracted photo upload function to upload to Azure Storage
                            async def upload_photo():
                                return await event_db.upload_event_instructor_photo(
                                    instructor_id=new_instructor.id,
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
                            
                            # Update instructor with the Azure Storage photo URL
                            instructor_update = EventInstructorUpdate(photo=photo_url)
                            updated_instructor = event_instructor_db.update_event_instructor(
                                instructor_id=new_instructor.id,
                                instructor_data=instructor_update,
                                home_id=home_id
                            )
                            if updated_instructor:
                                logger.info(f"Successfully uploaded and updated instructor {new_instructor.id} with photo URL: {photo_url}")
                            else:
                                logger.warning(f"Failed to update instructor {new_instructor.id} with photo URL")
                        except Exception as e:
                            logger.error(f"Error uploading photo for instructor {new_instructor.id}: {e}")
                            import traceback
                            logger.error(f"Full traceback: {traceback.format_exc()}")
                    
                    success_count += 1
                    logger.info(f"Successfully created event instructor: {instructor_data['id']} - {instructor_data['name']} -> {new_instructor.id}")
                else:
                    failed_count += 1
                    logger.error(f"Failed to create event instructor: {instructor_data['id']} - {instructor_data['name']}")
                    
            except Exception as e:
                failed_count += 1
                logger.error(f"Error creating event instructor {instructor_data['id']}: {e}")
        
        logger.info(f"Event instructors loading completed for tenant {tenant_name}: {success_count} successful, {failed_count} failed")
        return success_count > 0
        
    except Exception as e:
        logger.error(f"Error loading event instructor data for tenant {tenant_name}: {e}")
        return False


def load_event_instructor_sync(tenant_name: str, home_id: int):
    """
    Synchronous wrapper for load_event_instructor function
    
    Args:
        tenant_name: Name of the tenant to load event instructors for
        home_id: Home ID for the tenant
        
    Returns:
        Boolean indicating success
    """
    try:
        # Call the function directly since it's now synchronous
        return load_event_instructor(tenant_name, home_id)
    except Exception as e:
        logger.error(f"Error in sync wrapper for load_event_instructor: {e}")
        return False