"""
Data insertion script for the events table with Hebrew examples
Usage: python create_events_data.py <schema_name>
"""

import sys
from sqlalchemy import create_engine, text
from datetime import datetime, timedelta

def insert_events_data(schema_name: str):
    """
    Insert sample Hebrew event data into the events table
    
    Args:
        schema_name: Name of the schema where the table exists
    """
    
    # Connection string for the home database (using Windows Authentication)
    connection_string = "mssql+pyodbc://localhost\\SQLEXPRESS/home?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes&Trusted_Connection=yes"
    
    try:
        # Create SQLAlchemy engine
        engine = create_engine(connection_string)
        
        with engine.connect() as conn:
            # Get today's date for scheduling events
            base_date = datetime.now()
            
            # Insert Hebrew events
            insert_events_sql = text(f"""
                INSERT INTO [{schema_name}].[events] 
                (id, name, type, description, dateTime, location, maxParticipants, currentParticipants, image_url, recurring, recurring_end_date, recurring_pattern, created_at, updated_at, created_by, status)
                VALUES
                ('yoga-monday', N'יוגה בוקר', N'בריאות', N'שיעור יוגה רגוע לתחילת השבוע עם שרה כהן', DATEADD(day, 1, GETDATE()), N'חדר כושר', 15, 0, NULL, 'weekly', DATEADD(month, 3, GETDATE()), N'{{"dayOfWeek": 1, "time": "08:00"}}', GETDATE(), GETDATE(), 'default-manager-user', 'active'),
                ('art-therapy-wed', N'טיפול באמנות', N'תרבות', N'סדנת ציור וטיפול באמנות עם דוד לוי', DATEADD(day, 3, GETDATE()), N'חדר יצירה', 12, 0, NULL, 'weekly', DATEADD(month, 3, GETDATE()), N'{{"dayOfWeek": 3, "time": "14:00"}}', GETDATE(), GETDATE(), 'default-manager-user', 'active'),
                ('music-therapy-thu', N'טיפול במוזיקה', N'תרבות', N'מפגש זמרה ומוזיקה עם רחל ירוק', DATEADD(day, 4, GETDATE()), N'חדר מוזיקה', 20, 0, NULL, 'weekly', DATEADD(month, 3, GETDATE()), N'{{"dayOfWeek": 4, "time": "16:00"}}', GETDATE(), GETDATE(), 'default-manager-user', 'active'),
                ('cooking-class-sun', N'שיעור בישול', N'פעילות', N'בישול יחד - ארוחת שבת מסורתית עם אמה וילסון', DATEADD(day, 7, GETDATE()), N'מטבח', 8, 0, NULL, 'weekly', DATEADD(month, 3, GETDATE()), N'{{"dayOfWeek": 0, "time": "10:00"}}', GETDATE(), GETDATE(), 'default-manager-user', 'active'),
                ('meditation-tue', N'מדיטציה ומיינדפולנס', N'בריאות', N'מפגש מדיטציה שקטה עם אברהם גולדברג', DATEADD(day, 2, GETDATE()), N'חדר מדיטציה', 10, 0, NULL, 'weekly', DATEADD(month, 3, GETDATE()), N'{{"dayOfWeek": 2, "time": "18:00"}}', GETDATE(), GETDATE(), 'default-manager-user', 'active'),
                ('occupational-therapy-fri', N'טיפול בעיסוק', N'בריאות', N'פעילות יצירה ומלאכה עם מרים שפירא', DATEADD(day, 5, GETDATE()), N'חדר פעילות', 15, 0, NULL, 'weekly', DATEADD(month, 3, GETDATE()), N'{{"dayOfWeek": 5, "time": "15:00"}}', GETDATE(), GETDATE(), 'default-manager-user', 'active'),
                ('garden-walk-sat', N'טיול בגינה', N'פעילות', N'טיול וכושר בגינה עם יוסף רוזנברג', DATEADD(day, 6, GETDATE()), N'גינה', 25, 0, NULL, 'weekly', DATEADD(month, 3, GETDATE()), N'{{"dayOfWeek": 6, "time": "09:00"}}', GETDATE(), GETDATE(), 'default-manager-user', 'active'),
                ('book-club-wed', N'מועדון קריאה', N'תרבות', N'דיון על ספר השבוע', DATEADD(day, 10, GETDATE()), N'ספרייה', 12, 0, NULL, 'bi-weekly', DATEADD(month, 3, GETDATE()), N'{{"dayOfWeek": 3, "time": "17:00", "interval": 2}}', GETDATE(), GETDATE(), 'test-staff-user', 'active'),
                ('birthday-party', N'חגיגת יום הולדת קבוצתית', N'חגיגה', N'חגיגה משותפת לכל יולדי החודש', DATEADD(day, 15, GETDATE()), N'אולם ראשי', 50, 0, NULL, 'monthly', DATEADD(month, 6, GETDATE()), N'{{"dayOfMonth": 15, "time": "15:00"}}', GETDATE(), GETDATE(), 'test-staff-user', 'active'),
                ('special-lecture', N'הרצאה מיוחדת: זכרונות מהעבר', N'תרבות', N'הרצאה מרתקת על ההיסטוריה המקומית', DATEADD(day, 20, GETDATE()), N'אולם ראשי', 40, 0, NULL, 'none', NULL, NULL, GETDATE(), GETDATE(), 'test-staff-user', 'active')
            """)
            conn.execute(insert_events_sql)
            conn.commit()
            
            print(f"Sample Hebrew events data inserted successfully into schema '{schema_name}'")
            print("Events added:")
            print("- יוגה בוקר (יום שני - חדר כושר)")
            print("- טיפול באמנות (יום רביעי - חדר יצירה)")
            print("- טיפול במוזיקה (יום חמישי - חדר מוזיקה)")
            print("- שיעור בישול (יום ראשון - מטבח)")
            print("- מדיטציה ומיינדפולנס (יום שלישי - חדר מדיטציה)")
            print("- טיפול בעיסוק (יום שישי - חדר פעילות)")
            print("- טיול בגינה (יום שבת - גינה)")
            print("- מועדון קריאה (כל שבועיים - ספרייה)")
            print("- חגיגת יום הולדת קבוצתית (חודשי - אולם ראשי)")
            print("- הרצאה מיוחדת (חד פעמי - אולם ראשי)")
            return True
            
    except Exception as e:
        print(f"Error inserting events data into schema '{schema_name}': {e}")
        return False

def main():
    """Main function to handle command line arguments"""
    if len(sys.argv) != 2:
        print("Usage: python create_events_data.py <schema_name>")
        print("Example: python create_events_data.py beresheet")
        sys.exit(1)
    
    schema_name = sys.argv[1]
    
    if not schema_name.isalnum():
        print("Error: Schema name must be alphanumeric")
        sys.exit(1)
    
    success = insert_events_data(schema_name)
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()