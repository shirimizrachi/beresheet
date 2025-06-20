"""
DDL script for creating the requests table in a specific schema
Usage with API engine: create_requests_table(engine, schema_name)
"""

from sqlalchemy import text

def create_requests_table(engine, schema_name: str, drop_if_exists: bool = True):
    """
    Create the requests table in the specified schema using provided engine
    
    Args:
        engine: SQLAlchemy engine object
        schema_name: Name of the schema where the table should be created
        drop_if_exists: Whether to drop the table if it already exists
    """
    
    try:
        with engine.connect() as conn:
            # Drop table if exists and drop_if_exists is True
            if drop_if_exists:
                # First drop trigger if it exists
                drop_trigger_sql = text(f"""
                    IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'TR_{schema_name}_requests_update_timestamp')
                    BEGIN
                        DROP TRIGGER [{schema_name}].[TR_{schema_name}_requests_update_timestamp]
                        PRINT 'Dropped existing trigger TR_{schema_name}_requests_update_timestamp'
                    END
                """)
                conn.execute(drop_trigger_sql)
                
                # Then drop table if it exists
                drop_table_sql = text(f"""
                    IF EXISTS (SELECT * FROM information_schema.tables 
                              WHERE table_schema = '{schema_name}' AND table_name = 'requests')
                    BEGIN
                        DROP TABLE [{schema_name}].[requests]
                        PRINT 'Dropped existing requests table in schema {schema_name}'
                    END
                """)
                conn.execute(drop_table_sql)
            
            # Create requests table
            create_table_sql = text(f"""
                CREATE TABLE [{schema_name}].[requests] (
                    id NVARCHAR(50) PRIMARY KEY,
                    
                    -- Resident information
                    resident_id NVARCHAR(50) NOT NULL,
                    resident_phone_number NVARCHAR(20),
                    resident_full_name NVARCHAR(100),
                    resident_fcm_token NVARCHAR(500),
                    
                    -- Service provider information
                    service_provider_id NVARCHAR(50) NOT NULL,
                    service_provider_full_name NVARCHAR(100),
                    service_provider_phone_number NVARCHAR(20),
                    service_provider_fcm_token NVARCHAR(500),
                    service_provider_type_name NVARCHAR(100),
                    service_provider_type_description NVARCHAR(500),
                    
                    -- Request details
                    request_message NTEXT NOT NULL,
                    request_status NVARCHAR(20) DEFAULT 'open', -- 'open', 'in_progress', 'closed', 'abandoned'
                    
                    -- Timestamps
                    request_created_at DATETIME2 DEFAULT GETDATE(),
                    request_read_at DATETIME2 NULL,
                    request_closed_by_resident_at DATETIME2 NULL,
                    request_closed_by_service_provider_at DATETIME2 NULL,
                    
                    -- Communication and feedback
                    chat_messages NTEXT NULL, -- JSON string array of chat messages
                    service_rating INT NULL, -- 1-5 rating
                    service_comment NTEXT NULL,
                    
                    -- Duration calculation (in minutes)
                    request_duration_minutes INT NULL,
                    
                    -- Standard audit fields
                    created_at DATETIME2 DEFAULT GETDATE(),
                    updated_at DATETIME2 DEFAULT GETDATE()
                );
            """)
            conn.execute(create_table_sql)
            
            # Create indexes for better performance
            indexes_sql = text(f"""
                -- Index on resident_id for quick lookups by resident
                CREATE NONCLUSTERED INDEX IX_{schema_name}_requests_resident_id 
                ON [{schema_name}].[requests](resident_id);
                
                -- Index on service_provider_id for quick lookups by service provider
                CREATE NONCLUSTERED INDEX IX_{schema_name}_requests_service_provider_id 
                ON [{schema_name}].[requests](service_provider_id);
                
                -- Index on request_status for filtering by status
                CREATE NONCLUSTERED INDEX IX_{schema_name}_requests_status 
                ON [{schema_name}].[requests](request_status);
                
                -- Index on request_created_at for chronological sorting
                CREATE NONCLUSTERED INDEX IX_{schema_name}_requests_created_at 
                ON [{schema_name}].[requests](request_created_at);
                
                -- Composite index for active requests by service provider
                CREATE NONCLUSTERED INDEX IX_{schema_name}_requests_service_provider_status 
                ON [{schema_name}].[requests](service_provider_id, request_status);
                
                -- Composite index for active requests by resident
                CREATE NONCLUSTERED INDEX IX_{schema_name}_requests_resident_status
                ON [{schema_name}].[requests](resident_id, request_status);
                
                -- Index on service_provider_type_name for filtering by service type
                CREATE NONCLUSTERED INDEX IX_{schema_name}_requests_service_provider_type_name
                ON [{schema_name}].[requests](service_provider_type_name);
                
                -- Composite index for filtering by service provider type and status
                CREATE NONCLUSTERED INDEX IX_{schema_name}_requests_service_type_status
                ON [{schema_name}].[requests](service_provider_type_name, request_status);
            """)
            conn.execute(indexes_sql)
            
            # Create trigger to automatically update updated_at timestamp
            trigger_sql = text(f"""
                CREATE TRIGGER TR_{schema_name}_requests_update_timestamp
                ON [{schema_name}].[requests]
                AFTER UPDATE
                AS
                BEGIN
                    SET NOCOUNT ON;
                    UPDATE [{schema_name}].[requests]
                    SET updated_at = GETDATE()
                    FROM [{schema_name}].[requests] r
                    INNER JOIN inserted i ON r.id = i.id;
                END;
            """)
            conn.execute(trigger_sql)
            
            conn.commit()
            
            print(f"Requests table created successfully in schema '{schema_name}' with indexes and triggers.")
            print(f"Table supports communication tracking between residents and service providers.")
            return True
            
    except Exception as e:
        print(f"Error creating requests table in schema '{schema_name}': {e}")
        return False