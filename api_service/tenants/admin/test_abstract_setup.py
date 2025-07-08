#!/usr/bin/env python3
"""
Test script for the abstract database setup and schema operations
Verifies that the factory pattern works correctly with DATABASE_ENGINE configuration
"""

import sys
import os
from pathlib import Path

# Add the parent directories to the path so we can import modules
current_dir = Path(__file__).parent
api_service_dir = current_dir.parent.parent
sys.path.insert(0, str(api_service_dir))

from residents_config import DATABASE_ENGINE
from setup_residents_database import get_database_setup
from schema_operations import get_schema_operations

def test_database_setup_factory():
    """Test that the database setup factory works correctly"""
    print(f"🔧 Testing Database Setup Factory")
    print(f"   DATABASE_ENGINE: {DATABASE_ENGINE}")
    
    try:
        setup = get_database_setup()
        print(f"   ✅ Successfully created: {type(setup).__name__}")
        
        # Test that it has the required methods
        required_methods = [
            'get_connection_config', 'create_database', 'create_schema',
            'create_user_and_permissions', 'create_home_table', 'test_user_connection',
            'display_connection_info', 'create_home_index_schema',
            'create_home_index_user_and_permissions', 'create_home_index_table',
            'test_home_index_connection', 'run_setup'
        ]
        
        for method_name in required_methods:
            if hasattr(setup, method_name):
                print(f"   ✅ Method '{method_name}' exists")
            else:
                print(f"   ❌ Method '{method_name}' missing")
                return False
        
        return True
        
    except Exception as e:
        print(f"   ❌ Error: {e}")
        return False

def test_schema_operations_factory():
    """Test that the schema operations factory works correctly"""
    print(f"\n🔧 Testing Schema Operations Factory")
    print(f"   DATABASE_ENGINE: {DATABASE_ENGINE}")
    
    try:
        ops = get_schema_operations()
        print(f"   ✅ Successfully created: {type(ops).__name__}")
        
        # Test that it has the required methods
        required_methods = ['create_schema_and_user', 'delete_schema_and_user']
        
        for method_name in required_methods:
            if hasattr(ops, method_name):
                print(f"   ✅ Method '{method_name}' exists")
            else:
                print(f"   ❌ Method '{method_name}' missing")
                return False
        
        return True
        
    except Exception as e:
        print(f"   ❌ Error: {e}")
        return False

def test_convenience_functions():
    """Test that the convenience functions work correctly"""
    print(f"\n🔧 Testing Convenience Functions")
    
    try:
        from schema_operations import create_schema_and_user, delete_schema_and_user
        print(f"   ✅ Successfully imported convenience functions")
        
        # Test that they are callable
        if callable(create_schema_and_user):
            print(f"   ✅ Function 'create_schema_and_user' is callable")
        else:
            print(f"   ❌ Function 'create_schema_and_user' is not callable")
            return False
            
        if callable(delete_schema_and_user):
            print(f"   ✅ Function 'delete_schema_and_user' is callable")
        else:
            print(f"   ❌ Function 'delete_schema_and_user' is not callable")
            return False
        
        return True
        
    except Exception as e:
        print(f"   ❌ Error: {e}")
        return False

def main():
    """Run all tests"""
    print("🚀 Testing Abstract Database Setup and Schema Operations")
    print("=" * 60)
    
    tests = [
        ("Database Setup Factory", test_database_setup_factory),
        ("Schema Operations Factory", test_schema_operations_factory), 
        ("Convenience Functions", test_convenience_functions)
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        if test_func():
            passed += 1
            print(f"✅ {test_name}: PASSED")
        else:
            print(f"❌ {test_name}: FAILED")
    
    print("\n" + "=" * 60)
    print(f"📊 Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed! The abstract factory pattern is working correctly.")
        return True
    else:
        print("❌ Some tests failed. Please check the implementation.")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)