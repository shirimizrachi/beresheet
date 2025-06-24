import requests
import webbrowser
import time

def test_server():
    base_url = "http://localhost:8000"
    
    print("Testing Beresheet Community App Server...")
    print("=" * 50)
    
    try:
        # Test API health
        print("1. Testing API health...")
        response = requests.get(f"{base_url}/api/health")
        if response.status_code == 200:
            print("✅ API is healthy")
            print(f"   Response: {response.json()}")
        else:
            print("❌ API health check failed")
            return
        
        # Test tenant events endpoint (using beresheet as default tenant)
        print("\n2. Testing tenant events endpoint...")
        tenant_name = "beresheet"  # Default tenant for testing
        response = requests.get(f"{base_url}/{tenant_name}/api/events", headers={"homeID": "1"})
        if response.status_code == 200:
            events = response.json()
            print(f"✅ Events endpoint working - Found {len(events)} events")
            print(f"   Tested tenant: {tenant_name}")
        else:
            print("❌ Events endpoint failed")
            print(f"   Attempted URL: {base_url}/{tenant_name}/api/events")
            return
        
        # Test web app
        print("\n3. Testing web app...")
        response = requests.get(f"{base_url}/web")
        if response.status_code == 200:
            print("✅ Web app is accessible")
        else:
            print("❌ Web app not accessible")
            return
        
        print("\n" + "=" * 50)
        print("🎉 All tests passed!")
        print(f"🌐 Web App: {base_url}/web")
        print(f"📡 API: {base_url}/api")
        print(f"📚 API Docs: {base_url}/docs")
        print("=" * 50)
        
        # Ask if user wants to open browser
        open_browser = input("\nOpen web browser? (y/n): ").lower().strip()
        if open_browser == 'y':
            webbrowser.open(f"{base_url}/web")
        
    except requests.exceptions.ConnectionError:
        print("❌ Cannot connect to server. Make sure it's running on localhost:8000")
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    test_server()