#!/usr/bin/env python3

import requests
import re

def debug_login_page():
    """Debug the login page to see what's being served"""
    
    base_url = "http://localhost:8000"
    
    print("=== Debugging Login Page ===")
    print()
    
    # Test login page
    try:
        response = requests.get(f"{base_url}/demo/login", timeout=5)
        print(f"Login page status: {response.status_code}")
        
        if response.status_code == 200:
            content = response.text
            print(f"Content length: {len(content)} characters")
            
            # Check if it's HTML
            if content.strip().startswith("<!DOCTYPE html"):
                print("✓ Valid HTML response")
                
                # Check for base href
                base_match = re.search(r'<base href="([^"]*)"', content)
                if base_match:
                    base_href = base_match.group(1)
                    print(f"✓ Base href found: {base_href}")
                else:
                    print("❌ No base href found")
                
                # Check for Flutter scripts
                if "flutter.js" in content:
                    print("✓ flutter.js referenced")
                else:
                    print("❌ flutter.js not found")
                
                if "flutter_bootstrap.js" in content:
                    print("✓ flutter_bootstrap.js referenced") 
                else:
                    print("❌ flutter_bootstrap.js not found")
                
                # Check for manifest
                if "manifest.json" in content:
                    print("✓ manifest.json referenced")
                else:
                    print("❌ manifest.json not found")
                    
            elif content.strip() == "":
                print("❌ Empty response - this is the problem!")
                print("Possible causes:")
                print("  - Base href causing Flutter to not load")
                print("  - Missing assets")
                print("  - Build issue")
            else:
                print("❌ Not valid HTML")
                print(f"First 200 chars: {content[:200]}")
        
        print()
        
        # Test assets that should be available
        assets_to_test = [
            "/demo/login/flutter.js",
            "/demo/login/flutter_bootstrap.js", 
            "/demo/login/manifest.json",
            "/demo/login/favicon.png"
        ]
        
        print("Testing assets:")
        for asset in assets_to_test:
            try:
                asset_response = requests.get(f"{base_url}{asset}", timeout=5)
                status = "✓" if asset_response.status_code == 200 else "❌"
                print(f"  {status} {asset}: {asset_response.status_code}")
            except Exception as e:
                print(f"  ❌ {asset}: Error - {e}")
        
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    debug_login_page()