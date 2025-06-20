"""
Script to create the residents database with home schema and user
Supports both SQL Express local and Azure SQL Database configurations
"""

import sys
import os
import getpass
from sqlalchemy import create_engine, text
from typing import Optional

class DatabaseSetup:
    """Database setup class for residents database"""
    
    def __init__(self):
        self.database_name = "residents"
        self.schema_name = "home"
        self.user_name = "home"
        self.user_password = "home2025!"
        
    def get_connection_config(self) -> dict:
        """Get database connection configuration from user"""
        print("🏠 Residents Database Setup")
        print("=" * 50)
        print("Choose database configuration:")
        print("1. SQL Express Local")
        print("2. Azure SQL Database")
        
        choice = input("\nEnter your choice (1 or 2): ").strip()
        
        if choice == "1":
            return self._get_local_config()
        elif choice == "2":
            return self._get_azure_config()
        else:
            print("Invalid choice. Please run the script again.")
            sys.exit(1)
    
    def _get_local_config(self) -> dict:
        """Get SQL Express local configuration"""
        server_instance = input("Enter SQL Server instance (default: localhost\\SQLEXPRESS): ").strip()
        if not server_instance:
            server_instance = "localhost\\SQLEXPRESS"
        
        return {
            "type": "local",
            "server": server_instance,
            "master_connection": f"mssql+pyodbc://{server_instance}/master?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes&Trusted_Connection=yes",
            "db_connection": f"mssql+pyodbc://{server_instance}/{self.database_name}?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes&Trusted_Connection=yes",
            "user_connection": f"mssql+pyodbc://{self.user_name}:{self.user_password}@{server_instance}/{self.database_name}?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"
        }
    
    def _get_azure_config(self) -> dict:
        """Get Azure SQL Database configuration"""
        print("\nAzure SQL Database Configuration:")
        server_name = input("Enter Azure SQL Server name (without .database.windows.net): ").strip()
        admin_username = input("Enter admin username: ").strip()
        admin_password = getpass.getpass("Enter admin password: ")
        
        if not all([server_name, admin_username, admin_password]):
            print("All Azure SQL configuration fields are required.")
            sys.exit(1)
        
        server_fqdn = f"{server_name}.database.windows.net"
        
        return {
            "type": "azure",
            "server": server_fqdn,
            "admin_username": admin_username,
            "admin_password": admin_password,
            "master_connection": f"mssql+pyodbc://{admin_username}:{admin_password}@{server_fqdn}/master?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes",
            "db_connection": f"mssql+pyodbc://{admin_username}:{admin_password}@{server_fqdn}/{self.database_name}?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes",
            "user_connection": f"mssql+pyodbc://{self.user_name}:{self.user_password}@{server_fqdn}/{self.database_name}?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"
        }
    
    def create_database(self, config: dict) -> bool:
        """Create the residents database"""
        print(f"\n🔧 Creating database '{self.database_name}'...")
        
        try:
            # Use autocommit=True for database operations
            engine = create_engine(config["master_connection"], isolation_level="AUTOCOMMIT")
            
            with engine.connect() as conn:
                # Check if database exists
                check_db_sql = text("""
                    SELECT database_id
                    FROM sys.databases
                    WHERE name = :db_name
                """)
                
                result = conn.execute(check_db_sql, {"db_name": self.database_name}).fetchone()
                
                if result:
                    print(f"✅ Database '{self.database_name}' already exists.")
                else:
                    # Create database (autocommit is enabled)
                    create_db_sql = text(f"CREATE DATABASE [{self.database_name}]")
                    conn.execute(create_db_sql)
                    print(f"✅ Database '{self.database_name}' created successfully.")
                
                return True
                
        except Exception as e:
            print(f"❌ Error creating database: {e}")
            return False
    
    def create_schema(self, config: dict) -> bool:
        """Create the home schema"""
        print(f"\n🔧 Creating schema '{self.schema_name}'...")
        
        try:
            engine = create_engine(config["db_connection"])
            
            with engine.connect() as conn:
                # Check if schema exists
                check_schema_sql = text("""
                    SELECT schema_name 
                    FROM information_schema.schemata 
                    WHERE schema_name = :schema_name
                """)
                
                result = conn.execute(check_schema_sql, {"schema_name": self.schema_name}).fetchone()
                
                if result:
                    print(f"✅ Schema '{self.schema_name}' already exists.")
                else:
                    # Create schema
                    create_schema_sql = text(f"CREATE SCHEMA [{self.schema_name}]")
                    conn.execute(create_schema_sql)
                    conn.commit()
                    print(f"✅ Schema '{self.schema_name}' created successfully.")
                
                return True
                
        except Exception as e:
            print(f"❌ Error creating schema: {e}")
            return False
    
    def create_user_and_permissions(self, config: dict) -> bool:
        """Create user and grant permissions on schema"""
        print(f"\n🔧 Creating user '{self.user_name}' with permissions...")
        
        try:
            engine = create_engine(config["db_connection"])
            
            with engine.connect() as conn:
                # Check if user exists
                check_user_sql = text("""
                    SELECT name 
                    FROM sys.database_principals 
                    WHERE name = :user_name AND type = 'S'
                """)
                
                result = conn.execute(check_user_sql, {"user_name": self.user_name}).fetchone()
                
                if not result:
                    if config["type"] == "azure":
                        # For Azure SQL Database, create contained database user
                        create_user_sql = text(f"""
                            CREATE USER [{self.user_name}] WITH PASSWORD = '{self.user_password}'
                        """)
                    else:
                        # For SQL Express, create login first, then user
                        # Check if login exists
                        check_login_sql = text("""
                            SELECT name 
                            FROM sys.server_principals 
                            WHERE name = :user_name AND type = 'S'
                        """)
                        
                        # Connect to master to create login (use autocommit for CREATE LOGIN)
                        master_engine = create_engine(config["master_connection"], isolation_level="AUTOCOMMIT")
                        with master_engine.connect() as master_conn:
                            login_result = master_conn.execute(check_login_sql, {"user_name": self.user_name}).fetchone()
                            
                            if not login_result:
                                create_login_sql = text(f"""
                                    CREATE LOGIN [{self.user_name}] WITH PASSWORD = '{self.user_password}'
                                """)
                                master_conn.execute(create_login_sql)
                                print(f"✅ Login '{self.user_name}' created successfully.")
                        
                        # Create database user
                        create_user_sql = text(f"""
                            CREATE USER [{self.user_name}] FOR LOGIN [{self.user_name}]
                        """)
                    
                    conn.execute(create_user_sql)
                    conn.commit()
                    print(f"✅ User '{self.user_name}' created successfully.")
                else:
                    print(f"✅ User '{self.user_name}' already exists.")
                
                # Grant database-level permissions first
                db_permissions = [
                    "CREATE TABLE", "CREATE VIEW", "CREATE PROCEDURE",
                    "CREATE FUNCTION", "CREATE TYPE"
                ]
                
                for permission in db_permissions:
                    grant_db_permission_sql = text(f"""
                        GRANT {permission} TO [{self.user_name}]
                    """)
                    try:
                        conn.execute(grant_db_permission_sql)
                    except Exception as e:
                        print(f"⚠️  Could not grant {permission} permission: {e}")
                
                # Grant specific permissions on schema
                schema_permissions = [
                    "SELECT", "INSERT", "UPDATE", "DELETE",
                    "REFERENCES", "ALTER", "EXECUTE"
                ]
                
                for permission in schema_permissions:
                    grant_permission_sql = text(f"""
                        GRANT {permission} ON SCHEMA::[{self.schema_name}] TO [{self.user_name}]
                    """)
                    try:
                        conn.execute(grant_permission_sql)
                    except Exception as e:
                        # Some permissions might not be applicable to schemas, continue
                        print(f"⚠️  Could not grant {permission} permission on schema: {e}")
                
                # Also make the user the owner of the schema for full control
                try:
                    alter_schema_sql = text(f"""
                        ALTER AUTHORIZATION ON SCHEMA::[{self.schema_name}] TO [{self.user_name}]
                    """)
                    conn.execute(alter_schema_sql)
                    print(f"✅ User '{self.user_name}' is now owner of schema '{self.schema_name}'.")
                except Exception as e:
                    print(f"⚠️  Could not make user schema owner: {e}")
                
                conn.commit()
                print(f"✅ Database and schema permissions granted to user '{self.user_name}'.")
                
                return True
                
        except Exception as e:
            print(f"❌ Error creating user and permissions: {e}")
            return False
    
    def create_home_table(self, config: dict) -> bool:
        """Create the home table for managing all homes"""
        print(f"\n🔧 Creating home table...")
        
        try:
            engine = create_engine(config["user_connection"])
            
            with engine.connect() as conn:
                # Check if table exists
                check_table_sql = text(f"""
                    SELECT TABLE_NAME 
                    FROM INFORMATION_SCHEMA.TABLES 
                    WHERE TABLE_SCHEMA = '{self.schema_name}' AND TABLE_NAME = 'home'
                """)
                
                result = conn.execute(check_table_sql).fetchone()
                
                if result:
                    print(f"✅ Table '{self.schema_name}.home' already exists.")
                else:
                    # Create home table
                    create_table_sql = text(f"""
                        CREATE TABLE [{self.schema_name}].[home] (
                            [id] INT IDENTITY(1,1) PRIMARY KEY,
                            [name] NVARCHAR(50) NOT NULL UNIQUE,
                            [database_name] NVARCHAR(50) NOT NULL,
                            [database_type] NVARCHAR(20) NOT NULL DEFAULT 'mssql',
                            [database_schema] NVARCHAR(50) NOT NULL,
                            [admin_user_email] NVARCHAR(100) NOT NULL,
                            [admin_user_password] NVARCHAR(100) NOT NULL,
                            [created_at] DATETIME2 DEFAULT GETDATE(),
                            [updated_at] DATETIME2 DEFAULT GETDATE()
                        )
                    """)
                    
                    conn.execute(create_table_sql)
                    conn.commit()
                    print(f"✅ Table '{self.schema_name}.home' created successfully.")
                    
                    # Create index
                    create_index_sql = text(f"""
                        CREATE INDEX IX_home_name ON [{self.schema_name}].[home] ([name])
                    """)
                    
                    conn.execute(create_index_sql)
                    conn.commit()
                    print(f"✅ Index on 'name' column created successfully.")
                    
                    # Create update trigger
                    create_trigger_sql = text(f"""
                        CREATE TRIGGER [{self.schema_name}].[tr_home_update_timestamp]
                        ON [{self.schema_name}].[home]
                        AFTER UPDATE
                        AS
                        BEGIN
                            SET NOCOUNT ON;
                            UPDATE [{self.schema_name}].[home]
                            SET [updated_at] = GETDATE()
                            FROM [{self.schema_name}].[home] h
                            INNER JOIN inserted i ON h.id = i.id;
                        END
                    """)
                    
                    conn.execute(create_trigger_sql)
                    conn.commit()
                    print(f"✅ Update timestamp trigger created successfully.")
                
                return True
                
        except Exception as e:
            print(f"❌ Error creating home table: {e}")
            return False
    
    def test_user_connection(self, config: dict) -> bool:
        """Test connection with the created user"""
        print(f"\n🔧 Testing user connection...")
        
        try:
            engine = create_engine(config["user_connection"])
            
            with engine.connect() as conn:
                # Test basic query
                test_sql = text(f"""
                    SELECT COUNT(*) as table_count
                    FROM INFORMATION_SCHEMA.TABLES 
                    WHERE TABLE_SCHEMA = '{self.schema_name}'
                """)
                
                result = conn.execute(test_sql).fetchone()
                print(f"✅ User connection successful. Found {result[0]} tables in schema '{self.schema_name}'.")
                
                return True
                
        except Exception as e:
            print(f"❌ Error testing user connection: {e}")
            return False
    
    def display_connection_info(self, config: dict) -> bool:
        """Display connection information for manual configuration"""
        print(f"\n🔧 Connection Information:")
        print("=" * 50)
        
        print(f"Database Type: {config['type']}")
        print(f"Server: {config['server']}")
        print(f"Database: {self.database_name}")
        print(f"Schema: {self.schema_name}")
        print(f"User: {self.user_name}")
        print(f"Password: {self.user_password}")
        print(f"User Connection String: {config['user_connection']}")
        
        print("\n📝 To configure your API service:")
        print("1. Copy api_service/residents_db_config_template.py to api_service/residents_db_config.py")
        print("2. Update the configuration values in residents_db_config.py")
        print(f"3. Set DATABASE_TYPE = \"{config['type']}\"")
        if config['type'] == 'local':
            print(f"4. Set LOCAL_SERVER = \"{config['server']}\"")
            print(f"5. Update LOCAL_CONNECTION_STRING with the user connection string above")
        else:
            print(f"4. Set AZURE_SERVER = \"{config['server']}\"")
            print(f"5. Update AZURE_CONNECTION_STRING with the user connection string above")
        
        return True

def main():
    """Main setup function"""
    setup = DatabaseSetup()
    
    # Get configuration
    config = setup.get_connection_config()
    
    print(f"\n📋 Setup Summary:")
    print(f"   Database Type: {config['type']}")
    print(f"   Server: {config['server']}")
    print(f"   Database: {setup.database_name}")
    print(f"   Schema: {setup.schema_name}")
    print(f"   User: {setup.user_name}")
    
    # Confirm before proceeding
    response = input("\nDo you want to proceed with this configuration? (y/N): ").strip().lower()
    if response != 'y':
        print("Setup cancelled.")
        return
    
    # Run setup steps
    steps = [
        ("Creating database", lambda: setup.create_database(config)),
        ("Creating schema", lambda: setup.create_schema(config)),
        ("Creating user and permissions", lambda: setup.create_user_and_permissions(config)),
        ("Creating home table", lambda: setup.create_home_table(config)),
        ("Testing user connection", lambda: setup.test_user_connection(config)),
        ("Displaying connection information", lambda: setup.display_connection_info(config))
    ]
    
    success_count = 0
    for step_name, step_func in steps:
        print(f"\n{'='*60}")
        print(f"🚀 {step_name}")
        print(f"{'='*60}")
        
        if step_func():
            success_count += 1
        else:
            print(f"\n❌ Setup failed at step: {step_name}")
            print("Please fix the error and run the setup again.")
            return
    
    print(f"\n{'='*60}")
    print(f"🎉 RESIDENTS DATABASE SETUP COMPLETE")
    print(f"{'='*60}")
    print(f"✅ {success_count}/{len(steps)} steps completed successfully")
    print()
    print("📋 What was created:")
    print(f"   • Database: {setup.database_name}")
    print(f"   • Schema: {setup.schema_name}")
    print(f"   • User: {setup.user_name} (password: {setup.user_password})")
    print(f"   • Table: {setup.schema_name}.home")
    print()
    print("🚀 Next steps:")
    print("   1. Configure your API service using the connection information above")
    print("   2. Test the database connection with: python test_residents_database.py")
    print("   3. Start your application")

if __name__ == "__main__":
    main()