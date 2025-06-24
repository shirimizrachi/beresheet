"""
Events data loading module for tenant initialization.
This module provides functions to load events data into tenant tables using the create_event function from main.py.
"""

import csv
import os
import json
import asyncio
from pathlib import Path
from datetime import datetime, timedelta
from fastapi import UploadFile
import logging

logger = logging.getLogger(__name__)

async def load_events(tenant_name: str, home_id: int):
    """
    Load events data from CSV file and insert using the create_event function from main.py
    
    Args:
        tenant_name: Name of the tenant to load events for
        home_id: Home ID for the tenant
        
    Returns:
        Boolean indicating success
    """
    
    try:
        # Import the create_event function from main.py
        import sys
        import importlib.util
        
        # Get path to main.py
        main_path = Path(__file__).parent.parent / "main.py"
        
        # Load main.py as a module to access create_event function
        spec = importlib.util.spec_from_file_location("main", main_path)
        main_module = importlib.util.module_from_spec(spec)
        sys.modules["main_temp"] = main_module
        spec.loader.exec_module(main_module)
        
        # Get the CSV file path
        script_dir = Path(__file__).parent
        csv_file_path = script_dir / "schema" / "demo" / "data" / "event.csv"
        images_dir = script_dir / "schema" / "demo" / "events_images"
        
        if not csv_file_path.exists():
            logger.error(f"Events CSV file not found: {csv_file_path}")
            return False
        
        # Read events data from CSV
        events_data = []
        with open(csv_file_path, 'r', encoding='utf-8') as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                events_data.append(row)
        
        if not events_data:
            logger.warning("No events data found in CSV file")
            return False
        
        success_count = 0
        failed_count = 0
        
        for event_data in events_data:
            try:
                # Parse dates
                event_datetime_iso = _convert_sql_date_to_iso(event_data['dateTime'])
                
                recurring_end_date_iso = None
                if event_data['recurring_end_date'] and event_data['recurring_end_date'] != 'NULL':
                    recurring_end_date_iso = _convert_sql_date_to_iso(event_data['recurring_end_date'])
                
                recurring_pattern = None
                if event_data['recurring_pattern'] and event_data['recurring_pattern'] != 'NULL':
                    recurring_pattern = event_data['recurring_pattern']
                
                # Prepare image file if it exists
                image_file = None
                if event_data.get('image_url'):
                    image_filename = event_data['image_url']
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
                
                # Call the create_event function from main.py
                new_event = await main_module.create_event(
                    name=event_data['name'],
                    type=event_data['type'],
                    description=event_data['description'],
                    dateTime=event_datetime_iso,
                    location=event_data['location'],
                    maxParticipants=int(event_data['maxParticipants']),
                    currentParticipants=int(event_data['currentParticipants']),
                    status=event_data['status'],
                    recurring=event_data['recurring'],
                    recurring_end_date=recurring_end_date_iso,
                    recurring_pattern=recurring_pattern,
                    instructor_name=None,
                    instructor_desc=None,
                    instructor_photo=None,
                    image=image_file,
                    home_id=home_id,
                    firebase_token=None,
                    user_id=event_data['created_by']
                )
                
                if new_event:
                    success_count += 1
                    logger.info(f"Successfully created event: {event_data['id']} - {event_data['name']} -> {new_event.id}")
                else:
                    failed_count += 1
                    logger.error(f"Failed to create event: {event_data['id']} - {event_data['name']}")
                    
            except Exception as e:
                failed_count += 1
                logger.error(f"Error creating event {event_data['id']}: {e}")
        
        # Clean up module
        if "main_temp" in sys.modules:
            del sys.modules["main_temp"]
        
        logger.info(f"Events loading completed for tenant {tenant_name}: {success_count} successful, {failed_count} failed")
        return success_count > 0
        
    except Exception as e:
        logger.error(f"Error loading events data for tenant {tenant_name}: {e}")
        return False


def _convert_sql_date_to_iso(sql_date_expr: str) -> str:
    """
    Convert SQL date expressions like 'DATEADD(day, 1, GETDATE())' to ISO format
    For demo purposes, we'll use a base date and add the specified days
    
    Args:
        sql_date_expr: SQL date expression
        
    Returns:
        ISO formatted date string
    """
    try:
        base_date = datetime.now()
        
        if 'DATEADD(day,' in sql_date_expr:
            # Extract the number of days to add
            # Format: DATEADD(day, X, GETDATE())
            start_idx = sql_date_expr.find('DATEADD(day,') + len('DATEADD(day,')
            end_idx = sql_date_expr.find(',', start_idx)
            days_str = sql_date_expr[start_idx:end_idx].strip()
            
            try:
                days_to_add = int(days_str)
                result_date = base_date.replace(hour=8, minute=0, second=0, microsecond=0)
                
                # Add the days
                result_date += timedelta(days=days_to_add)
                
                return result_date.isoformat()
            except ValueError:
                pass
        
        elif 'DATEADD(month,' in sql_date_expr:
            # Extract the number of months to add
            start_idx = sql_date_expr.find('DATEADD(month,') + len('DATEADD(month,')
            end_idx = sql_date_expr.find(',', start_idx)
            months_str = sql_date_expr[start_idx:end_idx].strip()
            
            try:
                months_to_add = int(months_str)
                result_date = base_date.replace(hour=8, minute=0, second=0, microsecond=0)
                
                # Add the months (approximate)
                result_date += timedelta(days=months_to_add * 30)
                
                return result_date.isoformat()
            except ValueError:
                pass
        
        elif sql_date_expr == 'GETDATE()':
            return base_date.isoformat()
        
        # If we can't parse it, return current date + 1 day as fallback
        fallback_date = base_date + timedelta(days=1)
        return fallback_date.replace(hour=8, minute=0, second=0, microsecond=0).isoformat()
        
    except Exception as e:
        logger.warning(f"Could not parse SQL date expression '{sql_date_expr}': {e}")
        # Return a fallback date
        fallback_date = datetime.now() + timedelta(days=1)
        return fallback_date.replace(hour=8, minute=0, second=0, microsecond=0).isoformat()


def load_events_sync(tenant_name: str, home_id: int):
    """
    Synchronous wrapper for load_events function
    
    Args:
        tenant_name: Name of the tenant to load events for
        home_id: Home ID for the tenant
        
    Returns:
        Boolean indicating success
    """
    try:
        # Run the async function
        return asyncio.run(load_events(tenant_name, home_id))
    except Exception as e:
        logger.error(f"Error in sync wrapper for load_events: {e}")
        return False