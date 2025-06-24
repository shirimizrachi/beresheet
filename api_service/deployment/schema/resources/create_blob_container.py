"""
Create Azure Blob Storage container for tenant
This script creates a blob container with the naming convention: [tenant-name]-images
"""

import os
import sys
from azure.storage.blob import BlobServiceClient
from azure.core.exceptions import ResourceExistsError
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def create_blob_container(tenant_name: str) -> bool:
    """
    Create a blob container for the specified tenant
    
    Args:
        tenant_name: Name of the tenant (used for container naming)
    
    Returns:
        bool: True if container was created or already exists, False if error occurred
    """
    try:
        # Get connection string from environment
        connection_string = os.getenv('AZURE_STORAGE_CONNECTION_STRING')
        if not connection_string:
            print("ERROR: AZURE_STORAGE_CONNECTION_STRING environment variable is required")
            return False
        
        # Generate container name
        container_name = f"{tenant_name}-images"
        
        print(f"Creating blob container: {container_name}")
        
        # Initialize blob service client
        blob_service_client = BlobServiceClient.from_connection_string(connection_string)
        
        # Create the container
        container_client = blob_service_client.get_container_client(container_name)
        container_client.create_container()
        
        print(f"✓ Successfully created container: {container_name}")
        return True
        
    except ResourceExistsError:
        print(f"✓ Container already exists: {container_name}")
        return True
        
    except Exception as e:
        print(f"✗ Error creating container '{container_name}': {str(e)}")
        return False

def main():
    """Main function to handle command line execution"""
    if len(sys.argv) != 2:
        print("Usage: python create_blob_container.py <tenant_name>")
        print("Example: python create_blob_container.py demo")
        sys.exit(1)
    
    tenant_name = sys.argv[1]
    
    # Validate tenant name (basic validation)
    if not tenant_name or not tenant_name.replace('-', '').replace('_', '').isalnum():
        print("ERROR: Tenant name must contain only alphanumeric characters, hyphens, and underscores")
        sys.exit(1)
    
    success = create_blob_container(tenant_name)
    
    if not success:
        sys.exit(1)
    
    print(f"Blob container setup completed for tenant: {tenant_name}")

if __name__ == "__main__":
    main()