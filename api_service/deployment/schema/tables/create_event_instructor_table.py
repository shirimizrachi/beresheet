"""
DDL script for creating the event_instructor table in a specific schema
Usage with API engine: create_event_instructor_table(engine, schema_name)
"""

from sqlalchemy import text

def create_event_instructor_table(engine, schema_name: str, drop_if_exists: bool = True):
    """
    Create the event_instructor table in the specified schema using provided engine
    
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
                              WHERE table_schema = '{schema_name}' AND table_name = 'event_instructor')
                    BEGIN
                        DROP TABLE [{schema_name}].[event_instructor]
                        PRINT 'Dropped existing event_instructor table in schema {schema_name}'
                    END
                """)
                conn.execute(drop_table_sql)
            
            # Create event_instructor table
            create_table_sql = text(f"""
                CREATE TABLE [{schema_name}].[event_instructor] (
                    id NVARCHAR(36) PRIMARY KEY,
                    name NVARCHAR(255) NOT NULL,
                    description NVARCHAR(MAX) NULL,
                    photo NVARCHAR(1000) NULL,
                    created_at DATETIME2 DEFAULT GETDATE(),
                    updated_at DATETIME2 DEFAULT GETDATE()
                );
            """)
            conn.execute(create_table_sql)
            
            # Create indexes for better performance
            indexes_sql = text(f"""
                -- Index on name
                CREATE NONCLUSTERED INDEX IX_{schema_name}_event_instructor_name 
                ON [{schema_name}].[event_instructor](name);
            """)
            conn.execute(indexes_sql)
            
            conn.commit()
            
            print(f"Event_instructor table created successfully in schema '{schema_name}' with indexes.")
            return True
            
    except Exception as e:
        print(f"Error creating event_instructor table in schema '{schema_name}': {e}")
        return False