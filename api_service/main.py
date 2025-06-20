from fastapi import FastAPI, HTTPException, Query, File, UploadFile, Header, Depends, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from typing import List, Optional
from datetime import datetime
from models import (
    Event,
    EventCreate,
    EventUpdate,
    EventRegistration,
    EventVoteAndReviewUpdate,
    EventGallery,
    EventGalleryCreate,
    EventGalleryUpdate,
    UserProfile,
    UserProfileCreate,
    UserProfileUpdate,
    LoginRequest,
    LoginResponse,
    SessionInfo,
    Room,
    RoomCreate,
    EventInstructor,
    EventInstructorCreate,
    EventInstructorUpdate,
    ServiceProviderType,
    ServiceProviderTypeCreate,
    ServiceProviderTypeUpdate,
    ServiceRequest,
    ServiceRequestCreate,
    ServiceRequestUpdate,
    RequestStatusUpdate,
    ChatMessage,
    ServiceProviderProfile,
)
from events import event_db
from rooms import room_db
from events_registration import events_registration_db
from event_instructor import event_instructor_db
from event_gallery import event_gallery_db
from home_notification import router as home_notification_router
from users import user_db
from service_provider_types import service_provider_type_db
from request_service import request_db
from azure_storage_service import azure_storage_service
import uvicorn
import os
import json

# Create FastAPI app
app = FastAPI(
    title="Multi-Tenant Events API",
    description="Multi-tenant API for managing events with tenant-specific routing",
    version="2.0.0"
)

# Add middleware for request logging
from fastapi import Request
from fastapi.responses import Response
import time

@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    
    # Log incoming request details
    print(f"\n=== INCOMING REQUEST ===")
    print(f"Method: {request.method}")
    print(f"URL: {request.url}")
    print(f"Path: {request.url.path}")
    print(f"Query: {request.url.query}")
    print(f"Headers: {dict(request.headers)}")
    
    response = await call_next(request)
    
    process_time = time.time() - start_time
    print(f"Status: {response.status_code}")
    print(f"Process time: {process_time:.4f}s")
    print(f"========================\n")
    
    return response

# Add CORS middleware to allow requests from Flutter web and mobile
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Import multi-tenant routing components
from admin import admin_router, admin_api_router
from tenant_config import get_all_tenants
from tenant_auto_router import create_tenant_api_router

# Create API router (will be automatically wrapped with tenant routing)
from fastapi import APIRouter
api_router = APIRouter(prefix="/api")

# Web build path for Flutter web
web_build_path = "../build/web"

# Header dependencies
async def get_home_id(home_id: str = Header(..., alias="homeID")):
    """Dependency to extract and validate homeID header"""
    if not home_id:
        raise HTTPException(status_code=400, detail="homeID header is required")
    try:
        return int(home_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="homeID must be a valid integer")

async def get_firebase_token(firebase_token: Optional[str] = Header(None, alias="firebaseToken")):
    """Dependency to extract Firebase token header"""
    return firebase_token

async def get_user_id(user_id: Optional[str] = Header(None, alias="userId")):
    """Dependency to extract user ID header"""
    return user_id

async def get_user_role(user_id: str, home_id: int) -> str:
    """Get user role from database"""
    user = user_db.get_user_profile(user_id, home_id)
    if not user:
        raise HTTPException(status_code=404, detail="User profile not found")
    return user.role

async def require_manager_role(user_id: str, home_id: int):
    """Dependency to ensure user has manager role"""
    role = await get_user_role(user_id, home_id)
    if role != "manager":
        raise HTTPException(status_code=403, detail="Manager role required")
    return True

@app.get("/")
async def root():
    """Root endpoint - show available tenants"""
    try:
        tenants = get_all_tenants()
        tenant_links = {}
        for tenant in tenants:
            tenant_links[tenant.name] = {
                "web": f"/{tenant.name}/web",
                "api": f"/{tenant.name}/api",
                "docs": f"/{tenant.name}/docs"
            }
        
        return {
            "message": "Multi-Tenant Events API",
            "version": "2.0.0",
            "available_tenants": tenant_links,
            "admin": "/home/admin",
            "api_docs": "/docs"
        }
    except Exception as e:
        return {
            "message": "Multi-Tenant Events API",
            "version": "2.0.0",
            "error": f"Could not load tenants: {str(e)}",
            "admin": "/home/admin",
            "api_docs": "/docs"
        }

@app.get("/debug/routes")
async def debug_routes():
    """Debug endpoint to show all registered routes"""
    routes = []
    for route in app.routes:
        if hasattr(route, 'path'):
            routes.append({
                "path": route.path,
                "methods": getattr(route, 'methods', []),
                "name": getattr(route, 'name', None)
            })
    return {"total_routes": len(routes), "routes": routes}

@api_router.get("/")
async def api_root():
    """API root endpoint"""
    return {
        "message": "Beresheet Events API",
        "version": "1.0.0",
        "docs": "/docs"
    }

@api_router.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "events_count": len(event_db.get_all_events())}

# Events CRUD endpoints
@api_router.get("/events", response_model=List[Event])
async def get_events(
    type: Optional[str] = Query(None, description="Filter by event type"),
    upcoming: Optional[bool] = Query(False, description="Get only upcoming events"),
    approved_only: Optional[bool] = Query(False, description="Get only approved events"),
    home_id: int = Depends(get_home_id),
    firebase_token: Optional[str] = Depends(get_firebase_token),
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

@api_router.get("/events/home")
async def get_events_for_home(
    home_id: int = Depends(get_home_id),
    user_id: str = Depends(get_user_id),
    firebase_token: Optional[str] = Depends(get_firebase_token)
):
    """Get events for home screen with proper recurring event handling"""
    if not user_id:
        raise HTTPException(status_code=400, detail="User ID is required")
    
    print(f"Getting events for home {home_id}, user {user_id}")
    
    events_with_status = event_db.load_events_for_home(home_id, user_id)
    return events_with_status

@api_router.get("/events/{event_id}", response_model=Event)
async def get_event(
    event_id: str,
    home_id: int = Depends(get_home_id),
    firebase_token: Optional[str] = Depends(get_firebase_token),
    user_id: Optional[str] = Depends(get_user_id)
):
    """Get a specific event by ID"""
    event = event_db.get_event_by_id(event_id, home_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    return event

@api_router.post("/events", response_model=Event, status_code=201)
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
    firebase_token: Optional[str] = Depends(get_firebase_token),
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
            from models import EventUpdate
            event_update = EventUpdate(image_url=result)
            updated_event = event_db.update_event(new_event.id, event_update, home_id)
            if updated_event:
                new_event = updated_event
        
        return new_event
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error creating event: {str(e)}")

@api_router.put("/events/{event_id}", response_model=Event)
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
    firebase_token: Optional[str] = Depends(get_firebase_token),
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

@api_router.delete("/events/{event_id}")
async def delete_event(
    event_id: str,
    home_id: int = Depends(get_home_id),
    firebase_token: Optional[str] = Depends(get_firebase_token),
    user_id: Optional[str] = Depends(get_user_id)
):
    """Delete an event"""
    success = event_db.delete_event(event_id, home_id)
    if not success:
        raise HTTPException(status_code=404, detail="Event not found")
    return {"message": "Event deleted successfully"}

# Event registration endpoints
@api_router.post("/events/{event_id}/register")
async def register_for_event(
    event_id: str,
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Depends(get_firebase_token)
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

@api_router.post("/events/{event_id}/unregister")
async def unregister_from_event(
    event_id: str,
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Depends(get_firebase_token)
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

@api_router.put("/events/{event_id}/vote-review")
async def update_vote_and_review(
    event_id: str,
    vote_review_data: EventVoteAndReviewUpdate,
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Depends(get_firebase_token)
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
        vote=vote_review_data.vote,
        review_text=vote_review_data.review_text,
        home_id=home_id
    )
    
    if not success:
        raise HTTPException(status_code=400, detail="Failed to update vote and review")
    
    return {"message": "Vote and review updated successfully", "event_id": event_id}

@api_router.get("/events/{event_id}/vote-review")
async def get_vote_and_review(
    event_id: str,
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Depends(get_firebase_token)
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

@api_router.get("/events/{event_id}/votes-reviews/all")
async def get_all_votes_and_reviews(
    event_id: str,
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
    firebase_token: Optional[str] = Depends(get_firebase_token)
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
@api_router.get("/events/types/{event_type}", response_model=List[Event])
async def get_events_by_type(event_type: str, home_id: int = Depends(get_home_id)):
    """Get all events of a specific type"""
    events = event_db.get_events_by_type(event_type, home_id)
    return events

@api_router.get("/events/upcoming/all", response_model=List[Event])
async def get_upcoming_events(home_id: int = Depends(get_home_id)):
    """Get all upcoming events"""
    events = event_db.get_upcoming_events(home_id)
    return events

# ------------------------- Event Gallery Endpoints ------------------------- #
@api_router.get("/events/{event_id}/gallery", response_model=List[EventGallery])
async def get_event_gallery(
    event_id: str,
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Depends(get_firebase_token)
):
    """Get all gallery images for an event"""
    # Check if event exists
    event = event_db.get_event_by_id(event_id, home_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    gallery_images = event_gallery_db.get_event_gallery(event_id, home_id)
    return gallery_images

@api_router.post("/events/{event_id}/gallery", response_model=List[EventGallery], status_code=201)
async def upload_gallery_images(
    event_id: str,
    images: List[UploadFile] = File(...),
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Depends(get_firebase_token)
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

@api_router.get("/events/{event_id}/gallery/{photo_id}", response_model=EventGallery)
async def get_gallery_photo(
    event_id: str,
    photo_id: str,
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Depends(get_firebase_token)
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

@api_router.delete("/events/{event_id}/gallery/{photo_id}")
async def delete_gallery_photo(
    event_id: str,
    photo_id: str,
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Depends(get_firebase_token)
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

@api_router.delete("/events/{event_id}/gallery")
async def delete_event_gallery(
    event_id: str,
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Depends(get_firebase_token)
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

# Statistics endpoint
@api_router.get("/stats")
async def get_stats(home_id: int = Depends(get_home_id)):
    """Get API statistics"""
    all_events = event_db.get_all_events(home_id)
    upcoming_events = event_db.get_upcoming_events(home_id)
    
    # Count events by type
    type_counts = {}
    for event in all_events:
        type_counts[event.type] = type_counts.get(event.type, 0) + 1
    
    return {
        "total_events": len(all_events),
        "upcoming_events": len(upcoming_events),
        "events_by_type": type_counts,
        "total_participants": sum(event.currentParticipants for event in all_events),
        "available_spots": sum(event.maxParticipants - event.currentParticipants for event in all_events)
    }

# Homes endpoint
@api_router.get("/homes")
async def get_available_homes():
    """Get all available homes for creating user profiles"""
    homes = user_db.get_available_homes()
    return homes


# ------------------------- Rooms Endpoints ------------------------- #
@api_router.get("/rooms", response_model=List[Room])
async def get_rooms(
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
):
    """List all rooms - manager role required"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    rooms = room_db.get_all_rooms(home_id)
    return rooms


@api_router.get("/rooms/public", response_model=List[Room])
async def get_rooms_public(
    home_id: int = Depends(get_home_id),
):
    """List all rooms - public access for event forms"""
    rooms = room_db.get_all_rooms(home_id)
    return rooms


@api_router.post("/rooms", response_model=Room, status_code=201)
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


@api_router.delete("/rooms/{room_id}")
async def delete_room(
    room_id: int,
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


# ------------------------- Event Instructor Endpoints ------------------------- #
@api_router.get("/event-instructors", response_model=List[EventInstructor])
async def get_event_instructors(
    home_id: int = Depends(get_home_id),
):
    """List all event instructors - public access"""
    instructors = event_instructor_db.get_all_event_instructors(home_id)
    return instructors


@api_router.get("/event-instructors/{instructor_id}", response_model=EventInstructor)
async def get_event_instructor(
    instructor_id: int,
    home_id: int = Depends(get_home_id),
):
    """Get a specific event instructor by ID"""
    instructor = event_instructor_db.get_event_instructor_by_id(instructor_id, home_id)
    if not instructor:
        raise HTTPException(status_code=404, detail="Event instructor not found")
    return instructor


@api_router.post("/event-instructors", response_model=EventInstructor, status_code=201)
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


@api_router.put("/event-instructors/{instructor_id}", response_model=EventInstructor)
async def update_event_instructor(
    instructor_id: int,
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


@api_router.delete("/event-instructors/{instructor_id}")
async def delete_event_instructor(
    instructor_id: int,
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


# ------------------------- Service Provider Types Endpoints ------------------------- #
@api_router.get("/service-provider-types", response_model=List[ServiceProviderType])
async def get_service_provider_types(
    home_id: int = Depends(get_home_id),
):
    """List all service provider types - public access"""
    types = service_provider_type_db.get_all_service_provider_types(home_id)
    return types


@api_router.get("/service-provider-types/{type_id}", response_model=ServiceProviderType)
async def get_service_provider_type(
    type_id: int,
    home_id: int = Depends(get_home_id),
):
    """Get a specific service provider type by ID"""
    provider_type = service_provider_type_db.get_service_provider_type_by_id(type_id, home_id)
    if not provider_type:
        raise HTTPException(status_code=404, detail="Service provider type not found")
    return provider_type


@api_router.post("/service-provider-types", response_model=ServiceProviderType, status_code=201)
async def create_service_provider_type(
    provider_type: ServiceProviderTypeCreate,
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
):
    """Create a new service provider type - manager role required"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    new_type = service_provider_type_db.create_service_provider_type(provider_type, home_id)
    if not new_type:
        raise HTTPException(
            status_code=400, detail="Unable to create service provider type (duplicate name?)"
        )
    return new_type


@api_router.put("/service-provider-types/{type_id}", response_model=ServiceProviderType)
async def update_service_provider_type(
    type_id: int,
    provider_type: ServiceProviderTypeUpdate,
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
):
    """Update a service provider type (only description) - manager role required"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    updated_type = service_provider_type_db.update_service_provider_type(type_id, provider_type, home_id)
    if not updated_type:
        raise HTTPException(status_code=404, detail="Service provider type not found")
    return updated_type


@api_router.delete("/service-provider-types/{type_id}")
async def delete_service_provider_type(
    type_id: int,
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
):
    """Delete a service provider type by ID - manager role required"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    success = service_provider_type_db.delete_service_provider_type(type_id, home_id)
    if not success:
        raise HTTPException(status_code=404, detail="Service provider type not found")
    return {"message": "Service provider type deleted successfully"}


# ------------------------- Requests Endpoints ------------------------- #
@api_router.post("/requests", response_model=ServiceRequest, status_code=201)
async def create_request(
    request: ServiceRequestCreate,
    home_id: int = Depends(get_home_id),
    user_id: str = Depends(get_user_id),
):
    """Create a new request from resident to service provider"""
    if not user_id:
        raise HTTPException(status_code=400, detail="User ID is required")
    
    new_request = request_db.create_request(request, user_id, home_id)
    if not new_request:
        raise HTTPException(status_code=400, detail="Unable to create request")
    return new_request


@api_router.get("/requests", response_model=List[ServiceRequest])
async def get_requests(
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    status: Optional[str] = Query(None, description="Filter by request status"),
    role_filter: Optional[str] = Query(None, description="Filter by user role: 'resident', 'service_provider', or 'all'"),
):
    """Get requests - filtered by user role and status"""
    if not user_id:
        raise HTTPException(status_code=400, detail="User ID is required")
    
    # Get user role to determine what requests they can see
    user_role = await get_user_role(user_id, home_id)
    
    if role_filter == "all" and user_role in ["manager", "staff"]:
        # Managers and staff can see all requests
        requests = request_db.get_all_requests(home_id, status)
    elif role_filter == "service_provider" or user_role == "service":
        # Service providers see requests assigned to them
        requests = request_db.get_requests_by_service_provider(user_id, home_id, status)
    elif role_filter == "resident" or user_role == "resident":
        # Residents see requests they created
        requests = request_db.get_requests_by_resident(user_id, home_id, status)
    else:
        # Default: show user's relevant requests based on their role
        if user_role == "service":
            requests = request_db.get_requests_by_service_provider(user_id, home_id, status)
        elif user_role == "resident":
            requests = request_db.get_requests_by_resident(user_id, home_id, status)
        else:
            requests = request_db.get_all_requests(home_id, status)
    
    return requests


@api_router.get("/requests/{request_id}", response_model=ServiceRequest)
async def get_request(
    request_id: str,
    home_id: int = Depends(get_home_id),
    user_id: str = Depends(get_user_id),
):
    """Get a specific request by ID"""
    request = request_db.get_request_by_id(request_id, home_id)
    if not request:
        raise HTTPException(status_code=404, detail="Request not found")
    
    # Check if user has permission to view this request
    user_role = await get_user_role(user_id, home_id)
    if (user_role not in ["manager", "staff"] and
        request.resident_id != user_id and
        request.service_provider_id != user_id):
        raise HTTPException(status_code=403, detail="Access denied")
    
    return request


@api_router.put("/requests/{request_id}", response_model=ServiceRequest)
async def update_request(
    request_id: str,
    request_update: ServiceRequestUpdate,
    home_id: int = Depends(get_home_id),
    user_id: str = Depends(get_user_id),
):
    """Update a request"""
    # Check if request exists and user has permission
    request = request_db.get_request_by_id(request_id, home_id)
    if not request:
        raise HTTPException(status_code=404, detail="Request not found")
    
    user_role = await get_user_role(user_id, home_id)
    if (user_role not in ["manager", "staff"] and
        request.resident_id != user_id and
        request.service_provider_id != user_id):
        raise HTTPException(status_code=403, detail="Access denied")
    
    updated_request = request_db.update_request(request_id, request_update, home_id)
    if not updated_request:
        raise HTTPException(status_code=400, detail="Unable to update request")
    return updated_request


@api_router.put("/requests/{request_id}/status", response_model=ServiceRequest)
async def update_request_status(
    request_id: str,
    status_update: RequestStatusUpdate,
    home_id: int = Depends(get_home_id),
    user_id: str = Depends(get_user_id),
):
    """Update request status with timestamps"""
    # Check if request exists and user has permission
    request = request_db.get_request_by_id(request_id, home_id)
    if not request:
        raise HTTPException(status_code=404, detail="Request not found")
    
    user_role = await get_user_role(user_id, home_id)
    if (user_role not in ["manager", "staff"] and
        request.resident_id != user_id and
        request.service_provider_id != user_id):
        raise HTTPException(status_code=403, detail="Access denied")
    
    updated_request = request_db.update_request_status(request_id, status_update, home_id)
    if not updated_request:
        raise HTTPException(status_code=400, detail="Unable to update request status")
    return updated_request


@api_router.post("/requests/{request_id}/chat", response_model=ServiceRequest)
async def add_chat_message(
    request_id: str,
    chat_message: dict,
    home_id: int = Depends(get_home_id),
    user_id: str = Depends(get_user_id),
):
    """Add a chat message to a request"""
    message = chat_message.get("message", "").strip()
    if not message:
        raise HTTPException(status_code=400, detail="Message is required")
    
    # Check if request exists and user has permission
    request = request_db.get_request_by_id(request_id, home_id)
    if not request:
        raise HTTPException(status_code=404, detail="Request not found")
    
    # Determine sender type
    sender_type = "resident" if request.resident_id == user_id else "service_provider"
    
    if request.resident_id != user_id and request.service_provider_id != user_id:
        user_role = await get_user_role(user_id, home_id)
        if user_role not in ["manager", "staff"]:
            raise HTTPException(status_code=403, detail="Access denied")
        sender_type = "admin"
    
    updated_request = request_db.add_chat_message(request_id, user_id, sender_type, message, home_id)
    if not updated_request:
        raise HTTPException(status_code=400, detail="Unable to add chat message")
    return updated_request


@api_router.get("/requests/{request_id}/chat")
async def get_chat_messages(
    request_id: str,
    home_id: int = Depends(get_home_id),
    user_id: str = Depends(get_user_id),
):
    """Get all chat messages for a request"""
    # Check if request exists and user has permission
    request = request_db.get_request_by_id(request_id, home_id)
    if not request:
        raise HTTPException(status_code=404, detail="Request not found")
    
    user_role = await get_user_role(user_id, home_id)
    if (user_role not in ["manager", "staff"] and
        request.resident_id != user_id and
        request.service_provider_id != user_id):
        raise HTTPException(status_code=403, detail="Access denied")
    
    chat_messages = request_db.get_chat_messages(request_id, home_id)
    return {"request_id": request_id, "chat_messages": chat_messages}


@api_router.put("/requests/{request_id}/chat")
async def update_chat_messages(
    request_id: str,
    chat_data: dict,
    home_id: int = Depends(get_home_id),
    user_id: str = Depends(get_user_id),
):
    """Update the entire chat messages array for a request"""
    # Check if request exists and user has permission
    request = request_db.get_request_by_id(request_id, home_id)
    if not request:
        raise HTTPException(status_code=404, detail="Request not found")
    
    user_role = await get_user_role(user_id, home_id)
    if (user_role not in ["manager", "staff"] and
        request.resident_id != user_id and
        request.service_provider_id != user_id):
        raise HTTPException(status_code=403, detail="Access denied")
    
    # Validate chat messages format
    chat_messages = chat_data.get("chat_messages", [])
    if not isinstance(chat_messages, list):
        raise HTTPException(status_code=400, detail="chat_messages must be an array")
    
    # Validate each message format
    for i, message in enumerate(chat_messages):
        if not isinstance(message, dict):
            raise HTTPException(status_code=400, detail=f"Message {i} must be an object")
        if "message" not in message or "created_time" not in message:
            raise HTTPException(status_code=400, detail=f"Message {i} must have 'message' and 'created_time' fields")
    
    updated_request = request_db.update_chat_messages(request_id, chat_messages, home_id)
    if not updated_request:
        raise HTTPException(status_code=400, detail="Unable to update chat messages")
    
    return {"request_id": request_id, "message": "Chat messages updated successfully", "chat_messages": chat_messages}

# Service Requests - Upload media for a request message (creates request if needed)
@api_router.post("/requests/upload-media")
async def upload_request_media_with_creation(
    file: UploadFile = File(...),
    message_id: str = Form(...),
    service_provider_id: str = Form(...),
    request_message: Optional[str] = Form("Media message"),
    request_id: Optional[str] = Form(None),
    home_id: int = Depends(get_home_id),
    user_id: str = Header(..., alias="userId")
):
    """Upload media (image, video, or audio) for a service request message. Creates request if needed."""
    try:
        actual_request_id = request_id
        created_new_request = False
        
        # If no request_id provided, create a new request
        if not actual_request_id:
            from models import ServiceRequestCreate
            request_data = ServiceRequestCreate(
                service_provider_id=service_provider_id,
                request_message=request_message or "Media message"
            )
            
            new_request = request_db.create_request(request_data, user_id, home_id)
            if not new_request:
                raise HTTPException(status_code=400, detail="Unable to create request")
            
            actual_request_id = new_request.id
            created_new_request = True
        else:
            # Verify existing request and user access
            existing_request = request_db.get_request_by_id(actual_request_id, home_id)
            if not existing_request:
                raise HTTPException(status_code=404, detail="Request not found")
            
            # Check if user is either the resident or service provider
            if user_id not in [existing_request.resident_id, existing_request.service_provider_id]:
                raise HTTPException(status_code=403, detail="Access denied")
        
        # Read file data
        file_data = await file.read()
        
        # Upload to Azure Storage
        from azure_storage_service import azure_storage_service
        success, result = azure_storage_service.upload_request_media(
            home_id=home_id,
            request_id=actual_request_id,
            message_id=message_id,
            media_data=file_data,
            original_filename=file.filename or "media",
            content_type=file.content_type
        )
        
        if not success:
            raise HTTPException(status_code=400, detail=f"Upload failed: {result}")
        
        # Get the updated request to return details
        updated_request = request_db.get_request_by_id(actual_request_id, home_id)
        if updated_request:
            # Determine sender type
            sender_type = "resident" if updated_request.resident_id == user_id else "service_provider"
            
            # Create a chat message with the media URL
            media_message = f"[Media: {file.filename or 'media'}]({result})"
            request_db.add_chat_message(actual_request_id, user_id, sender_type, media_message, home_id)
            
            # Get the request again to include the new chat message
            final_request = request_db.get_request_by_id(actual_request_id, home_id)
        
        return {
            "status": "success",
            "media_url": result,
            "message_id": message_id,
            "request_id": actual_request_id,
            "created_new_request": created_new_request,
            "request_details": final_request.model_dump() if final_request else None
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@api_router.get("/requests/resident/{resident_id}", response_model=List[ServiceRequest])
async def get_requests_by_resident(
    resident_id: str,
    home_id: int = Depends(get_home_id),
    current_user_id: str = Depends(get_user_id),
    status: Optional[str] = Query(None, description="Filter by request status"),
):
    """Get all requests by a specific resident (admin or self only)"""
    user_role = await get_user_role(current_user_id, home_id)
    
    # Only allow access if user is admin or requesting their own requests
    if user_role not in ["manager", "staff"] and current_user_id != resident_id:
        raise HTTPException(status_code=403, detail="Access denied")
    
    requests = request_db.get_requests_by_resident(resident_id, home_id, status)
    return requests


@api_router.get("/requests/service-provider/{service_provider_id}", response_model=List[ServiceRequest])
async def get_requests_by_service_provider(
    service_provider_id: str,
    home_id: int = Depends(get_home_id),
    current_user_id: str = Depends(get_user_id),
    status: Optional[str] = Query(None, description="Filter by request status"),
):
    """Get all requests for a specific service provider (admin or self only)"""
    user_role = await get_user_role(current_user_id, home_id)
    
    # Only allow access if user is admin or requesting their own requests
    if user_role not in ["manager", "staff"] and current_user_id != service_provider_id:
        raise HTTPException(status_code=403, detail="Access denied")
    
    requests = request_db.get_requests_by_service_provider(service_provider_id, home_id, status)
    return requests


@api_router.get("/requests/service-provider-type/{service_provider_type}", response_model=List[ServiceRequest])
async def get_requests_by_service_provider_type(
    service_provider_type: str,
    home_id: int = Depends(get_home_id),
    current_user_id: str = Depends(get_user_id),
    status: Optional[str] = Query(None, description="Filter by request status"),
):
    """Get all requests for a specific service provider type (admin only)"""
    user_role = await get_user_role(current_user_id, home_id)
    
    # Only allow access for managers and staff
    if user_role not in ["manager", "staff"]:
        raise HTTPException(status_code=403, detail="Access denied")
    
    requests = request_db.get_requests_by_service_provider_type(service_provider_type, home_id, status)
    return requests


@api_router.delete("/requests/{request_id}")
async def delete_request(
    request_id: str,
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
):
    """Delete a request (admin only)"""
    # Only managers can delete requests
    await require_manager_role(current_user_id, home_id)
    
    success = request_db.delete_request(request_id, home_id)
    if not success:
        raise HTTPException(status_code=404, detail="Request not found")
    return {"message": "Request deleted successfully"}

# User Profile CRUD endpoints
@api_router.get("/users", response_model=List[UserProfile])
async def get_all_users(home_id: int = Depends(get_home_id)):
    """Get all user profiles"""
    users = user_db.get_all_users(home_id)
    return users

@api_router.get("/users/service-providers", response_model=List[ServiceProviderProfile])
async def get_service_providers(
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id)
):
    """Get all users with service provider role, ordered by most recent request interaction"""
    try:
        print(f"Getting service providers for home_id: {home_id}, user_id: {user_id}")
        
        # Get service providers ordered by most recent request interaction
        service_providers = user_db.get_service_providers_ordered_by_requests(home_id, user_id)
        print(f"Service providers found: {len(service_providers)}")
        return service_providers
    except Exception as e:
        print(f"Error in get_service_providers: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@api_router.get("/users/{user_id}", response_model=UserProfile)
async def get_user_profile(user_id: str, home_id: int = Depends(get_home_id)):
    """Get a specific user profile by user ID"""
    user = user_db.get_user_profile(user_id, home_id)
    if not user:
        raise HTTPException(status_code=404, detail="User profile not found")
    return user

@api_router.post("/users/by-phone", response_model=UserProfile)
async def get_user_profile_by_phone(
    request: dict,
    home_id: int = Depends(get_home_id),
    firebase_token: Optional[str] = Depends(get_firebase_token)
):
    """Get a user profile by phone number"""
    phone_number = request.get("phone_number")
    if not phone_number:
        raise HTTPException(status_code=400, detail="phone_number is required")
    
    user = user_db.get_user_profile_by_phone(phone_number, home_id)
    if not user:
        raise HTTPException(status_code=404, detail="User profile not found for this phone number")
    return user

@api_router.post("/users", response_model=UserProfile, status_code=201)
async def create_user_profile(
    user: UserProfileCreate,
    current_user_id: str = Header(..., alias="currentUserId"),
    home_id: int = Depends(get_home_id),
    firebase_id: Optional[str] = Header(None, alias="firebaseId")
):
    """Create a new user profile - requires manager role"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    try:
        new_user = user_db.create_user_profile(firebase_id, user, home_id)
        return new_user
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error creating user profile: {str(e)}")

@api_router.put("/users/{user_id}", response_model=UserProfile)
async def update_user_profile(
    user_id: str,
    full_name: Optional[str] = Form(None),
    phone_number: Optional[str] = Form(None),
    role: Optional[str] = Form(None),
    birthday: Optional[str] = Form(None),
    apartment_number: Optional[str] = Form(None),
    marital_status: Optional[str] = Form(None),
    gender: Optional[str] = Form(None),
    religious: Optional[str] = Form(None),
    native_language: Optional[str] = Form(None),
    service_provider_type_id: Optional[str] = Form(None),
    photo: Optional[UploadFile] = File(None),
    home_id: int = Depends(get_home_id)
):
    """Update an existing user profile with optional image upload"""
    try:
        # Check if user exists
        existing_user = user_db.get_user_profile(user_id, home_id)
        if not existing_user:
            raise HTTPException(status_code=404, detail="User profile not found")
        
        # Prepare update data
        update_data = {}
        
        if full_name is not None:
            update_data['full_name'] = full_name
        if phone_number is not None:
            update_data['phone_number'] = phone_number
        if role is not None:
            update_data['role'] = role
        if apartment_number is not None:
            update_data['apartment_number'] = apartment_number
        if marital_status is not None:
            update_data['marital_status'] = marital_status
        if gender is not None:
            update_data['gender'] = gender
        if religious is not None:
            update_data['religious'] = religious
        if native_language is not None:
            update_data['native_language'] = native_language
        if service_provider_type_id is not None:
            try:
                update_data['service_provider_type_id'] = int(service_provider_type_id)
            except ValueError:
                raise HTTPException(status_code=400, detail="Invalid service_provider_type_id format")
        
        # Parse birthday if provided
        if birthday is not None:
            try:
                from datetime import datetime
                parsed_birthday = datetime.fromisoformat(birthday.replace('Z', '+00:00')).date()
                update_data['birthday'] = parsed_birthday
            except ValueError:
                raise HTTPException(status_code=400, detail="Invalid birthday format")
        
        # Handle photo upload if provided
        if photo:
            # Validate file type
            if not photo.content_type or not photo.content_type.startswith('image/'):
                raise HTTPException(status_code=400, detail="Uploaded file must be an image")
            
            # Read photo data
            photo_data = await photo.read()
            
            # Upload to Azure Storage
            success, result = azure_storage_service.upload_user_photo(
                home_id=home_id,
                user_id=user_id,
                image_data=photo_data,
                original_filename=photo.filename or "profile.jpg",
                content_type=photo.content_type
            )
            
            if not success:
                raise HTTPException(status_code=400, detail=f"Photo upload failed: {result}")
            
            update_data['photo'] = result
        
        # Create UserProfileUpdate object
        user_update = UserProfileUpdate(**update_data)
        
        # Update the user profile
        updated_user = user_db.update_user_profile(user_id, user_update, home_id)
        if not updated_user:
            raise HTTPException(status_code=404, detail="User profile not found")
        
        return updated_user
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error updating user profile: {str(e)}")

@api_router.delete("/users/{user_id}")
async def delete_user_profile(user_id: str, home_id: int = Depends(get_home_id)):
    """Delete a user profile"""
    success = user_db.delete_user_profile(user_id, home_id)
    if not success:
        raise HTTPException(status_code=404, detail="User profile not found")
    return {"message": "User profile deleted successfully"}

@api_router.patch("/users/{user_id}/fcm-token")
async def update_user_fcm_token(
    user_id: str,
    token_data: dict,
    home_id: int = Depends(get_home_id)
):
    """Update only the Firebase FCM token for a user"""
    try:
        # Get the FCM token from request body
        fcm_token = token_data.get('firebase_fcm_token')
        if not fcm_token:
            raise HTTPException(status_code=400, detail="firebase_fcm_token is required")
        
        # Update the user's FCM token in the database
        success = user_db.update_user_fcm_token(user_id, fcm_token, home_id)
        
        if success:
            return {"message": "FCM token updated successfully"}
        else:
            raise HTTPException(status_code=404, detail="User not found or update failed")
            
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error updating FCM token: {e}")
        raise HTTPException(status_code=500, detail="Failed to update FCM token")

# User photo endpoints
@api_router.post("/users/{user_id}/photo")
async def upload_user_photo(
    user_id: str,
    photo: UploadFile = File(...),
    home_id: int = Depends(get_home_id)
):
    """Upload a photo for a user profile to Azure Storage"""
    # Check if user exists
    user = user_db.get_user_profile(user_id, home_id)
    if not user:
        raise HTTPException(status_code=404, detail="User profile not found")
    
    # Validate file type
    if not photo.content_type or not photo.content_type.startswith('image/'):
        raise HTTPException(status_code=400, detail="File must be an image")
    
    try:
        # Read photo data
        photo_data = await photo.read()
        
        # Upload to Azure Storage
        success, result = azure_storage_service.upload_user_photo(
            home_id=home_id,
            user_id=user_id,
            image_data=photo_data,
            original_filename=photo.filename or "profile.jpg",
            content_type=photo.content_type
        )
        
        if not success:
            raise HTTPException(status_code=400, detail=f"Photo upload failed: {result}")
        
        # Update user profile with Azure photo URL
        user_update = UserProfileUpdate(photo=result)
        updated_user = user_db.update_user_profile(user_id, user_update, home_id)
        
        if not updated_user:
            raise HTTPException(status_code=500, detail="Failed to update user profile with photo URL")
        
        return {
            "message": "Photo uploaded successfully",
            "photo_url": result
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error uploading photo: {str(e)}")

@api_router.get("/users/{user_id}/photo")
async def get_user_photo(user_id: str, home_id: int = Depends(get_home_id)):
    """Get a user's photo URL from Azure Storage"""
    # Get user profile to check if photo URL exists
    user = user_db.get_user_profile(user_id, home_id)
    if not user or not user.photo:
        raise HTTPException(status_code=404, detail="Photo not found")
    
    # If the photo URL is already a full Azure Storage URL with SAS token, redirect to it
    if user.photo.startswith('https://'):
        from fastapi.responses import RedirectResponse
        return RedirectResponse(url=user.photo)
    
    # Otherwise, assume it's a blob path and generate SAS URL
    blob_path = f"{home_id}/users/photos/{user_id}.jpg"
    photo_url = azure_storage_service.get_image_url(blob_path)
    if not photo_url:
        raise HTTPException(status_code=404, detail="Photo not found")
    
    from fastapi.responses import RedirectResponse
    return RedirectResponse(url=photo_url)

# Event Registration Management endpoints
@api_router.get("/registrations/user/{user_id}")
async def get_user_registrations(
    user_id: str,
    home_id: int = Depends(get_home_id),
    firebase_token: Optional[str] = Depends(get_firebase_token)
):
    """Get all registrations for a specific user"""
    registrations = events_registration_db.get_user_registrations(user_id, home_id)
    return [reg.to_dict() for reg in registrations]

@api_router.get("/registrations/event/{event_id}")
async def get_event_registrations(
    event_id: str,
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
    firebase_token: Optional[str] = Depends(get_firebase_token)
):
    """Get all registrations for a specific event - requires manager role"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    registrations = events_registration_db.get_event_registrations(event_id, home_id)
    return [reg.to_dict() for reg in registrations]

@api_router.get("/registrations/all")
async def get_all_registrations(
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
    firebase_token: Optional[str] = Depends(get_firebase_token)
):
    """Get all registrations - requires manager role"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    registrations = events_registration_db.get_all_registrations(home_id)
    return [reg.to_dict() for reg in registrations]

@api_router.get("/registrations/check/{event_id}/{user_id}")
async def check_registration_status(
    event_id: str,
    user_id: str,
    home_id: int = Depends(get_home_id),
    firebase_token: Optional[str] = Depends(get_firebase_token)
):
    """Check if a user is registered for an event"""
    is_registered = events_registration_db.is_user_registered(event_id, user_id, home_id)
    return {"is_registered": is_registered, "event_id": event_id, "user_id": user_id}

@api_router.delete("/registrations/admin/{event_id}/{user_id}")
async def admin_unregister_user(
    event_id: str,
    user_id: str,
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
    firebase_token: Optional[str] = Depends(get_firebase_token)
):
    """Admin endpoint to unregister a user from an event - requires manager role"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    success = events_registration_db.unregister_from_event(event_id, user_id, home_id)
    if not success:
        raise HTTPException(status_code=400, detail="Unable to unregister user from event")
    
    return {"message": "User successfully unregistered from event", "event_id": event_id, "user_id": user_id}

# Authentication endpoints - these need special handling in tenant routing
# They should not require homeID header since that's what users get after login
@api_router.post("/auth/login")
async def login(login_request: dict):
    """Authenticate user and create web session"""
    try:
        phone_number = login_request.get("phone_number")
        password = login_request.get("password")
        home_id = login_request.get("home_id")
        
        if not phone_number or not password or not home_id:
            return {
                "success": False,
                "message": "Phone number, password, and home ID are required"
            }
        
        # Authenticate user
        user = user_db.authenticate_user(phone_number, password, home_id)
        if not user:
            return {
                "success": False,
                "message": "Invalid phone number or password"
            }
        
        # Create web session
        session_id = user_db.create_web_session(user.id, home_id, user.role)
        if not session_id:
            return {
                "success": False,
                "message": "Failed to create session"
            }
        
        # Create JSON response
        response_data = {
            "success": True,
            "session_id": session_id,
            "user_id": user.id,
            "home_id": home_id,
            "user_role": user.role,
            "message": "Login successful"
        }
        
        # Create response with session cookie for web browsers
        from fastapi.responses import JSONResponse
        response = JSONResponse(content=response_data)
        response.set_cookie(
            key="web_session_id",
            value=session_id,
            max_age=86400,  # 24 hours (same as session expiry)
            httponly=True,  # Prevent JavaScript access for security
            secure=False,   # Set to True in production with HTTPS
            samesite="lax"
        )
        
        return response
        
    except Exception as e:
        return {
            "success": False,
            "message": f"Login failed: {str(e)}"
        }

@api_router.post("/auth/validate-session")
async def validate_session(request: dict):
    """Validate web session"""
    try:
        session_id = request.get("session_id")
        home_id = request.get("home_id")
        
        if not session_id or not home_id:
            return {
                "valid": False,
                "message": "Session ID and home ID are required"
            }
        
        session_info = user_db.validate_web_session(session_id, home_id)
        if session_info:
            return {
                "valid": True,
                "session_info": session_info
            }
        else:
            return {
                "valid": False,
                "message": "Invalid or expired session"
            }
            
    except Exception as e:
        return {
            "valid": False,
            "message": f"Session validation failed: {str(e)}"
        }

@api_router.post("/auth/logout")
async def logout(request: dict):
    """Logout user and invalidate session"""
    try:
        session_id = request.get("session_id")
        home_id = request.get("home_id")
        
        if not session_id or not home_id:
            return {
                "success": False,
                "message": "Session ID and home ID are required"
            }
        
        success = user_db.invalidate_web_session(session_id, home_id)
        return {
            "success": success,
            "message": "Logout successful" if success else "Failed to logout"
        }
        
    except Exception as e:
        return {
            "success": False,
            "message": f"Logout failed: {str(e)}"
        }

# Create complete tenant router with API and web endpoints
tenant_router = create_tenant_api_router(api_router)

# Create tenant-aware notification router
from tenant_auto_router import create_tenant_api_router
tenant_notification_router = create_tenant_api_router(home_notification_router)

# Include routers in the correct order
# 1. Admin routes (highest priority)
app.include_router(admin_router)
app.include_router(admin_api_router)

# 2. Complete tenant router (/{tenant_name}/api/* and /{tenant_name}/web)
app.include_router(tenant_router)

# 3. Tenant notification routes (/{tenant_name}/api/notifications/*)
app.include_router(tenant_notification_router)

# Note: ALL endpoints are now tenant-specific:
# - /{tenant_name}/api/* for all API endpoints
# - /{tenant_name}/web for web interface
# - /home/admin for tenant management

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
