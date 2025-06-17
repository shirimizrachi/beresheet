"""
DDL script for creating the event_instructor table in a specific schema
Usage: python create_event_instructor_table.py <schema_name>
"""

import sys
from sqlalchemy import create_engine, text

def create_event_instructor_table(schema_name: str):
    """
    Create the event_instructor table in the specified schema
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
                    id INT IDENTITY(1,1) PRIMARY KEY,
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

def main():
    """Main function to handle command line arguments"""
    if len(sys.argv) != 2:
        print("Usage: python create_event_instructor_table.py <schema_name>")
        print("Example: python create_event_instructor_table.py beresheet")
        sys.exit(1)
    
    schema_name = sys.argv[1]
    
    if not schema_name.isalnum():
        print("Error: Schema name must be alphanumeric")
        sys.exit(1)
    
    success = create_event_instructor_table(schema_name)
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()