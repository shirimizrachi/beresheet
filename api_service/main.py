from fastapi import FastAPI, HTTPException, Query, File, UploadFile, Header, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from typing import List, Optional
from models import (
    Event,
    EventCreate,
    EventUpdate,
    EventRegistration,
    UserProfile,
    UserProfileCreate,
    UserProfileUpdate,
    LoginRequest,
    LoginResponse,
    SessionInfo,
    Room,
    RoomCreate,
    ServiceProviderType,
    ServiceProviderTypeCreate,
    ServiceProviderTypeUpdate,
    Request,
    RequestCreate,
    RequestUpdate,
    RequestStatusUpdate,
    ChatMessage,
)
from events import event_db
from rooms import room_db
from events_registration import events_registration_db
from users import user_db
from service_provider_types import service_provider_type_db
from requests import request_db
import uvicorn
import os

# Create FastAPI app
app = FastAPI(
    title="Beresheet Events API",
    description="API for managing events in the Beresheet Flutter application",
    version="1.0.0"
)

# Add CORS middleware to allow requests from Flutter web and mobile
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Create API router
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
    """Root endpoint - redirect to web app"""
    return FileResponse(os.path.join(web_build_path, "index.html")) if os.path.exists(web_build_path) else {
        "message": "Beresheet Events API",
        "version": "1.0.0",
        "api_docs": "/docs",
        "web_app": "/web"
    }

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
    event: EventCreate,
    home_id: int = Depends(get_home_id),
    firebase_token: Optional[str] = Depends(get_firebase_token),
    user_id: Optional[str] = Depends(get_user_id)
):
    """Create a new event"""
    try:
        new_event = event_db.create_event(event, home_id, created_by=user_id)
        return new_event
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error creating event: {str(e)}")

@api_router.put("/events/{event_id}", response_model=Event)
async def update_event(
    event_id: str,
    event: EventUpdate,
    home_id: int = Depends(get_home_id),
    firebase_token: Optional[str] = Depends(get_firebase_token),
    user_id: Optional[str] = Depends(get_user_id)
):
    """Update an existing event"""
    updated_event = event_db.update_event(event_id, event, home_id)
    if not updated_event:
        raise HTTPException(status_code=404, detail="Event not found")
    return updated_event

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
    
    # Get user info for registration
    user_profile = user_db.get_user_profile(user_id, home_id)
    user_name = user_profile.full_name if user_profile else None
    user_phone = user_profile.phone if user_profile else None
    
    success = events_registration_db.register_for_event(
        event_id=event_id,
        user_id=user_id,
        user_name=user_name,
        user_phone=user_phone,
        resident_id=home_id
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
        resident_id=home_id
    )
    
    if not success:
        raise HTTPException(status_code=400, detail="Unable to unregister from event. You may not be registered for this event.")
    
    return {"message": "Successfully unregistered from event", "event_id": event_id}

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
@api_router.post("/requests", response_model=Request, status_code=201)
async def create_request(
    request: RequestCreate,
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


@api_router.get("/requests", response_model=List[Request])
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


@api_router.get("/requests/{request_id}", response_model=Request)
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


@api_router.put("/requests/{request_id}", response_model=Request)
async def update_request(
    request_id: str,
    request_update: RequestUpdate,
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


@api_router.put("/requests/{request_id}/status", response_model=Request)
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


@api_router.post("/requests/{request_id}/chat", response_model=Request)
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


@api_router.get("/requests/resident/{resident_id}", response_model=List[Request])
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


@api_router.get("/requests/service-provider/{service_provider_id}", response_model=List[Request])
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


@api_router.get("/requests/service-provider-type/{service_provider_type}", response_model=List[Request])
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
    user: UserProfileUpdate,
    home_id: int = Depends(get_home_id)
):
    """Update an existing user profile"""
    updated_user = user_db.update_user_profile(user_id, user, home_id)
    if not updated_user:
        raise HTTPException(status_code=404, detail="User profile not found")
    return updated_user

@api_router.delete("/users/{user_id}")
async def delete_user_profile(user_id: str, home_id: int = Depends(get_home_id)):
    """Delete a user profile"""
    success = user_db.delete_user_profile(user_id, home_id)
    if not success:
        raise HTTPException(status_code=404, detail="User profile not found")
    return {"message": "User profile deleted successfully"}

# User photo endpoints
@api_router.post("/users/{user_id}/photo")
async def upload_user_photo(
    user_id: str,
    photo: UploadFile = File(...),
    home_id: int = Depends(get_home_id)
):
    """Upload a photo for a user profile"""
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
        
        # Save photo
        photo_path = user_db.save_user_photo(user_id, photo_data, home_id)
        
        # Update user profile with photo path
        user_update = UserProfileUpdate(photo=f"/api/users/{user_id}/photo")
        updated_user = user_db.update_user_profile(user_id, user_update, home_id)
        
        return {
            "message": "Photo uploaded successfully",
            "photo_url": f"/api/users/{user_id}/photo"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error uploading photo: {str(e)}")

@api_router.get("/users/{user_id}/photo")
async def get_user_photo(user_id: str, home_id: int = Depends(get_home_id)):
    """Get a user's photo"""
    photo_path = user_db.get_user_photo_path(user_id, home_id)
    if not photo_path:
        raise HTTPException(status_code=404, detail="Photo not found")
    
    return FileResponse(photo_path, media_type="image/jpeg")

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

# Authentication endpoints
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
        
        return {
            "success": True,
            "session_id": session_id,
            "user_id": user.id,
            "home_id": home_id,
            "user_role": user.role,
            "message": "Login successful"
        }
        
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

# Include the API router
app.include_router(api_router)

# Serve Flutter web app at /web
@app.get("/web")
async def serve_web_app_root():
    """Serve Flutter web app root"""
    if not os.path.exists(web_build_path):
        raise HTTPException(status_code=404, detail="Web app not built yet. Please run 'flutter build web' first.")
    return FileResponse(os.path.join(web_build_path, "index.html"))

@app.get("/web/")
async def serve_web_app_root_slash():
    """Serve Flutter web app root with slash"""
    if not os.path.exists(web_build_path):
        raise HTTPException(status_code=404, detail="Web app not built yet. Please run 'flutter build web' first.")
    return FileResponse(os.path.join(web_build_path, "index.html"))

@app.get("/web/{full_path:path}")
async def serve_web_app(full_path: str):
    """Serve Flutter web app"""
    if not os.path.exists(web_build_path):
        raise HTTPException(status_code=404, detail="Web app not built yet. Please run 'flutter build web' first.")
    
    # Try to serve the requested file
    file_path = os.path.join(web_build_path, full_path)
    if os.path.exists(file_path) and os.path.isfile(file_path):
        return FileResponse(file_path)
    
    # Fall back to index.html for client-side routing
    return FileResponse(os.path.join(web_build_path, "index.html"))

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )