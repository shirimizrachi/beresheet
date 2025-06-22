#!/usr/bin/env python3

import os
import sys

def check_build_directories():
    """Check if the dual build directories exist and contain expected files"""
    
    print("=== Checking Dual Build Status ===")
    print()
    
    tenant_build = "build/web-tenant"
    admin_build = "build/web-admin"
    
    # Check tenant build
    print("1. Tenant Build (build/web-tenant):")
    if os.path.exists(tenant_build):
        print("   ✓ Directory exists")
        
        index_path = os.path.join(tenant_build, "index.html")
        if os.path.exists(index_path):
            print("   ✓ index.html found")
        else:
            print("   ❌ index.html missing")
            
        flutter_js = os.path.join(tenant_build, "flutter.js")
        if os.path.exists(flutter_js):
            print("   ✓ flutter.js found")
        else:
            print("   ❌ flutter.js missing")
            
        # List all files
        files = []
        for root, dirs, filenames in os.walk(tenant_build):
            for filename in filenames:
                files.append(filename)
        print(f"   - Total files: {len(files)}")
        
    else:
        print("   ❌ Directory does not exist")
        print("   → Run: flutter build web --target lib/main_web.dart --output build/web-tenant")
    
    print()
    
    # Check admin build  
    print("2. Admin Build (build/web-admin):")
    if os.path.exists(admin_build):
        print("   ✓ Directory exists")
        
        index_path = os.path.join(admin_build, "index.html")
        if os.path.exists(index_path):
            print("   ✓ index.html found")
        else:
            print("   ❌ index.html missing")
            
        flutter_js = os.path.join(admin_build, "flutter.js")
        if os.path.exists(flutter_js):
            print("   ✓ flutter.js found")
        else:
            print("   ❌ flutter.js missing")
            
        # List all files
        files = []
        for root, dirs, filenames in os.walk(admin_build):
            for filename in filenames:
                files.append(filename)
        print(f"   - Total files: {len(files)}")
        
    else:
        print("   ❌ Directory does not exist")
        print("   → Run: flutter build web --target lib/main_admin.dart --output build/web-admin")
    
    print()
    
    # Check if both builds exist
    both_exist = os.path.exists(tenant_build) and os.path.exists(admin_build)
    
    if both_exist:
        print("✅ Both builds are ready!")
        print()
        print("Next steps:")
        print("1. Restart your server (Ctrl+C and restart)")
        print("2. Test tenant app: http://localhost:8000/demo/web")
        print("3. Test admin app: http://localhost:8000/home/admin")
    else:
        print("❌ Missing builds!")
        print()
        print("To create both builds, run:")
        print("  Windows: build_dual_web.bat")
        print("  Linux/Mac: ./build_dual_web.sh")

if __name__ == "__main__":
    check_build_directories()