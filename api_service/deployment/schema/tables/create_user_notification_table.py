"""
DDL script for creating the user_notification table in a specific schema
Usage with API engine: create_user_notification_table(engine, schema_name)
"""

from sqlalchemy import text

def create_user_notification_table(engine, schema_name: str, drop_if_exists: bool = True):
    """
    Create the user_notification table in the specified schema using provided engine
    
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
                              WHERE table_schema = '{schema_name}' AND table_name = 'user_notification')
                    BEGIN
                        DROP TABLE [{schema_name}].[user_notification]
                        PRINT 'Dropped existing user_notification table in schema {schema_name}'
                    END
                """)
                conn.execute(drop_table_sql)
            
            # Create user_notification table
            create_table_sql = text(f"""
                CREATE TABLE [{schema_name}].[user_notification] (
                    id INT IDENTITY(1,1) PRIMARY KEY,
                    user_id NVARCHAR(50) NOT NULL,
                    user_read_date DATETIME2 NULL,
                    user_fcm NVARCHAR(MAX) NULL,
                    notification_id INT NOT NULL,
                    notification_sender_user_id NVARCHAR(50) NOT NULL,
                    notification_sender_user_name NVARCHAR(255) NOT NULL,
                    notification_sender_user_role_name NVARCHAR(100) NOT NULL,
                    notification_sender_user_service_provider_type_name NVARCHAR(255) NULL,
                    notification_status NVARCHAR(20) NOT NULL DEFAULT 'pending',
                    notification_time DATETIME2 NOT NULL DEFAULT GETDATE(),
                    notification_message NVARCHAR(MAX) NOT NULL,
                    notification_type NVARCHAR(20) NOT NULL DEFAULT 'regular',
                    created_at DATETIME2 DEFAULT GETDATE(),
                    updated_at DATETIME2 DEFAULT GETDATE(),
                    
                    -- Check constraints
                    CONSTRAINT CK_{schema_name}_user_notification_status 
                        CHECK (notification_status IN ('pending', 'sent', 'read', 'canceled')),
                    CONSTRAINT CK_{schema_name}_user_notification_type 
                        CHECK (notification_type IN ('regular', 'urgent'))
                );
            """)
            conn.execute(create_table_sql)
            
            # Create indexes for better performance
            indexes_sql = text(f"""
                -- Index on user_id for fast lookup of user notifications
                CREATE NONCLUSTERED INDEX IX_{schema_name}_user_notification_user_id 
                ON [{schema_name}].[user_notification](user_id);
                
                -- Index on notification_id for linking to home_notification
                CREATE NONCLUSTERED INDEX IX_{schema_name}_user_notification_notification_id 
                ON [{schema_name}].[user_notification](notification_id);
                
                -- Index on notification_status for filtering
                CREATE NONCLUSTERED INDEX IX_{schema_name}_user_notification_status 
                ON [{schema_name}].[user_notification](notification_status);
                
                -- Index on notification_time for chronological queries
                CREATE NONCLUSTERED INDEX IX_{schema_name}_user_notification_time 
                ON [{schema_name}].[user_notification](notification_time);
                
                -- Composite index for user and status
                CREATE NONCLUSTERED INDEX IX_{schema_name}_user_notification_user_status 
                ON [{schema_name}].[user_notification](user_id, notification_status);
                
                -- Composite index for notification and user
                CREATE NONCLUSTERED INDEX IX_{schema_name}_user_notification_notif_user 
                ON [{schema_name}].[user_notification](notification_id, user_id);
            """)
            conn.execute(indexes_sql)
            
            conn.commit()
            
            print(f"User notification table created successfully in schema '{schema_name}' with indexes and constraints.")
            return True
            
    except Exception as e:
        print(f"Error creating user notification table in schema '{schema_name}': {e}")
        return False
