"""
Test script for home_index functionality
"""

import sys
import os

# Add the current directory to the path so we can import our modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from home_index import home_index_db

def test_home_index_connection():
    """Test home_index database connection"""
    print("Testing home_index database connection...")
    try:
        success = home_index_db.test_connection()
        if success:
            print("✅ Home index connection test passed")
        else:
            print("❌ Home index connection test failed")
        return success
    except Exception as e:
        print(f"❌ Home index connection test failed with error: {e}")
        return False

def test_home_index_operations():
    """Test home_index CRUD operations"""
    print("\nTesting home_index CRUD operations...")
    
    test_phone = "+972501234567"
    test_home_id = 1
    test_home_name = "Test Home"
    
    try:
        # Test create
        print("Testing create operation...")
        success = home_index_db.create_home_entry(test_phone, test_home_id, test_home_name)
        if success:
            print("✅ Create operation passed")
        else:
            print("❌ Create operation failed")
            return False
        
        # Test read
        print("Testing read operation...")
        home_info = home_index_db.get_home_by_phone(test_phone)
        if home_info and home_info['home_id'] == test_home_id:
            print("✅ Read operation passed")
            print(f"   Retrieved: {home_info}")
        else:
            print("❌ Read operation failed")
            return False
        
        # Test update
        print("Testing update operation...")
        new_home_name = "Updated Test Home"
        success = home_index_db.update_home_entry(test_phone, home_name=new_home_name)
        if success:
            print("✅ Update operation passed")
            
            # Verify update
            updated_info = home_index_db.get_home_by_phone(test_phone)
            if updated_info and updated_info['home_name'] == new_home_name:
                print("✅ Update verification passed")
            else:
                print("❌ Update verification failed")
                return False
        else:
            print("❌ Update operation failed")
            return False
        
        # Test delete (cleanup)
        print("Testing delete operation (cleanup)...")
        success = home_index_db.delete_home_entry(test_phone)
        if success:
            print("✅ Delete operation passed")
        else:
            print("❌ Delete operation failed")
            return False
        
        # Verify delete
        deleted_info = home_index_db.get_home_by_phone(test_phone)
        if deleted_info is None:
            print("✅ Delete verification passed")
        else:
            print("❌ Delete verification failed - entry still exists")
            return False
        
        return True
        
    except Exception as e:
        print(f"❌ CRUD operations test failed with error: {e}")
        return False

def test_get_user_home_endpoint():
    """Test the get_user_home endpoint logic"""
    print("\nTesting get_user_home endpoint logic...")
    
    test_phone = "+972501234567"
    test_home_id = 1
    test_home_name = "Test Home"
    
    try:
        # Create test data
        print("Creating test data...")
        success = home_index_db.create_home_entry(test_phone, test_home_id, test_home_name)
        if not success:
            print("❌ Failed to create test data")
            return False
        
        # Import the user database to test the integration
        from users import user_db
        
        # Test get_user_home_info method
        print("Testing get_user_home_info method...")
        home_info = user_db.get_user_home_info(test_phone)
        if home_info and home_info['home_id'] == test_home_id:
            print("✅ get_user_home_info method passed")
            print(f"   Retrieved: {home_info}")
        else:
            print("❌ get_user_home_info method failed")
            print(f"   Expected home_id: {test_home_id}, got: {home_info}")
            return False
        
        # Test with non-existent phone
        print("Testing with non-existent phone...")
        non_existent_info = user_db.get_user_home_info("+972999999999")
        if non_existent_info is None:
            print("✅ Non-existent phone test passed")
        else:
            print("❌ Non-existent phone test failed - should return None")
            return False
        
        # Cleanup
        print("Cleaning up test data...")
        home_index_db.delete_home_entry(test_phone)
        
        return True
        
    except Exception as e:
        print(f"❌ get_user_home endpoint test failed with error: {e}")
        # Cleanup on error
        try:
            home_index_db.delete_home_entry(test_phone)
        except:
            pass
        return False

def main():
    """Run all tests"""
    print("🧪 Home Index Functionality Tests")
    print("=" * 50)
    
    tests = [
        ("Connection Test", test_home_index_connection),
        ("CRUD Operations Test", test_home_index_operations),
        ("Get User Home Endpoint Test", test_get_user_home_endpoint)
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        print(f"\n🚀 Running {test_name}...")
        try:
            if test_func():
                passed += 1
                print(f"✅ {test_name} PASSED")
            else:
                print(f"❌ {test_name} FAILED")
        except Exception as e:
            print(f"❌ {test_name} FAILED with exception: {e}")
    
    print(f"\n📊 Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed! Home index functionality is working correctly.")
        return True
    else:
        print("🚨 Some tests failed. Please check the errors above.")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)