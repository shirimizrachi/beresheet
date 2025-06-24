"""
DDL script for creating the event_gallery table in a specific schema
Usage with API engine: create_event_gallery_table(engine, schema_name)
"""

from sqlalchemy import text

def create_event_gallery_table(engine, schema_name: str, drop_if_exists: bool = True):
    """
    Create the event_gallery table in the specified schema using provided engine
    
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
                              WHERE table_schema = '{schema_name}' AND table_name = 'event_gallery')
                    BEGIN
                        DROP TABLE [{schema_name}].[event_gallery]
                        PRINT 'Dropped existing event_gallery table in schema {schema_name}'
                    END
                """)
                conn.execute(drop_table_sql)
            
            # Create event_gallery table
            create_table_sql = text(f"""
                CREATE TABLE [{schema_name}].[event_gallery] (
                    photo_id NVARCHAR(50) PRIMARY KEY,
                    event_id NVARCHAR(50) NOT NULL,
                    photo NVARCHAR(500) NOT NULL,
                    thumbnail_url NVARCHAR(500) NULL,
                    created_at DATETIME2 DEFAULT GETDATE(),
                    updated_at DATETIME2 DEFAULT GETDATE(),
                    created_by NVARCHAR(50)
                );
            """)
            conn.execute(create_table_sql)
            
            # Create indexes for better performance
            indexes_sql = text(f"""
                -- Index on event_id for quick gallery lookups
                CREATE NONCLUSTERED INDEX IX_{schema_name}_event_gallery_event_id 
                ON [{schema_name}].[event_gallery](event_id);
                
                -- Index on created_at for ordering
                CREATE NONCLUSTERED INDEX IX_{schema_name}_event_gallery_created_at 
                ON [{schema_name}].[event_gallery](created_at);
                
                -- Index on created_by
                CREATE NONCLUSTERED INDEX IX_{schema_name}_event_gallery_created_by 
                ON [{schema_name}].[event_gallery](created_by);
            """)
            conn.execute(indexes_sql)
            
            conn.commit()
            
            print(f"Event gallery table created successfully in schema '{schema_name}' with indexes.")
            return True
            
    except Exception as e:
        print(f"Error creating event_gallery table in schema '{schema_name}': {e}")
        return False