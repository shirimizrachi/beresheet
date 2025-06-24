"""
DDL script for creating the home_notification table in a specific schema
Usage with API engine: create_home_notification_table(engine, schema_name)
"""

from sqlalchemy import text

def create_home_notification_table(engine, schema_name: str, drop_if_exists: bool = True):
    """
    Create the home_notification table in the specified schema using provided engine
    
    Args:
        engine: SQLAlchemy engine object
        schema_name: Name of the schema where the table should be created
        drop_if_exists: Whether to drop the table if it already exists
    """
    
    try:
        with engine.connect() as conn:
            # Drop table if exists and drop_if_exists is True
            if drop_if_exists:
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
                    id NVARCHAR(36) PRIMARY KEY,
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
