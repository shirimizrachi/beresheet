"""
Table creation modules package
"""

# Import all table creation functions
from .create_users_table import create_users_table
from .create_service_provider_types_table import create_service_provider_types_table
from .create_event_instructor_table import create_event_instructor_table
from .create_events_table import create_events_table
from .create_rooms_table import create_rooms_table
from .create_event_gallery_table import create_event_gallery_table
from .create_events_registration_table import create_events_registration_table
from .create_home_notification_table import create_home_notification_table
from .create_user_notification_table import create_user_notification_table
from .create_requests_table import create_requests_table

# Dictionary mapping script names to functions for easy lookup
TABLE_CREATION_FUNCTIONS = {
    "create_users_table": create_users_table,
    "create_service_provider_types_table": create_service_provider_types_table,
    "create_event_instructor_table": create_event_instructor_table,
    "create_events_table": create_events_table,
    "create_rooms_table": create_rooms_table,
    "create_event_gallery_table": create_event_gallery_table,
    "create_events_registration_table": create_events_registration_table,
    "create_home_notification_table": create_home_notification_table,
    "create_user_notification_table": create_user_notification_table,
    "create_requests_table": create_requests_table
}

__all__ = [
    'create_users_table',
    'create_service_provider_types_table',
    'create_event_instructor_table',
    'create_events_table',
    'create_rooms_table',
    'create_event_gallery_table',
    'create_events_registration_table',
    'create_home_notification_table',
    'create_user_notification_table',
    'create_requests_table',
    'TABLE_CREATION_FUNCTIONS'
]