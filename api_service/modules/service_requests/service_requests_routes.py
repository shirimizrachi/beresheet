"""
Service Requests API routes for resident-service provider communication
"""

from fastapi import APIRouter, HTTPException, Query, Header, Depends, File, UploadFile, Form
from typing import List, Optional
from .models import ServiceRequest, ServiceRequestCreate, ServiceRequestUpdate, RequestStatusUpdate
from .service_requests import request_db

router = APIRouter(prefix="/requests", tags=["service_requests"])

# Header dependencies
async def get_home_id(home_id: str = Header(..., alias="homeID")):
    """Dependency to extract and validate homeID header"""
    if not home_id:
        raise HTTPException(status_code=400, detail="homeID header is required")
    try:
        return int(home_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="homeID must be a valid integer")

async def get_user_id(user_id: Optional[str] = Header(None, alias="userId")):
    """Dependency to extract user ID header"""
    return user_id

async def get_user_role(user_id: str, home_id: int) -> str:
    """Get user role from database"""
    from modules.users import user_db
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

# ------------------------- Requests Endpoints ------------------------- #
@router.post("/", response_model=ServiceRequest, status_code=201)
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


@router.get("/", response_model=List[ServiceRequest])
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


@router.get("/{request_id}", response_model=ServiceRequest)
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


@router.put("/{request_id}", response_model=ServiceRequest)
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


@router.put("/{request_id}/status", response_model=ServiceRequest)
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


@router.post("/{request_id}/chat", response_model=ServiceRequest)
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


@router.get("/{request_id}/chat")
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


@router.put("/{request_id}/chat")
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
@router.post("/upload-media")
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
        
        # Upload to Storage
        from storage.storage_service import azure_storage_service
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

@router.get("/resident/{resident_id}", response_model=List[ServiceRequest])
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


@router.get("/service-provider/{service_provider_id}", response_model=List[ServiceRequest])
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


@router.get("/service-provider-type/{service_provider_type}", response_model=List[ServiceRequest])
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


@router.delete("/{request_id}")
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