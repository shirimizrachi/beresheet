"""
Event API endpoints
Handles all event-related HTTP routes and request/response logic
"""

from datetime import datetime
from typing import Optional, List
from fastapi import APIRouter, HTTPException, Depends, UploadFile, File, Header, Query, Form
from .models import Event, EventCreate, EventUpdate, EventInstructor, EventInstructorCreate, EventInstructorUpdate, EventGallery, EventRegistration
from .events import event_db
from storage.storage_service import azure_storage_service
from .event_gallery import event_gallery_db
from .event_instructor import event_instructor_db
from .events_registration import events_registration_db
from users import user_db
import json

# Create FastAPI router
router = APIRouter()

# Header dependencies
async def get_home_id(home_id: str = Header(..., alias="homeID")):
    """Dependency to extract and validate homeID header"""
    try:
        return int(home_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid homeID format")

async def get_user_id(user_id: Optional[str] = Header(None, alias="userId")):
    """Dependency to extract user ID header"""
    return user_id

async def get_user_role(user_id: str, home_id: int) -> str:
    """Get user role from database"""
    try:
        user_profile = user_db.get_user_profile(user_id, home_id)
        if user_profile:
            return user_profile.role
        return "unknown"
    except Exception as e:
        print(f"Error getting user role: {e}")
        return "unknown"

async def require_manager_role(user_id: str, home_id: int):
    """Dependency to ensure user has manager role"""
    role = await get_user_role(user_id, home_id)
    if role != "manager":
        raise HTTPException(status_code=403, detail="Manager role required")
    return True

# ========================= Event API Endpoints ========================= #

# Events CRUD endpoints
@router.get("/events", response_model=List[Event])
async def get_events(
    type: Optional[str] = Query(None, description="Filter by event type"),
    upcoming: Optional[bool] = Query(False, description="Get only upcoming events"),
    approved_only: Optional[bool] = Query(False, description="Get only approved events"),
    home_id: int = Depends(get_home_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken"),
    user_id: Optional[str] = Depends(get_user_id)
):
    """Get events with various filtering options"""
    # Log headers for tracking (can be expanded for analytics/auditing)
    print(f"Request from homeID: {home_id}, userID: {user_id}")
    
    if approved_only:
        # For homepage - show only approved events
        events = event_db.get_approved_events(home_id)
    elif upcoming:
        events = event_db.get_upcoming_events(home_id)
    elif type:
        events = event_db.get_events_by_type(type, home_id)
    else:
        # Show all events for everyone
        events = event_db.get_all_events_ordered(home_id)
    
    return events

@router.get("/events/home")
async def get_events_for_home(
    home_id: int = Depends(get_home_id),
    user_id: str = Depends(get_user_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Get events for home screen with proper recurring event handling"""
    if not user_id:
        raise HTTPException(status_code=400, detail="User ID is required")
    
    print(f"Getting events for home {home_id}, user {user_id}")
    
    events_with_status = event_db.load_events_for_home(home_id, user_id)
    return events_with_status

@router.get("/events/{event_id}", response_model=Event)
async def get_event(
    event_id: str,
    home_id: int = Depends(get_home_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken"),
    user_id: Optional[str] = Depends(get_user_id)
):
    """Get a specific event by ID"""
    event = event_db.get_event_by_id(event_id, home_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    return event

@router.post("/events", response_model=Event, status_code=201)
async def create_event(
    name: str = Form(...),
    type: str = Form(...),
    description: str = Form(...),
    dateTime: str = Form(...),
    location: str = Form(...),
    maxParticipants: int = Form(...),
    currentParticipants: int = Form(0),
    status: str = Form("pending-approval"),
    recurring: str = Form("none"),
    recurring_end_date: Optional[str] = Form(None),
    recurring_pattern: Optional[str] = Form(None),
    instructor_name: Optional[str] = Form(None),
    instructor_desc: Optional[str] = Form(None),
    instructor_photo: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None),
    home_id: int = Depends(get_home_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken"),
    user_id: Optional[str] = Depends(get_user_id)
):
    """Create a new event with image upload"""
    try:
        # Parse dateTime
        try:
            event_datetime = datetime.fromisoformat(dateTime.replace('Z', '+00:00'))
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid dateTime format")
        
        # Parse optional datetime fields
        parsed_recurring_end_date = None
        if recurring_end_date:
            try:
                parsed_recurring_end_date = datetime.fromisoformat(recurring_end_date.replace('Z', '+00:00'))
            except ValueError:
                raise HTTPException(status_code=400, detail="Invalid recurring_end_date format")
        
        # First create event without image
        event_data = EventCreate(
            name=name,
            type=type,
            description=description,
            dateTime=event_datetime,
            location=location,
            maxParticipants=maxParticipants,
            image_url="",  # Will be updated after image upload
            currentParticipants=currentParticipants,
            status=status,
            recurring=recurring,
            recurring_end_date=parsed_recurring_end_date,
            recurring_pattern=recurring_pattern,
            instructor_name=instructor_name,
            instructor_desc=instructor_desc,
            instructor_photo=instructor_photo
        )
        
        # Create the event
        new_event = event_db.create_event(event_data, home_id, created_by=user_id)
        
        # Handle image upload after event creation
        if image:
            # Validate image file
            if not image.content_type or not image.content_type.startswith('image/'):
                raise HTTPException(status_code=400, detail="Uploaded file must be an image")
            
            # Read image data
            image_data = await image.read()
            
            # Upload to Azure Storage using event_id as filename
            success, result = azure_storage_service.upload_event_image(
                home_id=home_id,
                event_id=new_event.id,
                image_data=image_data,
                original_filename=image.filename or "event_image.jpg",
                content_type=image.content_type
            )
            
            if not success:
                raise HTTPException(status_code=400, detail=f"Image upload failed: {result}")
            
            # Update event with image URL
            from .models import EventUpdate
            event_update = EventUpdate(image_url=result)
            updated_event = event_db.update_event(new_event.id, event_update, home_id)
            if updated_event:
                new_event = updated_event
        
        return new_event
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error creating event: {str(e)}")

@router.put("/events/{event_id}", response_model=Event)
async def update_event(
    event_id: str,
    name: Optional[str] = Form(None),
    type: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    dateTime: Optional[str] = Form(None),
    location: Optional[str] = Form(None),
    maxParticipants: Optional[int] = Form(None),
    currentParticipants: Optional[int] = Form(None),
    status: Optional[str] = Form(None),
    recurring: Optional[str] = Form(None),
    recurring_end_date: Optional[str] = Form(None),
    recurring_pattern: Optional[str] = Form(None),
    instructor_name: Optional[str] = Form(None),
    instructor_desc: Optional[str] = Form(None),
    instructor_photo: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None),
    home_id: int = Depends(get_home_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken"),
    user_id: Optional[str] = Depends(get_user_id)
):
    """Update an existing event with image upload"""
    try:
        # Prepare update data
        update_data = {}
        
        if name is not None:
            update_data['name'] = name
        if type is not None:
            update_data['type'] = type
        if description is not None:
            update_data['description'] = description
        if location is not None:
            update_data['location'] = location
        if maxParticipants is not None:
            update_data['maxParticipants'] = maxParticipants
        if currentParticipants is not None:
            update_data['currentParticipants'] = currentParticipants
        if status is not None:
            update_data['status'] = status
        if recurring is not None:
            update_data['recurring'] = recurring
        if recurring_pattern is not None:
            update_data['recurring_pattern'] = recurring_pattern
        if instructor_name is not None:
            update_data['instructor_name'] = instructor_name
        if instructor_desc is not None:
            update_data['instructor_desc'] = instructor_desc
        if instructor_photo is not None:
            update_data['instructor_photo'] = instructor_photo
        
        # Parse datetime fields
        if dateTime is not None:
            try:
                update_data['dateTime'] = datetime.fromisoformat(dateTime.replace('Z', '+00:00'))
            except ValueError:
                raise HTTPException(status_code=400, detail="Invalid dateTime format")
        
        if recurring_end_date is not None:
            try:
                update_data['recurring_end_date'] = datetime.fromisoformat(recurring_end_date.replace('Z', '+00:00'))
            except ValueError:
                raise HTTPException(status_code=400, detail="Invalid recurring_end_date format")
        
        # Handle image update
        if image:
            # Validate image file
            if not image.content_type or not image.content_type.startswith('image/'):
                raise HTTPException(status_code=400, detail="Uploaded file must be an image")
            
            # Read image data
            image_data = await image.read()
            
            # Upload to Azure Storage using event_id as filename
            success, result = azure_storage_service.upload_event_image(
                home_id=home_id,
                event_id=event_id,
                image_data=image_data,
                original_filename=image.filename or "event_image.jpg",
                content_type=image.content_type
            )
            
            if not success:
                raise HTTPException(status_code=400, detail=f"Image upload failed: {result}")
            
            update_data['image_url'] = result
        
        # Create EventUpdate object
        event_update = EventUpdate(**update_data)
        
        # Update the event
        updated_event = event_db.update_event(event_id, event_update, home_id)
        if not updated_event:
            raise HTTPException(status_code=404, detail="Event not found")
        
        return updated_event
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error updating event: {str(e)}")

@router.delete("/events/{event_id}")
async def delete_event(
    event_id: str,
    home_id: int = Depends(get_home_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken"),
    user_id: Optional[str] = Depends(get_user_id)
):
    """Delete an event"""
    success = event_db.delete_event(event_id, home_id)
    if not success:
        raise HTTPException(status_code=404, detail="Event not found")
    return {"message": "Event deleted successfully"}

# Event registration endpoints
@router.post("/events/{event_id}/register")
async def register_for_event(
    event_id: str,
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Register for an event"""
    if not user_id:
        raise HTTPException(status_code=400, detail="User ID is required for registration")
    
    # Check if event exists
    event = event_db.get_event_by_id(event_id, home_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    # Get user info for registration - ensure all fields are populated
    user_profile = user_db.get_user_profile(user_id, home_id)
    if not user_profile:
        raise HTTPException(status_code=404, detail="User profile not found - cannot register for event")
    
    # Ensure we have the user's name and phone
    user_name = user_profile.full_name or "Unknown User"
    user_phone = user_profile.phone_number or ""
    
    print(f"Registering user {user_id} ({user_name}, {user_phone}) for event {event_id}")
    
    success = events_registration_db.register_for_event(
        event_id=event_id,
        user_id=user_id,
        user_name=user_name,
        user_phone=user_phone,
        home_id=home_id
    )
    
    if not success:
        raise HTTPException(status_code=400, detail="Unable to register for event. Event may be full or you may already be registered.")
    
    return {"message": "Successfully registered for event", "event_id": event_id}

@router.post("/events/{event_id}/unregister")
async def unregister_from_event(
    event_id: str,
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Unregister from an event"""
    if not user_id:
        raise HTTPException(status_code=400, detail="User ID is required for unregistration")
    
    # Check if event exists
    event = event_db.get_event_by_id(event_id, home_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    success = events_registration_db.unregister_from_event(
        event_id=event_id,
        user_id=user_id,
        home_id=home_id
    )
    
    if not success:
        raise HTTPException(status_code=400, detail="Unable to unregister from event. You may not be registered for this event.")
    
    return {"message": "Successfully unregistered from event", "event_id": event_id}

@router.put("/events/{event_id}/vote-review")
async def update_vote_and_review(
    event_id: str,
    vote_review_data: dict,
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Update vote and/or add review for an event registration"""
    if not user_id:
        raise HTTPException(status_code=400, detail="User ID is required")
    
    # Check if event exists
    event = event_db.get_event_by_id(event_id, home_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    # Check if user is registered for this event
    is_registered = events_registration_db.is_user_registered(event_id, user_id, home_id)
    if not is_registered:
        raise HTTPException(status_code=400, detail="User must be registered for this event to vote or review")
    
    # Update vote and/or review
    success = events_registration_db.update_vote_and_review(
        event_id=event_id,
        user_id=user_id,
        vote=vote_review_data.get('vote'),
        review_text=vote_review_data.get('review_text'),
        home_id=home_id
    )
    
    if not success:
        raise HTTPException(status_code=400, detail="Failed to update vote and review")
    
    return {"message": "Vote and review updated successfully", "event_id": event_id}

@router.get("/events/{event_id}/vote-review")
async def get_vote_and_review(
    event_id: str,
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Get vote and reviews for an event registration"""
    if not user_id:
        raise HTTPException(status_code=400, detail="User ID is required")
    
    # Check if event exists
    event = event_db.get_event_by_id(event_id, home_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    # Get vote and reviews data
    vote_data = events_registration_db.get_vote_and_reviews(event_id, user_id, home_id)
    
    if not vote_data:
        raise HTTPException(status_code=404, detail="Registration not found for this event")
    
    return vote_data

@router.get("/events/{event_id}/votes-reviews/all")
async def get_all_votes_and_reviews(
    event_id: str,
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Get all votes and reviews for an event - requires manager role"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    # Check if event exists
    event = event_db.get_event_by_id(event_id, home_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    # Get all registrations for this event
    registrations = events_registration_db.get_event_registrations(event_id, home_id)
    
    # Filter and format votes and reviews data
    votes_reviews_data = []
    for registration in registrations:
        reg_dict = registration.to_dict()
        if reg_dict.get('vote') is not None or (reg_dict.get('reviews') and reg_dict.get('reviews').strip()):
            # Parse reviews if they exist
            reviews_list = []
            if reg_dict.get('reviews'):
                try:
                    import json
                    reviews_list = json.loads(reg_dict['reviews'])
                except (json.JSONDecodeError, Exception):
                    reviews_list = []
            
            votes_reviews_data.append({
                'registration_id': reg_dict['id'],
                'user_id': reg_dict['user_id'],
                'user_name': reg_dict['user_name'],
                'vote': reg_dict.get('vote'),
                'reviews': reviews_list,
                'registration_date': reg_dict['registration_date']
            })
    
    return {
        'event_id': event_id,
        'event_name': event.name,
        'total_votes_reviews': len(votes_reviews_data),
        'votes_reviews': votes_reviews_data
    }

# Event type endpoints
@router.get("/events/types/{event_type}", response_model=List[Event])
async def get_events_by_type(event_type: str, home_id: int = Depends(get_home_id)):
    """Get all events of a specific type"""
    events = event_db.get_events_by_type(event_type, home_id)
    return events

@router.get("/events/upcoming/all", response_model=List[Event])
async def get_upcoming_events(home_id: int = Depends(get_home_id)):
    """Get all upcoming events"""
    events = event_db.get_upcoming_events(home_id)
    return events

# ------------------------- Event Gallery Endpoints ------------------------- #
@router.get("/events/{event_id}/gallery", response_model=List[EventGallery])
async def get_event_gallery(
    event_id: str,
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Get all gallery images for an event"""
    # Check if event exists
    event = event_db.get_event_by_id(event_id, home_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    gallery_images = event_gallery_db.get_event_gallery(event_id, home_id)
    return gallery_images

@router.post("/events/{event_id}/gallery", response_model=List[EventGallery], status_code=201)
async def upload_gallery_images(
    event_id: str,
    images: List[UploadFile] = File(...),
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Upload multiple images to event gallery (max 3)"""
    # Check if event exists
    event = event_db.get_event_by_id(event_id, home_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    # Limit to 3 images maximum
    if len(images) > 3:
        raise HTTPException(status_code=400, detail="Maximum 3 images allowed per upload")
    
    # Validate all images
    image_files = []
    for image in images:
        if not image.content_type or not image.content_type.startswith('image/'):
            raise HTTPException(status_code=400, detail=f"File {image.filename} must be an image")
        
        # Read image data
        image_data = await image.read()
        image_files.append({
            'filename': image.filename or "gallery_image.jpg",
            'content': image_data,
            'content_type': image.content_type
        })
    
    try:
        # Upload images to gallery
        created_galleries = event_gallery_db.upload_gallery_images(
            event_id=event_id,
            home_id=home_id,
            image_files=image_files,
            created_by=user_id
        )
        
        if not created_galleries:
            raise HTTPException(status_code=400, detail="Failed to upload images")
        
        return created_galleries
        
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error uploading gallery images: {str(e)}")

@router.get("/events/{event_id}/gallery/{photo_id}", response_model=EventGallery)
async def get_gallery_photo(
    event_id: str,
    photo_id: str,
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Get a specific gallery photo"""
    # Check if event exists
    event = event_db.get_event_by_id(event_id, home_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    photo = event_gallery_db.get_gallery_photo(photo_id, home_id)
    if not photo:
        raise HTTPException(status_code=404, detail="Gallery photo not found")
    
    # Verify photo belongs to the event
    if photo.event_id != event_id:
        raise HTTPException(status_code=404, detail="Gallery photo not found for this event")
    
    return photo

@router.delete("/events/{event_id}/gallery/{photo_id}")
async def delete_gallery_photo(
    event_id: str,
    photo_id: str,
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Delete a specific gallery photo"""
    # Check if event exists
    event = event_db.get_event_by_id(event_id, home_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    # Get photo to verify it belongs to the event
    photo = event_gallery_db.get_gallery_photo(photo_id, home_id)
    if not photo or photo.event_id != event_id:
        raise HTTPException(status_code=404, detail="Gallery photo not found for this event")
    
    success = event_gallery_db.delete_gallery_photo(photo_id, home_id)
    if not success:
        raise HTTPException(status_code=404, detail="Gallery photo not found")
    
    return {"message": "Gallery photo deleted successfully"}

@router.delete("/events/{event_id}/gallery")
async def delete_event_gallery(
    event_id: str,
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Delete all gallery photos for an event"""
    # Check if event exists
    event = event_db.get_event_by_id(event_id, home_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    success = event_gallery_db.delete_event_gallery(event_id, home_id)
    if not success:
        raise HTTPException(status_code=400, detail="Failed to delete event gallery")
    
    return {"message": "Event gallery deleted successfully"}

# ------------------------- Event Instructor Endpoints ------------------------- #
@router.get("/event-instructors", response_model=List[EventInstructor])
async def get_event_instructors(
    home_id: int = Depends(get_home_id),
):
    """List all event instructors - public access"""
    instructors = event_instructor_db.get_all_event_instructors(home_id)
    return instructors

@router.get("/event-instructors/{instructor_id}", response_model=EventInstructor)
async def get_event_instructor(
    instructor_id: str,
    home_id: int = Depends(get_home_id),
):
    """Get a specific event instructor by ID"""
    instructor = event_instructor_db.get_event_instructor_by_id(instructor_id, home_id)
    if not instructor:
        raise HTTPException(status_code=404, detail="Event instructor not found")
    return instructor

@router.post("/event-instructors", response_model=EventInstructor, status_code=201)
async def create_event_instructor(
    name: str = Form(...),
    description: Optional[str] = Form(None),
    photo: Optional[UploadFile] = File(None),
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
):
    """Create a new event instructor with photo upload - manager role required"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    try:
        # First create instructor without photo
        instructor_data = EventInstructorCreate(
            name=name,
            description=description
        )
        
        # Create the instructor
        new_instructor = event_instructor_db.create_event_instructor(instructor_data, home_id)
        if not new_instructor:
            raise HTTPException(status_code=400, detail="Unable to create event instructor")
        
        # Handle photo upload if provided
        if photo:
            # Validate photo file
            if not photo.content_type or not photo.content_type.startswith('image/'):
                raise HTTPException(status_code=400, detail="Uploaded file must be an image")
            
            # Read photo data
            photo_data = await photo.read()
            
            # Upload to Azure Storage using instructor_id as filename
            success, result = azure_storage_service.upload_event_instructor_photo(
                home_id=home_id,
                instructor_id=new_instructor.id,
                image_data=photo_data,
                original_filename=photo.filename or "instructor_photo.jpg",
                content_type=photo.content_type
            )
            
            if not success:
                raise HTTPException(status_code=400, detail=f"Photo upload failed: {result}")
            
            # Update instructor with photo URL
            instructor_update = EventInstructorUpdate(photo=result)
            updated_instructor = event_instructor_db.update_event_instructor(new_instructor.id, instructor_update, home_id)
            if updated_instructor:
                new_instructor = updated_instructor
        
        return new_instructor
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error creating event instructor: {str(e)}")

@router.put("/event-instructors/{instructor_id}", response_model=EventInstructor)
async def update_event_instructor(
    instructor_id: str,
    name: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    photo: Optional[UploadFile] = File(None),
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
):
    """Update an event instructor with photo upload - manager role required"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    try:
        # Check if instructor exists
        existing_instructor = event_instructor_db.get_event_instructor_by_id(instructor_id, home_id)
        if not existing_instructor:
            raise HTTPException(status_code=404, detail="Event instructor not found")
        
        # Prepare update data
        update_data = {}
        
        if name is not None:
            update_data['name'] = name
        if description is not None:
            update_data['description'] = description
        
        # Handle photo update if provided
        if photo:
            # Validate photo file
            if not photo.content_type or not photo.content_type.startswith('image/'):
                raise HTTPException(status_code=400, detail="Uploaded file must be an image")
            
            # Read photo data
            photo_data = await photo.read()
            
            # Upload to Azure Storage using instructor_id as filename
            success, result = azure_storage_service.upload_event_instructor_photo(
                home_id=home_id,
                instructor_id=instructor_id,
                image_data=photo_data,
                original_filename=photo.filename or "instructor_photo.jpg",
                content_type=photo.content_type
            )
            
            if not success:
                raise HTTPException(status_code=400, detail=f"Photo upload failed: {result}")
            
            update_data['photo'] = result
        
        # Create EventInstructorUpdate object
        instructor_update = EventInstructorUpdate(**update_data)
        
        # Update the instructor
        updated_instructor = event_instructor_db.update_event_instructor(instructor_id, instructor_update, home_id)
        if not updated_instructor:
            raise HTTPException(status_code=404, detail="Event instructor not found")
        
        return updated_instructor
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error updating event instructor: {str(e)}")

@router.delete("/event-instructors/{instructor_id}")
async def delete_event_instructor(
    instructor_id: str,
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
):
    """Delete an event instructor by ID - manager role required"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    success = event_instructor_db.delete_event_instructor(instructor_id, home_id)
    if not success:
        raise HTTPException(status_code=404, detail="Event instructor not found")
    return {"message": "Event instructor deleted successfully"}

# Event Registration Management endpoints
@router.get("/registrations/user/{user_id}")
async def get_user_registrations(
    user_id: str,
    home_id: int = Depends(get_home_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Get all registrations for a specific user"""
    registrations = events_registration_db.get_user_registrations(user_id, home_id)
    return [reg.to_dict() for reg in registrations]

@router.get("/registrations/event/{event_id}")
async def get_event_registrations(
    event_id: str,
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Get all registrations for a specific event - requires manager role"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    registrations = events_registration_db.get_event_registrations(event_id, home_id)
    return [reg.to_dict() for reg in registrations]

@router.get("/registrations/all")
async def get_all_registrations(
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Get all registrations - requires manager role"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    registrations = events_registration_db.get_all_registrations(home_id)
    return [reg.to_dict() for reg in registrations]

@router.get("/registrations/check/{event_id}/{user_id}")
async def check_registration_status(
    event_id: str,
    user_id: str,
    home_id: int = Depends(get_home_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Check if a user is registered for an event"""
    is_registered = events_registration_db.is_user_registered(event_id, user_id, home_id)
    return {"is_registered": is_registered, "event_id": event_id, "user_id": user_id}

@router.delete("/registrations/admin/{event_id}/{user_id}")
async def admin_unregister_user(
    event_id: str,
    user_id: str,
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Admin endpoint to unregister a user from an event - requires manager role"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    success = events_registration_db.unregister_from_event(event_id, user_id, home_id)
    if not success:
        raise HTTPException(status_code=400, detail="Unable to unregister user from event")
    
    return {"message": "User successfully unregistered from event", "event_id": event_id, "user_id": user_id}


# ------------------------- Rooms Endpoints ------------------------- #
from .events_room import Room, RoomCreate, room_db

@router.get("/rooms", response_model=List[Room])
async def get_rooms(
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
):
    """List all rooms - manager role required"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    rooms = room_db.get_all_rooms(home_id)
    return rooms


@router.get("/rooms/public", response_model=List[Room])
async def get_rooms_public(
    home_id: int = Depends(get_home_id),
):
    """List all rooms - public access for event forms"""
    rooms = room_db.get_all_rooms(home_id)
    return rooms


@router.post("/rooms", response_model=Room, status_code=201)
async def create_room(
    room: RoomCreate,
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
):
    """Create a new room - manager role required"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    new_room = room_db.create_room(room, home_id)
    if not new_room:
        raise HTTPException(
            status_code=400, detail="Unable to create room (duplicate name?)"
        )
    return new_room


@router.delete("/rooms/{room_id}")
async def delete_room(
    room_id: str,
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
):
    """Delete a room by ID - manager role required"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    success = room_db.delete_room(room_id, home_id)
    if not success:
        raise HTTPException(status_code=404, detail="Room not found")
    return {"message": "Room deleted successfully"}