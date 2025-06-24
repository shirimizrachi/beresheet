from fastapi import APIRouter, HTTPException, Depends, Header
from datetime import datetime, timedelta
import jwt
import bcrypt
from typing import Optional
import os
from pydantic import BaseModel
from users import user_db

# Web JWT Router - completely separate from admin JWT
web_jwt_router = APIRouter(prefix="/api/web-auth", tags=["Web JWT Authentication"])

# JWT Configuration - separate from admin JWT
WEB_JWT_SECRET_KEY = os.getenv("WEB_JWT_SECRET_KEY", "web-jwt-secret-key-change-in-production")
WEB_JWT_ALGORITHM = "HS256"
WEB_JWT_ACCESS_TOKEN_EXPIRE_MINUTES = 60  # 1 hour
WEB_JWT_REFRESH_TOKEN_EXPIRE_DAYS = 30  # 30 days

class WebJwtCredentials(BaseModel):
    phoneNumber: str
    password: str
    homeId: int

class WebJwtUser(BaseModel):
    id: str
    phoneNumber: str
    fullName: str
    role: str
    homeId: int
    homeName: Optional[str] = None
    photo: Optional[str] = None
    apartmentNumber: Optional[str] = None
    createdAt: datetime
    updatedAt: datetime

class WebJwtSession(BaseModel):
    token: str
    refreshToken: str
    user: WebJwtUser
    expiresAt: datetime
    refreshExpiresAt: datetime
    createdAt: datetime

class WebJwtLoginResponse(BaseModel):
    success: bool
    message: str
    session: Optional[WebJwtSession] = None
    error: Optional[str] = None

class WebJwtValidateResponse(BaseModel):
    valid: bool
    message: str
    user: Optional[WebJwtUser] = None

class WebJwtRefreshRequest(BaseModel):
    refresh_token: str

class WebJwtRefreshResponse(BaseModel):
    success: bool
    token: str
    refresh_token: str
    expires_at: str
    refresh_expires_at: str
    message: str

def create_web_jwt_token(user_data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create a web JWT token"""
    to_encode = user_data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=WEB_JWT_ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire, "type": "access", "iss": "web"})
    encoded_jwt = jwt.encode(to_encode, WEB_JWT_SECRET_KEY, algorithm=WEB_JWT_ALGORITHM)
    return encoded_jwt

def create_web_jwt_refresh_token(user_data: dict) -> str:
    """Create a web JWT refresh token"""
    to_encode = user_data.copy()
    expire = datetime.utcnow() + timedelta(days=WEB_JWT_REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode.update({"exp": expire, "type": "refresh", "iss": "web"})
    encoded_jwt = jwt.encode(to_encode, WEB_JWT_SECRET_KEY, algorithm=WEB_JWT_ALGORITHM)
    return encoded_jwt

def verify_web_jwt_token(token: str) -> Optional[dict]:
    """Verify and decode a web JWT token"""
    try:
        payload = jwt.decode(token, WEB_JWT_SECRET_KEY, algorithms=[WEB_JWT_ALGORITHM])
        # Ensure this is a web token
        if payload.get("iss") != "web":
            return None
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.JWTError:
        return None

def get_web_jwt_user_from_token(token: str = Header(..., alias="Authorization")) -> dict:
    """Dependency to extract user from JWT token"""
    if not token.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization header format")
    
    token = token.split(" ")[1]
    payload = verify_web_jwt_token(token)
    if payload is None:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    
    return payload

@web_jwt_router.post("/login")
async def web_jwt_login(credentials: WebJwtCredentials):
    """Web JWT Login endpoint"""
    try:
        print(f"Web JWT login attempt for phone: {credentials.phoneNumber}, homeId: {credentials.homeId}")
        
        # Authenticate user using existing user_db
        user = user_db.authenticate_user(credentials.phoneNumber, credentials.password, credentials.homeId)
        if not user:
            print("Web JWT login failed: Invalid credentials")
            return {
                "success": False,
                "message": "Invalid phone number or password",
                "error": "invalid_credentials"
            }
        
        print(f"Web JWT login successful for user: {user.full_name}")
        
        # Get home name from tenant config
        from tenant_config import get_all_homes
        homeName = None
        for home in get_all_homes():
            if home['id'] == credentials.homeId:
                homeName = home['name']
                break
        
        # Create JWT tokens
        user_data = {
            "user_id": user.id,
            "phone_number": user.phone_number,
            "full_name": user.full_name,
            "role": user.role,
            "home_id": user.home_id,
            "home_name": homeName,
        }
        
        # Create access token (1 hour)
        access_token_expires = timedelta(minutes=WEB_JWT_ACCESS_TOKEN_EXPIRE_MINUTES)
        access_token = create_web_jwt_token(user_data, access_token_expires)
        
        # Create refresh token (30 days)
        refresh_token = create_web_jwt_refresh_token(user_data)
        
        # Calculate expiration times (use local time like admin system)
        expires_at = datetime.now() + access_token_expires
        refresh_expires_at = datetime.now() + timedelta(days=WEB_JWT_REFRESH_TOKEN_EXPIRE_DAYS)
        
        # Create user object for response
        jwt_user = WebJwtUser(
            id=user.id,
            phoneNumber=user.phone_number,
            fullName=user.full_name,
            role=user.role,
            homeId=user.home_id,
            homeName=homeName,
            photo=user.photo,
            apartmentNumber=user.apartment_number,
            createdAt=user.created_at or datetime.now(),
            updatedAt=user.updated_at or datetime.now(),
        )
        
        # Create session object
        session = WebJwtSession(
            token=access_token,
            refreshToken=refresh_token,
            user=jwt_user,
            expiresAt=expires_at,
            refreshExpiresAt=refresh_expires_at,
            createdAt=datetime.now(),
        )
        
        # Create response with JWT session data (match admin format)
        response_data = {
            "success": True,
            "message": "Login successful",
            "session": {
                "token": session.token,
                "refreshToken": session.refreshToken,
                "user": {
                    "id": session.user.id,
                    "phoneNumber": session.user.phoneNumber,
                    "fullName": session.user.fullName,
                    "role": session.user.role,
                    "homeId": session.user.homeId,
                    "homeName": session.user.homeName,
                    "photo": session.user.photo,
                    "apartmentNumber": session.user.apartmentNumber,
                    "createdAt": session.user.createdAt.isoformat(),
                    "updatedAt": session.user.updatedAt.isoformat(),
                },
                "expiresAt": session.expiresAt.isoformat(),
                "refreshExpiresAt": session.refreshExpiresAt.isoformat(),
                "createdAt": session.createdAt.isoformat(),
            }
        }
        
        # Create response with JWT cookie for web browsers
        from fastapi.responses import JSONResponse
        response = JSONResponse(content=response_data)
        
        # Set JWT cookie for tenant routing compatibility
        response.set_cookie(
            key="web_jwt_token",
            value=access_token,
            max_age=WEB_JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            httponly=True,  # Prevent JavaScript access for security
            secure=False,   # Set to True in production with HTTPS
            samesite="lax"
        )
        
        # Set home info cookie for tenant routing
        response.set_cookie(
            key="tenant_info",
            value=f"{homeName}:{credentials.homeId}" if homeName else f"home_{credentials.homeId}:{credentials.homeId}",
            max_age=86400,  # 24 hours
            httponly=False,  # Allow JavaScript access
            secure=False,   # Set to True in production with HTTPS
            samesite="lax"
        )
        
        return response
        
    except Exception as e:
        print(f"Error during web JWT login: {e}")
        return WebJwtLoginResponse(
            success=False,
            message=f"Login failed: {str(e)}",
            error="server_error"
        )

@web_jwt_router.post("/validate", response_model=WebJwtValidateResponse)
async def web_jwt_validate(current_user: dict = Depends(get_web_jwt_user_from_token)):
    """Validate web JWT token"""
    try:
        print(f"Web JWT token validation for user: {current_user.get('user_id')}")
        
        # Get user from database to ensure they still exist
        user = user_db.get_user_profile(current_user["user_id"], current_user["home_id"])
        if not user:
            print("Web JWT validation failed: User not found")
            return WebJwtValidateResponse(
                valid=False,
                message="User not found"
            )
        
        # Create user object for response
        jwt_user = WebJwtUser(
            id=user.id,
            phoneNumber=user.phone_number,
            fullName=user.full_name,
            role=user.role,
            homeId=user.home_id,
            homeName=current_user.get("home_name"),
            photo=user.photo,
            apartmentNumber=user.apartment_number,
            createdAt=user.created_at or datetime.now(),
            updatedAt=user.updated_at or datetime.now(),
        )
        
        print("Web JWT token validation successful")
        return WebJwtValidateResponse(
            valid=True,
            message="Token is valid",
            user=jwt_user
        )
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error during web JWT validation: {e}")
        return WebJwtValidateResponse(
            valid=False,
            message=f"Validation failed: {str(e)}"
        )

@web_jwt_router.post("/refresh", response_model=WebJwtRefreshResponse)
async def web_jwt_refresh(refresh_request: WebJwtRefreshRequest, current_user: dict = Depends(get_web_jwt_user_from_token)):
    """Refresh web JWT token"""
    try:
        print(f"Web JWT token refresh for user: {current_user.get('user_id')}")
        
        # Verify refresh token
        refresh_payload = verify_web_jwt_token(refresh_request.refresh_token)
        if not refresh_payload or refresh_payload.get("type") != "refresh":
            raise HTTPException(status_code=401, detail="Invalid refresh token")
        
        # Ensure refresh token belongs to the same user
        if refresh_payload.get("user_id") != current_user.get("user_id"):
            raise HTTPException(status_code=401, detail="Refresh token does not match user")
        
        # Get fresh user data
        user = user_db.get_user_profile(current_user["user_id"], current_user["home_id"])
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Create new tokens
        user_data = {
            "user_id": user.id,
            "phone_number": user.phone_number,
            "full_name": user.full_name,
            "role": user.role,
            "home_id": user.home_id,
            "home_name": current_user.get("home_name"),
        }
        
        # Create new access token (1 hour)
        access_token_expires = timedelta(minutes=WEB_JWT_ACCESS_TOKEN_EXPIRE_MINUTES)
        new_access_token = create_web_jwt_token(user_data, access_token_expires)
        
        # Create new refresh token (30 days)
        new_refresh_token = create_web_jwt_refresh_token(user_data)
        
        # Calculate new expiration times (use local time like admin system)
        expires_at = datetime.now() + access_token_expires
        refresh_expires_at = datetime.now() + timedelta(days=WEB_JWT_REFRESH_TOKEN_EXPIRE_DAYS)
        
        print("Web JWT token refresh successful")
        return WebJwtRefreshResponse(
            success=True,
            token=new_access_token,
            refresh_token=new_refresh_token,
            expires_at=expires_at.isoformat(),
            refresh_expires_at=refresh_expires_at.isoformat(),
            message="Tokens refreshed successfully"
        )
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error during web JWT refresh: {e}")
        raise HTTPException(status_code=500, detail=f"Token refresh failed: {str(e)}")

@web_jwt_router.post("/logout")
async def web_jwt_logout(current_user: dict = Depends(get_web_jwt_user_from_token)):
    """Web JWT Logout endpoint"""
    try:
        print(f"Web JWT logout for user: {current_user.get('user_id')}")
        
        # In a production environment, you might want to maintain a blacklist of invalidated tokens
        # For now, we'll just return success as the client will delete the token
        
        print("Web JWT logout successful")
        return {
            "success": True,
            "message": "Logout successful"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error during web JWT logout: {e}")
        return {
            "success": False,
            "message": f"Logout failed: {str(e)}"
        }

@web_jwt_router.get("/me", response_model=WebJwtUser)
async def web_jwt_get_current_user(current_user: dict = Depends(get_web_jwt_user_from_token)):
    """Get current user information from JWT token"""
    try:
        print(f"Web JWT get current user: {current_user.get('user_id')}")
        
        # Get fresh user data from database
        user = user_db.get_user_profile(current_user["user_id"], current_user["home_id"])
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Create user object for response
        jwt_user = WebJwtUser(
            id=user.id,
            phoneNumber=user.phone_number,
            fullName=user.full_name,
            role=user.role,
            homeId=user.home_id,
            homeName=current_user.get("home_name"),
            photo=user.photo,
            apartmentNumber=user.apartment_number,
            createdAt=user.created_at or datetime.now(),
            updatedAt=user.updated_at or datetime.now(),
        )
        
        return jwt_user
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error getting current web JWT user: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get user: {str(e)}")