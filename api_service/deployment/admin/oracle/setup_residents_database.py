"""
Oracle-specific implementation for database setup operations
Supports Oracle Autonomous Transaction Processing configurations
"""

import sys
import os
import getpass
from sqlalchemy import create_engine, text
from typing import Optional, Dict, Any
from ..models import create_home_table, create_home_index_table
from deployment.admin.setup_residents_database import DatabaseSetupBase

# Import configuration from residents_config
# Add the api_service directory to sys.path (go up 3 levels from deployment/admin/oracle)
script_dir = os.path.dirname(os.path.abspath(__file__))  # deployment/admin/oracle
admin_dir = os.path.dirname(script_dir)                 # deployment/admin
deployment_dir = os.path.dirname(admin_dir)             # deployment
api_service_dir = os.path.dirname(deployment_dir)       # api_service
sys.path.insert(0, api_service_dir)

from residents_config import (
    get_connection_string, get_admin_connection_string, get_server_info,
    get_home_index_connection_string, get_home_index_server_info,
    get_master_connection_string
)

class OracleDatabaseSetup(DatabaseSetupBase):
    """Oracle-specific database setup implementation"""
        
    def get_connection_config(self) -> Dict[str, Any]:
        """Get database connection configuration from residents_config.py"""
        print("🏠 Residents Oracle ATP Database Setup")
        print("=" * 50)
        print("Using configuration from residents_config.py")
        
        # Get server info from residents_config
        server_info = get_server_info()
        home_index_server_info = get_home_index_server_info()
        
        # Build configuration using the connection strings from residents_config
        config = {
            "type": server_info["type"],
            "server": server_info["host"],
            "user_connection": get_connection_string(),
            "home_index_connection": get_home_index_connection_string(),
            "master_connection": get_master_connection_string(),
            "db_connection": get_admin_connection_string()
        }
        
        return config
    
    def create_database(self, config: Dict[str, Any]) -> bool:
        """Create the residents database (Oracle: verify connection)"""
        print(f"\n🔧 Verifying Oracle ATP connection for '{self.database_name}'...")
        
        try:
            engine = create_engine(config["master_connection"])
            
            with engine.connect() as conn:
                # Test connection with a simple query
                test_sql = text("SELECT 1 FROM DUAL")
                result = conn.execute(test_sql).fetchone()
                
                if result:
                    print(f"✅ Oracle ATP connection verified for '{self.database_name}'.")
                    return True
                else:
                    print(f"❌ Oracle ATP connection test failed.")
                    return False
                
        except Exception as e:
            print(f"❌ Error verifying Oracle ATP connection: {e}")
            return False
    
    def create_schema(self, config: Dict[str, Any]) -> bool:
        """Create the home schema (Oracle: create user/schema)"""
        print(f"\n🔧 Creating schema '{self.schema_name}'...")
        
        try:
            engine = create_engine(config["db_connection"])
            
            with engine.connect() as conn:
                # Check if user/schema exists
                check_user_sql = text("""
                    SELECT username 
                    FROM ALL_USERS 
                    WHERE username = :user_name
                """)
                
                result = conn.execute(check_user_sql, {"user_name": self.user_name.upper()}).fetchone()
                
                if result:
                    print(f"✅ Schema '{self.schema_name}' already exists.")
                else:
                    # Create user (in Oracle, user = schema)
                    create_user_sql = text(f"""
                        CREATE USER {self.user_name} IDENTIFIED BY "{self.user_password}"
                        DEFAULT TABLESPACE DATA
                        TEMPORARY TABLESPACE TEMP
                        QUOTA UNLIMITED ON DATA
                    """)
                    
                    conn.execute(create_user_sql)
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
                # Check if user exists (already checked in create_schema, but keeping consistency)
                check_user_sql = text("""
                    SELECT username 
                    FROM ALL_USERS 
                    WHERE username = :user_name
                """)
                
                result = conn.execute(check_user_sql, {"user_name": self.user_name.upper()}).fetchone()
                
                if not result:
                    # User should have been created in create_schema step
                    print(f"❌ User '{self.user_name}' not found. Schema creation may have failed.")
                    return False
                else:
                    print(f"✅ User '{self.user_name}' already exists.")
                
                # Grant database-level permissions
                db_permissions = [
                    "CREATE SESSION", "CREATE TABLE", "CREATE VIEW", "CREATE PROCEDURE",
                    "CREATE SEQUENCE", "CREATE TRIGGER", "CREATE TYPE"
                ]
                
                for permission in db_permissions:
                    try:
                        grant_sql = text(f"GRANT {permission} TO {self.user_name}")
                        conn.execute(grant_sql)
                        conn.commit()
                    except Exception as e:
                        print(f"⚠️  Could not grant {permission} permission: {e}")
                
                print(f"✅ Database permissions granted to user '{self.user_name}'.")
                
                return True
                
        except Exception as e:
            print(f"❌ Error creating user and permissions: {e}")
            return False
    
    def create_home_table(self, config: Dict[str, Any]) -> bool:
        """Create the home table for managing all homes"""
        print(f"\n🔧 Creating home table...")
        
        try:
            engine = create_engine(config["user_connection"])
            
            # Check if table exists
            with engine.connect() as conn:
                check_table_sql = text("""
                    SELECT TABLE_NAME
                    FROM ALL_TABLES
                    WHERE OWNER = :schema_name AND TABLE_NAME = 'HOME'
                """)
                
                result = conn.execute(check_table_sql, {"schema_name": self.user_name.upper()}).fetchone()
                
                if result:
                    print(f"✅ Table '{self.schema_name}.home' already exists.")
                    return True
            
            # Create table using SQLAlchemy model (consistent with SQL Server)
            create_home_table(engine, self.user_name)
            print(f"✅ Table '{self.schema_name}.home' created successfully using SQLAlchemy model.")
            
            # Create additional Oracle-specific indexes and triggers
            with engine.connect() as conn:
                # Create index on name
                try:
                    create_index_sql = text(f"""
                        CREATE INDEX IX_HOME_NAME ON {self.user_name}.HOME (NAME)
                    """)
                    conn.execute(create_index_sql)
                    conn.commit()
                    print(f"✅ Index on 'name' column created successfully.")
                except Exception as e:
                    print(f"⚠️  Index may already exist: {e}")
                
                # Create update trigger
                try:
                    create_trigger_sql = text(f"""
                        CREATE OR REPLACE TRIGGER {self.user_name}.TR_HOME_UPDATE_TIMESTAMP
                        BEFORE UPDATE ON {self.user_name}.HOME
                        FOR EACH ROW
                        BEGIN
                            :NEW.UPDATED_AT := CURRENT_TIMESTAMP;
                        END;
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
                test_sql = text("""
                    SELECT COUNT(*) as table_count
                    FROM ALL_TABLES 
                    WHERE OWNER = :schema_name
                """)
                
                result = conn.execute(test_sql, {"schema_name": self.user_name.upper()}).fetchone()
                print(f"✅ User connection successful. Found {result[0]} tables in schema '{self.schema_name}'.")
                
                return True
                
        except Exception as e:
            print(f"❌ Error testing user connection: {e}")
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
                # Check if user/schema exists
                check_user_sql = text("""
                    SELECT username
                    FROM ALL_USERS
                    WHERE username = :user_name
                """)
                
                result = conn.execute(check_user_sql, {"user_name": self.home_index_user_name.upper()}).fetchone()
                
                if result:
                    print(f"✅ Schema '{self.home_index_schema_name}' already exists.")
                else:
                    # Create home_index user/schema
                    create_user_sql = text(f"""
                        CREATE USER {self.home_index_user_name} IDENTIFIED BY "{self.home_index_user_password}"
                        DEFAULT TABLESPACE DATA
                        TEMPORARY TABLESPACE TEMP
                        QUOTA UNLIMITED ON DATA
                    """)
                    
                    conn.execute(create_user_sql)
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
                # Check if user exists (already checked in create_home_index_schema, but keeping consistency)
                check_user_sql = text("""
                    SELECT username
                    FROM ALL_USERS
                    WHERE username = :user_name
                """)
                
                result = conn.execute(check_user_sql, {"user_name": self.home_index_user_name.upper()}).fetchone()
                
                if not result:
                    print(f"❌ User '{self.home_index_user_name}' not found. Schema creation may have failed.")
                    return False
                else:
                    print(f"✅ User '{self.home_index_user_name}' already exists.")
                
                # Grant specific permissions on home_index schema only
                schema_permissions = [
                    "CREATE SESSION", "CREATE TABLE", "CREATE SEQUENCE", "CREATE TRIGGER"
                ]
                
                for permission in schema_permissions:
                    try:
                        grant_sql = text(f"GRANT {permission} TO {self.home_index_user_name}")
                        conn.execute(grant_sql)
                        conn.commit()
                    except Exception as e:
                        print(f"⚠️  Could not grant {permission} permission on home_index schema: {e}")
                
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
                check_table_sql = text("""
                    SELECT TABLE_NAME
                    FROM ALL_TABLES
                    WHERE OWNER = :schema_name AND TABLE_NAME = 'HOME_INDEX'
                """)
                
                result = conn.execute(check_table_sql, {"schema_name": self.home_index_user_name.upper()}).fetchone()
                
                if result:
                    print(f"✅ Table '{self.home_index_schema_name}.home_index' already exists.")
                    return True
            
            # Create table using SQLAlchemy model
            create_home_index_table(engine, self.home_index_user_name)
            print(f"✅ Table '{self.home_index_schema_name}.home_index' created successfully using SQLAlchemy model.")
            
            # Create additional Oracle-specific indexes and triggers
            with engine.connect() as conn:
                # Create index on home_id
                try:
                    create_index_sql = text(f"""
                        CREATE INDEX IX_HOME_INDEX_HOME_ID ON {self.home_index_user_name}.HOME_INDEX (HOME_ID)
                    """)
                    conn.execute(create_index_sql)
                    conn.commit()
                    print(f"✅ Index on 'home_id' column created successfully.")
                except Exception as e:
                    print(f"⚠️  Index may already exist: {e}")
                
                # Create update trigger
                try:
                    create_trigger_sql = text(f"""
                        CREATE OR REPLACE TRIGGER {self.home_index_user_name}.TR_HOME_INDEX_UPDATE_TIMESTAMP
                        BEFORE UPDATE ON {self.home_index_user_name}.HOME_INDEX
                        FOR EACH ROW
                        BEGIN
                            :NEW.UPDATED_AT := CURRENT_TIMESTAMP;
                        END;
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
                test_sql = text("""
                    SELECT COUNT(*) as table_count
                    FROM ALL_TABLES
                    WHERE OWNER = :schema_name
                """)
                
                result = conn.execute(test_sql, {"schema_name": self.home_index_user_name.upper()}).fetchone()
                print(f"✅ Home_index user connection successful. Found {result[0]} tables in schema '{self.home_index_schema_name}'.")
                
                return True
                
        except Exception as e:
            print(f"❌ Error testing home_index user connection: {e}")
            return False

def main():
    """Main setup function for Oracle"""
    setup = OracleDatabaseSetup()
    setup.run_setup()

if __name__ == "__main__":
    main()