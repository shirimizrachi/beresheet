"""
Cleanup script to remove unused files from the old tenant router implementation
"""

import os
import sys

def remove_file_if_exists(file_path):
    """Remove a file if it exists"""
    try:
        if os.path.exists(file_path):
            os.remove(file_path)
            print(f"✅ Removed: {file_path}")
            return True
        else:
            print(f"ℹ️  File not found: {file_path}")
            return False
    except Exception as e:
        print(f"❌ Error removing {file_path}: {e}")
        return False

def main():
    """Main cleanup function"""
    print("🧹 Cleaning up unused tenant router files...")
    print("=" * 50)
    
    # Files to remove
    files_to_remove = [
        "api_service/multi_tenant_router.py",
        "api_service/multi_tenant_router.py.bak",
    ]
    
    removed_count = 0
    for file_path in files_to_remove:
        if remove_file_if_exists(file_path):
            removed_count += 1
    
    print("\n" + "=" * 50)
    print(f"🎉 Cleanup complete! Removed {removed_count} unused files.")
    print("\n📋 Remaining active files:")
    print("  ✅ api_service/tenant_auto_router.py - Complete tenant routing system")
    print("  ✅ api_service/tenant_config.py - Tenant database operations")
    print("  ✅ api_service/admin.py - Admin interface")
    print("  ✅ api_service/main.py - Clean application setup")
    print("\n🚀 The automatic tenant routing system is now clean and ready to use!")

if __name__ == "__main__":
    main()