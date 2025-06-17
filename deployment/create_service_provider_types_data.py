"""
Data insertion script for the service_provider_types table with Hebrew data
Usage: python create_service_provider_types_data.py <schema_name>
"""

import sys
from sqlalchemy import create_engine, text

def insert_service_provider_types_data(schema_name: str):
    """
    Insert Hebrew service provider types data into the service_provider_types table
    
    Args:
        schema_name: Name of the schema where the table exists
    """
    
    # Connection string for the home database (using Windows Authentication)
    connection_string = "mssql+pyodbc://localhost\\SQLEXPRESS/home?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes&Trusted_Connection=yes"
    
    try:
        # Create SQLAlchemy engine
        engine = create_engine(connection_string)
        
        with engine.connect() as conn:
            # Insert Hebrew service provider types
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
                (N'מנהל', N'שירותי ניהול', GETDATE(), GETDATE()),
                (N'רופא', N'שירותי רפואה מומחה', GETDATE(), GETDATE()),
                (N'פיזיותרפיסט', N'שירותי פיזיותרפיה', GETDATE(), GETDATE()),
                (N'דיאטנית', N'שירותי תזונה', GETDATE(), GETDATE()),
                (N'פסיכולוג', N'שירותי טיפול נפשי', GETDATE(), GETDATE())
            """)
            conn.execute(insert_default_types_sql)
            conn.commit()
            
            print(f"Service provider types data inserted successfully into schema '{schema_name}'")
            print("Service provider types added:")
            print("- תחזוקה (Maintenance)")
            print("- שרות לדייר (Resident Service)")
            print("- משק (Housekeeping)")
            print("- עובדת סוציאלית (Social Worker)")
            print("- אחות (Nurse)")
            print("- תרבות (Culture)")
            print("- מנהל חשבונות (Accountant)")
            print("- מנהל (Manager)")
            print("- רופא (Doctor)")
            print("- פיזיותרפיסט (Physiotherapist)")
            print("- דיאטנית (Dietitian)")
            print("- פסיכולוג (Psychologist)")
            return True
            
    except Exception as e:
        print(f"Error inserting service provider types data into schema '{schema_name}': {e}")
        return False

def main():
    """Main function to handle command line arguments"""
    if len(sys.argv) != 2:
        print("Usage: python create_service_provider_types_data.py <schema_name>")
        print("Example: python create_service_provider_types_data.py beresheet")
        sys.exit(1)
    
    schema_name = sys.argv[1]
    
    if not schema_name.isalnum():
        print("Error: Schema name must be alphanumeric")
        sys.exit(1)
    
    success = insert_service_provider_types_data(schema_name)
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()