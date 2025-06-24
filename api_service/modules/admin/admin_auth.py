"""
Admin authentication functions for JWT token management
"""

import jwt
import logging
from datetime import datetime, timedelta
from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy import text, create_engine

# Set up logging
logger = logging.getLogger(__name__)

# JWT Configuration
JWT_SECRET_KEY = "admin_secret_key_2025"  # In production, use environment variable
JWT_ALGORITHM = "HS256"
JWT_EXPIRATION_HOURS = 8

# Security
security = HTTPBearer()

def create_access_token(data: dict) -> str:
    """Create JWT access token"""
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(hours=JWT_EXPIRATION_HOURS)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)
    return encoded_jwt

def verify_token(token: str) -> dict:
    """Verify JWT token"""
    try:
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token has expired")
    except jwt.JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

def get_current_admin_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Get current authenticated admin user from token"""
    token = credentials.credentials
    payload = verify_token(token)
    return payload

async def authenticate_admin(email: str, password: str) -> dict:
    """Authenticate admin against home table"""
    try:
        from residents_db_config import get_connection_string
        engine = create_engine(get_connection_string())
        
        with engine.connect() as conn:
            # Query home table for admin user
            query = text("""
                SELECT id, name, database_name, database_type, database_schema,
                       admin_user_email, admin_user_password, created_at, updated_at
                FROM home.home
                WHERE admin_user_email = :email
            """)
            
            result = conn.execute(query, {"email": email}).fetchone()
            
            if not result:
                raise HTTPException(status_code=401, detail="Invalid credentials")
            
            # Verify password (assuming plain text for now - in production use bcrypt)
            if result.admin_user_password != password:
                raise HTTPException(status_code=401, detail="Invalid credentials")
            
            # Return user data
            return {
                "id": result.id,
                "name": result.name,
                "database_name": result.database_name,
                "database_type": result.database_type,
                "database_schema": result.database_schema,
                "admin_user_email": result.admin_user_email,
                "admin_user_password": result.admin_user_password,
                "created_at": result.created_at.isoformat(),
                "updated_at": result.updated_at.isoformat(),
            }
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Authentication error: {e}")
        raise HTTPException(status_code=500, detail="Authentication failed")