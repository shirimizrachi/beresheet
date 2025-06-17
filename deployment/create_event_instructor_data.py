"""
Data insertion script for the event_instructor table with Hebrew examples
Usage: python create_event_instructor_data.py <schema_name>
"""

import sys
from sqlalchemy import create_engine, text

def insert_event_instructor_data(schema_name: str):
    """
    Insert sample Hebrew instructor data into the event_instructor table
    
    Args:
        schema_name: Name of the schema where the table exists
    """
    
    # Connection string for the home database (using Windows Authentication)
    connection_string = "mssql+pyodbc://localhost\\SQLEXPRESS/home?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes&Trusted_Connection=yes"
    
    try:
        # Create SQLAlchemy engine
        engine = create_engine(connection_string)
        
        with engine.connect() as conn:
            # Insert Hebrew instructors
            insert_instructors_sql = text(f"""
                INSERT INTO [{schema_name}].[event_instructor] (name, description, photo, created_at, updated_at)
                VALUES
                (N'שרה כהן', N'מדריכת יוגה ובריאות עם 10 שנות ניסיון', NULL, GETDATE(), GETDATE()),
                (N'דוד לוי', N'מומחה לטיפול באמנות ומדריך ציור', NULL, GETDATE(), GETDATE()),
                (N'רחל ירוק', N'מטפלת במוזיקה ומנצחת מקהלה', NULL, GETDATE(), GETDATE()),
                (N'מיכאל ברוך', N'פיזיותרפיסט ומדריך כושר גופני', NULL, GETDATE(), GETDATE()),
                (N'אמה וילסון', N'מומחית בישול ותזונה', NULL, GETDATE(), GETDATE()),
                (N'אברהם גולדברג', N'מדריך מדיטציה ומיינדפולנס', NULL, GETDATE(), GETDATE()),
                (N'מרים שפירא', N'מטפלת בעיסוק ומדריכת יצירה', NULL, GETDATE(), GETDATE()),
                (N'יוסף רוזנברג', N'מדריך טיולים ופעילות חוץ', NULL, GETDATE(), GETDATE())
            """)
            conn.execute(insert_instructors_sql)
            conn.commit()
            
            print(f"Sample Hebrew instructor data inserted successfully into schema '{schema_name}'")
            print("Instructors added:")
            print("- שרה כהן (יוגה ובריאות)")
            print("- דוד לוי (טיפול באמנות)")
            print("- רחל ירוק (מוזיקה)")
            print("- מיכאל ברוך (פיזיותרפיה)")
            print("- אמה וילסון (בישול ותזונה)")
            print("- אברהם גולדברג (מדיטציה)")
            print("- מרים שפירא (טיפול בעיסוק)")
            print("- יוסף רוזנברג (טיולים)")
            return True
            
    except Exception as e:
        print(f"Error inserting instructor data into schema '{schema_name}': {e}")
        return False

def main():
    """Main function to handle command line arguments"""
    if len(sys.argv) != 2:
        print("Usage: python create_event_instructor_data.py <schema_name>")
        print("Example: python create_event_instructor_data.py beresheet")
        sys.exit(1)
    
    schema_name = sys.argv[1]
    
    if not schema_name.isalnum():
        print("Error: Schema name must be alphanumeric")
        sys.exit(1)
    
    success = insert_event_instructor_data(schema_name)
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()