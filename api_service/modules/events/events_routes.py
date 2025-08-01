"""
Event API endpoints
Handles all event-related HTTP routes and request/response logic
"""

from datetime import datetime
from typing import Optional, List
from fastapi import APIRouter, HTTPException, Depends, UploadFile, File, Header, Query, Form, Path
from .models import Event, EventCreate, EventUpdate, EventInstructor, EventInstructorCreate, EventInstructorUpdate, EventGallery, EventRegistration
from .events import event_db
from storage.storage_service import StorageServiceProxy
from .event_gallery import event_gallery_db
from .event_instructor import event_instructor_db
from .events_registration import events_registration_db
from modules.users import user_db
import json

# Create FastAPI router
router = APIRouter(prefix="/api")

# Header dependencies
async def get_home_id(home_id: str = Header(..., alias="homeID")):
    """Dependency to extract and validate homeID header"""
    print(f"DEBUG: get_home_id - Received homeID: {home_id}")
    try:
        result = int(home_id)
        print(f"DEBUG: get_home_id - Converted to int: {result}")
        return result
    except ValueError:
        print(f"DEBUG: get_home_id - ValueError converting homeID: {home_id}")
        raise HTTPException(status_code=400, detail="Invalid homeID format")

async def get_user_id(user_id: Optional[str] = Header(None, alias="userId")):
    """Dependency to extract user ID header"""
    print(f"DEBUG: get_user_id - Received userId: {user_id}")
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
    status: Optional[str] = Query(None, description="Filter by event status"),
    include_reviews: Optional[bool] = Query(False, description="Include reviews for completed events"),
    include_gallery: Optional[bool] = Query(False, description="Include gallery photos for completed events"),
    gallery_view: Optional[bool] = Query(False, description="Get only events with existing gallery photos"),
    home_id: int = Depends(get_home_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken"),
    user_id: Optional[str] = Depends(get_user_id)
):
    """Get events with various filtering options"""
    # Log headers for tracking (can be expanded for analytics/auditing)
    print(f"Request from homeID: {home_id}, userID: {user_id}")
    
    if gallery_view:
        # For gallery view - show only events with existing gallery photos
        events = event_db.get_events_with_gallery(home_id)
    elif approved_only:
        # For homepage - show only approved events
        events = event_db.get_approved_events(home_id)
    elif upcoming:
        events = event_db.get_upcoming_events(home_id)
    elif type:
        events = event_db.get_events_by_type(type, home_id)
    elif status:
        # Filter by specific status (e.g., "done" for completed events)
        events = event_db.get_events_by_status(status, home_id)
        
        # Add reviews or gallery data if requested
        if include_reviews and status == "done":
            events = event_db.get_completed_events_with_reviews(home_id)
        elif include_gallery:
            events = event_db.get_events_with_gallery(home_id)
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
    try:
        print(f"DEBUG: /events/home - Received request with home_id: {home_id}, user_id: {user_id}")
        
        if not user_id:
            print("DEBUG: /events/home - Missing user_id")
            raise HTTPException(status_code=400, detail="User ID is required")
        
        print(f"DEBUG: /events/home - Getting events for home {home_id}, user {user_id}")
        
        events_with_status = event_db.load_events_for_home(home_id, user_id)
        print(f"DEBUG: /events/home - Successfully loaded {len(events_with_status)} events")
        
        # Debug: Print first event structure if any
        if events_with_status:
            print(f"DEBUG: /events/home - First event structure: {events_with_status[0]}")
        
        return events_with_status
    
    except HTTPException as e:
        print(f"DEBUG: /events/home - HTTPException: {e.detail}")
        raise
    except Exception as e:
        print(f"DEBUG: /events/home - Unexpected error: {str(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

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
    date_time: str = Form(...),
    location: str = Form(...),
    max_participants: int = Form(...),
    current_participants: int = Form(0),
    duration: int = Form(60),
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
        # Parse date_time
        try:
            event_datetime = datetime.fromisoformat(date_time.replace('Z', '+00:00'))
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid date_time format")
        
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
            date_time=event_datetime,
            location=location,
            max_participants=max_participants,
            image_url="",  # Will be updated after image upload
            duration=duration,
            current_participants=current_participants,
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
            # Get tenant name for storage
            from tenant_config import get_schema_name_by_home_id
            tenant_name = get_schema_name_by_home_id(home_id)
            if not tenant_name:
                raise HTTPException(status_code=400, detail=f"No tenant found for home_id: {home_id}")
            
            # Use the extracted event image upload function
            image_url = await event_db.upload_event_image(new_event.id, image, home_id, tenant_name)
            
            # Update event with image URL
            from .models import EventUpdate
            event_update = EventUpdate(image_url=image_url)
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
    date_time: Optional[str] = Form(None),
    location: Optional[str] = Form(None),
    max_participants: Optional[int] = Form(None),
    current_participants: Optional[int] = Form(None),
    duration: Optional[int] = Form(None),
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
        if max_participants is not None:
            update_data['max_participants'] = max_participants
        if current_participants is not None:
            update_data['current_participants'] = current_participants
        if duration is not None:
            update_data['duration'] = duration
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
        if date_time is not None:
            try:
                update_data['date_time'] = datetime.fromisoformat(date_time.replace('Z', '+00:00'))
            except ValueError:
                raise HTTPException(status_code=400, detail="Invalid date_time format")
        
        if recurring_end_date is not None:
            try:
                update_data['recurring_end_date'] = datetime.fromisoformat(recurring_end_date.replace('Z', '+00:00'))
            except ValueError:
                raise HTTPException(status_code=400, detail="Invalid recurring_end_date format")
        
        # Handle image update
        if image:
            # Get tenant name for storage
            from tenant_config import get_schema_name_by_home_id
            tenant_name = get_schema_name_by_home_id(home_id)
            if not tenant_name:
                raise HTTPException(status_code=400, detail=f"No tenant found for home_id: {home_id}")
            
            # Use the extracted event image upload function
            image_url = await event_db.upload_event_image(event_id, image, home_id, tenant_name)
            update_data['image_url'] = image_url
        
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
    print(f"DEBUG: upload_gallery_images called with event_id={event_id}, home_id={home_id}, user_id={user_id}")
    print(f"DEBUG: Received {len(images)} images")
    
    # Check if event exists
    try:
        print(f"DEBUG: Checking if event {event_id} exists for home {home_id}")
        event = event_db.get_event_by_id(event_id, home_id)
        if not event:
            print(f"DEBUG: Event {event_id} not found for home {home_id}")
            raise HTTPException(status_code=404, detail="Event not found")
        print(f"DEBUG: Event found: {event.name}")
    except Exception as e:
        print(f"DEBUG: Error checking event existence: {e}")
        raise HTTPException(status_code=500, detail=f"Error checking event: {str(e)}")
    
    # Limit to 3 images maximum
    if len(images) > 3:
        print(f"DEBUG: Too many images: {len(images)}")
        raise HTTPException(status_code=400, detail="Maximum 3 images allowed per upload")
    
    # Validate all images
    image_files = []
    for i, image in enumerate(images):
        print(f"DEBUG: Processing image {i+1}: filename={image.filename}, content_type={image.content_type}")
        
        # Read image data first
        try:
            image_data = await image.read()
            print(f"DEBUG: Read {len(image_data)} bytes from image {i+1}")
            
            # Validate image content by trying to open it with PIL
            from PIL import Image as PILImage
            import io
            try:
                with PILImage.open(io.BytesIO(image_data)) as img:
                    # Get the actual image format
                    actual_format = img.format.lower()
                    print(f"DEBUG: Detected image format: {actual_format}")
                    
                    # Determine proper content type based on actual format
                    if actual_format in ['jpeg', 'jpg']:
                        detected_content_type = 'image/jpeg'
                    elif actual_format == 'png':
                        detected_content_type = 'image/png'
                    elif actual_format == 'gif':
                        detected_content_type = 'image/gif'
                    elif actual_format == 'webp':
                        detected_content_type = 'image/webp'
                    else:
                        detected_content_type = 'image/jpeg'  # Default fallback
                    
                    print(f"DEBUG: Using detected content type: {detected_content_type}")
                    
            except Exception as pil_error:
                print(f"DEBUG: PIL validation failed for image {i+1}: {pil_error}")
                raise HTTPException(status_code=400, detail=f"File {image.filename} is not a valid image")
            
            image_files.append({
                'filename': image.filename or f"gallery_image_{i+1}.jpg",
                'content': image_data,
                'content_type': detected_content_type  # Use detected content type instead of reported one
            })
        except HTTPException:
            raise
        except Exception as e:
            print(f"DEBUG: Error reading image {i+1}: {e}")
            raise HTTPException(status_code=400, detail=f"Error reading image: {str(e)}")
    
    try:
        # Get user role for status determination
        print(f"DEBUG: Getting user role for user_id={user_id}, home_id={home_id}")
        user_role = await get_user_role(user_id, home_id) if user_id else "unknown"
        print(f"DEBUG: User role: {user_role}")
        
        # Upload images to gallery
        print(f"DEBUG: Calling event_gallery_db.upload_gallery_images")
        created_galleries = event_gallery_db.upload_gallery_images(
            event_id=event_id,
            home_id=home_id,
            image_files=image_files,
            created_by=user_id,
            user_role=user_role
        )
        
        if not created_galleries:
            print(f"DEBUG: No galleries created")
            raise HTTPException(status_code=400, detail="Failed to upload images")
        
        print(f"DEBUG: Successfully created {len(created_galleries)} gallery entries")
        return created_galleries
        
    except Exception as e:
        print(f"DEBUG: Exception in upload_gallery_images: {e}")
        import traceback
        traceback.print_exc()
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

@router.put("/events/{event_id}/gallery/{photo_id}/approve")
async def approve_gallery_photo(
    event_id: str,
    photo_id: str,
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Approve a gallery photo (change status from private to public) - requires manager role"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    # Check if event exists
    event = event_db.get_event_by_id(event_id, home_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    # Get photo to verify it exists and belongs to the event
    photo = event_gallery_db.get_gallery_photo(photo_id, home_id)
    if not photo or photo.event_id != event_id:
        raise HTTPException(status_code=404, detail="Gallery photo not found for this event")
    
    # Check if photo is already public
    if photo.status == "public":
        return {"message": "Gallery photo is already public", "photo_id": photo_id}
    
    # Approve the photo
    success = event_gallery_db.approve_gallery_photo(photo_id, home_id)
    if not success:
        raise HTTPException(status_code=400, detail="Failed to approve gallery photo")
    
    return {"message": "Gallery photo approved successfully", "photo_id": photo_id}

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
            # Get tenant name for storage
            from tenant_config import get_schema_name_by_home_id
            tenant_name = get_schema_name_by_home_id(home_id)
            if not tenant_name:
                raise HTTPException(status_code=400, detail=f"No tenant found for home_id: {home_id}")
            
            # Use the extracted photo upload function
            photo_url = await event_db.upload_event_instructor_photo(new_instructor.id, photo, home_id, tenant_name)
            
            # Update instructor with photo URL
            instructor_update = EventInstructorUpdate(photo=photo_url)
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
            # Get tenant name for storage
            from tenant_config import get_schema_name_by_home_id
            tenant_name = get_schema_name_by_home_id(home_id)
            if not tenant_name:
                raise HTTPException(status_code=400, detail=f"No tenant found for home_id: {home_id}")
            
            # Use the extracted photo upload function
            photo_url = await event_db.upload_event_instructor_photo(instructor_id, photo, home_id, tenant_name)
            update_data['photo'] = photo_url
        
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
    """Get all registered events for a specific user with calculated display datetime"""
    try:
        print(f"DEBUG: /registrations/user/{user_id} - Getting registered events for user {user_id}, home {home_id}")
        
        # Get user registrations
        registrations = events_registration_db.get_user_registrations(user_id, home_id)
        print(f"DEBUG: Found {len(registrations)} registrations for user {user_id}")
        
        registered_events = []
        
        for registration in registrations:
            reg_dict = registration.to_dict()
            event_id = reg_dict.get('event_id')
            
            if event_id:
                # Get full event details
                event = event_db.get_event_by_id(event_id, home_id)
                if event:
                    # Convert to dict and add calculated date_time
                    event_dict = {
                        'id': event.id,
                        'name': event.name,
                        'type': event.type,
                        'description': event.description,
                        'date_time': event.date_time.isoformat(),
                        'location': event.location,
                        'max_participants': event.max_participants,
                        'current_participants': event.current_participants,
                        'image_url': event.image_url,
                        'status': event.status,
                        'recurring': event.recurring,
                        'recurring_end_date': event.recurring_end_date.isoformat() if event.recurring_end_date else None,
                        'recurring_pattern': event.recurring_pattern,
                        'instructor_name': event.instructor_name,
                        'instructor_desc': event.instructor_desc,
                        'instructor_photo': event.instructor_photo,
                        'is_registered': True
                    }
                    
                    # Calculate display datetime using the same logic as homepage
                    from datetime import datetime
                    from .events import calculate_next_occurrence
                    
                    display_datetime = event.date_time
                    now = datetime.now()
                    
                    # For recurring events, calculate next occurrence only if recurring period is still active
                    if event.recurring and event.recurring != 'none':
                        if event.recurring_pattern and event.recurring_end_date:
                            # If the recurring end date has passed, keep original date (show as completed)
                            if event.recurring_end_date <= now:
                                display_datetime = event.date_time
                                print(f"DEBUG: Recurring end date passed for {event.name}, using original date: {display_datetime}")
                            else:
                                # Recurring period is still active, calculate next occurrence
                                next_occurrence = calculate_next_occurrence(
                                    event.date_time,
                                    event.recurring_pattern,
                                    event.recurring_end_date
                                )
                                
                                # Use next occurrence if it's valid and in the future
                                if next_occurrence <= event.recurring_end_date and next_occurrence > now:
                                    display_datetime = next_occurrence
                                    print(f"DEBUG: Using next occurrence for {event.name}: {display_datetime}")
                                else:
                                    # No valid future occurrence, use original date
                                    display_datetime = event.date_time
                                    print(f"DEBUG: No valid future occurrence for {event.name}, using original date: {display_datetime}")
                    
                    # Update the date_time with calculated display datetime
                    event_dict['date_time'] = display_datetime.isoformat()
                    
                    registered_events.append(event_dict)
                    print(f"DEBUG: Added registered event: {event.name} with display_datetime: {display_datetime}")
        
        # Sort by calculated date_time
        registered_events.sort(key=lambda x: x['date_time'])
        
        print(f"DEBUG: Returning {len(registered_events)} registered events")
        return registered_events
        
    except Exception as e:
        print(f"ERROR: get_user_registrations - Exception: {str(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@router.get("/registrations/event/{event_id}")
async def get_event_registrations(
    event_id: str,
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Get all registrations for a specific event - requires manager role"""
    # Check if current user has manager role
    if user_id:
        await require_manager_role(user_id, home_id)
    
    registrations = events_registration_db.get_event_registrations(event_id, home_id)
    return [reg.to_dict() for reg in registrations]

@router.get("/registrations/all")
async def get_all_registrations(
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Get all registrations - requires manager role"""
    # Check if current user has manager role
    if user_id:
        await require_manager_role(user_id, home_id)
    
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

@router.delete("/registrations/admin/{event_id}/{registered_user_id}")
async def admin_unregister_user(
    event_id: str,
    registered_user_id: str,
    home_id: int = Depends(get_home_id),
    current_user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Admin endpoint to unregister a user from an event - requires manager role"""
    # Check if current user has manager role
    if current_user_id:
        await require_manager_role(current_user_id, home_id)
    
    success = events_registration_db.unregister_from_event(event_id, registered_user_id, home_id)
    if not success:
        raise HTTPException(status_code=400, detail="Unable to unregister user from event")
    
    return {"message": "User successfully unregistered from event", "event_id": event_id, "user_id": registered_user_id}


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

# ------------------------- Public Display Endpoints Removed ------------------------- #
# These endpoints have been removed as requested to enforce JWT authentication.
# The display.html page now uses the authenticated /events endpoint with appropriate
# query parameters (approved_only=true and gallery_view=true) instead.
