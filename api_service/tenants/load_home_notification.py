"""
Home notification data loading module for tenant initialization.
This module provides functions to load home notification data into tenant tables using the home_notification_db from home_notification.py.
"""

import csv
import os
import json
import asyncio
from pathlib import Path
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

def load_home_notification(tenant_name: str, home_id: int):
    """
    Load home notification data from CSV file and insert using the home_notification_db
    
    Args:
        tenant_name: Name of the tenant to load home notifications for
        home_id: Home ID for the tenant
        
    Returns:
        Boolean indicating success
    """
    
    try:
        # Import the home notification database and models
        from modules.notification import home_notification_db, HomeNotificationCreate
        
        # Get the CSV file path
        script_dir = Path(__file__).parent
        csv_file_path = script_dir / "schema" / "demo" / "data" / "home_notification.csv"
        
        if not csv_file_path.exists():
            logger.error(f"Home notification CSV file not found: {csv_file_path}")
            return False
        
        # Read home notification data from CSV
        notifications_data = []
        with open(csv_file_path, 'r', encoding='utf-8') as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                notifications_data.append(row)
        
        if not notifications_data:
            logger.warning("No home notification data found in CSV file")
            return False
        
        success_count = 0
        failed_count = 0
        
        for notification_data in notifications_data:
            try:
                # Create HomeNotificationCreate object
                notification_create = HomeNotificationCreate(
                    message=notification_data['message'],
                    send_floor=int(notification_data['send_floor']) if notification_data['send_floor'] and notification_data['send_floor'] != 'NULL' else None,
                    send_datetime=datetime.now(),  # Use current time for send_datetime
                    send_type=notification_data['send_type']
                )
                
                # Create current user dict for the database function
                current_user = {
                    'id': notification_data['create_by_user_id'],
                    'full_name': notification_data['create_by_user_name'],
                    'role': notification_data['create_by_user_role_name'],
                    'service_provider_type': notification_data['create_by_user_service_provider_type_name'] if notification_data['create_by_user_service_provider_type_name'] != 'NULL' else None
                }
                
                # Call the create_home_notification function from home_notification_db
                new_notification = home_notification_db.create_home_notification(
                    notification_data=notification_create,
                    home_id=home_id,
                    current_user=current_user
                )
                
                if new_notification:
                    # If the notification should be approved, update its status
                    if notification_data['send_status'] == 'approved':
                        from modules.notification import HomeNotificationUpdate
                        status_update = HomeNotificationUpdate(send_status='approved')
                        
                        # Create approver user dict
                        approver_user = {
                            'id': notification_data['send_approved_by_user_id'] if notification_data['send_approved_by_user_id'] != 'NULL' else notification_data['create_by_user_id']
                        }
                        
                        # Update status to approved - this will automatically create user notifications for all residents
                        # Note: The home_notification.py update_notification_status function creates user notifications
                        # for users with 'resident' role when status changes to 'approved'
                        success = home_notification_db.update_notification_status(
                            notification_id=new_notification.id,
                            status_update=status_update,
                            home_id=home_id,
                            current_user=approver_user
                        )
                        
                        if success:
                            logger.info(f"Successfully approved notification and created user notifications for residents: {new_notification.id}")
                        else:
                            logger.warning(f"Failed to approve notification: {new_notification.id}")
                    
                    success_count += 1
                    logger.info(f"Successfully created home notification: {notification_data['id']} -> {new_notification.id}")
                else:
                    failed_count += 1
                    logger.error(f"Failed to create home notification: {notification_data['id']}")
                    
            except Exception as e:
                failed_count += 1
                logger.error(f"Error creating home notification {notification_data['id']}: {e}")
        
        logger.info(f"Home notifications loading completed for tenant {tenant_name}: {success_count} successful, {failed_count} failed")
        return success_count > 0
        
    except Exception as e:
        logger.error(f"Error loading home notification data for tenant {tenant_name}: {e}")
        return False


def load_home_notification_sync(tenant_name: str, home_id: int):
    """
    Synchronous wrapper for load_home_notification function
    
    Args:
        tenant_name: Name of the tenant to load home notifications for
        home_id: Home ID for the tenant
        
    Returns:
        Boolean indicating success
    """
    try:
        # Call the function directly since it's now synchronous
        return load_home_notification(tenant_name, home_id)
    except Exception as e:
        logger.error(f"Error in sync wrapper for load_home_notification: {e}")
        return False