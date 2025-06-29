"""
Rooms data loading module for tenant initialization.
This module provides functions to load rooms data into tenant tables using the create_room function from main.py.
"""

import csv
import os
import json
import asyncio
from pathlib import Path
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

def load_rooms(tenant_name: str, home_id: int):
    """
    Load rooms data from CSV file and insert using the create_room function from main.py
    
    Args:
        tenant_name: Name of the tenant to load rooms for
        home_id: Home ID for the tenant
        
    Returns:
        Boolean indicating success
    """
    
    try:
        # Import the necessary modules
        import sys
        sys.path.append(str(Path(__file__).parent.parent))
        
        # Import the room database functions
        from modules.events.events_room import room_db, RoomCreate
        
        # Get the CSV file path
        script_dir = Path(__file__).parent
        csv_file_path = script_dir / "schema" / "demo" / "data" / "rooms.csv"
        
        if not csv_file_path.exists():
            logger.error(f"Rooms CSV file not found: {csv_file_path}")
            return False
        
        # Read rooms data from CSV
        rooms_data = []
        with open(csv_file_path, 'r', encoding='utf-8') as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                rooms_data.append(row)
        
        if not rooms_data:
            logger.warning("No rooms data found in CSV file")
            return False
        
        success_count = 0
        failed_count = 0
        
        for room_data in rooms_data:
            try:
                # Create RoomCreate object
                room_create = RoomCreate(
                    room_name=room_data['room_name']
                )
                
                # Call the create_room function from room database
                new_room = room_db.create_room(
                    room_data=room_create,
                    home_id=home_id
                )
                
                if new_room:
                    success_count += 1
                    logger.info(f"Successfully created room: {room_data['id']} - {room_data['room_name']} -> {new_room.id}")
                else:
                    failed_count += 1
                    logger.error(f"Failed to create room: {room_data['id']} - {room_data['room_name']}")
                    
            except Exception as e:
                failed_count += 1
                logger.error(f"Error creating room {room_data['id']}: {e}")
        
        logger.info(f"Rooms loading completed for tenant {tenant_name}: {success_count} successful, {failed_count} failed")
        return success_count > 0
        
    except Exception as e:
        logger.error(f"Error loading rooms data for tenant {tenant_name}: {e}")
        return False


def load_rooms_sync(tenant_name: str, home_id: int):
    """
    Synchronous wrapper for load_rooms function
    
    Args:
        tenant_name: Name of the tenant to load rooms for
        home_id: Home ID for the tenant
        
    Returns:
        Boolean indicating success
    """
    try:
        # Call the function directly since it's now synchronous
        return load_rooms(tenant_name, home_id)
    except Exception as e:
        logger.error(f"Error in sync wrapper for load_rooms: {e}")
        return False