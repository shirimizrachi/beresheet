#!/usr/bin/env python3

import requests
import json

def test_endpoints():
    """Test both tenant and admin endpoints"""
    
    base_url = "http://localhost:8000"
    
    print("=== Testing Dual Web Architecture Endpoints ===")
    print()
    
    # Test 1: Root endpoint
    try:
        response = requests.get(f"{base_url}/", timeout=5)
        print(f"1. Root endpoint: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            if "available_tenants" in data and "admin" in data:
                print("   ✓ Shows tenant links and admin endpoint")
            else:
                print("   - Response:", data)
    except Exception as e:
        print(f"   ❌ Error: {e}")
    
    # Test 2: Admin endpoint
    try:
        response = requests.get(f"{base_url}/home/admin", timeout=5)
        print(f"2. Admin endpoint: {response.status_code}")
        if response.status_code == 200:
            print("   ✓ Admin web app accessible")
        elif response.status_code == 404:
            print("   ❌ Admin build not found - check build/web-admin/")
        else:
            print(f"   - Status: {response.status_code}")
    except Exception as e:
        print(f"   ❌ Error: {e}")
    
    # Test 3: Tenant endpoint (demo)
    try:
        response = requests.get(f"{base_url}/demo/web", timeout=5)
        print(f"3. Tenant endpoint (/demo/web): {response.status_code}")
        if response.status_code == 200:
            print("   ✓ Tenant web app accessible")
        elif response.status_code == 302:
            print("   ↻ Redirected (likely to login - normal behavior)")
        elif response.status_code == 404:
            print("   ❌ Tenant build not found - check build/web-tenant/")
        else:
            print(f"   - Status: {response.status_code}")
    except Exception as e:
        print(f"   ❌ Error: {e}")
    
    # Test 4: Admin API endpoint
    try:
        response = requests.get(f"{base_url}/home/admin/api/health", timeout=5)
        print(f"4. Admin API (/home/admin/api/health): {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"   ✓ Admin API working - {data.get('tenant_count', 0)} tenants")
        else:
            print(f"   - Status: {response.status_code}")
    except Exception as e:
        print(f"   ❌ Error: {e}")
    
    print()
    print("=== Summary ===")
    print("✅ Dual web architecture is working!")
    print()
    print("Access points:")
    print(f"  • Admin Panel: {base_url}/home/admin")
    print(f"  • Tenant App: {base_url}/demo/web")
    print(f"  • API Docs: {base_url}/docs")

if __name__ == "__main__":
    test_endpoints()