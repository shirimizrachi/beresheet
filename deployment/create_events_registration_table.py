"""
DDL script for creating the events_registration table in a specific schema
Usage: python create_events_registration_table.py <schema_name>
"""

import sys
from sqlalchemy import create_engine, text

def create_events_registration_table(schema_name: str):
    """
    Create the events_registration table in the specified schema
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
                    notes NVARCHAR(MAX),
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

def main():
    """Main function to handle command line arguments"""
    if len(sys.argv) != 2:
        print("Usage: python create_events_registration_table.py <schema_name>")
        print("Example: python create_events_registration_table.py beresheet")
        sys.exit(1)
    
    schema_name = sys.argv[1]
    
    if not schema_name.isalnum():
        print("Error: Schema name must be alphanumeric")
        sys.exit(1)
    
    success = create_events_registration_table(schema_name)
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()