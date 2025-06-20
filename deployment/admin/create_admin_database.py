"""
Script to create the admin database for tenant management
This creates a separate database from tenant data for complete isolation
"""

import sys
import pyodbc
from sqlalchemy import create_engine, text

def create_admin_database():
    """
    Create the admin database for tenant management
    """
    
    # Connection string for SQL Server (using Windows Authentication)
    connection_string = "mssql+pyodbc://localhost\\SQLEXPRESS/master?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes&Trusted_Connection=yes"
    
    try:
        # Create SQLAlchemy engine
        engine = create_engine(connection_string)
        
        # Use autocommit=True to avoid transactions for CREATE DATABASE
        with engine.connect().execution_options(autocommit=True) as conn:
            # Check if database already exists
            check_db_sql = text("""
                SELECT database_id
                FROM sys.databases
                WHERE name = 'home_admin'
            """)
            
            result = conn.execute(check_db_sql).fetchone()
            
            if result:
                print("Admin database 'home_admin' already exists.")
            else:
                # Create the admin database (autocommit enabled)
                conn.execute(text("CREATE DATABASE [home_admin]"))
                print("Admin database 'home_admin' created successfully.")
            
            return True
            
    except Exception as e:
        print(f"Error creating admin database: {e}")
        return False

def create_admin_schema():
    """
    Create the home schema within the admin database
    """
    
    # Connection string for the admin database
    #connection_string = "mssql+pyodbc://localhost\\SQLEXPRESS/home_admin?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes&Trusted_Connection=yes"
    connection_string = "mssql+pyodbc://localhost\\SQLEXPRESS/home?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes&Trusted_Connection=yes"
    
    try:
        # Create SQLAlchemy engine
        engine = create_engine(connection_string)
        
        with engine.connect() as conn:
            # Check if schema already exists
            check_schema_sql = text("""
                SELECT schema_name 
                FROM information_schema.schemata 
                WHERE schema_name = 'home'
            """)
            
            result = conn.execute(check_schema_sql).fetchone()
            
            if result:
                print("Schema 'home' already exists in admin database.")
            else:
                # Create the home schema
                create_schema_sql = text("CREATE SCHEMA [home]")
                conn.execute(create_schema_sql)
                conn.commit()
                print("Schema 'home' created successfully in admin database.")
            
            return True
            
    except Exception as e:
        print(f"Error creating home schema in admin database: {e}")
        return False

def main():
    """Main function to create admin database and schema"""
    print("Setting up admin database for tenant management...")
    
    # Create admin database
    # if not create_admin_database():
    #     print("Failed to create admin database")
    #     sys.exit(1)
    
    # Create home schema
    if not create_admin_schema():
        print("Failed to create home schema")
        sys.exit(1)
    
    print("Admin database setup completed successfully!")
    print("Next step: Run create_tenant_table.py to create the tenant configuration table")

if __name__ == "__main__":
    main()