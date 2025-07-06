"""
User management routes
"""

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Query, Header, Form
from typing import List, Optional
from .models import (
    UserProfile, UserProfileCreate, UserProfileUpdate, ServiceProviderProfile,
    ServiceProviderType, ServiceProviderTypeCreate, ServiceProviderTypeUpdate,
    UserByPhoneRequest
)
from .users import user_db
from .service_provider_types import service_provider_type_db
# Import header dependencies from main module
async def get_home_id(home_id: str = Header(..., alias="homeID")):
    """Dependency to extract and validate homeID header"""
    if not home_id:
        raise HTTPException(status_code=400, detail="homeID header is required")
    try:
        return int(home_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="homeID must be a valid integer")

async def get_current_user_id(current_user_id: Optional[str] = Header(None, alias="currentUserId")):
    """Dependency to extract current user ID header"""
    return current_user_id

from storage.storage_service import StorageServiceProxy
import uuid

# Add missing dependencies that are needed for some user routes
async def get_user_id(user_id: Optional[str] = Header(None, alias="userId")):
    """Dependency to extract user ID header"""
    return user_id

async def get_firebase_token(firebase_token: Optional[str] = Header(None, alias="firebaseToken")):
    """Dependency to extract Firebase token header"""
    return firebase_token

router = APIRouter(prefix="/api")

# User Profile CRUD endpoints
@router.get("/users", response_model=List[UserProfile])
async def get_all_users(home_id: int = Depends(get_home_id)):
    """Get all user profiles"""
    users = user_db.get_all_users(home_id)
    return users

@router.get("/users/service-providers", response_model=List[ServiceProviderProfile])
async def get_service_providers(
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_current_user_id)
):
    """Get all users with service provider role, ordered by most recent request interaction"""
    try:
        service_providers = user_db.get_service_providers_ordered_by_requests(
            home_id=home_id, 
            user_id=user_id
        )
        return service_providers
    except Exception as e:
        print(f"Error getting service providers: {e}")
        raise HTTPException(status_code=500, detail="Error retrieving service providers")

@router.get("/users/{user_id}", response_model=UserProfile)
async def get_user_profile(user_id: str, home_id: int = Depends(get_home_id)):
    """Get a specific user profile"""
    user = user_db.get_user_profile(user_id, home_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user

@router.post("/users/by-phone", response_model=UserProfile)
async def get_user_profile_by_phone(
    request: UserByPhoneRequest,
    home_id: int = Depends(get_home_id)
):
    """Get a user profile by phone number"""
    user = user_db.get_user_profile_by_phone(request.phone_number, home_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user

@router.post("/users", response_model=UserProfile, status_code=201)
async def create_user_profile(
    user: UserProfileCreate,
    home_id: int = Depends(get_home_id)
):
    """Create a new user profile"""
    try:
        print(f"Creating user with data: {user.model_dump()}")
        
        # Set home_id from the authenticated request
        user.home_id = home_id
        
        # Generate a temporary Firebase ID for web-created users
        import uuid
        temp_firebase_id = f"web_{uuid.uuid4()}"
        
        print(f"Generated Firebase ID: {temp_firebase_id}")
        
        new_user = user_db.create_user_profile(temp_firebase_id, user, home_id)
        if not new_user:
            print("create_user_profile returned None")
            raise HTTPException(status_code=422, detail="Failed to create user - database operation returned None")
        
        print(f"User created successfully with ID: {new_user.id}")
        return new_user
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error creating user: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=422, detail=f"Failed to create user: {str(e)}")

@router.put("/users/{user_id}", response_model=UserProfile)
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
    """Update user profile with form data"""
    try:
        print(f"Update request for user {user_id}:")
        print(f"  full_name: {full_name}")
        print(f"  phone_number: {phone_number}")
        print(f"  role: {role}")
        print(f"  birthday: {birthday}")
        print(f"  apartment_number: {apartment_number}")
        print(f"  marital_status: {marital_status}")
        print(f"  gender: {gender}")
        print(f"  religious: {religious}")
        print(f"  native_language: {native_language}")
        
        # Handle photo upload if provided
        photo_url = None
        if photo and photo.filename:
            # Get tenant name for storage
            from tenant_config import get_schema_name_by_home_id
            tenant_name = get_schema_name_by_home_id(home_id)
            if not tenant_name:
                raise HTTPException(status_code=400, detail=f"No tenant found for home_id: {home_id}")
            
            # Use the extracted photo upload function
            photo_url = await user_db.upload_user_profile_photo(user_id, photo, home_id, tenant_name)
        
        # Parse birthday if provided
        birthday_date = None
        if birthday:
            from datetime import datetime
            try:
                # Handle ISO datetime format (e.g., "1920-01-12T00:00:00.000")
                if 'T' in birthday:
                    # Remove microseconds if present and parse
                    birthday_clean = birthday.split('.')[0] if '.' in birthday else birthday
                    birthday_date = datetime.fromisoformat(birthday_clean).date()
                else:
                    # Handle simple date format (e.g., "1920-01-12")
                    birthday_date = datetime.strptime(birthday, '%Y-%m-%d').date()
            except ValueError as e:
                print(f"Birthday parsing error: {e}")
                raise HTTPException(status_code=400, detail=f"Invalid birthday format: {birthday}. Use YYYY-MM-DD or ISO format")
        
        # Create update data
        update_data = UserProfileUpdate(
            full_name=full_name,
            phone_number=phone_number,
            role=role,
            birthday=birthday_date,
            apartment_number=apartment_number,
            marital_status=marital_status,
            gender=gender,
            religious=religious,
            native_language=native_language,
            service_provider_type_id=service_provider_type_id,
            photo=photo_url
        )
        
        print(f"UserProfileUpdate object: {update_data.model_dump()}")
        
        updated_user = user_db.update_user_profile(user_id, update_data, home_id)
        if not updated_user:
            raise HTTPException(status_code=404, detail="User not found")
        return updated_user
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error updating user: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/users/{user_id}")
async def delete_user_profile(user_id: str, home_id: int = Depends(get_home_id)):
    """Delete a user profile"""
    success = user_db.delete_user_profile(user_id, home_id)
    if not success:
        raise HTTPException(status_code=404, detail="User not found")
    return {"message": "User deleted successfully"}

@router.patch("/users/{user_id}/fcm-token")
async def update_user_fcm_token(
    user_id: str,
    fcm_token: str,
    home_id: int = Depends(get_home_id)
):
    """Update user's Firebase FCM token"""
    try:
        success = user_db.update_user_fcm_token(user_id, fcm_token, home_id)
        if success:
            return {"message": "FCM token updated successfully"}
        else:
            raise HTTPException(status_code=404, detail="User not found")
    except Exception as e:
        print(f"Error updating FCM token: {e}")
        raise HTTPException(status_code=500, detail="Error updating FCM token")

# User photo endpoints
@router.post("/users/{user_id}/photo")
async def upload_user_photo(
    user_id: str,
    photo: UploadFile = File(...),
    home_id: int = Depends(get_home_id)
):
    """Upload a photo for a user"""
    try:
        # Get tenant name for storage
        from tenant_config import get_schema_name_by_home_id
        tenant_name = get_schema_name_by_home_id(home_id)
        if not tenant_name:
            raise HTTPException(status_code=400, detail=f"No tenant found for home_id: {home_id}")
        
        # Use the extracted photo upload function
        photo_url = await user_db.upload_user_profile_photo(user_id, photo, home_id, tenant_name)
        
        # Update user record with photo URL
        update_data = UserProfileUpdate(photo=photo_url)
        updated_user = user_db.update_user_profile(user_id, update_data, home_id)
        
        if not updated_user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Return the URL for the uploaded photo
        return {
            "message": "Photo uploaded successfully",
            "photo_url": photo_url
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error uploading photo: {e}")
        raise HTTPException(status_code=500, detail="Error uploading photo")

@router.get("/users/{user_id}/photo")
async def get_user_photo(user_id: str, home_id: int = Depends(get_home_id)):
    """Get user photo URL"""
    try:
        user = user_db.get_user_profile(user_id, home_id)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        if user.photo:
            # If user has a photo path, generate SAS URL
            photo_url = azure_storage_service.get_image_url(user.photo)
            return {"photo_url": photo_url}
        
        # Otherwise, assume it's a blob path and generate SAS URL
        blob_path = f"{home_id}/users/photos/{user_id}.jpg"
        photo_url = azure_storage_service.get_image_url(blob_path)
        return {"photo_url": photo_url}
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error getting photo: {e}")
        raise HTTPException(status_code=500, detail="Error retrieving photo")

# Authentication endpoints - these need special handling in tenant routing
# They should not require homeID header since that's what users get after login
# SESSION-BASED AUTHENTICATION ENDPOINTS REMOVED
# Replaced with JWT authentication in web_jwt_auth.py

# Home Index endpoint - special endpoint that doesn't require homeID header
@router.get("/users/get_user_home")
async def get_user_home(phone_number: str = Query(...)):
    """Get user's home information by phone number - used for tenant routing"""
    try:
        # Import the normalization function
        from .users import normalize_phone_number
        
        # Normalize phone number by removing leading zeros
        normalized_phone = normalize_phone_number(phone_number)
        
        home_info = user_db.get_user_home_info(normalized_phone)
        if home_info:
            return {
                "success": True,
                "home_id": home_info['home_id'],
                "home_name": home_info['home_name']
            }
        else:
            return {
                "success": False,
                "message": "User not found in any home"
            }
    except Exception as e:
        print(f"Error getting user home info: {e}")
        raise HTTPException(status_code=500, detail="Error retrieving user home information")


# ------------------------- Service Provider Types Endpoints ------------------------- #
@router.get("/service-provider-types", response_model=List[ServiceProviderType])
async def get_service_provider_types(
    home_id: int = Depends(get_home_id),
):
    """List all service provider types - public access"""
    types = service_provider_type_db.get_all_service_provider_types(home_id)
    return types


@router.get("/service-provider-types/{type_id}", response_model=ServiceProviderType)
async def get_service_provider_type(
    type_id: str,
    home_id: int = Depends(get_home_id),
):
    """Get a specific service provider type by ID"""
    provider_type = service_provider_type_db.get_service_provider_type_by_id(type_id, home_id)
    if not provider_type:
        raise HTTPException(status_code=404, detail="Service provider type not found")
    return provider_type


@router.post("/service-provider-types", response_model=ServiceProviderType, status_code=201)
async def create_service_provider_type(
    provider_type: ServiceProviderTypeCreate,
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
):
    """Create a new service provider type - manager role required"""
    # Check if current user has manager role
    from main import require_manager_role
    await require_manager_role(current_user_id, home_id)
    
    new_type = service_provider_type_db.create_service_provider_type(provider_type, home_id)
    if not new_type:
        raise HTTPException(
            status_code=400, detail="Unable to create service provider type (duplicate name?)"
        )
    return new_type


@router.put("/service-provider-types/{type_id}", response_model=ServiceProviderType)
async def update_service_provider_type(
    type_id: str,
    provider_type: ServiceProviderTypeUpdate,
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
):
    """Update a service provider type (only description) - manager role required"""
    # Check if current user has manager role
    from main import require_manager_role
    await require_manager_role(current_user_id, home_id)
    
    updated_type = service_provider_type_db.update_service_provider_type(type_id, provider_type, home_id)
    if not updated_type:
        raise HTTPException(status_code=404, detail="Service provider type not found")
    return updated_type


@router.delete("/service-provider-types/{type_id}")
async def delete_service_provider_type(
    type_id: str,
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
):
    """Delete a service provider type by ID - manager role required"""
    # Check if current user has manager role
    from main import require_manager_role
    await require_manager_role(current_user_id, home_id)
    
    success = service_provider_type_db.delete_service_provider_type(type_id, home_id)
    if not success:
        raise HTTPException(status_code=404, detail="Service provider type not found")
    return {"message": "Service provider type deleted successfully"}