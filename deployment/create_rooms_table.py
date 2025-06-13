"""
DDL script for creating the rooms table in a specific schema
Usage: python create_rooms_table.py <schema_name>
"""

import sys
from sqlalchemy import create_engine, text

def create_rooms_table(schema_name: str):
    """
    Create the rooms table in the specified schema
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
                    id INT IDENTITY(1,1) PRIMARY KEY,
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
            
            # Insert some default rooms
            insert_rooms_sql = text(f"""
                INSERT INTO [{schema_name}].[rooms] (room_name, created_at, updated_at)
                VALUES
                ('Main Hall', GETDATE(), GETDATE()),
                ('Conference Room', GETDATE(), GETDATE()),
                ('Activity Room', GETDATE(), GETDATE()),
                ('Library', GETDATE(), GETDATE()),
                ('Garden', GETDATE(), GETDATE())
            """)
            conn.execute(insert_rooms_sql)
            conn.commit()
            
            print(f"Rooms table created successfully in schema '{schema_name}' with indexes.")
            print(f"Default rooms added: Main Hall, Conference Room, Activity Room, Library, Garden")
            return True
            
    except Exception as e:
        print(f"Error creating rooms table in schema '{schema_name}': {e}")
        return False

def main():
    """Main function to handle command line arguments"""
    if len(sys.argv) != 2:
        print("Usage: python create_rooms_table.py <schema_name>")
        print("Example: python create_rooms_table.py beresheet")
        sys.exit(1)
    
    schema_name = sys.argv[1]
    
    if not schema_name.isalnum():
        print("Error: Schema name must be alphanumeric")
        sys.exit(1)
    
    success = create_rooms_table(schema_name)
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()