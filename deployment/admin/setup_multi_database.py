"""
Multi-tenant setup script
Runs all database setup scripts in the correct order
"""

import sys
import subprocess
import os

def run_script(script_name, description):
    """Run a Python script and handle errors"""
    print(f"\n{'='*60}")
    print(f"🚀 {description}")
    print(f"{'='*60}")
    
    try:
        # Change to the deployment directory
        script_path = os.path.join(os.path.dirname(__file__), script_name)
        
        if not os.path.exists(script_path):
            print(f"❌ Script not found: {script_path}")
            return False
        
        # Run the script
        result = subprocess.run([sys.executable, script_path], 
                              capture_output=True, text=True, cwd=os.path.dirname(__file__))
        
        if result.returncode == 0:
            print("✅ SUCCESS")
            if result.stdout:
                print("Output:")
                print(result.stdout)
            return True
        else:
            print("❌ FAILED")
            if result.stderr:
                print("Error:")
                print(result.stderr)
            if result.stdout:
                print("Output:")
                print(result.stdout)
            return False
            
    except Exception as e:
        print(f"❌ Exception: {e}")
        return False

def main():
    """Main setup function"""
    print("🏠 Multi-Tenant Database Setup")
    print("This script will set up the multi-tenant architecture database")
    print()
    
    # Confirm before proceeding
    response = input("Do you want to proceed? (y/N): ").strip().lower()
    if response != 'y':
        print("Setup cancelled.")
        return
    
    setup_steps = [
        ("create_admin_database.py", "Creating admin database for tenant management"),
        ("create_tenant_table.py", "Creating tenant configuration table"),
        ("init_tenant_data.py", "Initializing default tenant data (beresheet and demo)"),
    ]
    
    success_count = 0
    total_steps = len(setup_steps)
    
    for script, description in setup_steps:
        if run_script(script, description):
            success_count += 1
        else:
            print(f"\n❌ Setup failed at step: {description}")
            print("Please fix the error and run the setup again.")
            return
    
    print(f"\n{'='*60}")
    print(f"🎉 MULTI-TENANT SETUP COMPLETE")
    print(f"{'='*60}")
    print(f"✅ {success_count}/{total_steps} steps completed successfully")
    print()
    print("📋 What was created:")
    print("   • Admin database: home_admin")
    print("   • Admin schema: home")
    print("   • Tenant configuration table: home.home")
    print("   • Demo schema in home database: demo")
    print("   • Default tenants: beresheet, demo")
    print()
    print("🚀 Next steps:")
    print("   1. Start the API server:")
    print("      cd api_service")
    print("      python main.py")
    print()
    print("   2. Access the admin interface:")
    print("      http://localhost:8000/home/admin")
    print()
    print("   3. Access tenant endpoints:")
    print("      http://localhost:8000/beresheet/web")
    print("      http://localhost:8000/beresheet/api")
    print("      http://localhost:8000/demo/web")
    print("      http://localhost:8000/demo/api")
    print()
    print("   4. View API documentation:")
    print("      http://localhost:8000/docs")
    print()
    print("📖 For more information, see MULTI_TENANT_ARCHITECTURE_PLAN.md")

if __name__ == "__main__":
    main()