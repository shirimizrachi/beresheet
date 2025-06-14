"""
DDL script for creating the users table in a specific schema
Usage: python create_users_table.py <schema_name>
"""

import sys
from sqlalchemy import create_engine, text

def create_users_table(schema_name: str):
    """
    Create the users table in the specified schema
    Drops the table first if it exists
    
    Args:
        schema_name: Name of the schema where the table should be created
    """
    
    # Connection string for the home database (using Windows Authentication)
    connection_string = "mssql+pyodbc://localhost\\SQLEXPRESS/home?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes&Trusted_Connection=yes"
    
    try:
        # Create SQLAlchemy engine
        engine = create_engine(connection_string)
        
        with engine.connect() as conn:
            # Drop table if exists
            drop_table_sql = text(f"""
                IF EXISTS (SELECT * FROM information_schema.tables 
                          WHERE table_schema = '{schema_name}' AND table_name = 'users')
                BEGIN
                    DROP TABLE [{schema_name}].[users]
                    PRINT 'Dropped existing users table in schema {schema_name}'
                END
            """)
            conn.execute(drop_table_sql)
            
            # Create users table
            create_table_sql = text(f"""
                CREATE TABLE [{schema_name}].[users] (
                    id NVARCHAR(50) PRIMARY KEY,
                    firebase_id NVARCHAR(50) UNIQUE NOT NULL,
                    home_id INT NOT NULL,
                    password NVARCHAR(255) NOT NULL,
                    display_name NVARCHAR(100),
                    full_name NVARCHAR(100),
                    email NVARCHAR(255),
                    phone_number NVARCHAR(20),
                    birth_date DATE,
                    birthday DATE,
                    gender NVARCHAR(10),
                    city NVARCHAR(50),
                    address NVARCHAR(255),
                    apartment_number NVARCHAR(50),
                    marital_status NVARCHAR(20),
                    religious NVARCHAR(50),
                    native_language NVARCHAR(50),
                    role NVARCHAR(50) DEFAULT 'resident',
                    service_provider_type NVARCHAR(100) NULL,
                    firebase_fcm_token NVARCHAR(500),
                    profile_photo_url NVARCHAR(500),
                    photo NVARCHAR(500),
                    created_at DATETIME2 DEFAULT GETDATE(),
                    updated_at DATETIME2 DEFAULT GETDATE()
                );
            """)
            conn.execute(create_table_sql)
            
            # Create indexes for better performance
            indexes_sql = text(f"""
                -- Index on firebase_id
                CREATE NONCLUSTERED INDEX IX_{schema_name}_users_firebase_id 
                ON [{schema_name}].[users](firebase_id);
                
                -- Index on home_id
                CREATE NONCLUSTERED INDEX IX_{schema_name}_users_home_id 
                ON [{schema_name}].[users](home_id);
                
                -- Index on phone_number
                CREATE NONCLUSTERED INDEX IX_{schema_name}_users_phone_number 
                ON [{schema_name}].[users](phone_number);
                
                -- Index on role
                CREATE NONCLUSTERED INDEX IX_{schema_name}_users_role
                ON [{schema_name}].[users](role);
                
                -- Index on service_provider_type
                CREATE NONCLUSTERED INDEX IX_{schema_name}_users_service_provider_type
                ON [{schema_name}].[users](service_provider_type);
                
                -- Index on firebase_fcm_token
                CREATE NONCLUSTERED INDEX IX_{schema_name}_users_firebase_fcm_token
                ON [{schema_name}].[users](firebase_fcm_token);
            """)
            conn.execute(indexes_sql)
            
            conn.commit()
            
            # Insert default test users with proper values matching UserProfile validation
            insert_user_sql = text(f"""
                INSERT INTO [{schema_name}].[users]
                (id, firebase_id, home_id, password, phone_number, full_name, role, birthday, apartment_number, marital_status, gender, religious, native_language, service_provider_type, firebase_fcm_token, created_at, updated_at)
                VALUES
                ('default-manager-user', 'default-manager-firebase', 1, '541111111', '541111111', 'Default Manager', 'manager', '1980-01-01', 'A1', 'single', 'male', 'secular', 'hebrew', NULL, NULL, GETDATE(), GETDATE()),
                ('test-staff-user', 'test-staff-firebase', 1, '541111222', '541111222', 'Test Staff', 'staff', '1985-05-15', 'B2', 'married', 'female', 'traditional', 'hebrew', NULL, NULL, GETDATE(), GETDATE()),
                ('test-service-construction', 'test-service-construction-firebase', 1, '541111333', '541111333', 'Construction Service', 'service', '1982-03-20', 'C3', 'single', 'male', 'secular', 'english', 'Maintenance', NULL, GETDATE(), GETDATE()),
                ('test-service-manager', 'test-service-manager-firebase', 1, '541111444', '541111444', 'Manager Service', 'service', '1978-12-10', 'D4', 'married', 'male', 'orthodox', 'hebrew', 'Manager', NULL, GETDATE(), GETDATE()),
                ('test-service-cleaning', 'test-service-cleaning-firebase', 1, '541111555', '541111555', 'Cleaning Service', 'service', '1990-08-25', 'E5', 'single', 'female', 'secular', 'hebrew', 'Cleaning Services', NULL, GETDATE(), GETDATE()),
                ('test-resident-user', 'test-resident-firebase', 1, '541111666', '541111666', 'Test Resident', 'resident', '1975-11-30', 'F6', 'married', 'male', 'traditional', 'hebrew', NULL, NULL, GETDATE(), GETDATE())
            """)
            conn.execute(insert_user_sql)
            conn.commit()
            
            print(f"Users table created successfully in schema '{schema_name}' with indexes.")
            print(f"Test users added:")
            print(f"  Manager: 541111111 / 541111111")
            print(f"  Staff: 541111222 / 541111222")
            print(f"  Service (Construction): 541111333 / 541111333")
            print(f"  Service (Manager): 541111444 / 541111444")
            print(f"  Service (Cleaning): 541111555 / 541111555")
            print(f"  Resident: 541111666 / 541111666")
            return True
            
    except Exception as e:
        print(f"Error creating users table in schema '{schema_name}': {e}")
        return False

def main():
    """Main function to handle command line arguments"""
    if len(sys.argv) != 2:
        print("Usage: python create_users_table.py <schema_name>")
        print("Example: python create_users_table.py beresheet")
        sys.exit(1)
    
    schema_name = sys.argv[1]
    
    if not schema_name.isalnum():
        print("Error: Schema name must be alphanumeric")
        sys.exit(1)
    
    success = create_users_table(schema_name)
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()