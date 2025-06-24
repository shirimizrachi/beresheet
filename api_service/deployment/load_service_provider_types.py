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

async def load_service_provider_types(tenant_name: str, home_id: int):
    """
    Load service provider types data from CSV file and insert using the create_service_provider_type function from main.py
    
    Args:
        tenant_name: Name of the tenant to load service provider types for
        home_id: Home ID for the tenant
        
    Returns:
        Boolean indicating success
    """
    
    try:
        # Import the create_service_provider_type function from main.py
        import sys
        import importlib.util
        
        # Get path to main.py
        main_path = Path(__file__).parent.parent / "main.py"
        
        # Load main.py as a module to access create_service_provider_type function
        spec = importlib.util.spec_from_file_location("main", main_path)
        main_module = importlib.util.module_from_spec(spec)
        sys.modules["main_temp"] = main_module
        spec.loader.exec_module(main_module)
        
        # Import models for ServiceProviderTypeCreate
        from models import ServiceProviderTypeCreate
        
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
                
                # Call the create_service_provider_type function from main.py
                new_type = await main_module.create_service_provider_type(
                    provider_type=type_create,
                    home_id=home_id,
                    current_user_id='default-manager-user'  # Use default manager as creator
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
        
        # Clean up module
        if "main_temp" in sys.modules:
            del sys.modules["main_temp"]
        
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
        # Run the async function
        return asyncio.run(load_service_provider_types(tenant_name, home_id))
    except Exception as e:
        logger.error(f"Error in sync wrapper for load_service_provider_types: {e}")
        return False