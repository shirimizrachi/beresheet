"""
DDL script for creating the event_gallery table in a specific schema
Usage: python create_event_gallery_table.py <schema_name>
"""

import sys
from sqlalchemy import create_engine, text

def create_event_gallery_table(schema_name: str):
    """
    Create the event_gallery table in the specified schema
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
                    created_by NVARCHAR(50),
                    
                    -- Foreign key constraint to events table
                    FOREIGN KEY (event_id) REFERENCES [{schema_name}].[events](id) ON DELETE CASCADE
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

def main():
    """Main function to handle command line arguments"""
    if len(sys.argv) != 2:
        print("Usage: python create_event_gallery_table.py <schema_name>")
        print("Example: python create_event_gallery_table.py beresheet")
        sys.exit(1)
    
    schema_name = sys.argv[1]
    
    if not schema_name.isalnum():
        print("Error: Schema name must be alphanumeric")
        sys.exit(1)
    
    success = create_event_gallery_table(schema_name)
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()