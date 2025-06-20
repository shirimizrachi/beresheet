"""
DDL script for creating the service_provider_types table in a specific schema
Usage with API engine: create_service_provider_types_table(engine, schema_name)
"""

from sqlalchemy import text

def create_service_provider_types_table(engine, schema_name: str, drop_if_exists: bool = True):
    """
    Create the service_provider_types table in the specified schema using provided engine
    
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
                              WHERE table_schema = '{schema_name}' AND table_name = 'service_provider_types')
                    BEGIN
                        DROP TABLE [{schema_name}].[service_provider_types]
                        PRINT 'Dropped existing service_provider_types table in schema {schema_name}'
                    END
                """)
                conn.execute(drop_table_sql)
            
            # Create service_provider_types table
            create_table_sql = text(f"""
                CREATE TABLE [{schema_name}].[service_provider_types] (
                    id INT IDENTITY(1,1) PRIMARY KEY,
                    name NVARCHAR(100) UNIQUE NOT NULL,
                    description NVARCHAR(500),
                    created_at DATETIME2 DEFAULT GETDATE(),
                    updated_at DATETIME2 DEFAULT GETDATE()
                );
            """)
            conn.execute(create_table_sql)
            
            # Create indexes for better performance
            indexes_sql = text(f"""
                -- Index on name for quick lookups
                CREATE NONCLUSTERED INDEX IX_{schema_name}_service_provider_types_name 
                ON [{schema_name}].[service_provider_types](name);
            """)
            conn.execute(indexes_sql)
            
            conn.commit()
            
            print(f"Service provider types table created successfully in schema '{schema_name}' with indexes.")
            return True
            
    except Exception as e:
        print(f"Error creating service_provider_types table in schema '{schema_name}': {e}")
        return False