"""
Event Gallery management using SQLAlchemy
Handles all event gallery-related database operations
"""

import uuid
import os
from datetime import datetime
from typing import Optional, List, Tuple
from sqlalchemy import create_engine, Table, MetaData, Column, String, Integer, DateTime, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import SQLAlchemyError
from models import EventGallery, EventGalleryCreate, EventGalleryUpdate
from tenant_config import get_schema_name_by_home_id
from database_utils import get_schema_engine, get_engine_for_home
from azure_storage_service import azure_storage_service
from PIL import Image
import io

class EventGalleryDatabase:
    def __init__(self):
        # Note: This class now uses tenant-specific connections through database_utils
        # No default engine is created as all operations use schema-specific engines
        self.metadata = MetaData()

    def get_event_gallery_table(self, schema_name: str):
        """Get the event_gallery table for a specific schema using schema-specific connection"""
        try:
            # Get schema-specific engine
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                print(f"No engine found for schema {schema_name}")
                return None
            
            # Reflect the event_gallery table from the specified schema
            metadata = MetaData(schema=schema_name)
            metadata.reflect(bind=schema_engine, only=['event_gallery'])
            return metadata.tables[f'{schema_name}.event_gallery']
        except Exception as e:
            print(f"Error reflecting event_gallery table for schema {schema_name}: {e}")
            return None

    def create_thumbnail(self, image_data: bytes, max_size: Tuple[int, int] = (300, 300)) -> bytes:
        """Create a thumbnail from image data"""
        try:
            # Open the image
            with Image.open(io.BytesIO(image_data)) as img:
                # Convert to RGB if necessary (for PNG with transparency)
                if img.mode in ('RGBA', 'LA', 'P'):
                    background = Image.new('RGB', img.size, (255, 255, 255))
                    if img.mode == 'P':
                        img = img.convert('RGBA')
                    background.paste(img, mask=img.split()[-1] if img.mode == 'RGBA' else None)
                    img = background
                
                # Create thumbnail
                img.thumbnail(max_size, Image.Resampling.LANCZOS)
                
                # Save to bytes
                output = io.BytesIO()
                img.save(output, format='JPEG', quality=85, optimize=True)
                return output.getvalue()
                
        except Exception as e:
            print(f"Error creating thumbnail: {e}")
            return image_data  # Return original if thumbnail creation fails

    def upload_gallery_images(self, event_id: str, home_id: int, image_files: List[dict], 
                             created_by: str = None) -> List[EventGallery]:
        """
        Upload multiple images to event gallery with thumbnails
        
        Args:
            event_id: The event ID
            home_id: The home ID for organizing files
            image_files: List of dicts with 'filename', 'content', 'content_type'
            created_by: User who uploaded the images
        
        Returns:
            List of created EventGallery objects
        """
        try:
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                raise ValueError(f"No schema found for home ID {home_id}")

            # Get the event_gallery table
            gallery_table = self.get_event_gallery_table(schema_name)
            if gallery_table is None:
                raise ValueError(f"Event gallery table not found in schema {schema_name}")

            created_galleries = []
            
            for image_file in image_files:
                try:
                    # Generate unique photo_id
                    photo_id = str(uuid.uuid4())
                    current_time = datetime.now()
                    
                    # Get file extension
                    file_extension = os.path.splitext(image_file['filename'])[1].lower()
                    if not file_extension:
                        file_extension = '.jpg'
                    
                    # Upload main image to Azure Storage
                    main_image_name = f"{photo_id}{file_extension}"
                    success, main_url = azure_storage_service.upload_image(
                        home_id=home_id,
                        file_name=main_image_name,
                        file_path=f"gallery/{event_id}/",
                        image_data=image_file['content'],
                        content_type=image_file.get('content_type')
                    )
                    
                    if not success:
                        print(f"Failed to upload main image {main_image_name}: {main_url}")
                        continue
                    
                    # Create and upload thumbnail
                    thumbnail_data = self.create_thumbnail(image_file['content'])
                    thumbnail_name = f"{photo_id}{file_extension}"
                    success_thumb, thumbnail_url = azure_storage_service.upload_image(
                        home_id=home_id,
                        file_name=thumbnail_name,
                        file_path=f"gallery/{event_id}/thumbnails/",
                        image_data=thumbnail_data,
                        content_type='image/jpeg'
                    )
                    
                    if not success_thumb:
                        print(f"Failed to upload thumbnail {thumbnail_name}: {thumbnail_url}")
                        thumbnail_url = main_url  # Use main image as fallback
                    
                    # Prepare gallery data
                    gallery_data = {
                        'photo_id': photo_id,
                        'event_id': event_id,
                        'photo': main_url,
                        'thumbnail_url': thumbnail_url,
                        'created_by': created_by,
                        'created_at': current_time,
                        'updated_at': current_time
                    }
                    
                    # Insert into database
                    schema_engine = get_schema_engine(schema_name)
                    if not schema_engine:
                        return None
                    with schema_engine.connect() as conn:
                        result = conn.execute(gallery_table.insert().values(**gallery_data))
                        conn.commit()
                    
                    # Create EventGallery object
                    gallery_obj = EventGallery(
                        photo_id=photo_id,
                        event_id=event_id,
                        photo=main_url,
                        thumbnail_url=thumbnail_url,
                        created_by=created_by,
                        created_at=current_time,
                        updated_at=current_time
                    )
                    created_galleries.append(gallery_obj)
                    
                except Exception as e:
                    print(f"Error uploading image {image_file.get('filename', 'unknown')}: {e}")
                    continue
            
            return created_galleries
            
        except Exception as e:
            print(f"Error uploading gallery images: {e}")
            raise

    def get_event_gallery(self, event_id: str, home_id: int) -> List[EventGallery]:
        """Get all gallery images for an event"""
        try:
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return []

            # Get the event_gallery table
            gallery_table = self.get_event_gallery_table(schema_name)
            if gallery_table is None:
                return []

            galleries = []
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                return []
            with schema_engine.connect() as conn:
                results = conn.execute(
                    gallery_table.select()
                    .where(gallery_table.c.event_id == event_id)
                    .order_by(gallery_table.c.created_at.desc())
                ).fetchall()
                
                for result in results:
                    galleries.append(EventGallery(
                        photo_id=result.photo_id,
                        event_id=result.event_id,
                        photo=result.photo,
                        thumbnail_url=result.thumbnail_url,
                        created_by=result.created_by,
                        created_at=result.created_at,
                        updated_at=result.updated_at
                    ))
            return galleries

        except Exception as e:
            print(f"Error getting event gallery for event {event_id}: {e}")
            return []

    def get_gallery_photo(self, photo_id: str, home_id: int) -> Optional[EventGallery]:
        """Get a specific gallery photo by ID"""
        try:
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return None

            # Get the event_gallery table
            gallery_table = self.get_event_gallery_table(schema_name)
            if gallery_table is None:
                return None

            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                return None
            with schema_engine.connect() as conn:
                result = conn.execute(
                    gallery_table.select().where(gallery_table.c.photo_id == photo_id)
                ).fetchone()

                if result:
                    return EventGallery(
                        photo_id=result.photo_id,
                        event_id=result.event_id,
                        photo=result.photo,
                        thumbnail_url=result.thumbnail_url,
                        created_by=result.created_by,
                        created_at=result.created_at,
                        updated_at=result.updated_at
                    )
                return None

        except Exception as e:
            print(f"Error getting gallery photo {photo_id}: {e}")
            return None

    def delete_gallery_photo(self, photo_id: str, home_id: int) -> bool:
        """Delete a gallery photo"""
        try:
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return False

            # Get the event_gallery table
            gallery_table = self.get_event_gallery_table(schema_name)
            if gallery_table is None:
                return False

            # Get photo details first for Azure cleanup
            photo = self.get_gallery_photo(photo_id, home_id)
            if not photo:
                return False

            # Delete from database
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                return False
            with schema_engine.connect() as conn:
                result = conn.execute(
                    gallery_table.delete().where(gallery_table.c.photo_id == photo_id)
                )
                conn.commit()
                
                if result.rowcount > 0:
                    # Try to delete from Azure Storage (optional cleanup)
                    try:
                        # Extract blob path from URL
                        main_blob_path = self._extract_blob_path_from_url(photo.photo)
                        thumbnail_blob_path = self._extract_blob_path_from_url(photo.thumbnail_url)
                        
                        if main_blob_path:
                            azure_storage_service.delete_image(main_blob_path)
                        if thumbnail_blob_path:
                            azure_storage_service.delete_image(thumbnail_blob_path)
                    except Exception as e:
                        print(f"Warning: Failed to delete Azure Storage files: {e}")
                    
                    return True
                return False

        except Exception as e:
            print(f"Error deleting gallery photo {photo_id}: {e}")
            return False

    def delete_event_gallery(self, event_id: str, home_id: int) -> bool:
        """Delete all gallery photos for an event"""
        try:
            # Get all photos first
            photos = self.get_event_gallery(event_id, home_id)
            
            # Delete each photo
            for photo in photos:
                self.delete_gallery_photo(photo.photo_id, home_id)
            
            return True

        except Exception as e:
            print(f"Error deleting event gallery for event {event_id}: {e}")
            return False

    def _extract_blob_path_from_url(self, url: str) -> Optional[str]:
        """Extract blob path from Azure Storage URL"""
        try:
            if not url:
                return None
            
            # Remove query parameters (SAS token)
            base_url = url.split('?')[0]
            
            # Extract path after container name
            parts = base_url.split('/')
            if len(parts) >= 2:
                # Find container name index and get everything after it
                container_index = -1
                for i, part in enumerate(parts):
                    if 'beresheet-images' in part or part == azure_storage_service.container_name:
                        container_index = i
                        break
                
                if container_index >= 0 and container_index + 1 < len(parts):
                    return '/'.join(parts[container_index + 1:])
            
            return None
        except Exception:
            return None

# Create global instance
event_gallery_db = EventGalleryDatabase()