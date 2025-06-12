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
)
from events import event_db
from rooms import room_db
from events_registration import events_registration_db
from users import user_db
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
    home_id: int = Depends(get_home_id),
    firebase_token: Optional[str] = Depends(get_firebase_token),
    user_id: Optional[str] = Depends(get_user_id)
):
    """Get all events, optionally filtered by type or upcoming only"""
    # Log headers for tracking (can be expanded for analytics/auditing)
    print(f"Request from homeID: {home_id}, userID: {user_id}")
    
    if upcoming:
        events = event_db.get_upcoming_events(home_id)
    elif type:
        events = event_db.get_events_by_type(type, home_id)
    else:
        events = event_db.get_all_events(home_id)
    
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
        new_event = event_db.create_event(event, home_id)
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
    permitted: bool = Depends(require_manager_role),
):
    """List all rooms - manager role required"""
    rooms = room_db.get_all_rooms(home_id)
    return rooms


@api_router.post("/rooms", response_model=Room, status_code=201)
async def create_room(
    room: RoomCreate,
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
    permitted: bool = Depends(require_manager_role),
):
    """Create a new room - manager role required"""
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
    permitted: bool = Depends(require_manager_role),
):
    """Delete a room by ID - manager role required"""
    success = room_db.delete_room(room_id, home_id)
    if not success:
        raise HTTPException(status_code=404, detail="Room not found")
    return {"message": "Room deleted successfully"}

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