#!/usr/bin/env python3
"""
Manual schema deletion script
Completely removes a tenant schema, all tables, users, and associated objects

Usage:
    python delete_schema_manual.py <schema_name>

Example:
    python delete_schema_manual.py demo
"""

import sys
import os
import logging
from pathlib import Path

# Add the parent directories to the path so we can import modules
current_dir = Path(__file__).parent
api_service_dir = current_dir.parent.parent
sys.path.insert(0, str(api_service_dir))

from residents_db_config import get_admin_connection_string, DATABASE_ENGINE
from sqlserver.schema_operations import delete_schema_and_user_sqlserver
from mysql.schema_operations import delete_schema_and_user_mysql

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def main():
    """Main function to delete a schema manually"""
    
    if len(sys.argv) != 2:
        print("❌ Error: Schema name is required")
        print("\nUsage:")
        print("    python delete_schema_manual.py <schema_name>")
        print("\nExample:")
        print("    python delete_schema_manual.py demo")
        sys.exit(1)
    
    schema_name = sys.argv[1]
    
    # Validate schema name
    if not schema_name.replace("_", "").replace("-", "").isalnum():
        print(f"❌ Error: Schema name '{schema_name}' must be alphanumeric (with optional hyphens and underscores)")
        sys.exit(1)
    
    print(f"🗑️  Starting deletion process for schema: {schema_name}")
    print("=" * 60)
    
    try:
        # Get admin database connection and engine type
        admin_connection_string = get_admin_connection_string()
        database_engine = DATABASE_ENGINE
        
        print(f"📊 Database Engine: {database_engine}")
        print(f"🔗 Admin Connection: {admin_connection_string.split('@')[1] if '@' in admin_connection_string else 'configured'}")
        
        # Confirm deletion
        confirmation = input(f"\n⚠️  Are you sure you want to PERMANENTLY DELETE schema '{schema_name}'? (yes/no): ")
        if confirmation.lower() not in ['yes', 'y']:
            print("🚫 Deletion cancelled by user")
            sys.exit(0)
        
        # Delete schema based on database engine
        if database_engine == "mysql":
            print(f"\n🔥 Deleting MySQL database '{schema_name}'...")
            result = delete_schema_and_user_mysql(schema_name, admin_connection_string)
        else:
            print(f"\n🔥 Deleting SQL Server schema '{schema_name}'...")
            result = delete_schema_and_user_sqlserver(schema_name, admin_connection_string)
        
        # Display results
        print("\n" + "=" * 60)
        print("📋 DELETION RESULTS")
        print("=" * 60)
        
        if result["status"] == "success":
            print(f"✅ Status: {result['status'].upper()}")
            print(f"📝 Message: {result['message']}")
            print(f"🗃️  Schema: {result['schema_name']}")
            print(f"📊 Tables dropped: {result['tables_dropped']}")
            
            if database_engine == "mssql":
                print(f"👤 User dropped: {'Yes' if result['user_dropped'] else 'No'}")
                print(f"🔐 Login dropped: {'Yes' if result['login_dropped'] else 'No'}")
            else:
                print(f"👤 User dropped: {'Yes' if result['user_dropped'] else 'No'}")
                if 'table_names' in result and result['table_names']:
                    print(f"📋 Tables that were dropped: {', '.join(result['table_names'])}")
            
            print(f"\n🎉 Schema '{schema_name}' has been completely deleted!")
            
        elif result["status"] == "warning":
            print(f"⚠️  Status: {result['status'].upper()}")
            print(f"📝 Message: {result['message']}")
            
        else:
            print(f"❌ Status: {result['status'].upper()}")
            print(f"📝 Message: {result['message']}")
            sys.exit(1)
            
    except ImportError as e:
        print(f"❌ Import Error: {e}")
        print("💡 Make sure you're running this script from the correct directory")
        print("   and that all required modules are available")
        sys.exit(1)
        
    except Exception as e:
        logger.error(f"Unexpected error during schema deletion: {e}")
        print(f"❌ Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()