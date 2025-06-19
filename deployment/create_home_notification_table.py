"""
DDL script for creating the home_notification table in a specific schema
Usage: python create_home_notification_table.py <schema_name>
"""

import sys
from sqlalchemy import create_engine, text

def create_home_notification_table(schema_name: str):
    """
    Create the home_notification table in the specified schema
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
                          WHERE table_schema = '{schema_name}' AND table_name = 'home_notification')
                BEGIN
                    DROP TABLE [{schema_name}].[home_notification]
                    PRINT 'Dropped existing home_notification table in schema {schema_name}'
                END
            """)
            conn.execute(drop_table_sql)
            
            # Create home_notification table
            create_table_sql = text(f"""
                CREATE TABLE [{schema_name}].[home_notification] (
                    id INT IDENTITY(1,1) PRIMARY KEY,
                    create_by_user_id NVARCHAR(50) NOT NULL,
                    create_by_user_name NVARCHAR(255) NOT NULL,
                    create_by_user_role_name NVARCHAR(100) NOT NULL,
                    create_by_user_service_provider_type_name NVARCHAR(255) NULL,
                    message NVARCHAR(MAX) NOT NULL,
                    send_status NVARCHAR(50) NOT NULL DEFAULT 'pending-approval',
                    send_approved_by_user_id NVARCHAR(50) NULL,
                    send_floor INT NULL,
                    send_datetime DATETIME2 NOT NULL DEFAULT GETDATE(),
                    send_type NVARCHAR(20) NOT NULL DEFAULT 'regular',
                    created_at DATETIME2 DEFAULT GETDATE(),
                    updated_at DATETIME2 DEFAULT GETDATE(),
                    
                    -- Check constraints
                    CONSTRAINT CK_{schema_name}_home_notification_send_status 
                        CHECK (send_status IN ('pending-approval', 'approved', 'canceled', 'sent')),
                    CONSTRAINT CK_{schema_name}_home_notification_send_type 
                        CHECK (send_type IN ('regular', 'urgent'))
                );
            """)
            conn.execute(create_table_sql)
            
            # Create indexes for better performance
            indexes_sql = text(f"""
                -- Index on send_status for filtering
                CREATE NONCLUSTERED INDEX IX_{schema_name}_home_notification_send_status 
                ON [{schema_name}].[home_notification](send_status);
                
                -- Index on send_datetime for chronological queries
                CREATE NONCLUSTERED INDEX IX_{schema_name}_home_notification_send_datetime 
                ON [{schema_name}].[home_notification](send_datetime);
                
                -- Index on create_by_user_id for user-specific queries
                CREATE NONCLUSTERED INDEX IX_{schema_name}_home_notification_create_by_user_id 
                ON [{schema_name}].[home_notification](create_by_user_id);
                
                -- Index on send_floor for floor-specific queries
                CREATE NONCLUSTERED INDEX IX_{schema_name}_home_notification_send_floor 
                ON [{schema_name}].[home_notification](send_floor);
                
                -- Composite index for status and date ordering
                CREATE NONCLUSTERED INDEX IX_{schema_name}_home_notification_status_date 
                ON [{schema_name}].[home_notification](send_status, send_datetime DESC);
            """)
            conn.execute(indexes_sql)
            
            conn.commit()
            
            print(f"Home notification table created successfully in schema '{schema_name}' with indexes and constraints.")
            return True
            
    except Exception as e:
        print(f"Error creating home notification table in schema '{schema_name}': {e}")
        return False

def main():
    """Main function to handle command line arguments"""
    if len(sys.argv) != 2:
        print("Usage: python create_home_notification_table.py <schema_name>")
        print("Example: python create_home_notification_table.py beresheet")
        sys.exit(1)
    
    schema_name = sys.argv[1]
    
    if not schema_name.isalnum():
        print("Error: Schema name must be alphanumeric")
        sys.exit(1)
    
    success = create_home_notification_table(schema_name)
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()
