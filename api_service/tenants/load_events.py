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
from .csv_date_helpers import process_csv_row

logger = logging.getLogger(__name__)

def load_events(tenant_name: str, home_id: int, auto_populate: bool = True):
    """
    Load events data from CSV file and insert using the create_event function from main.py
    
    Args:
        tenant_name: Name of the tenant to load events for
        home_id: Home ID for the tenant
        auto_populate: Whether to auto-populate location and instructor from existing data
        
    Returns:
        Boolean indicating success
    """
    
    try:
        # Import the necessary modules
        import sys
        sys.path.append(str(Path(__file__).parent.parent))
        
        # Import the event database functions
        from modules.events.events import event_db
        from modules.events.models import EventCreate
        
        # Import other modules for rooms and instructors
        from modules.events.events_room import room_db
        from modules.events.event_instructor import event_instructor_db
        
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
                # Debug: Print raw row to see if columns are aligned correctly
                logger.info(f"Raw CSV row for {row.get('id', 'unknown')}: {row}")
                
                # Process the row to convert date functions
                processed_row = process_csv_row(row)
                
                # Debug: Print processed row
                logger.info(f"Processed row for {processed_row.get('id', 'unknown')}: dateTime={processed_row.get('dateTime')}, maxParticipants={processed_row.get('maxParticipants')}")
                
                events_data.append(processed_row)
        
        if not events_data:
            logger.warning("No events data found in CSV file")
            return False
        
        # Get available rooms and instructors for auto-population if enabled
        rooms = []
        instructors = []
        if auto_populate:
            try:
                rooms = room_db.get_all_rooms(home_id)
                instructors = event_instructor_db.get_all_event_instructors(home_id)
                logger.info(f"Auto-populate enabled: Found {len(rooms)} rooms and {len(instructors)} instructors")
            except Exception as e:
                logger.warning(f"Could not load rooms/instructors for auto-population: {e}")
                rooms = []
                instructors = []
        else:
            logger.info("Auto-populate disabled")
        
        success_count = 0
        failed_count = 0
        
        for event_data in events_data:
            try:
                # Parse dates - already processed by CSV helper
                try:
                    event_datetime_iso = datetime.fromisoformat(event_data['dateTime'])
                except ValueError:
                    logger.warning(f"Invalid dateTime format for event {event_data['id']}: {event_data['dateTime']}")
                    event_datetime_iso = datetime.now() + timedelta(days=1)
                
                recurring_end_date_iso = None
                if event_data['recurring_end_date'] and event_data['recurring_end_date'] != 'NULL':
                    try:
                        recurring_end_date_iso = datetime.fromisoformat(event_data['recurring_end_date'])
                    except ValueError:
                        logger.warning(f"Invalid recurring_end_date format for event {event_data['id']}: {event_data['recurring_end_date']}")
                        recurring_end_date_iso = datetime.now() + timedelta(days=90)
                
                recurring_pattern = None
                if event_data['recurring_pattern'] and event_data['recurring_pattern'] != 'NULL':
                    recurring_pattern = event_data['recurring_pattern']
                
                # Parse integer fields with error handling
                try:
                    max_participants = int(event_data['maxParticipants'].strip())
                except (ValueError, AttributeError) as e:
                    logger.warning(f"Invalid maxParticipants value '{event_data['maxParticipants']}' for event {event_data['id']}, using default 10")
                    max_participants = 10
                
                try:
                    current_participants = int(event_data['currentParticipants'].strip())
                except (ValueError, AttributeError) as e:
                    logger.warning(f"Invalid currentParticipants value '{event_data['currentParticipants']}' for event {event_data['id']}, using default 0")
                    current_participants = 0
                
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
                
                # Handle location - use CSV value or auto-populate if empty
                location = event_data.get('location', '').strip()
                if not location and auto_populate and rooms:
                    # Use random room from available rooms
                    import random
                    selected_room = random.choice(rooms)
                    location = selected_room.room_name
                    logger.info(f"Auto-assigned random location '{location}' to event {event_data['id']}")
                elif not location:
                    location = "חדר כללי"  # Default room name
                    logger.warning(f"No location data available, using default for event {event_data['id']}")
                
                # Handle instructor - auto-populate instructor fields if not specified in CSV
                instructor_id = event_data.get('instructor_id', '').strip()
                instructor_name = event_data.get('instructor_name', '').strip()
                instructor_desc = event_data.get('instructor_desc', '').strip()
                instructor_photo = event_data.get('instructor_photo', '').strip()
                
                if not instructor_id and not instructor_name and auto_populate and instructors:
                    # Use random instructor from available instructors
                    import random
                    selected_instructor = random.choice(instructors)
                    instructor_id = selected_instructor.id
                    instructor_name = selected_instructor.name
                    instructor_desc = selected_instructor.description or ""
                    instructor_photo = selected_instructor.photo or ""
                    logger.info(f"Auto-assigned random instructor '{instructor_name}' to event {event_data['id']}")
                elif not instructor_id and not instructor_name:
                    logger.info(f"No instructor assigned to event {event_data['id']}")
                
                # Create EventCreate object
                event_create = EventCreate(
                    name=event_data['name'],
                    type=event_data['type'],
                    description=event_data['description'],
                    dateTime=event_datetime_iso,
                    location=location,
                    maxParticipants=max_participants,
                    currentParticipants=current_participants,
                    status=event_data['status'],
                    recurring=event_data['recurring'],
                    recurring_end_date=recurring_end_date_iso,
                    recurring_pattern=recurring_pattern,
                    instructor_name=instructor_name,
                    instructor_desc=instructor_desc,
                    instructor_photo=instructor_photo
                )
                
                # Call the create_event function from event database
                new_event = event_db.create_event(
                    event_data=event_create,
                    home_id=home_id,
                    created_by=event_data['created_by']
                )
                
                if new_event:
                    # Handle event image upload if specified
                    if event_data.get('image_url'):
                        image_filename = event_data['image_url']
                        image_path = images_dir / image_filename
                        if image_path.exists():
                            try:
                                # Read image data
                                with open(image_path, 'rb') as img_file:
                                    image_data = img_file.read()
                                
                                # Create UploadFile-like object
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
                                
                                async_image_file = AsyncMockUploadFile(image_filename, image_data, content_type)
                                
                                # Use the extracted event image upload function
                                async def upload_event_image():
                                    return await event_db.upload_event_image(
                                        event_id=new_event.id,
                                        photo=async_image_file,
                                        home_id=home_id,
                                        tenant_name=tenant_name
                                    )
                                
                                # Run the async upload function
                                try:
                                    loop = asyncio.get_event_loop()
                                    if loop.is_running():
                                        import concurrent.futures
                                        with concurrent.futures.ThreadPoolExecutor() as executor:
                                            future = executor.submit(asyncio.run, upload_event_image())
                                            image_url = future.result()
                                    else:
                                        image_url = loop.run_until_complete(upload_event_image())
                                except RuntimeError:
                                    image_url = asyncio.run(upload_event_image())
                                
                                # Update event with image URL
                                from modules.events.models import EventUpdate
                                event_update = EventUpdate(image_url=image_url)
                                event_db.update_event(new_event.id, event_update, home_id)
                                logger.info(f"Event image uploaded for {new_event.id}: {image_url}")
                                    
                            except Exception as e:
                                logger.error(f"Error uploading event image for {new_event.id}: {e}")
                                import traceback
                                logger.error(f"Full traceback: {traceback.format_exc()}")
                                logger.info(f"Event {new_event.id} created without image due to upload error")
                        else:
                            logger.info(f"Event image file not found for {new_event.id}: {image_path}")
                            logger.info(f"Event {new_event.id} created without image - file missing")
                    
                    success_count += 1
                    logger.info(f"Successfully created event: {event_data['id']} - {event_data['name']} -> {new_event.id}")
                else:
                    failed_count += 1
                    logger.error(f"Failed to create event: {event_data['id']} - {event_data['name']}")
                    
            except Exception as e:
                failed_count += 1
                logger.error(f"Error creating event {event_data['id']}: {e}")
        
        logger.info(f"Events loading completed for tenant {tenant_name}: {success_count} successful, {failed_count} failed")
        return success_count > 0
        
    except Exception as e:
        logger.error(f"Error loading events data for tenant {tenant_name}: {e}")
        return False


# Note: SQL date conversion function removed - now using csv_date_helpers


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
        # Call the function directly since it's now synchronous
        return load_events(tenant_name, home_id)
    except Exception as e:
        logger.error(f"Error in sync wrapper for load_events: {e}")
        return False