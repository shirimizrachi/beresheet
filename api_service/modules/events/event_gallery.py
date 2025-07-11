"""
Event Gallery management using SQLAlchemy
Handles all event gallery-related database operations
"""

import uuid
import os
from datetime import datetime
from typing import Optional, List, Tuple
from sqlalchemy import create_engine, Table, MetaData, Column, String, Integer, DateTime, text, func
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import SQLAlchemyError
from .models import EventGallery, EventGalleryCreate, EventGalleryUpdate
from tenant_config import get_schema_name_by_home_id
from database_utils import get_schema_engine, get_engine_for_home
from storage.storage_service import StorageServiceProxy
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
                              created_by: str = None, user_role: str = None) -> List[EventGallery]:
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
            print(f"DEBUG: Starting gallery upload for event {event_id}, home {home_id}")
            print(f"DEBUG: Number of files to upload: {len(image_files)}")
            print(f"DEBUG: created_by: {created_by}, user_role: {user_role}")
            
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                print(f"DEBUG: No schema found for home ID {home_id}")
                raise ValueError(f"No schema found for home ID {home_id}")
            print(f"DEBUG: Using schema: {schema_name}")

            # Get the event_gallery table
            gallery_table = self.get_event_gallery_table(schema_name)
            if gallery_table is None:
                print(f"DEBUG: Event gallery table not found in schema {schema_name}")
                raise ValueError(f"Event gallery table not found in schema {schema_name}")
            print(f"DEBUG: Gallery table found: {gallery_table}")

            # Initialize storage service
            storage_service = StorageServiceProxy()
            print(f"DEBUG: Storage service initialized: {type(storage_service.service)}")
            # Use schema_name as tenant_name for storage operations
            tenant_name = schema_name
            print(f"DEBUG: Using tenant_name: {tenant_name}")
            created_galleries = []
            
            for i, image_file in enumerate(image_files):
                try:
                    print(f"Processing image {i+1}/{len(image_files)}: {image_file.get('filename', 'unknown')}")
                    print(f"Content type: {image_file.get('content_type')}")
                    print(f"Content size: {len(image_file.get('content', b''))}")
                    
                    # Generate unique photo_id
                    photo_id = str(uuid.uuid4())
                    current_time = datetime.now()
                    
                    # Get file extension
                    file_extension = os.path.splitext(image_file['filename'])[1].lower()
                    if not file_extension:
                        file_extension = '.jpg'
                    print(f"File extension: {file_extension}")
                    
                    # Upload main image to Storage
                    main_image_name = f"{photo_id}{file_extension}"
                    file_path = f"gallery/{event_id}/"
                    print(f"Uploading main image: {main_image_name} to path: {file_path}")
                    
                    success, main_url = storage_service.upload_image(
                        home_id=home_id,
                        file_name=main_image_name,
                        file_path=file_path,
                        image_data=image_file['content'],
                        content_type=image_file.get('content_type'),
                        tenant_name=tenant_name
                    )
                    
                    print(f"Main image upload result: success={success}, url={main_url}")
                    if not success:
                        print(f"Failed to upload main image {main_image_name}: {main_url}")
                        continue
                    
                    # Create and upload thumbnail
                    print(f"Creating thumbnail for {main_image_name}")
                    thumbnail_data = self.create_thumbnail(image_file['content'])
                    thumbnail_name = f"{photo_id}{file_extension}"
                    thumbnail_path = f"gallery/{event_id}/thumbnails/"
                    print(f"Uploading thumbnail: {thumbnail_name} to path: {thumbnail_path}")
                    
                    success_thumb, thumbnail_url = storage_service.upload_image(
                        home_id=home_id,
                        file_name=thumbnail_name,
                        file_path=thumbnail_path,
                        image_data=thumbnail_data,
                        content_type='image/jpeg',
                        tenant_name=tenant_name
                    )
                    
                    print(f"Thumbnail upload result: success={success_thumb}, url={thumbnail_url}")
                    if not success_thumb:
                        print(f"Failed to upload thumbnail {thumbnail_name}: {thumbnail_url}")
                        thumbnail_url = main_url  # Use main image as fallback
                    
                    # Determine status based on user role
                    status = "public" if user_role in ["manager", "staff"] else "private"
                    
                    # Prepare gallery data
                    gallery_data = {
                        'photo_id': photo_id,
                        'event_id': event_id,
                        'photo': main_url,
                        'thumbnail_url': thumbnail_url,
                        'status': status,
                        'created_by': created_by,
                        'created_at': current_time,
                        'updated_at': current_time
                    }
                    
                    # Insert into database
                    print(f"DEBUG: Inserting gallery data into database for photo_id: {photo_id}")
                    print(f"DEBUG: Gallery data: {gallery_data}")
                    
                    schema_engine = get_schema_engine(schema_name)
                    if not schema_engine:
                        print(f"DEBUG: No schema engine found for schema {schema_name}")
                        raise ValueError(f"No schema engine found for schema {schema_name}")
                    
                    with schema_engine.connect() as conn:
                        result = conn.execute(gallery_table.insert().values(**gallery_data))
                        conn.commit()
                        print(f"DEBUG: Database insert successful for photo_id: {photo_id}")
                    
                    # Create EventGallery object
                    gallery_obj = EventGallery(
                        photo_id=photo_id,
                        event_id=event_id,
                        photo=main_url,
                        thumbnail_url=thumbnail_url,
                        status=status,
                        created_by=created_by,
                        created_at=current_time,
                        updated_at=current_time
                    )
                    created_galleries.append(gallery_obj)
                    print(f"DEBUG: Created gallery object for photo_id: {photo_id}")
                    
                except Exception as e:
                    print(f"DEBUG: Error uploading image {image_file.get('filename', 'unknown')}: {e}")
                    import traceback
                    traceback.print_exc()
                    continue
            
            print(f"DEBUG: Returning {len(created_galleries)} created galleries")
            return created_galleries
            
        except Exception as e:
            print(f"DEBUG: Error uploading gallery images: {e}")
            import traceback
            traceback.print_exc()
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
                        status=getattr(result, 'status', 'private'),  # Default to private if not found
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
                        status=getattr(result, 'status', 'private'),  # Default to private if not found
                        created_by=result.created_by,
                        created_at=result.created_at,
                        updated_at=result.updated_at
                    )
                return None

        except Exception as e:
            print(f"Error getting gallery photo {photo_id}: {e}")
            return None

    def approve_gallery_photo(self, photo_id: str, home_id: int) -> bool:
        """Approve a gallery photo by changing its status from private to public"""
        try:
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return False

            # Get the event_gallery table
            gallery_table = self.get_event_gallery_table(schema_name)
            if gallery_table is None:
                return False

            # Update status to public
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                return False
            with schema_engine.connect() as conn:
                result = conn.execute(
                    gallery_table.update()
                    .where(gallery_table.c.photo_id == photo_id)
                    .values(status='public', updated_at=func.now())
                )
                conn.commit()
                
                return result.rowcount > 0

        except Exception as e:
            print(f"Error approving gallery photo {photo_id}: {e}")
            return False

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
                    # Try to delete from Storage (optional cleanup)
                    try:
                        storage_service = StorageServiceProxy()
                        
                        if photo.photo:
                            storage_service.delete_image(photo.photo)
                        if photo.thumbnail_url:
                            storage_service.delete_image(photo.thumbnail_url)
                    except Exception as e:
                        print(f"Warning: Failed to delete storage files: {e}")
                    
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