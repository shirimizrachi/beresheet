"""
Script to display all automatically created tenant endpoints
Shows the transformation from /api/* to /{tenant_name}/api/*
"""

import sys
import os
from fastapi import FastAPI
from fastapi.routing import APIRoute

# Add the current directory to the path so we can import modules
sys.path.insert(0, os.path.dirname(__file__))

def show_endpoints():
    """Display all tenant endpoints that will be created"""
    print("🔍 Tenant Endpoint Transformation Analysis")
    print("=" * 60)
    
    try:
        # Import the routers
        from main import api_router, home_notification_router
        from tenant_auto_router import TenantAPIRouter
        
        print("📋 Original API Endpoints:")
        print("-" * 40)
        
        original_endpoints = []
        for route in api_router.routes:
            if isinstance(route, APIRoute):
                methods = ', '.join(route.methods)
                original_endpoints.append({
                    'path': route.path,
                    'methods': methods,
                    'name': route.name or 'unnamed'
                })
                print(f"  {methods:<10} {route.path}")
        
        print(f"\nTotal original endpoints: {len(original_endpoints)}")
        
        # Create tenant router to see transformations
        print("\n🔄 Creating Tenant API Router...")
        tenant_wrapper = TenantAPIRouter(api_router)
        
        print("\n🎯 Transformed Tenant Endpoints:")
        print("-" * 40)
        
        tenant_endpoints = []
        for route in tenant_wrapper.tenant_router.routes:
            if isinstance(route, APIRoute):
                methods = ', '.join(route.methods)
                tenant_endpoints.append({
                    'path': route.path,
                    'methods': methods,
                    'name': route.name or 'unnamed'
                })
                print(f"  {methods:<10} {route.path}")
        
        print(f"\nTotal tenant endpoints: {len(tenant_endpoints)}")
        
        # Show route summary
        summary = tenant_wrapper.get_route_summary()
        print(f"\n📊 Route Wrapping Summary:")
        print(f"  - Original routes processed: {summary['total_routes']}")
        print(f"  - Tenant routes created: {summary['tenant_router_routes']}")
        
        # Show examples with tenant names
        print(f"\n✨ Example URLs for tenant 'beresheet':")
        print("-" * 40)
        for endpoint in original_endpoints[:5]:  # Show first 5 examples
            original = endpoint['path']
            tenant_url = f"/beresheet/api{original}"
            print(f"  {endpoint['methods']:<10} {tenant_url}")
        
        if len(original_endpoints) > 5:
            print(f"  ... and {len(original_endpoints) - 5} more endpoints")
        
        print(f"\n✨ Example URLs for tenant 'demo':")
        print("-" * 40)
        for endpoint in original_endpoints[:5]:  # Show first 5 examples
            original = endpoint['path']
            tenant_url = f"/demo/api{original}"
            print(f"  {endpoint['methods']:<10} {tenant_url}")
        
        if len(original_endpoints) > 5:
            print(f"  ... and {len(original_endpoints) - 5} more endpoints")
        
        # Show notification router endpoints if they exist
        if hasattr(home_notification_router, 'routes') and home_notification_router.routes:
            print(f"\n📢 Home Notification Endpoints:")
            print("-" * 40)
            for route in home_notification_router.routes:
                if isinstance(route, APIRoute):
                    methods = ', '.join(route.methods)
                    print(f"  {methods:<10} /{'{tenant_name}'}/api{route.path}")
        
        print(f"\n🎉 Success! All endpoints automatically support tenant routing!")
        print(f"🔗 Access patterns:")
        print(f"   - Beresheet: http://localhost:8000/beresheet/api/[endpoint]")
        print(f"   - Demo: http://localhost:8000/demo/api/[endpoint]")
        print(f"   - Headers required: homeID (must match tenant)")
        
        return True
        
    except ImportError as e:
        print(f"❌ Import error: {e}")
        print("Make sure you're running this from the api_service directory")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def show_required_headers():
    """Show the header requirements for tenant endpoints"""
    print(f"\n📋 Required Headers for Tenant Endpoints:")
    print("=" * 50)
    print("For /beresheet/api/* endpoints:")
    print("  - homeID: 1")
    print("  - userId: [user_id] (optional, depends on endpoint)")
    print("  - firebaseToken: [token] (optional)")
    print()
    print("For /demo/api/* endpoints:")
    print("  - homeID: 2") 
    print("  - userId: [user_id] (optional, depends on endpoint)")
    print("  - firebaseToken: [token] (optional)")
    print()
    print("⚠️  The homeID header MUST match the tenant:")
    print("   - beresheet tenant expects homeID: 1")
    print("   - demo tenant expects homeID: 2")
    print("   - Mismatched headers will result in 400 error")

def main():
    """Main function"""
    if not show_endpoints():
        sys.exit(1)
    
    show_required_headers()
    
    print(f"\n🚀 Next steps:")
    print("1. Start the server: python main.py")
    print("2. Test endpoints: python test_multi_tenant.py")
    print("3. Access admin: http://localhost:8000/home/admin")

if __name__ == "__main__":
    main()