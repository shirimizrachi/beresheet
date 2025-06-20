"""
Script to create the tenant configuration table in the admin database
This table stores all tenant configurations for multi-tenant routing
"""

import sys
import pyodbc
from sqlalchemy import create_engine, text

def create_tenant_table():
    """
    Create the tenant configuration table in the admin database
    """
    
    # Connection string for the admin database
    #connection_string = "mssql+pyodbc://localhost\\SQLEXPRESS/home_admin?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes&Trusted_Connection=yes"
    connection_string = "mssql+pyodbc://localhost\\SQLEXPRESS/home?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes&Trusted_Connection=yes"
    
    try:
        # Create SQLAlchemy engine
        engine = create_engine(connection_string)
        
        with engine.connect() as conn:
            # Check if table already exists
            check_table_sql = text("""
                SELECT TABLE_NAME 
                FROM INFORMATION_SCHEMA.TABLES 
                WHERE TABLE_SCHEMA = 'home' AND TABLE_NAME = 'home'
            """)
            
            result = conn.execute(check_table_sql).fetchone()
            
            if result:
                print("Tenant table 'home.home' already exists in admin database.")
                return True
            
            # Create the tenant configuration table
            create_table_sql = text("""
                CREATE TABLE [home].[home] (
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
            
            print("Tenant configuration table 'home.home' created successfully.")
            
            # Create an index on the name column for fast lookups
            create_index_sql = text("""
                CREATE INDEX IX_home_name ON [home].[home] ([name])
            """)
            
            conn.execute(create_index_sql)
            conn.commit()
            
            print("Index on 'name' column created successfully.")
            
            # Create a trigger to automatically update the updated_at column
            create_trigger_sql = text("""
                CREATE TRIGGER [home].[tr_home_update_timestamp]
                ON [home].[home]
                AFTER UPDATE
                AS
                BEGIN
                    SET NOCOUNT ON;
                    UPDATE [home].[home]
                    SET [updated_at] = GETDATE()
                    FROM [home].[home] h
                    INNER JOIN inserted i ON h.id = i.id;
                END
            """)
            
            conn.execute(create_trigger_sql)
            conn.commit()
            
            print("Update timestamp trigger created successfully.")
            
            return True
            
    except Exception as e:
        print(f"Error creating tenant table: {e}")
        return False

def verify_table_structure():
    """
    Verify the table structure is correct
    """
    
    connection_string = "mssql+pyodbc://localhost\\SQLEXPRESS/home?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes&Trusted_Connection=yes"
    
    try:
        engine = create_engine(connection_string)
        
        with engine.connect() as conn:
            # Get table structure
            structure_sql = text("""
                SELECT 
                    COLUMN_NAME,
                    DATA_TYPE,
                    IS_NULLABLE,
                    COLUMN_DEFAULT
                FROM INFORMATION_SCHEMA.COLUMNS 
                WHERE TABLE_SCHEMA = 'home' AND TABLE_NAME = 'home'
                ORDER BY ORDINAL_POSITION
            """)
            
            result = conn.execute(structure_sql).fetchall()
            
            print("\nTable structure verification:")
            print("Column Name          | Data Type    | Nullable | Default")
            print("-" * 60)
            
            for row in result:
                column_name = row[0].ljust(20)
                data_type = row[1].ljust(12)
                nullable = row[2].ljust(8)
                default = str(row[3]) if row[3] else "None"
                print(f"{column_name}| {data_type}| {nullable}| {default}")
            
            return True
            
    except Exception as e:
        print(f"Error verifying table structure: {e}")
        return False

def main():
    """Main function to create and verify tenant table"""
    print("Creating tenant configuration table...")
    
    # Create tenant table
    if not create_tenant_table():
        print("Failed to create tenant table")
        sys.exit(1)
    
    # Verify table structure
    if not verify_table_structure():
        print("Failed to verify table structure")
        sys.exit(1)
    
    print("\nTenant configuration table setup completed successfully!")
    print("Next step: Run init_tenant_data.py to insert initial tenant configurations")

if __name__ == "__main__":
    main()