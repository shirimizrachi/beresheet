"""
Chat database operations
"""

import uuid
from datetime import datetime
from typing import List, Optional
from .models import ChatMessage, ChatMessageCreate
from modules.users import user_db

class ChatDatabase:
    def __init__(self):
        self.messages = {}  # In-memory storage for chat messages by home_id
    
    def add_message(self, message_create: ChatMessageCreate, user_id: str, home_id: int) -> Optional[ChatMessage]:
        """Add a new chat message"""
        try:
            # Get user profile for display name
            user_profile = user_db.get_user_profile(user_id, home_id)
            user_name = user_profile.display_name if user_profile else "Unknown User"
            
            # Generate unique message ID
            message_id = str(uuid.uuid4())
            
            # Create chat message
            chat_message = ChatMessage(
                message_id=message_id,
                user_id=user_id,
                user_name=user_name,
                message=message_create.message,
                media_type=message_create.media_type,
                media_url=message_create.media_url,
                timestamp=datetime.now(),
                home_id=home_id
            )
            
            # Store message
            if home_id not in self.messages:
                self.messages[home_id] = []
            
            self.messages[home_id].append(chat_message)
            
            # Keep only latest 100 messages per home
            if len(self.messages[home_id]) > 100:
                self.messages[home_id] = self.messages[home_id][-100:]
            
            return chat_message
            
        except Exception as e:
            print(f"Error adding chat message: {e}")
            return None
    
    def get_messages(self, home_id: int, limit: int = 20, offset: int = 0) -> List[ChatMessage]:
        """Get chat messages for a home"""
        if home_id not in self.messages:
            return []
        
        # Sort messages by timestamp (newest first) and apply pagination
        sorted_messages = sorted(self.messages[home_id], key=lambda x: x.timestamp, reverse=True)
        
        # Apply offset and limit
        start_idx = offset
        end_idx = offset + limit
        
        return sorted_messages[start_idx:end_idx]
    
    def get_recent_messages(self, home_id: int, limit: int = 5) -> List[ChatMessage]:
        """Get the most recent messages for display in footer"""
        return self.get_messages(home_id, limit=limit, offset=0)
    
    def get_message_count(self, home_id: int) -> int:
        """Get total message count for a home"""
        if home_id not in self.messages:
            return 0
        return len(self.messages[home_id])
    
    def add_media_message(self, message_text: str, media_type: str, media_url: str, user_id: str, home_id: int) -> Optional[ChatMessage]:
        """Add a message with media attachment"""
        message_create = ChatMessageCreate(
            message=message_text,
            media_type=media_type,
            media_url=media_url
        )
        return self.add_message(message_create, user_id, home_id)

# Global instance
chat_db = ChatDatabase()