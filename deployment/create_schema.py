"""
Script to create a new schema in the home database
Usage: python create_schema.py <schema_name>
"""

import sys
import pyodbc
from sqlalchemy import create_engine, text

def create_schema(schema_name: str):
    """
    Create a new schema in the home database
    
    Args:
        schema_name: Name of the schema to create
    """
    
    # Connection string for the home database (using Windows Authentication)
    connection_string = "mssql+pyodbc://localhost\\SQLEXPRESS/home?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes&Trusted_Connection=yes"
    
    try:
        # Create SQLAlchemy engine
        engine = create_engine(connection_string)
        
        with engine.connect() as conn:
            # Check if schema already exists
            check_schema_sql = text("""
                SELECT schema_name 
                FROM information_schema.schemata 
                WHERE schema_name = :schema_name
            """)
            
            result = conn.execute(check_schema_sql, {"schema_name": schema_name}).fetchone()
            
            if result:
                print(f"Schema '{schema_name}' already exists.")
                return True
            
            # Create the schema
            create_schema_sql = text(f"CREATE SCHEMA [{schema_name}]")
            conn.execute(create_schema_sql)
            conn.commit()
            
            print(f"Schema '{schema_name}' created successfully.")
            return True
            
    except Exception as e:
        print(f"Error creating schema '{schema_name}': {e}")
        return False

def main():
    """Main function to handle command line arguments"""
    if len(sys.argv) != 2:
        print("Usage: python create_schema.py <schema_name>")
        print("Example: python create_schema.py beresheet")
        sys.exit(1)
    
    schema_name = sys.argv[1]
    
    if not schema_name.isalnum():
        print("Error: Schema name must be alphanumeric")
        sys.exit(1)
    
    success = create_schema(schema_name)
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()