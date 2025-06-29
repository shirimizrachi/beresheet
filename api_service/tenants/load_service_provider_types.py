"""
Service provider types data loading module for tenant initialization.
This module provides functions to load service provider types data into tenant tables using the create_service_provider_type function from main.py.
"""

import csv
import os
import json
import asyncio
from pathlib import Path
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

def load_service_provider_types(tenant_name: str, home_id: int):
    """
    Load service provider types data from CSV file and insert using the create_service_provider_type function from main.py
    
    Args:
        tenant_name: Name of the tenant to load service provider types for
        home_id: Home ID for the tenant
        
    Returns:
        Boolean indicating success
    """
    
    try:
        # Import the service provider type database directly from the users module
        import sys
        sys.path.append(str(Path(__file__).parent.parent))
        
        from modules.users import service_provider_type_db
        from modules.users.models import ServiceProviderTypeCreate
        
        # Get the CSV file path
        script_dir = Path(__file__).parent
        csv_file_path = script_dir / "schema" / "demo" / "data" / "service_provider_types.csv"
        
        if not csv_file_path.exists():
            logger.error(f"Service provider types CSV file not found: {csv_file_path}")
            return False
        
        # Read service provider types data from CSV
        types_data = []
        with open(csv_file_path, 'r', encoding='utf-8') as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                types_data.append(row)
        
        if not types_data:
            logger.warning("No service provider types data found in CSV file")
            return False
        
        success_count = 0
        failed_count = 0
        
        for type_data in types_data:
            try:
                # Create ServiceProviderTypeCreate object
                type_create = ServiceProviderTypeCreate(
                    name=type_data['name'],
                    description=type_data['description']
                )
                
                # Call the create_service_provider_type function from service_provider_type_db
                new_type = service_provider_type_db.create_service_provider_type(
                    type_data=type_create,
                    home_id=home_id
                )
                
                if new_type:
                    success_count += 1
                    logger.info(f"Successfully created service provider type: {type_data['id']} - {type_data['name']} -> {new_type.id}")
                else:
                    failed_count += 1
                    logger.error(f"Failed to create service provider type: {type_data['id']} - {type_data['name']}")
                    
            except Exception as e:
                failed_count += 1
                logger.error(f"Error creating service provider type {type_data['id']}: {e}")
        
        logger.info(f"Service provider types loading completed for tenant {tenant_name}: {success_count} successful, {failed_count} failed")
        return success_count > 0
        
    except Exception as e:
        logger.error(f"Error loading service provider types data for tenant {tenant_name}: {e}")
        return False


def load_service_provider_types_sync(tenant_name: str, home_id: int):
    """
    Synchronous wrapper for load_service_provider_types function
    
    Args:
        tenant_name: Name of the tenant to load service provider types for
        home_id: Home ID for the tenant
        
    Returns:
        Boolean indicating success
    """
    try:
        # Call the function directly since it's now synchronous
        return load_service_provider_types(tenant_name, home_id)
    except Exception as e:
        logger.error(f"Error in sync wrapper for load_service_provider_types: {e}")
        return False