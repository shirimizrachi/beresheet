"""
Data insertion script for the users table with Hebrew examples
Usage with API engine: insert_users_data(engine, schema_name)
"""

from sqlalchemy import text

def insert_users_data(engine, schema_name: str):
    """
    Insert sample Hebrew user data into the users table using provided engine
    
    Args:
        engine: SQLAlchemy engine object
        schema_name: Name of the schema where the table exists
    """
    
    try:
        with engine.connect() as conn:
            # Insert Hebrew test users with proper values matching UserProfile validation
            insert_user_sql = text(f"""
                INSERT INTO [{schema_name}].[users]
                (id, firebase_id, home_id, password, phone_number, full_name, role, birthday, apartment_number, marital_status, gender, religious, native_language, service_provider_type, firebase_fcm_token, created_at, updated_at)
                VALUES
                ('default-manager-user', 'default-manager-firebase', 1, '541111111', '541111111', N'יוסי כהן - מנהל', 'manager', '1980-01-01', 'A1', 'single', 'male', 'secular', 'hebrew', NULL, NULL, GETDATE(), GETDATE()),
                ('test-staff-user', 'test-staff-firebase', 1, '541111222', '541111222', N'רחל לוי - צוות', 'staff', '1985-05-15', 'B2', 'married', 'female', 'traditional', 'hebrew', NULL, NULL, GETDATE(), GETDATE()),
                ('test-service-maintenance', 'test-service-maintenance-firebase', 1, '541111333', '541111333', N'דוד אברהם - תחזוקה', 'service', '1982-03-20', 'C3', 'single', 'male', 'secular', 'english', N'תחזוקה', NULL, GETDATE(), GETDATE()),
                ('test-service-manager', 'test-service-manager-firebase', 1, '541111444', '541111444', N'מרים גולדברג - מנהלת', 'service', '1978-12-10', 'D4', 'married', 'female', 'orthodox', 'hebrew', N'מנהל', NULL, GETDATE(), GETDATE()),
                ('test-service-nursing', 'test-service-nursing-firebase', 1, '541111555', '541111555', N'שרה רוזן - אחות', 'service', '1990-08-25', 'E5', 'single', 'female', 'secular', 'hebrew', N'אחות', NULL, GETDATE(), GETDATE()),
                ('test-resident-user1', 'test-resident-firebase1', 1, '541111666', '541111666', N'אברהם ישראלי - דייר', 'resident', '1975-11-30', 'F6', 'married', 'male', 'traditional', 'hebrew', NULL, NULL, GETDATE(), GETDATE()),
                ('test-resident-user2', 'test-resident-firebase2', 1, '541111777', '541111777', N'שושנה כהן - דיירת', 'resident', '1945-06-15', 'G7', 'widowed', 'female', 'orthodox', 'hebrew', NULL, NULL, GETDATE(), GETDATE()),
                ('test-service-social', 'test-service-social-firebase', 1, '541111888', '541111888', N'נעמי שפירא - עו"ס', 'service', '1988-09-12', 'H8', 'single', 'female', 'secular', 'hebrew', N'עובדת סוציאלית', NULL, GETDATE(), GETDATE()),
                ('test-service-culture', 'test-service-culture-firebase', 1, '541111999', '541111999', N'אלי ברק - תרבות', 'service', '1992-04-18', 'I9', 'married', 'male', 'traditional', 'hebrew', N'תרבות', NULL, GETDATE(), GETDATE())
            """)
            conn.execute(insert_user_sql)
            conn.commit()
            
            print(f"Hebrew user data inserted successfully into schema '{schema_name}'")
            print("Test users added:")
            print("  מנהל: 541111111 / יוסי כהן - מנהל")
            print("  צוות: 541111222 / רחל לוי - צוות")
            print("  שרות (תחזוקה): 541111333 / דוד אברהם - תחזוקה")
            print("  שרות (מנהלת): 541111444 / מרים גולדברג - מנהלת")
            print("  שרות (אחות): 541111555 / שרה רוזן - אחות")
            print("  דייר: 541111666 / אברהם ישראלי - דייר")
            print("  דיירת: 541111777 / שושנה כהן - דיירת")
            print("  שרות (עו\"ס): 541111888 / נעמי שפירא - עו\"ס")
            print("  שרות (תרבות): 541111999 / אלי ברק - תרבות")
            return True
            
    except Exception as e:
        print(f"Error inserting user data into schema '{schema_name}': {e}")
        return False