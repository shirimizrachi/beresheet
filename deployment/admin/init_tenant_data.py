"""
Script to initialize tenant data in the admin database
Inserts the initial tenant configurations for beresheet and demo
"""

import sys
import pyodbc
from sqlalchemy import create_engine, text

def insert_initial_tenants():
    """
    Insert the initial tenant configurations
    """
    
    # Connection string for the admin database
    connection_string = "mssql+pyodbc://localhost\\SQLEXPRESS/home?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes&Trusted_Connection=yes"
    
    try:
        # Create SQLAlchemy engine
        engine = create_engine(connection_string)
        
        with engine.connect() as conn:
            # Check if tenants already exist
            check_tenants_sql = text("""
                SELECT name FROM [home].[home] WHERE name IN ('beresheet', 'demo')
            """)
            
            existing_tenants = conn.execute(check_tenants_sql).fetchall()
            existing_names = [row[0] for row in existing_tenants]
            
            # Insert beresheet tenant if it doesn't exist
            if 'beresheet' not in existing_names:
                insert_beresheet_sql = text("""
                    INSERT INTO [home].[home] (
                        [name], 
                        [database_name], 
                        [database_type], 
                        [database_schema], 
                        [admin_user_email], 
                        [admin_user_password]
                    ) VALUES (
                        :name,
                        :database_name,
                        :database_type,
                        :database_schema,
                        :admin_user_email,
                        :admin_user_password
                    )
                """)
                
                conn.execute(insert_beresheet_sql, {
                    "name": "beresheet",
                    "database_name": "home",
                    "database_type": "mssql",
                    "database_schema": "beresheet",
                    "admin_user_email": "ranmizrachi@gmail.com",
                    "admin_user_password": "123456"
                })
                
                print("Inserted 'beresheet' tenant configuration.")
            else:
                print("Tenant 'beresheet' already exists.")
            
            # Insert demo tenant if it doesn't exist
            if 'demo' not in existing_names:
                insert_demo_sql = text("""
                    INSERT INTO [home].[home] (
                        [name], 
                        [database_name], 
                        [database_type], 
                        [database_schema], 
                        [admin_user_email], 
                        [admin_user_password]
                    ) VALUES (
                        :name,
                        :database_name,
                        :database_type,
                        :database_schema,
                        :admin_user_email,
                        :admin_user_password
                    )
                """)
                
                conn.execute(insert_demo_sql, {
                    "name": "demo",
                    "database_name": "home",
                    "database_type": "mssql",
                    "database_schema": "demo",
                    "admin_user_email": "ranmizrachi@gmail.com",
                    "admin_user_password": "123456"
                })
                
                print("Inserted 'demo' tenant configuration.")
            else:
                print("Tenant 'demo' already exists.")
            
            conn.commit()
            return True
            
    except Exception as e:
        print(f"Error inserting initial tenant data: {e}")
        return False

def verify_tenant_data():
    """
    Verify the tenant data was inserted correctly
    """
    
    connection_string = "mssql+pyodbc://localhost\\SQLEXPRESS/home?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes&Trusted_Connection=yes"
    
    try:
        engine = create_engine(connection_string)
        
        with engine.connect() as conn:
            # Get all tenant configurations
            select_sql = text("""
                SELECT 
                    [id],
                    [name],
                    [database_name],
                    [database_type],
                    [database_schema],
                    [admin_user_email],
                    [created_at]
                FROM [home].[home]
                ORDER BY [id]
            """)
            
            result = conn.execute(select_sql).fetchall()
            
            print("\nTenant configurations:")
            print("ID | Name      | DB Name | DB Type | Schema     | Admin Email")
            print("-" * 70)
            
            for row in result:
                tenant_id = str(row[0]).ljust(2)
                name = row[1].ljust(9)
                db_name = row[2].ljust(7)
                db_type = row[3].ljust(7)
                schema = row[4].ljust(10)
                email = row[5]
                print(f"{tenant_id} | {name} | {db_name} | {db_type} | {schema} | {email}")
            
            print(f"\nTotal tenants configured: {len(result)}")
            return True
            
    except Exception as e:
        print(f"Error verifying tenant data: {e}")
        return False

def create_demo_schema():
    """
    Create the demo schema in the home database if it doesn't exist
    """
    
    # Connection string for the home database
    connection_string = "mssql+pyodbc://localhost\\SQLEXPRESS/home?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes&Trusted_Connection=yes"
    
    try:
        engine = create_engine(connection_string)
        
        with engine.connect() as conn:
            # Check if demo schema exists
            check_schema_sql = text("""
                SELECT schema_name 
                FROM information_schema.schemata 
                WHERE schema_name = 'demo'
            """)
            
            result = conn.execute(check_schema_sql).fetchone()
            
            if result:
                print("Schema 'demo' already exists in home database.")
            else:
                # Create the demo schema
                create_schema_sql = text("CREATE SCHEMA [demo]")
                conn.execute(create_schema_sql)
                conn.commit()
                print("Schema 'demo' created successfully in home database.")
            
            return True
            
    except Exception as e:
        print(f"Error creating demo schema: {e}")
        return False

def main():
    """Main function to initialize tenant data"""
    print("Initializing tenant data...")
    
    # Create demo schema in home database
    print("\nCreating demo schema in home database...")
    if not create_demo_schema():
        print("Failed to create demo schema")
        sys.exit(1)
    
    # Insert initial tenant configurations
    print("\nInserting initial tenant configurations...")
    if not insert_initial_tenants():
        print("Failed to insert initial tenant data")
        sys.exit(1)
    
    # Verify tenant data
    if not verify_tenant_data():
        print("Failed to verify tenant data")
        sys.exit(1)
    
    print("\nTenant data initialization completed successfully!")
    print("\nNext steps:")
    print("1. Run deployment scripts to create tables in the 'demo' schema")
    print("2. Implement tenant configuration loading in the API")

if __name__ == "__main__":
    main()