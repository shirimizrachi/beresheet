"""
Data insertion script for the home_notification table with Hebrew welcome message
Usage: python create_home_notification_data.py <schema_name>
"""

import sys
from sqlalchemy import create_engine, text

def insert_home_notification_data(engine, schema_name: str):
    """
    Insert welcome notification data into the home_notification table using provided engine
    
    Args:
        engine: SQLAlchemy engine object
        schema_name: Name of the schema where the table exists
    """
    
    try:
        with engine.connect() as conn:
            # Insert Hebrew welcome notification from manager
            insert_notification_sql = text(f"""
                INSERT INTO [{schema_name}].[home_notification]
                (create_by_user_id, create_by_user_name, create_by_user_role_name, create_by_user_service_provider_type_name, message, send_status, send_approved_by_user_id, send_floor, send_datetime, send_type, created_at, updated_at)
                VALUES
                ('default-manager-user', N'יוסי כהן - מנהל', 'manager', NULL, N'ברוכים הבאים לקהילת בראשית! אנו שמחים לקבל אתכם לבית החדש שלכם. אנא אל תהססו לפנות אלינו בכל שאלה או בקשה. אנו כאן כדי לעזור ולהבטיח שתרגישו בבית. בברכה, צוות הניהול', 'approved', 'default-manager-user', NULL, GETDATE(), 'regular', GETDATE(), GETDATE())
            """)
            conn.execute(insert_notification_sql)
            conn.commit()
            
            print(f"Home notification data inserted successfully into schema '{schema_name}'")
            print("Welcome notification created:")
            print("  מאת: יוסי כהן - מנהל")
            print("  סטטוס: approved (מאושר)")
            print("  סוג: regular (רגיל)")
            print("  תוכן: ברוכים הבאים לקהילת בראשית!")
            return True
            
    except Exception as e:
        print(f"Error inserting home notification data into schema '{schema_name}': {e}")
        return False

def main():
    """Main function to handle command line arguments"""
    if len(sys.argv) != 2:
        print("Usage: python create_home_notification_data.py <schema_name>")
        print("Example: python create_home_notification_data.py beresheet")
        sys.exit(1)
    
    schema_name = sys.argv[1]
    
    if not schema_name.isalnum():
        print("Error: Schema name must be alphanumeric")
        sys.exit(1)
    
    success = insert_home_notification_data(schema_name)
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()