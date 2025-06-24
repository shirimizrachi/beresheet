"""
Script to create the residents database with home schema and user for MySQL
Supports both local MySQL and cloud MySQL configurations
"""

import sys
import os
import getpass
from sqlalchemy import create_engine, text
from typing import Optional

# Import configuration from residents_db_config
# Add the api_service directory to sys.path (go up 2 levels from deployment/admin)
script_dir = os.path.dirname(os.path.abspath(__file__))  # deployment/admin/mysql
deployment_dir = os.path.dirname(script_dir)            # deployment/admin
api_service_dir = os.path.dirname(os.path.dirname(deployment_dir))  # api_service
sys.path.insert(0, api_service_dir)

from residents_db_config import (
    DATABASE_NAME, SCHEMA_NAME, USER_NAME, USER_PASSWORD,
    HOME_INDEX_SCHEMA_NAME, HOME_INDEX_USER_NAME, HOME_INDEX_USER_PASSWORD,
    get_connection_string, get_admin_connection_string, get_server_info,
    get_home_index_connection_string, get_home_index_server_info,
    get_master_connection_string
)

class MySQLDatabaseSetup:
    """MySQL database setup class for residents database"""
    
    def __init__(self):
        # Import all configuration from residents_db_config.py
        self.database_name = DATABASE_NAME
        self.schema_name = SCHEMA_NAME
        self.user_name = USER_NAME
        self.user_password = USER_PASSWORD
        
        # Home Index configuration from residents_db_config.py
        self.home_index_schema_name = HOME_INDEX_SCHEMA_NAME
        self.home_index_user_name = HOME_INDEX_USER_NAME
        self.home_index_user_password = HOME_INDEX_USER_PASSWORD
        
    def get_connection_config(self) -> dict:
        """Get database connection configuration from residents_db_config.py"""
        print("🏠 Residents MySQL Database Setup")
        print("=" * 50)
        print("Using configuration from residents_db_config.py")
        
        # Get server info from residents_db_config
        server_info = get_server_info()
        home_index_server_info = get_home_index_server_info()
        
        # Build configuration using the connection strings from residents_db_config
        config = {
            "type": server_info["type"],
            "server": server_info["server"],
            "user_connection": get_connection_string(),
            "home_index_connection": get_home_index_connection_string(),
            "master_connection": get_master_connection_string(),
            "admin_connection": get_admin_connection_string()
        }
        
        return config
    
    def create_database(self, config: dict) -> bool:
        """Create the residents database"""
        print(f"\n🔧 Creating database '{self.database_name}'...")
        
        try:
            engine = create_engine(config["master_connection"])
            
            with engine.connect() as conn:
                # Check if database exists
                check_db_sql = text("""
                    SELECT SCHEMA_NAME
                    FROM INFORMATION_SCHEMA.SCHEMATA
                    WHERE SCHEMA_NAME = :db_name
                """)
                
                result = conn.execute(check_db_sql, {"db_name": self.database_name}).fetchone()
                
                if result:
                    print(f"✅ Database '{self.database_name}' already exists.")
                else:
                    # Create database
                    create_db_sql = text(f"CREATE DATABASE `{self.database_name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
                    conn.execute(create_db_sql)
                    conn.commit()
                    print(f"✅ Database '{self.database_name}' created successfully.")
                
                return True
                
        except Exception as e:
            print(f"❌ Error creating database: {e}")
            return False
    
    def create_user_and_permissions(self, config: dict) -> bool:
        """Create user and grant permissions on database"""
        print(f"\n🔧 Creating user '{self.user_name}' with permissions...")
        
        try:
            engine = create_engine(config["master_connection"])
            
            with engine.connect() as conn:
                # Check if user exists
                check_user_sql = text("""
                    SELECT User
                    FROM mysql.user
                    WHERE User = :user_name
                """)
                
                result = conn.execute(check_user_sql, {"user_name": self.user_name}).fetchone()
                
                if not result:
                    # Create MySQL user
                    create_user_sql = text(f"""
                        CREATE USER '{self.user_name}'@'%' IDENTIFIED BY '{self.user_password}'
                    """)
                    conn.execute(create_user_sql)
                    print(f"✅ User '{self.user_name}' created successfully.")
                else:
                    print(f"✅ User '{self.user_name}' already exists.")
                
                # Grant full permissions on the database to the user
                grant_permissions_sql = text(f"""
                    GRANT ALL PRIVILEGES ON `{self.database_name}`.* TO '{self.user_name}'@'%'
                """)
                conn.execute(grant_permissions_sql)
                
                # Flush privileges to ensure they take effect
                flush_privileges_sql = text("FLUSH PRIVILEGES")
                conn.execute(flush_privileges_sql)
                
                conn.commit()
                print(f"✅ Full permissions granted to user '{self.user_name}' on database '{self.database_name}'.")
                
                return True
                
        except Exception as e:
            print(f"❌ Error creating user and permissions: {e}")
            return False
    
    def create_home_table(self, config: dict) -> bool:
        """Create the home table for managing all homes"""
        print(f"\n🔧 Creating home table...")
        
        try:
            # Use user connection to connect to the specific database
            engine = create_engine(config["user_connection"])
            
            with engine.connect() as conn:
                # Check if table exists
                check_table_sql = text(f"""
                    SELECT TABLE_NAME
                    FROM INFORMATION_SCHEMA.TABLES
                    WHERE TABLE_SCHEMA = '{self.database_name}' AND TABLE_NAME = 'home'
                """)
                
                result = conn.execute(check_table_sql).fetchone()
                
                if result:
                    print(f"✅ Table 'home' already exists.")
                else:
                    # Create home table
                    create_table_sql = text(f"""
                        CREATE TABLE `home` (
                            `id` INT AUTO_INCREMENT PRIMARY KEY,
                            `name` VARCHAR(50) NOT NULL UNIQUE,
                            `database_name` VARCHAR(50) NOT NULL,
                            `database_type` VARCHAR(20) NOT NULL DEFAULT 'mysql',
                            `database_schema` VARCHAR(50) NOT NULL,
                            `admin_user_email` VARCHAR(100) NOT NULL,
                            `admin_user_password` VARCHAR(100) NOT NULL,
                            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
                        ) ENGINE=InnoDB
                    """)
                    
                    conn.execute(create_table_sql)
                    conn.commit()
                    print(f"✅ Table 'home' created successfully.")
                    
                    # Create index
                    create_index_sql = text(f"""
                        CREATE INDEX idx_home_name ON `home` (`name`)
                    """)
                    
                    conn.execute(create_index_sql)
                    conn.commit()
                    print(f"✅ Index on 'name' column created successfully.")
                
                return True
                
        except Exception as e:
            print(f"❌ Error creating home table: {e}")
            return False
    
    def create_home_index_database(self, config: dict) -> bool:
        """Create the home_index database"""
        print(f"\n🔧 Creating home_index database '{self.home_index_schema_name}'...")
        
        try:
            engine = create_engine(config["master_connection"])
            
            with engine.connect() as conn:
                # Check if database exists
                check_db_sql = text("""
                    SELECT SCHEMA_NAME
                    FROM INFORMATION_SCHEMA.SCHEMATA
                    WHERE SCHEMA_NAME = :schema_name
                """)
                
                result = conn.execute(check_db_sql, {"schema_name": self.home_index_schema_name}).fetchone()
                
                if result:
                    print(f"✅ Database '{self.home_index_schema_name}' already exists.")
                else:
                    # Create database
                    create_db_sql = text(f"CREATE DATABASE `{self.home_index_schema_name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
                    conn.execute(create_db_sql)
                    conn.commit()
                    print(f"✅ Database '{self.home_index_schema_name}' created successfully.")
                
                return True
                
        except Exception as e:
            print(f"❌ Error creating home_index database: {e}")
            return False
    
    def create_home_index_user_and_permissions(self, config: dict) -> bool:
        """Create home_index user and grant permissions on home_index database only"""
        print(f"\n🔧 Creating home_index user '{self.home_index_user_name}' with limited permissions...")
        
        try:
            engine = create_engine(config["master_connection"])
            
            with engine.connect() as conn:
                # Check if user exists
                check_user_sql = text("""
                    SELECT User
                    FROM mysql.user
                    WHERE User = :user_name
                """)
                
                result = conn.execute(check_user_sql, {"user_name": self.home_index_user_name}).fetchone()
                
                if not result:
                    # Create MySQL user
                    create_user_sql = text(f"""
                        CREATE USER '{self.home_index_user_name}'@'%' IDENTIFIED BY '{self.home_index_user_password}'
                    """)
                    conn.execute(create_user_sql)
                    print(f"✅ User '{self.home_index_user_name}' created successfully.")
                else:
                    print(f"✅ User '{self.home_index_user_name}' already exists.")
                
                # Grant specific permissions on home_index database only
                grant_permissions_sql = text(f"""
                    GRANT SELECT, INSERT, UPDATE, DELETE ON `{self.home_index_schema_name}`.* TO '{self.home_index_user_name}'@'%'
                """)
                conn.execute(grant_permissions_sql)
                
                # Flush privileges to ensure they take effect
                flush_privileges_sql = text("FLUSH PRIVILEGES")
                conn.execute(flush_privileges_sql)
                
                conn.commit()
                print(f"✅ Limited permissions granted to user '{self.home_index_user_name}' on database '{self.home_index_schema_name}' only.")
                
                return True
                
        except Exception as e:
            print(f"❌ Error creating home_index user and permissions: {e}")
            return False
    
    def create_home_index_table(self, config: dict) -> bool:
        """Create the home_index table"""
        print(f"\n🔧 Creating home_index table...")
        
        try:
            # Use home index connection to connect to the specific database
            engine = create_engine(config["home_index_connection"])
            
            with engine.connect() as conn:
                # Check if table exists
                check_table_sql = text(f"""
                    SELECT TABLE_NAME
                    FROM INFORMATION_SCHEMA.TABLES
                    WHERE TABLE_SCHEMA = '{self.home_index_schema_name}' AND TABLE_NAME = 'home_index'
                """)
                
                result = conn.execute(check_table_sql).fetchone()
                
                if result:
                    print(f"✅ Table 'home_index' already exists.")
                else:
                    # Create home_index table
                    create_table_sql = text(f"""
                        CREATE TABLE `home_index` (
                            `phone_number` VARCHAR(20) PRIMARY KEY,
                            `home_id` INT NOT NULL,
                            `home_name` VARCHAR(50) NOT NULL,
                            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
                        ) ENGINE=InnoDB
                    """)
                    
                    conn.execute(create_table_sql)
                    conn.commit()
                    print(f"✅ Table 'home_index' created successfully.")
                    
                    # Create index on home_id
                    create_index_sql = text(f"""
                        CREATE INDEX idx_home_index_home_id ON `home_index` (`home_id`)
                    """)
                    
                    conn.execute(create_index_sql)
                    conn.commit()
                    print(f"✅ Index on 'home_id' column created successfully.")
                
                return True
                
        except Exception as e:
            print(f"❌ Error creating home_index table: {e}")
            return False
    
    def test_user_connection(self, config: dict) -> bool:
        """Test connection with the created user"""
        print(f"\n🔧 Testing user connection...")
        
        try:
            # Use the connection string from residents_db_config.py
            user_connection = config["user_connection"]
            engine = create_engine(user_connection)
            
            with engine.connect() as conn:
                # Test basic query
                test_sql = text(f"""
                    SELECT COUNT(*) as table_count
                    FROM INFORMATION_SCHEMA.TABLES 
                    WHERE TABLE_SCHEMA = '{self.database_name}'
                """)
                
                result = conn.execute(test_sql).fetchone()
                print(f"✅ User connection successful. Found {result[0]} tables in database '{self.database_name}'.")
                
                return True
                
        except Exception as e:
            print(f"❌ Error testing user connection: {e}")
            return False
    
    def test_home_index_connection(self, config: dict) -> bool:
        """Test connection with the home_index user"""
        print(f"\n🔧 Testing home_index user connection...")
        
        try:
            # Use the connection string from residents_db_config.py
            home_index_connection = config["home_index_connection"]
            engine = create_engine(home_index_connection)
            
            with engine.connect() as conn:
                # Test basic query
                test_sql = text(f"""
                    SELECT COUNT(*) as table_count
                    FROM INFORMATION_SCHEMA.TABLES
                    WHERE TABLE_SCHEMA = '{self.home_index_schema_name}'
                """)
                
                result = conn.execute(test_sql).fetchone()
                print(f"✅ Home_index user connection successful. Found {result[0]} tables in database '{self.home_index_schema_name}'.")
                
                return True
                
        except Exception as e:
            print(f"❌ Error testing home_index user connection: {e}")
            return False
    
    def display_connection_info(self, config: dict) -> bool:
        """Display connection information for manual configuration"""
        print(f"\n🔧 Connection Information:")
        print("=" * 50)
        
        print(f"Database Type: MySQL")
        print(f"Server: {config['server']}")
        print(f"Database: {self.database_name}")
        print(f"User: {self.user_name}")
        print(f"Password: {self.user_password}")
        print(f"User Connection String: {config['user_connection']}")
        print(f"Home Index Connection String: {config['home_index_connection']}")
        
        print("\n📝 Configuration is already set in residents_db_config.py:")
        print(f"✅ DATABASE_TYPE = \"mysql\"")
        print(f"✅ Connection strings are properly configured")
        print("✅ All database credentials are set")
        
        return True

def main():
    """Main setup function"""
    setup = MySQLDatabaseSetup()
    
    # Get configuration
    config = setup.get_connection_config()
    
    print(f"\n📋 Setup Summary:")
    print(f"   Database Type: MySQL")
    print(f"   Server: {config['server']}")
    print(f"   Database: {setup.database_name}")
    print(f"   User: {setup.user_name}")
    
    # Confirm before proceeding
    response = input("\nDo you want to proceed with this configuration? (y/N): ").strip().lower()
    if response != 'y':
        print("Setup cancelled.")
        return
    
    # Run setup steps
    steps = [
        ("Creating database", lambda: setup.create_database(config)),
        ("Creating user and permissions", lambda: setup.create_user_and_permissions(config)),
        ("Creating home table", lambda: setup.create_home_table(config)),
        ("Creating home_index database", lambda: setup.create_home_index_database(config)),
        ("Creating home_index user and permissions", lambda: setup.create_home_index_user_and_permissions(config)),
        ("Creating home_index table", lambda: setup.create_home_index_table(config)),
        ("Testing user connection", lambda: setup.test_user_connection(config)),
        ("Testing home_index connection", lambda: setup.test_home_index_connection(config)),
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
    print(f"🎉 RESIDENTS MYSQL DATABASE SETUP COMPLETE")
    print(f"{'='*60}")
    print(f"✅ {success_count}/{len(steps)} steps completed successfully")
    print()
    print("📋 What was created:")
    print(f"   • Database: {setup.database_name}")
    print(f"   • User: {setup.user_name} (password: {setup.user_password})")
    print(f"   • Table: {setup.database_name}.home")
    print(f"   • Home Index Database: {setup.home_index_schema_name}")
    print(f"   • Home Index User: {setup.home_index_user_name} (password: {setup.home_index_user_password})")
    print(f"   • Table: {setup.home_index_schema_name}.home_index")
    print()
    print("🚀 Next steps:")
    print("   1. Configure your API service using the connection information above")
    print("   2. Test the database connection")
    print("   3. Start your application")

if __name__ == "__main__":
    main()