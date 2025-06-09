from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from typing import List, Optional
from models import Event, EventCreate, EventUpdate, EventRegistration
from database import db
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
    upcoming: Optional[bool] = Query(False, description="Get only upcoming events")
):
    """Get all events, optionally filtered by type or upcoming only"""
    if upcoming:
        events = db.get_upcoming_events()
    elif type:
        events = db.get_events_by_type(type)
    else:
        events = db.get_all_events()
    
    return events

@api_router.get("/events/{event_id}", response_model=Event)
async def get_event(event_id: str):
    """Get a specific event by ID"""
    event = db.get_event_by_id(event_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    return event

@api_router.post("/events", response_model=Event, status_code=201)
async def create_event(event: EventCreate):
    """Create a new event"""
    try:
        new_event = db.create_event(event)
        return new_event
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error creating event: {str(e)}")

@api_router.put("/events/{event_id}", response_model=Event)
async def update_event(event_id: str, event: EventUpdate):
    """Update an existing event"""
    updated_event = db.update_event(event_id, event)
    if not updated_event:
        raise HTTPException(status_code=404, detail="Event not found")
    return updated_event

@api_router.delete("/events/{event_id}")
async def delete_event(event_id: str):
    """Delete an event"""
    success = db.delete_event(event_id)
    if not success:
        raise HTTPException(status_code=404, detail="Event not found")
    return {"message": "Event deleted successfully"}

# Event registration endpoints
@api_router.post("/events/{event_id}/register")
async def register_for_event(event_id: str, registration: Optional[EventRegistration] = None):
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
async def unregister_from_event(event_id: str, registration: Optional[EventRegistration] = None):
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