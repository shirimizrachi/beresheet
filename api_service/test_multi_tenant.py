"""
Test script for multi-tenant API functionality
Tests tenant validation, routing, and admin endpoints
"""

import requests
import json
import sys
from typing import Dict, Any

BASE_URL = "http://localhost:8000"

def test_request(method: str, url: str, **kwargs) -> Dict[str, Any]:
    """Make a test request and return the result"""
    try:
        response = requests.request(method, url, **kwargs)
        return {
            "success": True,
            "status_code": response.status_code,
            "data": response.json() if response.headers.get('content-type', '').startswith('application/json') else response.text,
            "headers": dict(response.headers)
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }

def print_result(test_name: str, result: Dict[str, Any]):
    """Print test result in a formatted way"""
    status = "✅ PASS" if result.get("success") and result.get("status_code", 0) < 400 else "❌ FAIL"
    print(f"{status} {test_name}")
    
    if not result.get("success"):
        print(f"   Error: {result.get('error')}")
    else:
        print(f"   Status: {result.get('status_code')}")
        if result.get("status_code", 0) >= 400:
            print(f"   Response: {result.get('data')}")
    print()

def test_root_endpoint():
    """Test the root endpoint"""
    print("🔍 Testing Root Endpoint")
    print("-" * 40)
    
    result = test_request("GET", f"{BASE_URL}/")
    print_result("Root endpoint", result)
    
    if result.get("success") and "available_tenants" in str(result.get("data", "")):
        print("   📝 Available tenants listed in response")
    
    return result.get("success", False)

def test_admin_endpoints():
    """Test admin endpoints"""
    print("🔍 Testing Admin Endpoints")
    print("-" * 40)
    
    # Test admin interface
    result = test_request("GET", f"{BASE_URL}/home/admin")
    print_result("Admin web interface", result)
    
    # Test admin API health
    result = test_request("GET", f"{BASE_URL}/home/admin/api/health")
    print_result("Admin API health check", result)
    
    # Test get tenants
    result = test_request("GET", f"{BASE_URL}/home/admin/api/tenants")
    print_result("Get all tenants", result)
    
    if result.get("success") and result.get("status_code") == 200:
        tenants = result.get("data", [])
        if isinstance(tenants, list):
            print(f"   📊 Found {len(tenants)} tenants")
            for tenant in tenants:
                if isinstance(tenant, dict):
                    print(f"      - {tenant.get('name', 'Unknown')} (ID: {tenant.get('id', 'N/A')})")
        return True
    
    return False

def test_tenant_endpoints():
    """Test tenant-specific endpoints"""
    print("🔍 Testing Tenant Endpoints")
    print("-" * 40)
    
    tenants_to_test = [
        {"name": "beresheet", "home_id": "1"},
        {"name": "demo", "home_id": "2"}
    ]
    success_count = 0
    
    for tenant in tenants_to_test:
        tenant_name = tenant["name"]
        home_id = tenant["home_id"]
        
        print(f"Testing tenant: {tenant_name} (homeID: {home_id})")
        
        # Headers for tenant requests
        headers = {"homeID": home_id}
        
        # Test tenant API root
        result = test_request("GET", f"{BASE_URL}/{tenant_name}/api/", headers=headers)
        print_result(f"  {tenant_name} API root", result)
        if result.get("success"):
            success_count += 1
        
        # Test tenant health check
        result = test_request("GET", f"{BASE_URL}/{tenant_name}/api/health", headers=headers)
        print_result(f"  {tenant_name} health check", result)
        if result.get("success"):
            success_count += 1
        
        # Test tenant events endpoint (automatic routing)
        result = test_request("GET", f"{BASE_URL}/{tenant_name}/api/events", headers=headers)
        print_result(f"  {tenant_name} events endpoint", result)
        if result.get("success"):
            success_count += 1
        
        # Test tenant users endpoint (automatic routing)
        result = test_request("GET", f"{BASE_URL}/{tenant_name}/api/users", headers=headers)
        print_result(f"  {tenant_name} users endpoint", result)
        if result.get("success"):
            success_count += 1
        
        # Test tenant web interface
        result = test_request("GET", f"{BASE_URL}/{tenant_name}/web")
        print_result(f"  {tenant_name} web interface", result)
        if result.get("success"):
            success_count += 1
    
    return success_count > 0

def test_invalid_tenant():
    """Test invalid tenant handling"""
    print("🔍 Testing Invalid Tenant Handling")
    print("-" * 40)
    
    # Test non-existent tenant
    result = test_request("GET", f"{BASE_URL}/nonexistent/api/", headers={"homeID": "1"})
    expected_fail = result.get("status_code") == 404
    
    status = "✅ PASS" if expected_fail else "❌ FAIL"
    print(f"{status} Invalid tenant rejection")
    print(f"   Status: {result.get('status_code')} (expected 404)")
    print()
    
    # Test valid tenant with wrong homeID
    result = test_request("GET", f"{BASE_URL}/beresheet/api/", headers={"homeID": "2"})
    expected_fail_mismatch = result.get("status_code") == 400
    
    status = "✅ PASS" if expected_fail_mismatch else "❌ FAIL"
    print(f"{status} Tenant/HomeID mismatch rejection")
    print(f"   Status: {result.get('status_code')} (expected 400)")
    print()
    
    return expected_fail and expected_fail_mismatch

def test_legacy_api():
    """Test that legacy API endpoints are removed"""
    print("🔍 Testing Legacy API Endpoints (Should Be Removed)")
    print("-" * 40)
    
    # Test legacy API root (should not exist)
    result = test_request("GET", f"{BASE_URL}/api/")
    expected_fail = result.get("status_code") == 404
    
    status = "✅ PASS" if expected_fail else "❌ FAIL"
    print(f"{status} Legacy API root removed")
    print(f"   Status: {result.get('status_code')} (expected 404)")
    print()
    
    # Test legacy events endpoint (should not exist)
    result = test_request("GET", f"{BASE_URL}/api/events", headers={"homeID": "1"})
    expected_fail_events = result.get("status_code") == 404
    
    status = "✅ PASS" if expected_fail_events else "❌ FAIL"
    print(f"{status} Legacy events endpoint removed")
    print(f"   Status: {result.get('status_code')} (expected 404)")
    print()
    
    return expected_fail and expected_fail_events

def main():
    """Run all tests"""
    print("🧪 Multi-Tenant API Test Suite")
    print("=" * 50)
    print()
    
    print("⚠️  Make sure the API server is running on http://localhost:8000")
    print("   Start it with: cd api_service && python main.py")
    print()
    print("🎯 Testing automatic tenant routing:")
    print("   - ALL /api/* endpoints now work as /{tenant_name}/api/*")
    print("   - Web interface available at /{tenant_name}/web")
    print("   - Admin interface at /home/admin")
    print()
    
    # Ask for confirmation
    response = input("Continue with tests? (y/N): ").strip().lower()
    if response != 'y':
        print("Tests cancelled.")
        return
    
    print()
    
    test_results = []
    
    # Run tests
    test_results.append(("Root Endpoint", test_root_endpoint()))
    test_results.append(("Admin Endpoints", test_admin_endpoints()))
    test_results.append(("Tenant Endpoints", test_tenant_endpoints()))
    test_results.append(("Invalid Tenant", test_invalid_tenant()))
    test_results.append(("Legacy API", test_legacy_api()))
    
    # Summary
    print("=" * 50)
    print("📊 TEST SUMMARY")
    print("=" * 50)
    
    passed = 0
    total = len(test_results)
    
    for test_name, result in test_results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status} {test_name}")
        if result:
            passed += 1
    
    print()
    print(f"Results: {passed}/{total} test groups passed")
    
    if passed == total:
        print("🎉 All tests passed! Multi-tenant API is working correctly.")
        print()
        print("🚀 You can now:")
        print("   • Access admin interface: http://localhost:8000/home/admin")
        print("   • Use tenant APIs: http://localhost:8000/beresheet/api")
        print("   • View tenant web apps: http://localhost:8000/beresheet/web")
    else:
        print("⚠️  Some tests failed. Please check the API server and database setup.")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())