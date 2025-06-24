"""
DDL script for creating the rooms table in a specific schema
Usage with API engine: create_rooms_table(engine, schema_name)
"""

from sqlalchemy import text

def create_rooms_table(engine, schema_name: str, drop_if_exists: bool = True):
    """
    Create the rooms table in the specified schema using provided engine
    
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
                              WHERE table_schema = '{schema_name}' AND table_name = 'rooms')
                    BEGIN
                        DROP TABLE [{schema_name}].[rooms]
                        PRINT 'Dropped existing rooms table in schema {schema_name}'
                    END
                """)
                conn.execute(drop_table_sql)
            
            # Create rooms table
            create_table_sql = text(f"""
                CREATE TABLE [{schema_name}].[rooms] (
                    id NVARCHAR(36) PRIMARY KEY,
                    room_name NVARCHAR(100) NOT NULL UNIQUE,
                    created_at DATETIME2 DEFAULT GETDATE(),
                    updated_at DATETIME2 DEFAULT GETDATE()
                );
            """)
            conn.execute(create_table_sql)
            
            # Create indexes for better performance
            indexes_sql = text(f"""
                -- Index on room_name
                CREATE NONCLUSTERED INDEX IX_{schema_name}_rooms_room_name 
                ON [{schema_name}].[rooms](room_name);
            """)
            conn.execute(indexes_sql)
            
            conn.commit()
            
            print(f"Rooms table created successfully in schema '{schema_name}' with indexes.")
            return True
            
    except Exception as e:
        print(f"Error creating rooms table in schema '{schema_name}': {e}")
        return False