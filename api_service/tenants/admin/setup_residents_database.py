"""
Abstract base class for database setup operations
Factory pattern that determines implementation based on DATABASE_ENGINE
"""

import sys
import os
from abc import ABC, abstractmethod
from typing import Dict, Any, Optional

# Add the api_service directory to sys.path
script_dir = os.path.dirname(os.path.abspath(__file__))  # deployment/admin
deployment_dir = os.path.dirname(script_dir)            # deployment
api_service_dir = os.path.dirname(deployment_dir)       # api_service
sys.path.insert(0, api_service_dir)

from dotenv import load_dotenv
load_dotenv()

import os
DATABASE_ENGINE = os.getenv("DATABASE_ENGINE")

class DatabaseSetupBase(ABC):
    """Abstract base class for database setup operations"""
    
    def __init__(self):
        """Initialize with configuration from residents_config.py"""
        from residents_config import (
            DATABASE_NAME, SCHEMA_NAME, USER_NAME, USER_PASSWORD,
            HOME_INDEX_SCHEMA_NAME, HOME_INDEX_USER_NAME, HOME_INDEX_USER_PASSWORD
        )
        
        self.database_name = DATABASE_NAME
        self.schema_name = SCHEMA_NAME
        self.user_name = USER_NAME
        self.user_password = USER_PASSWORD
        
        # Home Index configuration
        self.home_index_schema_name = HOME_INDEX_SCHEMA_NAME
        self.home_index_user_name = HOME_INDEX_USER_NAME
        self.home_index_user_password = HOME_INDEX_USER_PASSWORD
    
    @abstractmethod
    def get_connection_config(self) -> Dict[str, Any]:
        """Get database connection configuration"""
        pass
    
    @abstractmethod
    def create_database(self, config: Dict[str, Any]) -> bool:
        """Create the residents database"""
        pass
    
    @abstractmethod
    def create_schema(self, config: Dict[str, Any]) -> bool:
        """Create the home schema"""
        pass
    
    @abstractmethod
    def create_user_and_permissions(self, config: Dict[str, Any]) -> bool:
        """Create user and grant permissions on schema"""
        pass
    
    @abstractmethod
    def create_home_table(self, config: Dict[str, Any]) -> bool:
        """Create the home table for managing all homes"""
        pass
    
    @abstractmethod
    def test_user_connection(self, config: Dict[str, Any]) -> bool:
        """Test connection with the created user"""
        pass
    
    @abstractmethod
    def display_connection_info(self, config: Dict[str, Any]) -> bool:
        """Display connection information for manual configuration"""
        pass
    
    @abstractmethod
    def create_home_index_schema(self, config: Dict[str, Any]) -> bool:
        """Create the home_index schema"""
        pass
    
    @abstractmethod
    def create_home_index_user_and_permissions(self, config: Dict[str, Any]) -> bool:
        """Create home_index user and grant permissions"""
        pass
    
    @abstractmethod
    def create_home_index_table(self, config: Dict[str, Any]) -> bool:
        """Create the home_index table"""
        pass
    
    @abstractmethod
    def test_home_index_connection(self, config: Dict[str, Any]) -> bool:
        """Test connection with the home_index user"""
        pass
    
    def create_shared_storage_bucket(self) -> bool:
        """Create shared storage bucket for Cloudflare (if storage type is cloudflare)"""
        try:
            from residents_config import get_storage_provider, get_cloudflare_shared_bucket_name
            storage_type = get_storage_provider()
            
            if storage_type == 'cloudflare':
                bucket_name = get_cloudflare_shared_bucket_name()
                print(f"Creating shared Cloudflare R2 bucket '{bucket_name}'...")
                from tenants.schema.resources.create_shared_residents_bucket import create_shared_residents_bucket
                success = create_shared_residents_bucket()
                if success:
                    print(f"✅ Shared Cloudflare R2 bucket '{bucket_name}' created successfully")
                    return True
                else:
                    print(f"❌ Failed to create shared Cloudflare R2 bucket '{bucket_name}'")
                    return False
            else:
                print(f"Storage type is '{storage_type}' - skipping shared bucket creation")
                return True
                
        except Exception as e:
            print(f"❌ Error creating shared storage bucket: {e}")
            return False

    def run_setup(self) -> bool:
        """Run the complete setup process"""
        # Get configuration
        config = self.get_connection_config()
        
        # Check storage type for display
        storage_type = "unknown"
        try:
            from residents_config import get_storage_provider
            storage_type = get_storage_provider()
        except:
            pass
        
        print(f"\n📋 Setup Summary:")
        print(f"   Database Type: {config.get('type', 'unknown')}")
        print(f"   Server: {config.get('server', 'unknown')}")
        print(f"   Database: {self.database_name}")
        print(f"   Schema: {self.schema_name}")
        print(f"   User: {self.user_name}")
        print(f"   Storage Type: {storage_type}")
        
        # Confirm before proceeding
        response = input("\nDo you want to proceed with this configuration? (y/N): ").strip().lower()
        if response != 'y':
            print("Setup cancelled.")
            return False
        
        # Run setup steps
        steps = [
            ("Creating database", lambda: self.create_database(config)),
            ("Creating schema", lambda: self.create_schema(config)),
            ("Creating user and permissions", lambda: self.create_user_and_permissions(config)),
            ("Creating home table", lambda: self.create_home_table(config)),
            ("Creating home_index schema", lambda: self.create_home_index_schema(config)),
            ("Creating home_index user and permissions", lambda: self.create_home_index_user_and_permissions(config)),
            ("Creating home_index table", lambda: self.create_home_index_table(config)),
            ("Creating shared storage bucket", lambda: self.create_shared_storage_bucket()),
            ("Testing user connection", lambda: self.test_user_connection(config)),
            ("Testing home_index connection", lambda: self.test_home_index_connection(config)),
            ("Displaying connection information", lambda: self.display_connection_info(config))
        ]
        
        success_count = 0
        for step_name, step_func in steps:
            print(f"\n{'='*60}")
            print(f"🚀 {step_name}")
            print(f"{'='*60}")
            
            if step_func():
                success_count += 1
            else:
                print(f"\n❌ Setup failed at step: {step_name}")
                print("Please fix the error and run the setup again.")
                return False
        
        print(f"\n{'='*60}")
        print(f"🎉 RESIDENTS DATABASE SETUP COMPLETE")
        print(f"{'='*60}")
        print(f"✅ {success_count}/{len(steps)} steps completed successfully")
        print()
        print("📋 What was created:")
        print(f"   • Database: {self.database_name}")
        print(f"   • Schema: {self.schema_name}")
        print(f"   • User: {self.user_name} (password: {self.user_password})")
        print(f"   • Table: {self.schema_name}.home")
        print(f"   • Home Index Schema: {self.home_index_schema_name}")
        print(f"   • Home Index User: {self.home_index_user_name} (password: {self.home_index_user_password})")
        print(f"   • Table: {self.home_index_schema_name}.home_index")
        
        # Add storage bucket info if Cloudflare
        try:
            from residents_config import get_storage_provider, get_cloudflare_shared_bucket_name
            storage_type = get_storage_provider()
            if storage_type == 'cloudflare':
                bucket_name = get_cloudflare_shared_bucket_name()
                print(f"   • Shared Storage Bucket: {bucket_name} (Cloudflare R2)")
        except:
            pass
            
        print()
        print("🚀 Next steps:")
        print("   1. Configure your API service using the connection information above")
        print("   2. Test the database connection with: python test_residents_database.py")
        print("   3. Start your application")
        
        return True


def get_database_setup() -> DatabaseSetupBase:
    """Factory function to get the appropriate database setup implementation"""
    if DATABASE_ENGINE == "oracle":
        from tenants.admin.oracle.setup_residents_database import OracleDatabaseSetup
        return OracleDatabaseSetup()
    elif DATABASE_ENGINE == "sqlserver":
        from tenants.admin.sqlserver.setup_residents_database import SqlServerDatabaseSetup
        return SqlServerDatabaseSetup()
    else:
        raise ValueError(f"Unsupported DATABASE_ENGINE: {DATABASE_ENGINE}")


def main():
    """Main setup function"""
    try:
        setup = get_database_setup()
        setup.run_setup()
    except Exception as e:
        print(f"❌ Setup failed: {e}")
        return False


if __name__ == "__main__":
    main()