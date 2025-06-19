"""
Profile photo upload script for users
Uploads profile photos from demo_data/users-profile to Azure Storage
Usage: python create_users_profile_photo.py <schema_name>
"""

import sys
import os
from pathlib import Path
from sqlalchemy import create_engine, text

# Add the parent directory to the path to import from api_service
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

from api_service.azure_storage_service import azure_storage_service


def upload_users_profile_photos(schema_name: str):
    """
    Upload profile photos for users from demo_data/users-profile directory
    
    Args:
        schema_name: Name of the schema where the users table exists
    """
    
    # Connection string for the home database (using Windows Authentication)
    connection_string = "mssql+pyodbc://localhost\\SQLEXPRESS/home?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes&Trusted_Connection=yes"
    
    # Get the directory where this script is located
    script_dir = Path(__file__).parent
    photos_dir = script_dir / "demo_data" / "users-profile"
    
    if not photos_dir.exists():
        print(f"Error: Photos directory does not exist: {photos_dir}")
        return False
    
    try:
        # Create SQLAlchemy engine
        engine = create_engine(connection_string)
        
        with engine.connect() as conn:
            # Get all photo files
            photo_files = list(photos_dir.glob("*.jpg")) + list(photos_dir.glob("*.jpeg")) + list(photos_dir.glob("*.png"))
            
            if not photo_files:
                print("No photo files found in demo_data/users-profile directory")
                return False
            
            print(f"Found {len(photo_files)} photo files")
            
            success_count = 0
            failed_count = 0
            
            for photo_file in photo_files:
                # Extract user_id from filename (remove extension)
                user_id = photo_file.stem
                
                try:
                    # Check if user exists in database
                    check_user_sql = text(f"""
                        SELECT COUNT(*) as count FROM [{schema_name}].[users] WHERE id = :user_id
                    """)
                    result = conn.execute(check_user_sql, {"user_id": user_id}).fetchone()
                    
                    if result.count == 0:
                        print(f"Warning: User '{user_id}' not found in database, skipping photo: {photo_file.name}")
                        failed_count += 1
                        continue
                    
                    # Read the photo file
                    with open(photo_file, 'rb') as f:
                        image_data = f.read()
                    
                    # Determine content type
                    extension = photo_file.suffix.lower()
                    if extension in ['.jpg', '.jpeg']:
                        content_type = 'image/jpeg'
                    elif extension == '.png':
                        content_type = 'image/png'
                    else:
                        content_type = 'image/jpeg'  # Default
                    
                    # Upload to Azure Storage using home_id = 1 (matching the user data)
                    success, result_message = azure_storage_service.upload_user_photo(
                        home_id=1,
                        user_id=user_id,
                        image_data=image_data,
                        original_filename=photo_file.name,
                        content_type=content_type
                    )
                    
                    if success:
                        # Update user's photo URL in database
                        update_user_sql = text(f"""
                            UPDATE [{schema_name}].[users]
                            SET photo = :photo_url, updated_at = GETDATE()
                            WHERE id = :user_id
                        """)
                        conn.execute(update_user_sql, {
                            "photo_url": result_message,
                            "user_id": user_id
                        })
                        conn.commit()
                        
                        print(f"✓ Successfully uploaded photo for user '{user_id}': {photo_file.name}")
                        success_count += 1
                    else:
                        print(f"✗ Failed to upload photo for user '{user_id}': {result_message}")
                        failed_count += 1
                        
                except Exception as e:
                    print(f"✗ Error processing photo for user '{user_id}': {e}")
                    failed_count += 1
            
            print(f"\nProfile photo upload completed:")
            print(f"  Successful uploads: {success_count}")
            print(f"  Failed uploads: {failed_count}")
            print(f"  Total processed: {success_count + failed_count}")
            
            return success_count > 0
            
    except Exception as e:
        print(f"Error connecting to database or uploading photos: {e}")
        return False


def main():
    """Main function to handle command line arguments"""
    if len(sys.argv) != 2:
        print("Usage: python create_users_profile_photo.py <schema_name>")
        print("Example: python create_users_profile_photo.py beresheet")
        sys.exit(1)
    
    schema_name = sys.argv[1]
    
    if not schema_name.isalnum():
        print("Error: Schema name must be alphanumeric")
        sys.exit(1)
    
    print(f"Starting profile photo upload for schema '{schema_name}'...")
    
    success = upload_users_profile_photos(schema_name)
    if not success:
        sys.exit(1)
    
    print("Profile photo upload process completed successfully!")


if __name__ == "__main__":
    main()