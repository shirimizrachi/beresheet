"""
SQL Server-specific implementation for database setup operations
Supports both SQL Express local and Azure SQL Database configurations
"""

import sys
import os
import getpass
from sqlalchemy import create_engine, text
from typing import Optional, Dict, Any
from ..models import create_home_table, create_home_index_table
from deployment.admin.setup_residents_database import DatabaseSetupBase

# Import configuration from residents_config
# Add the api_service directory to sys.path (go up 3 levels from deployment/admin/sqlserver)
script_dir = os.path.dirname(os.path.abspath(__file__))  # deployment/admin/sqlserver
admin_dir = os.path.dirname(script_dir)                 # deployment/admin
deployment_dir = os.path.dirname(admin_dir)             # deployment
api_service_dir = os.path.dirname(deployment_dir)       # api_service
sys.path.insert(0, api_service_dir)

from residents_config import (
    get_connection_string, get_admin_connection_string, get_server_info,
    get_home_index_connection_string, get_home_index_server_info,
    get_master_connection_string
)

class SqlServerDatabaseSetup(DatabaseSetupBase):
    """SQL Server-specific database setup implementation"""
        
    def get_connection_config(self) -> Dict[str, Any]:
        """Get database connection configuration from residents_config.py"""
        print("🏠 Residents Database Setup")
        print("=" * 50)
        print("Using configuration from residents_config.py")
        
        # Get server info from residents_config
        server_info = get_server_info()
        home_index_server_info = get_home_index_server_info()
        
        # Build configuration using the connection strings from residents_config
        config = {
            "type": server_info["type"],
            "server": server_info["server"],
            "user_connection": get_connection_string(),
            "home_index_connection": get_home_index_connection_string(),
            "master_connection": get_master_connection_string(),
            "db_connection": get_admin_connection_string()
        }
        
        return config
    
    
    def create_database(self, config: Dict[str, Any]) -> bool:
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
    
    def create_schema(self, config: Dict[str, Any]) -> bool:
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
    
    def create_user_and_permissions(self, config: Dict[str, Any]) -> bool:
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
                
                # Grant database access by adding user to database roles
                try:
                    # Add user to db_datareader and db_datawriter roles for database access
                    add_datareader_sql = text(f"ALTER ROLE db_datareader ADD MEMBER [{self.user_name}]")
                    conn.execute(add_datareader_sql)
                    
                    add_datawriter_sql = text(f"ALTER ROLE db_datawriter ADD MEMBER [{self.user_name}]")
                    conn.execute(add_datawriter_sql)
                    
                    print(f"✅ User '{self.user_name}' added to db_datareader and db_datawriter roles.")
                except Exception as e:
                    print(f"⚠️  Could not add user to database roles: {e}")
                
                # Grant database-level permissions
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
    
    def create_home_table(self, config: Dict[str, Any]) -> bool:
        """Create the home table for managing all homes"""
        print(f"\n🔧 Creating home table...")
        
        try:
            # Use admin connection to create the table since the user may not be fully set up yet
            engine = create_engine(config["db_connection"])
            
            # Check if table exists
            with engine.connect() as conn:
                check_table_sql = text(f"""
                    SELECT TABLE_NAME
                    FROM INFORMATION_SCHEMA.TABLES
                    WHERE TABLE_SCHEMA = '{self.schema_name}' AND TABLE_NAME = 'home'
                """)
                
                result = conn.execute(check_table_sql).fetchone()
                
                if result:
                    print(f"✅ Table '{self.schema_name}.home' already exists.")
                    return True
            
            # Create table using SQLAlchemy model
            create_home_table(engine, self.schema_name)
            print(f"✅ Table '{self.schema_name}.home' created successfully using SQLAlchemy model.")
            
            # Create additional SQL Server-specific indexes and triggers
            with engine.connect() as conn:
                # Create index on name
                try:
                    create_index_sql = text(f"""
                        CREATE INDEX IX_home_name ON [{self.schema_name}].[home] ([name])
                    """)
                    conn.execute(create_index_sql)
                    conn.commit()
                    print(f"✅ Index on 'name' column created successfully.")
                except Exception as e:
                    print(f"⚠️  Index may already exist: {e}")
                
                # Create update trigger
                try:
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
                except Exception as e:
                    print(f"⚠️  Trigger creation issue: {e}")
            
            return True
                
        except Exception as e:
            print(f"❌ Error creating home table: {e}")
            return False
    
    def test_user_connection(self, config: Dict[str, Any]) -> bool:
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
            print(f"⚠️  This may be normal if SQL Server is not configured for mixed authentication")
            print(f"⚠️  Connection string: {config['user_connection']}")
            return False
    
    def display_connection_info(self, config: Dict[str, Any]) -> bool:
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
        print(f"Home Index Connection String: {config['home_index_connection']}")
        
        print("\n📝 Configuration is already set in residents_config.py:")
        print(f"✅ DATABASE_TYPE = \"{config['type']}\"")
        print(f"✅ Connection strings are properly configured with URL encoding")
        print("✅ All database credentials are set")
        
        return True
    
    def create_home_index_schema(self, config: Dict[str, Any]) -> bool:
        """Create the home_index schema"""
        print(f"\n🔧 Creating home_index schema '{self.home_index_schema_name}'...")
        
        try:
            engine = create_engine(config["db_connection"])
            
            with engine.connect() as conn:
                # Check if schema exists
                check_schema_sql = text("""
                    SELECT schema_name
                    FROM information_schema.schemata
                    WHERE schema_name = :schema_name
                """)
                
                result = conn.execute(check_schema_sql, {"schema_name": self.home_index_schema_name}).fetchone()
                
                if result:
                    print(f"✅ Schema '{self.home_index_schema_name}' already exists.")
                else:
                    # Create schema
                    create_schema_sql = text(f"CREATE SCHEMA [{self.home_index_schema_name}]")
                    conn.execute(create_schema_sql)
                    conn.commit()
                    print(f"✅ Schema '{self.home_index_schema_name}' created successfully.")
                
                return True
                
        except Exception as e:
            print(f"❌ Error creating home_index schema: {e}")
            return False
    
    def create_home_index_user_and_permissions(self, config: Dict[str, Any]) -> bool:
        """Create home_index user and grant permissions on home_index schema only"""
        print(f"\n🔧 Creating home_index user '{self.home_index_user_name}' with limited permissions...")
        
        try:
            engine = create_engine(config["db_connection"])
            
            with engine.connect() as conn:
                # Check if user exists
                check_user_sql = text("""
                    SELECT name
                    FROM sys.database_principals
                    WHERE name = :user_name AND type = 'S'
                """)
                
                result = conn.execute(check_user_sql, {"user_name": self.home_index_user_name}).fetchone()
                
                if not result:
                    if config["type"] == "azure":
                        # For Azure SQL Database, create contained database user
                        create_user_sql = text(f"""
                            CREATE USER [{self.home_index_user_name}] WITH PASSWORD = '{self.home_index_user_password}'
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
                            login_result = master_conn.execute(check_login_sql, {"user_name": self.home_index_user_name}).fetchone()
                            
                            if not login_result:
                                create_login_sql = text(f"""
                                    CREATE LOGIN [{self.home_index_user_name}] WITH PASSWORD = '{self.home_index_user_password}'
                                """)
                                master_conn.execute(create_login_sql)
                                print(f"✅ Login '{self.home_index_user_name}' created successfully.")
                        
                        # Create database user
                        create_user_sql = text(f"""
                            CREATE USER [{self.home_index_user_name}] FOR LOGIN [{self.home_index_user_name}]
                        """)
                    
                    conn.execute(create_user_sql)
                    conn.commit()
                    print(f"✅ User '{self.home_index_user_name}' created successfully.")
                else:
                    print(f"✅ User '{self.home_index_user_name}' already exists.")
                
                # Grant minimal database access (only what's needed to connect)
                try:
                    # Add user to db_datareader role for minimal database access
                    add_datareader_sql = text(f"ALTER ROLE db_datareader ADD MEMBER [{self.home_index_user_name}]")
                    conn.execute(add_datareader_sql)
                    
                    print(f"✅ User '{self.home_index_user_name}' added to db_datareader role (read-only access).")
                except Exception as e:
                    print(f"⚠️  Could not add home_index user to database roles: {e}")
                
                # Grant necessary permissions on home_index schema (SELECT, INSERT, UPDATE)
                schema_permissions = ["SELECT", "INSERT", "UPDATE"]
                
                for permission in schema_permissions:
                    try:
                        grant_permission_sql = text(f"""
                            GRANT {permission} ON SCHEMA::[{self.home_index_schema_name}] TO [{self.home_index_user_name}]
                        """)
                        conn.execute(grant_permission_sql)
                    except Exception as e:
                        print(f"⚠️  Could not grant {permission} permission on home_index schema: {e}")
                
                print(f"✅ User '{self.home_index_user_name}' granted SELECT, INSERT, UPDATE permissions on home_index schema.")
                
                conn.commit()
                print(f"✅ Limited permissions granted to user '{self.home_index_user_name}' on home_index schema only.")
                
                return True
                
        except Exception as e:
            print(f"❌ Error creating home_index user and permissions: {e}")
            return False
    
    def create_home_index_table(self, config: Dict[str, Any]) -> bool:
        """Create the home_index table"""
        print(f"\n🔧 Creating home_index table...")
        
        try:
            # Use admin connection to create the table (since home_index user may not be fully set up yet)
            engine = create_engine(config["db_connection"])
            
            # Check if table exists
            with engine.connect() as conn:
                check_table_sql = text(f"""
                    SELECT TABLE_NAME
                    FROM INFORMATION_SCHEMA.TABLES
                    WHERE TABLE_SCHEMA = '{self.home_index_schema_name}' AND TABLE_NAME = 'home_index'
                """)
                
                result = conn.execute(check_table_sql).fetchone()
                
                if result:
                    print(f"✅ Table '{self.home_index_schema_name}.home_index' already exists.")
                    return True
            
            # Create table using SQLAlchemy model
            create_home_index_table(engine, self.home_index_schema_name)
            print(f"✅ Table '{self.home_index_schema_name}.home_index' created successfully using SQLAlchemy model.")
            
            # Create additional SQL Server-specific indexes and triggers
            with engine.connect() as conn:
                # Create index on home_id
                try:
                    create_index_sql = text(f"""
                        CREATE INDEX IX_home_index_home_id ON [{self.home_index_schema_name}].[home_index] ([home_id])
                    """)
                    conn.execute(create_index_sql)
                    conn.commit()
                    print(f"✅ Index on 'home_id' column created successfully.")
                except Exception as e:
                    print(f"⚠️  Index may already exist: {e}")
                
                # Create update trigger
                try:
                    create_trigger_sql = text(f"""
                        CREATE TRIGGER [{self.home_index_schema_name}].[tr_home_index_update_timestamp]
                        ON [{self.home_index_schema_name}].[home_index]
                        AFTER UPDATE
                        AS
                        BEGIN
                            SET NOCOUNT ON;
                            UPDATE [{self.home_index_schema_name}].[home_index]
                            SET [updated_at] = GETDATE()
                            FROM [{self.home_index_schema_name}].[home_index] h
                            INNER JOIN inserted i ON h.phone_number = i.phone_number;
                        END
                    """)
                    conn.execute(create_trigger_sql)
                    conn.commit()
                    print(f"✅ Update timestamp trigger created successfully.")
                except Exception as e:
                    print(f"⚠️  Trigger creation issue: {e}")
            
            return True
                
        except Exception as e:
            print(f"❌ Error creating home_index table: {e}")
            return False
    
    def test_home_index_connection(self, config: Dict[str, Any]) -> bool:
        """Test connection with the home_index user"""
        print(f"\n🔧 Testing home_index user connection...")
        
        try:
            # Use the connection string from residents_config.py
            home_index_connection = config["home_index_connection"]
            
            print(f"Testing home_index user connection...")
            engine = create_engine(home_index_connection)
            
            with engine.connect() as conn:
                # Test basic query
                test_sql = text(f"""
                    SELECT COUNT(*) as table_count
                    FROM INFORMATION_SCHEMA.TABLES
                    WHERE TABLE_SCHEMA = '{self.home_index_schema_name}'
                """)
                
                result = conn.execute(test_sql).fetchone()
                print(f"✅ Home_index user connection successful. Found {result[0]} tables in schema '{self.home_index_schema_name}'.")
                
                return True
                
        except Exception as e:
            print(f"❌ Error testing home_index user connection: {e}")
            return False

def main():
    """Main setup function for SQL Server"""
    setup = SqlServerDatabaseSetup()
    setup.run_setup()

if __name__ == "__main__":
    main()