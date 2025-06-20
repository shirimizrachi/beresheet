"""
DDL script for creating the events table in a specific schema
Usage with API engine: create_events_table(engine, schema_name)
"""

from sqlalchemy import text

def create_events_table(engine, schema_name: str, drop_if_exists: bool = True):
    """
    Create the events table in the specified schema using provided engine
    
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
                              WHERE table_schema = '{schema_name}' AND table_name = 'events')
                    BEGIN
                        DROP TABLE [{schema_name}].[events]
                        PRINT 'Dropped existing events table in schema {schema_name}'
                    END
                """)
                conn.execute(drop_table_sql)
            
            # Create events table
            create_table_sql = text(f"""
                CREATE TABLE [{schema_name}].[events] (
                    id NVARCHAR(50) PRIMARY KEY,
                    name NVARCHAR(100) NOT NULL,
                    type NVARCHAR(50) NOT NULL,
                    description NVARCHAR(MAX),
                    dateTime DATETIME2 NOT NULL,
                    location NVARCHAR(200),
                    maxParticipants INT NOT NULL DEFAULT 0,
                    currentParticipants INT NOT NULL DEFAULT 0,
                    image_url NVARCHAR(500),
                    recurring NVARCHAR(50) DEFAULT 'none',
                    recurring_end_date DATETIME2 NULL,
                    recurring_pattern NVARCHAR(MAX) NULL,
                    instructor_name NVARCHAR(100) NULL,
                    instructor_desc NVARCHAR(MAX) NULL,
                    instructor_photo NVARCHAR(500) NULL,
                    created_at DATETIME2 DEFAULT GETDATE(),
                    updated_at DATETIME2 DEFAULT GETDATE(),
                    created_by NVARCHAR(50),
                    status NVARCHAR(20) DEFAULT 'active'
                );
            """)
            conn.execute(create_table_sql)
            
            # Create indexes for better performance
            indexes_sql = text(f"""
                -- Index on event type
                CREATE NONCLUSTERED INDEX IX_{schema_name}_events_type 
                ON [{schema_name}].[events](type);
                
                -- Index on dateTime for upcoming events queries
                CREATE NONCLUSTERED INDEX IX_{schema_name}_events_datetime 
                ON [{schema_name}].[events](dateTime);
                
                -- Index on status
                CREATE NONCLUSTERED INDEX IX_{schema_name}_events_status 
                ON [{schema_name}].[events](status);
                
                -- Index on created_by
                CREATE NONCLUSTERED INDEX IX_{schema_name}_events_created_by 
                ON [{schema_name}].[events](created_by);
                
                -- Composite index for upcoming events by type
                CREATE NONCLUSTERED INDEX IX_{schema_name}_events_type_datetime 
                ON [{schema_name}].[events](type, dateTime);
            """)
            conn.execute(indexes_sql)
            
            conn.commit()
            
            print(f"Events table created successfully in schema '{schema_name}' with indexes.")
            return True
            
    except Exception as e:
        print(f"Error creating events table in schema '{schema_name}': {e}")
        return False