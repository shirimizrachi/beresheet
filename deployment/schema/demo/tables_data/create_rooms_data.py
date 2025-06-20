"""
Data insertion script for the rooms table with Hebrew examples
Usage: python create_rooms_data.py <schema_name>
"""

import sys
from sqlalchemy import create_engine, text

def insert_rooms_data(schema_name: str):
    """
    Insert sample Hebrew room data into the rooms table
    
    Args:
        schema_name: Name of the schema where the table exists
    """
    
    # Connection string for the home database (using Windows Authentication)
    connection_string = "mssql+pyodbc://localhost\\SQLEXPRESS/home?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes&Trusted_Connection=yes"
    
    try:
        # Create SQLAlchemy engine
        engine = create_engine(connection_string)
        
        with engine.connect() as conn:
            # Insert Hebrew rooms
            insert_rooms_sql = text(f"""
                INSERT INTO [{schema_name}].[rooms] (room_name, created_at, updated_at)
                VALUES
                (N'אולם ראשי', GETDATE(), GETDATE()),
                (N'חדר ישיבות', GETDATE(), GETDATE()),
                (N'חדר פעילות', GETDATE(), GETDATE()),
                (N'ספרייה', GETDATE(), GETDATE()),
                (N'גינה', GETDATE(), GETDATE()),
                (N'חדר יצירה', GETDATE(), GETDATE()),
                (N'חדר מוזיקה', GETDATE(), GETDATE()),
                (N'חדר כושר', GETDATE(), GETDATE()),
                (N'מטבח', GETDATE(), GETDATE()),
                (N'חדר מדיטציה', GETDATE(), GETDATE())
            """)
            conn.execute(insert_rooms_sql)
            conn.commit()
            
            print(f"Sample Hebrew room data inserted successfully into schema '{schema_name}'")
            print("Rooms added:")
            print("- אולם ראשי (Main Hall)")
            print("- חדר ישיבות (Conference Room)")
            print("- חדר פעילות (Activity Room)")
            print("- ספרייה (Library)")
            print("- גינה (Garden)")
            print("- חדר יצירה (Creation Room)")
            print("- חדר מוזיקה (Music Room)")
            print("- חדר כושר (Fitness Room)")
            print("- מטבח (Kitchen)")
            print("- חדר מדיטציה (Meditation Room)")
            return True
            
    except Exception as e:
        print(f"Error inserting room data into schema '{schema_name}': {e}")
        return False

def main():
    """Main function to handle command line arguments"""
    if len(sys.argv) != 2:
        print("Usage: python create_rooms_data.py <schema_name>")
        print("Example: python create_rooms_data.py beresheet")
        sys.exit(1)
    
    schema_name = sys.argv[1]
    
    if not schema_name.isalnum():
        print("Error: Schema name must be alphanumeric")
        sys.exit(1)
    
    success = insert_rooms_data(schema_name)
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()