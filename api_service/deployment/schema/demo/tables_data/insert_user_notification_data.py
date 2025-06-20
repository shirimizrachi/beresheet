"""
Data insertion script for the user_notification table with individual notifications for residents
Usage: python create_user_notification_data.py <schema_name>
"""

import sys
from sqlalchemy import create_engine, text

def insert_user_notification_data(engine, schema_name: str):
    """
    Insert user notification data for all residents linking to the home notification using provided engine
    
    Args:
        engine: SQLAlchemy engine object
        schema_name: Name of the schema where the table exists
    """
    
    try:
        with engine.connect() as conn:
            # First, get the notification_id from the home_notification table
            get_notification_id_sql = text(f"""
                SELECT TOP 1 id FROM [{schema_name}].[home_notification] 
                WHERE create_by_user_id = 'default-manager-user' 
                AND send_status = 'approved'
                ORDER BY created_at DESC
            """)
            result = conn.execute(get_notification_id_sql)
            notification_row = result.fetchone()
            
            if not notification_row:
                print(f"Error: No approved home notification found in schema '{schema_name}'. Please run create_home_notification_data.py first.")
                return False
            
            notification_id = notification_row[0]
            
            # Insert user notifications for ALL users (excluding the sender manager to avoid self-notification)
            insert_user_notifications_sql = text(f"""
                INSERT INTO [{schema_name}].[user_notification]
                (user_id, user_read_date, user_fcm, notification_id, notification_sender_user_id, notification_sender_user_name, notification_sender_user_role_name, notification_sender_user_service_provider_type_name, notification_status, notification_time, notification_message, notification_type, created_at, updated_at)
                VALUES
                -- Staff: רחל לוי - צוות
                ('test-staff-user', NULL, NULL, {notification_id}, 'default-manager-user', N'יוסי כהן - מנהל', 'manager', NULL, 'sent', GETDATE(), N'ברוכים הבאים לקהילת בראשית! אנו שמחים לקבל אתכם לבית החדש שלכם. אנא אל תהססו לפנות אלינו בכל שאלה או בקשה. אנו כאן כדי לעזור ולהבטיח שתרגישו בבית. בברכה, צוות הניהול', 'regular', GETDATE(), GETDATE()),
                -- Service - Maintenance: דוד אברהם - תחזוקה
                ('test-service-maintenance', NULL, NULL, {notification_id}, 'default-manager-user', N'יוסי כהן - מנהל', 'manager', NULL, 'sent', GETDATE(), N'ברוכים הבאים לקהילת בראשית! אנו שמחים לקבל אתכם לבית החדש שלכם. אנא אל תהססו לפנות אלינו בכל שאלה או בקשה. אנו כאן כדי לעזור ולהבטיח שתרגישו בבית. בברכה, צוות הניהול', 'regular', GETDATE(), GETDATE()),
                -- Service - Manager: מרים גולדברג - מנהלת
                ('test-service-manager', NULL, NULL, {notification_id}, 'default-manager-user', N'יוסי כהן - מנהל', 'manager', NULL, 'sent', GETDATE(), N'ברוכים הבאים לקהילת בראשית! אנו שמחים לקבל אתכם לבית החדש שלכם. אנא אל תהססו לפנות אלינו בכל שאלה או בקשה. אנו כאן כדי לעזור ולהבטיח שתרגישו בבית. בברכה, צוות הניהול', 'regular', GETDATE(), GETDATE()),
                -- Service - Nursing: שרה רוזן - אחות
                ('test-service-nursing', NULL, NULL, {notification_id}, 'default-manager-user', N'יוסי כהן - מנהל', 'manager', NULL, 'sent', GETDATE(), N'ברוכים הבאים לקהילת בראשית! אנו שמחים לקבל אתכם לבית החדש שלכם. אנא אל תהססו לפנות אלינו בכל שאלה או בקשה. אנו כאן כדי לעזור ולהבטיח שתרגישו בבית. בברכה, צוות הניהול', 'regular', GETDATE(), GETDATE()),
                -- Resident 1: אברהם ישראלי - דייר
                ('test-resident-user1', NULL, NULL, {notification_id}, 'default-manager-user', N'יוסי כהן - מנהל', 'manager', NULL, 'sent', GETDATE(), N'ברוכים הבאים לקהילת בראשית! אנו שמחים לקבל אתכם לבית החדש שלכם. אנא אל תהססו לפנות אלינו בכל שאלה או בקשה. אנו כאן כדי לעזור ולהבטיח שתרגישו בבית. בברכה, צוות הניהול', 'regular', GETDATE(), GETDATE()),
                -- Resident 2: שושנה כהן - דיירת
                ('test-resident-user2', NULL, NULL, {notification_id}, 'default-manager-user', N'יוסי כהן - מנהל', 'manager', NULL, 'sent', GETDATE(), N'ברוכים הבאים לקהילת בראשית! אנו שמחים לקבל אתכם לבית החדש שלכם. אנא אל תהססו לפנות אלינו בכל שאלה או בקשה. אנו כאן כדי לעזור ולהבטיח שתרגישו בבית. בברכה, צוות הניהול', 'regular', GETDATE(), GETDATE()),
                -- Service - Social Worker: נעמי שפירא - עו"ס
                ('test-service-social', NULL, NULL, {notification_id}, 'default-manager-user', N'יוסי כהן - מנהל', 'manager', NULL, 'sent', GETDATE(), N'ברוכים הבאים לקהילת בראשית! אנו שמחים לקבל אתכם לבית החדש שלכם. אנא אל תהססו לפנות אלינו בכל שאלה או בקשה. אנו כאן כדי לעזור ולהבטיח שתרגישו בבית. בברכה, צוות הניהול', 'regular', GETDATE(), GETDATE()),
                -- Service - Culture: אלי ברק - תרבות
                ('test-service-culture', NULL, NULL, {notification_id}, 'default-manager-user', N'יוסי כהן - מנהל', 'manager', NULL, 'sent', GETDATE(), N'ברוכים הבאים לקהילת בראשית! אנו שמחים לקבל אתכם לבית החדש שלכם. אנא אל תהססו לפנות אלינו בכל שאלה או בקשה. אנו כאן כדי לעזור ולהבטיח שתרגישו בבית. בברכה, צוות הניהול', 'regular', GETDATE(), GETDATE())
            """)
            conn.execute(insert_user_notifications_sql)
            conn.commit()
            
            print(f"User notification data inserted successfully into schema '{schema_name}'")
            print(f"Individual notifications created for ALL users (linked to home notification ID: {notification_id}):")
            print("  ✅ test-staff-user - רחל לוי - צוות (phone: 541111222)")
            print("  ✅ test-service-maintenance - דוד אברהם - תחזוקה (phone: 541111333)")
            print("  ✅ test-service-manager - מרים גולדברג - מנהלת (phone: 541111444)")
            print("  ✅ test-service-nursing - שרה רוזן - אחות (phone: 541111555)")
            print("  ✅ test-resident-user1 - אברהם ישראלי - דייר (phone: 541111666)")
            print("  ✅ test-resident-user2 - שושנה כהן - דיירת (phone: 541111777)")
            print("  ✅ test-service-social - נעמי שפירא - עו\"ס (phone: 541111888)")
            print("  ✅ test-service-culture - אלי ברק - תרבות (phone: 541111999)")
            print("  📧 Status: sent (נשלח)")
            print("  📱 Ready to view in mobile app")
            print("  📌 Note: Manager (default-manager-user) excluded to avoid self-notification")
            return True
            
    except Exception as e:
        print(f"Error inserting user notification data into schema '{schema_name}': {e}")
        return False

def main():
    """Main function to handle command line arguments"""
    if len(sys.argv) != 2:
        print("Usage: python create_user_notification_data.py <schema_name>")
        print("Example: python create_user_notification_data.py beresheet")
        sys.exit(1)
    
    schema_name = sys.argv[1]
    
    if not schema_name.isalnum():
        print("Error: Schema name must be alphanumeric")
        sys.exit(1)
    
    success = insert_user_notification_data(schema_name)
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()