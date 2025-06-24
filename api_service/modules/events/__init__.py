"""
Events module
Provides event database operations and API routes
"""

from .events import event_db, calculate_next_occurrence, EventDatabase
from .events_routes import router
from .event_gallery import event_gallery_db, EventGalleryDatabase
from .event_instructor import event_instructor_db, EventInstructorDatabase
from .events_registration import events_registration_db, EventRegistrationDatabase, EventRegistration
from .events_room import room_db, RoomDatabase, Room, RoomCreate
from .models import *

__all__ = [
    'event_db', 'calculate_next_occurrence', 'EventDatabase', 'router',
    'event_gallery_db', 'EventGalleryDatabase',
    'event_instructor_db', 'EventInstructorDatabase',
    'events_registration_db', 'EventRegistrationDatabase', 'EventRegistration',
    'room_db', 'RoomDatabase', 'Room', 'RoomCreate',
    # Event models
    'RecurrencePatternData', 'EventBase', 'EventCreate', 'EventUpdate', 'Event', 'EventWithRegistrationStatus',
    'EventRegistration', 'EventRegistrationRecord', 'EventRegistrationCreate', 'EventRegistrationUpdate', 'EventVoteAndReviewUpdate',
    'EventInstructor', 'EventInstructorCreate', 'EventInstructorUpdate',
    'EventGallery', 'EventGalleryBase', 'EventGalleryCreate', 'EventGalleryUpdate', 'EventGalleryUpload'
]