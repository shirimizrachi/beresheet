from fastapi import FastAPI, HTTPException, Query, File, UploadFile, Header, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from typing import List, Optional
from models import Event, EventCreate, EventUpdate, EventRegistration, UserProfile, UserProfileCreate, UserProfileUpdate
from database import db, user_db
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
async def get_resident_id(resident_id: str = Header(..., alias="residentID")):
    """Dependency to extract and validate residentID header"""
    if not resident_id:
        raise HTTPException(status_code=400, detail="residentID header is required")
    try:
        return int(resident_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="residentID must be a valid integer")

async def get_firebase_token(firebase_token: Optional[str] = Header(None, alias="firebaseToken")):
    """Dependency to extract Firebase token header"""
    return firebase_token

async def get_user_id(user_id: Optional[str] = Header(None, alias="userId")):
    """Dependency to extract user ID header"""
    return user_id

async def get_user_role(unique_id: str) -> str:
    """Get user role from database"""
    user = user_db.get_user_profile(unique_id)
    if not user:
        raise HTTPException(status_code=404, detail="User profile not found")
    return user.role

async def require_manager_role(unique_id: str):
    """Dependency to ensure user has manager role"""
    role = await get_user_role(unique_id)
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
    return {"status": "healthy", "events_count": len(db.get_all_events())}

# Events CRUD endpoints
@api_router.get("/events", response_model=List[Event])
async def get_events(
    type: Optional[str] = Query(None, description="Filter by event type"),
    upcoming: Optional[bool] = Query(False, description="Get only upcoming events"),
    resident_id: int = Depends(get_resident_id),
    firebase_token: Optional[str] = Depends(get_firebase_token),
    user_id: Optional[str] = Depends(get_user_id)
):
    """Get all events, optionally filtered by type or upcoming only"""
    # Log headers for tracking (can be expanded for analytics/auditing)
    print(f"Request from residentID: {resident_id}, userID: {user_id}")
    
    if upcoming:
        events = db.get_upcoming_events()
    elif type:
        events = db.get_events_by_type(type)
    else:
        events = db.get_all_events()
    
    return events

@api_router.get("/events/{event_id}", response_model=Event)
async def get_event(
    event_id: str,
    resident_id: int = Depends(get_resident_id),
    firebase_token: Optional[str] = Depends(get_firebase_token),
    user_id: Optional[str] = Depends(get_user_id)
):
    """Get a specific event by ID"""
    event = db.get_event_by_id(event_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    return event

@api_router.post("/events", response_model=Event, status_code=201)
async def create_event(
    event: EventCreate,
    resident_id: int = Depends(get_resident_id),
    firebase_token: Optional[str] = Depends(get_firebase_token),
    user_id: Optional[str] = Depends(get_user_id)
):
    """Create a new event"""
    try:
        new_event = db.create_event(event)
        return new_event
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error creating event: {str(e)}")

@api_router.put("/events/{event_id}", response_model=Event)
async def update_event(
    event_id: str,
    event: EventUpdate,
    resident_id: int = Depends(get_resident_id),
    firebase_token: Optional[str] = Depends(get_firebase_token),
    user_id: Optional[str] = Depends(get_user_id)
):
    """Update an existing event"""
    updated_event = db.update_event(event_id, event)
    if not updated_event:
        raise HTTPException(status_code=404, detail="Event not found")
    return updated_event

@api_router.delete("/events/{event_id}")
async def delete_event(
    event_id: str,
    resident_id: int = Depends(get_resident_id),
    firebase_token: Optional[str] = Depends(get_firebase_token),
    user_id: Optional[str] = Depends(get_user_id)
):
    """Delete an event"""
    success = db.delete_event(event_id)
    if not success:
        raise HTTPException(status_code=404, detail="Event not found")
    return {"message": "Event deleted successfully"}

# Event registration endpoints
@api_router.post("/events/{event_id}/register")
async def register_for_event(
    event_id: str,
    registration: Optional[EventRegistration] = None,
    resident_id: int = Depends(get_resident_id)
):
    """Register for an event"""
    user_id = registration.user_id if registration else None
    
    # Check if event exists
    event = db.get_event_by_id(event_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    # Check if event is full
    if event.currentParticipants >= event.maxParticipants:
        raise HTTPException(status_code=400, detail="Event is full")
    
    success = db.register_for_event(event_id, user_id)
    if not success:
        raise HTTPException(status_code=400, detail="Unable to register for event")
    
    return {"message": "Successfully registered for event", "event_id": event_id}

@api_router.post("/events/{event_id}/unregister")
async def unregister_from_event(
    event_id: str,
    registration: Optional[EventRegistration] = None,
    resident_id: int = Depends(get_resident_id)
):
    """Unregister from an event"""
    user_id = registration.user_id if registration else None
    
    # Check if event exists
    event = db.get_event_by_id(event_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    success = db.unregister_from_event(event_id, user_id)
    if not success:
        raise HTTPException(status_code=400, detail="Unable to unregister from event")
    
    return {"message": "Successfully unregistered from event", "event_id": event_id}

# Event type endpoints
@api_router.get("/events/types/{event_type}", response_model=List[Event])
async def get_events_by_type(event_type: str):
    """Get all events of a specific type"""
    events = db.get_events_by_type(event_type)
    return events

@api_router.get("/events/upcoming/all", response_model=List[Event])
async def get_upcoming_events():
    """Get all upcoming events"""
    events = db.get_upcoming_events()
    return events

# Statistics endpoint
@api_router.get("/stats")
async def get_stats():
    """Get API statistics"""
    all_events = db.get_all_events()
    upcoming_events = db.get_upcoming_events()
    
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

# User Profile CRUD endpoints
@api_router.get("/users", response_model=List[UserProfile])
async def get_all_users(resident_id: int = Depends(get_resident_id)):
    """Get all user profiles"""
    users = user_db.get_all_users()
    return users

@api_router.get("/users/{unique_id}", response_model=UserProfile)
async def get_user_profile(unique_id: str, resident_id: int = Depends(get_resident_id)):
    """Get a specific user profile by unique ID"""
    user = user_db.get_user_profile(unique_id)
    if not user:
        raise HTTPException(status_code=404, detail="User profile not found")
    return user

@api_router.post("/users/{unique_id}", response_model=UserProfile, status_code=201)
async def create_user_profile(
    unique_id: str,
    user: UserProfileCreate,
    current_user_id: str = Header(..., alias="currentUserId"),
    resident_id: int = Depends(get_resident_id)
):
    """Create a new user profile - requires manager role"""
    # Check if current user has manager role
    await require_manager_role(current_user_id)
    
    # Check if user already exists
    existing_user = user_db.get_user_profile(unique_id)
    if existing_user:
        raise HTTPException(status_code=400, detail="User profile already exists")
    
    try:
        new_user = user_db.create_user_profile(unique_id, user)
        return new_user
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error creating user profile: {str(e)}")

@api_router.put("/users/{unique_id}", response_model=UserProfile)
async def update_user_profile(
    unique_id: str,
    user: UserProfileUpdate,
    resident_id: int = Depends(get_resident_id)
):
    """Update an existing user profile"""
    updated_user = user_db.update_user_profile(unique_id, user)
    if not updated_user:
        raise HTTPException(status_code=404, detail="User profile not found")
    return updated_user

@api_router.delete("/users/{unique_id}")
async def delete_user_profile(unique_id: str, resident_id: int = Depends(get_resident_id)):
    """Delete a user profile"""
    success = user_db.delete_user_profile(unique_id)
    if not success:
        raise HTTPException(status_code=404, detail="User profile not found")
    return {"message": "User profile deleted successfully"}

# User photo endpoints
@api_router.post("/users/{unique_id}/photo")
async def upload_user_photo(
    unique_id: str,
    photo: UploadFile = File(...),
    resident_id: int = Depends(get_resident_id)
):
    """Upload a photo for a user profile"""
    # Check if user exists
    user = user_db.get_user_profile(unique_id)
    if not user:
        raise HTTPException(status_code=404, detail="User profile not found")
    
    # Validate file type
    if not photo.content_type or not photo.content_type.startswith('image/'):
        raise HTTPException(status_code=400, detail="File must be an image")
    
    try:
        # Read photo data
        photo_data = await photo.read()
        
        # Save photo
        photo_path = user_db.save_user_photo(unique_id, photo_data)
        
        # Update user profile with photo path
        user_update = UserProfileUpdate(photo=f"/api/users/{unique_id}/photo")
        updated_user = user_db.update_user_profile(unique_id, user_update)
        
        return {
            "message": "Photo uploaded successfully",
            "photo_url": f"/api/users/{unique_id}/photo"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error uploading photo: {str(e)}")

@api_router.get("/users/{unique_id}/photo")
async def get_user_photo(unique_id: str, resident_id: int = Depends(get_resident_id)):
    """Get a user's photo"""
    photo_path = user_db.get_user_photo_path(unique_id)
    if not photo_path:
        raise HTTPException(status_code=404, detail="Photo not found")
    
    return FileResponse(photo_path, media_type="image/jpeg")

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