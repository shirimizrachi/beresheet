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

async def load_event_instructor(tenant_name: str, home_id: int):
    """
    Load event instructor data from CSV file and insert using the create_event_instructor function from main.py
    
    Args:
        tenant_name: Name of the tenant to load event instructors for
        home_id: Home ID for the tenant
        
    Returns:
        Boolean indicating success
    """
    
    try:
        # Import the create_event_instructor function from main.py
        import sys
        import importlib.util
        
        # Get path to main.py
        main_path = Path(__file__).parent.parent / "main.py"
        
        # Load main.py as a module to access create_event_instructor function
        spec = importlib.util.spec_from_file_location("main", main_path)
        main_module = importlib.util.module_from_spec(spec)
        sys.modules["main_temp"] = main_module
        spec.loader.exec_module(main_module)
        
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
                # Prepare image file if it exists
                image_file = None
                if instructor_data.get('photo'):
                    image_filename = instructor_data['photo']
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
                            
                        except Exception as e:
                            logger.warning(f"Error reading image file {image_filename}: {e}")
                
                # Call the create_event_instructor function from main.py
                new_instructor = await main_module.create_event_instructor(
                    name=instructor_data['name'],
                    description=instructor_data['description'],
                    photo=image_file,
                    home_id=home_id,
                    current_user_id='default-manager-user'  # Use default manager as creator
                )
                
                if new_instructor:
                    success_count += 1
                    logger.info(f"Successfully created event instructor: {instructor_data['id']} - {instructor_data['name']} -> {new_instructor.id}")
                else:
                    failed_count += 1
                    logger.error(f"Failed to create event instructor: {instructor_data['id']} - {instructor_data['name']}")
                    
            except Exception as e:
                failed_count += 1
                logger.error(f"Error creating event instructor {instructor_data['id']}: {e}")
        
        # Clean up module
        if "main_temp" in sys.modules:
            del sys.modules["main_temp"]
        
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
        # Run the async function
        return asyncio.run(load_event_instructor(tenant_name, home_id))
    except Exception as e:
        logger.error(f"Error in sync wrapper for load_event_instructor: {e}")
        return False