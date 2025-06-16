"""
DDL script for creating the service_provider_types table in a specific schema
Usage: python create_service_provider_types_table.py <schema_name>
"""

import sys
from sqlalchemy import create_engine, text

def create_service_provider_types_table(schema_name: str):
    """
    Create the service_provider_types table in the specified schema
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
            
            # Insert default service provider types
            insert_default_types_sql = text(f"""
                INSERT INTO [{schema_name}].[service_provider_types]
                (name, description, created_at, updated_at)
                VALUES
                (N'תחזוקה', N'שירותי תחזוקה כלליים', GETDATE(), GETDATE()),
                (N'שרות לדייר', N'שירותי תמיכה ועזרה לדיירים', GETDATE(), GETDATE()),
                (N'משק', N'שירותי משק ביתי', GETDATE(), GETDATE()),
                (N'עובדת סוציאלית', N'שירותי רווחה וייעוץ', GETDATE(), GETDATE()),
                (N'אחות', N'שירותי בריאות', GETDATE(), GETDATE()),
                (N'תרבות', N'שירותי תרבות ופנאי', GETDATE(), GETDATE()),
                (N'מנהל חשבונות', N'שירותי ניהול כספים וחשבונות', GETDATE(), GETDATE()),
                (N'מנהל', N'שירותי ניהול', GETDATE(), GETDATE())
            """)
            conn.execute(insert_default_types_sql)
            conn.commit()
            
            print(f"Service provider types table created successfully in schema '{schema_name}' with indexes.")
            print(f"Default service provider types added.")
            return True
            
    except Exception as e:
        print(f"Error creating service_provider_types table in schema '{schema_name}': {e}")
        return False

def main():
    """Main function to handle command line arguments"""
    if len(sys.argv) != 2:
        print("Usage: python create_service_provider_types_table.py <schema_name>")
        print("Example: python create_service_provider_types_table.py beresheet")
        sys.exit(1)
    
    schema_name = sys.argv[1]
    
    if not schema_name.isalnum():
        print("Error: Schema name must be alphanumeric")
        sys.exit(1)
    
    success = create_service_provider_types_table(schema_name)
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()