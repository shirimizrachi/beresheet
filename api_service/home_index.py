"""
Home Index management using SQLAlchemy
Handles home indexing for phone number to home mapping
"""

import uuid
from datetime import datetime
from typing import Optional, Dict
from sqlalchemy import create_engine, Table, MetaData, Column, String, Integer, DateTime, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import SQLAlchemyError
from residents_config import get_home_index_connection_string, HOME_INDEX_SCHEMA_NAME

class HomeIndexDatabase:
    def __init__(self):
        # Use dedicated home_index connection
        self._engine = None
        self.metadata = MetaData()
        self.schema_name = HOME_INDEX_SCHEMA_NAME

    @property
    def engine(self):
        """Get or create the home_index database engine"""
        if self._engine is None:
            try:
                connection_string = get_home_index_connection_string()
                self._engine = create_engine(connection_string)
            except Exception as e:
                print(f"Failed to connect to home_index database: {e}")
                raise
        return self._engine

    def get_home_index_table(self):
        """Get the home_index table"""
        try:
            # Reflect the home_index table from the home_index schema
            metadata = MetaData(schema=self.schema_name)
            metadata.reflect(bind=self.engine, only=['home_index'])
            
            return metadata.tables[f'{self.schema_name}.home_index']
        except Exception as e:
            print(f"Error reflecting home_index table: {e}")
            return None

    def create_home_entry(self, phone_number: str, home_id: int, home_name: str) -> bool:
        """Create a new home entry for a phone number, or update if it already exists"""
        try:
            home_index_table = self.get_home_index_table()
            if home_index_table is None:
                raise ValueError("Home index table not found")

            # Check if entry already exists
            existing_entry = self.get_home_by_phone(phone_number)
            
            if existing_entry:
                # Update existing entry
                print(f"Home index entry already exists for phone {phone_number}, updating it...")
                return self.update_home_entry(phone_number, home_id, home_name)
            else:
                # Create new entry
                current_time = datetime.now()

                # Prepare home index data
                home_data = {
                    'phone_number': phone_number,
                    'home_id': home_id,
                    'home_name': home_name,
                    'created_at': current_time,
                    'updated_at': current_time
                }

                # Insert home index data
                with self.engine.connect() as conn:
                    conn.execute(home_index_table.insert().values(**home_data))
                    conn.commit()

                print(f"Home index entry created for phone {phone_number} -> home {home_name} (ID: {home_id})")
                return True

        except Exception as e:
            print(f"Error creating home index entry for phone {phone_number}: {e}")
            return False

    def update_home_entry(self, phone_number: str, home_id: int = None, home_name: str = None) -> bool:
        """Update an existing home entry"""
        try:
            home_index_table = self.get_home_index_table()
            if home_index_table is None:
                raise ValueError("Home index table not found")

            # Prepare update data (only non-None fields)
            update_data = {'updated_at': datetime.now()}
            
            if home_id is not None:
                update_data['home_id'] = home_id
            if home_name is not None:
                update_data['home_name'] = home_name

            if len(update_data) == 1:  # Only updated_at
                print("No fields to update")
                return False

            # Update home index entry
            with self.engine.connect() as conn:
                result = conn.execute(
                    home_index_table.update()
                    .where(home_index_table.c.phone_number == phone_number)
                    .values(**update_data)
                )
                conn.commit()
                
                if result.rowcount > 0:
                    print(f"Home index entry updated for phone {phone_number}")
                    return True
                else:
                    print(f"No home index entry found for phone {phone_number}")
                    return False

        except Exception as e:
            print(f"Error updating home index entry for phone {phone_number}: {e}")
            return False

    def get_home_by_phone(self, phone_number: str) -> Optional[Dict[str, any]]:
        """Get home information by phone number"""
        try:
            # Import the normalization function
            from modules.users.users import normalize_phone_number
            
            # Normalize phone number by removing leading zeros
            normalized_phone = normalize_phone_number(phone_number)
            
            home_index_table = self.get_home_index_table()
            if home_index_table is None:
                return None

            # Query home index by normalized phone_number
            with self.engine.connect() as conn:
                result = conn.execute(
                    home_index_table.select().where(home_index_table.c.phone_number == normalized_phone)
                ).fetchone()

                if result:
                    return {
                        'phone_number': result.phone_number,
                        'home_id': result.home_id,
                        'home_name': result.home_name,
                        'created_at': result.created_at.isoformat() if isinstance(result.created_at, datetime) else result.created_at,
                        'updated_at': result.updated_at.isoformat() if isinstance(result.updated_at, datetime) else result.updated_at
                    }
                return None

        except Exception as e:
            print(f"Error getting home info by phone {phone_number}: {e}")
            return None

    def delete_home_entry(self, phone_number: str) -> bool:
        """Delete a home entry (for admin use only)"""
        try:
            home_index_table = self.get_home_index_table()
            if home_index_table is None:
                return False

            # Delete home index entry
            with self.engine.connect() as conn:
                result = conn.execute(
                    home_index_table.delete().where(home_index_table.c.phone_number == phone_number)
                )
                conn.commit()
                
                if result.rowcount > 0:
                    print(f"Home index entry deleted for phone {phone_number}")
                    return True
                else:
                    print(f"No home index entry found for phone {phone_number}")
                    return False

        except Exception as e:
            print(f"Error deleting home index entry for phone {phone_number}: {e}")
            return False

    def get_all_home_entries(self) -> list:
        """Get all home entries (for admin use only)"""
        try:
            home_index_table = self.get_home_index_table()
            if home_index_table is None:
                return []

            entries = []
            with self.engine.connect() as conn:
                results = conn.execute(home_index_table.select()).fetchall()
                
                for result in results:
                    entries.append({
                        'phone_number': result.phone_number,
                        'home_id': result.home_id,
                        'home_name': result.home_name,
                        'created_at': result.created_at.isoformat() if isinstance(result.created_at, datetime) else result.created_at,
                        'updated_at': result.updated_at.isoformat() if isinstance(result.updated_at, datetime) else result.updated_at
                    })
            return entries

        except Exception as e:
            print(f"Error getting all home entries: {e}")
            return []

    def test_connection(self) -> bool:
        """Test home_index database connection"""
        try:
            with self.engine.connect() as conn:
                # Test basic query
                test_sql = text(f"""
                    SELECT COUNT(*) as table_count
                    FROM INFORMATION_SCHEMA.TABLES 
                    WHERE TABLE_SCHEMA = '{self.schema_name}'
                """)
                
                result = conn.execute(test_sql).fetchone()
                print(f"Home index connection successful. Found {result[0]} tables in schema '{self.schema_name}'.")
                return True
                
        except Exception as e:
            print(f"Error testing home_index connection: {e}")
            return False

# Create global instance
home_index_db = HomeIndexDatabase()