"""
DDL script for creating the events_registration table in a specific schema
Usage with API engine: create_events_registration_table(engine, schema_name)
"""

from sqlalchemy import text

def create_events_registration_table(engine, schema_name: str, drop_if_exists: bool = True):
    """
    Create the events_registration table in the specified schema using provided engine
    
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
                              WHERE table_schema = '{schema_name}' AND table_name = 'events_registration')
                    BEGIN
                        DROP TABLE [{schema_name}].[events_registration]
                        PRINT 'Dropped existing events_registration table in schema {schema_name}'
                    END
                """)
                conn.execute(drop_table_sql)
            
            # Create events_registration table
            create_table_sql = text(f"""
                CREATE TABLE [{schema_name}].[events_registration] (
                    id NVARCHAR(50) PRIMARY KEY,
                    event_id NVARCHAR(50) NOT NULL,
                    user_id NVARCHAR(50) NOT NULL,
                    user_name NVARCHAR(100),
                    user_phone NVARCHAR(20),
                    registration_date DATETIME2 DEFAULT GETDATE(),
                    status NVARCHAR(20) DEFAULT 'registered',
                    vote INT NULL CHECK (vote >= 1 AND vote <= 5),
                    reviews NVARCHAR(MAX),
                    instructor_name NVARCHAR(100) NULL,
                    instructor_desc NVARCHAR(MAX) NULL,
                    instructor_photo NVARCHAR(500) NULL,
                    created_at DATETIME2 DEFAULT GETDATE(),
                    updated_at DATETIME2 DEFAULT GETDATE(),
                    
                    -- Unique constraint to prevent duplicate registrations
                    CONSTRAINT UK_{schema_name}_events_registration_user_event
                        UNIQUE (event_id, user_id)
                );
            """)
            conn.execute(create_table_sql)
            
            # Create indexes for better performance
            indexes_sql = text(f"""
                -- Index on event_id for fast lookup of event registrations
                CREATE NONCLUSTERED INDEX IX_{schema_name}_events_registration_event_id 
                ON [{schema_name}].[events_registration](event_id);
                
                -- Index on user_id for fast lookup of user registrations
                CREATE NONCLUSTERED INDEX IX_{schema_name}_events_registration_user_id 
                ON [{schema_name}].[events_registration](user_id);
                
                -- Index on registration_date for chronological queries
                CREATE NONCLUSTERED INDEX IX_{schema_name}_events_registration_date 
                ON [{schema_name}].[events_registration](registration_date);
                
                -- Index on status
                CREATE NONCLUSTERED INDEX IX_{schema_name}_events_registration_status 
                ON [{schema_name}].[events_registration](status);
                
                -- Composite index for event and registration date
                CREATE NONCLUSTERED INDEX IX_{schema_name}_events_registration_event_date 
                ON [{schema_name}].[events_registration](event_id, registration_date);
            """)
            conn.execute(indexes_sql)
            
            conn.commit()
            
            print(f"Events registration table created successfully in schema '{schema_name}' with indexes and constraints.")
            return True
            
    except Exception as e:
        print(f"Error creating events registration table in schema '{schema_name}': {e}")
        return False