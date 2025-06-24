"""
Admin-related Pydantic models for authentication and API responses
"""

from pydantic import BaseModel
from typing import Optional

# Pydantic models for authentication
class AdminCredentials(BaseModel):
    email: str
    password: str

class TokenResponse(BaseModel):
    token: str
    user: dict
    expires_at: str
    created_at: str

class TokenValidation(BaseModel):
    token: str
    refresh: Optional[bool] = False