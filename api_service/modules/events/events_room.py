"""
Room management using SQLAlchemy
Provides CRUD (Create, Read, Delete) operations on the **rooms** table.
"""

from typing import List, Optional
from pydantic import BaseModel

from sqlalchemy import create_engine, MetaData, Table, text
from tenant_config import get_schema_name_by_home_id
from database_utils import get_schema_engine, get_engine_for_home

# Room Models
class Room(BaseModel):
    id: str
    room_name: str

    class Config:
        from_attributes = True

class RoomCreate(BaseModel):
    room_name: str


class RoomDatabase:
    """
    Handles all room-related database operations.
    Mirrors the structure of `events.py` but with a simpler CRUD surface.
    """

    def __init__(self):
        # Note: This class now uses tenant-specific connections through database_utils
        # No default engine is created as all operations use schema-specific engines
        pass

    # --------------------------------------------------------------------- #
    # Table reflection helper                                               #
    # --------------------------------------------------------------------- #
    def _get_rooms_table(self, schema_name: str) -> Optional[Table]:
        """
        Reflect the **rooms** table from the specified schema and return it.
        """
        try:
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                print(f"No engine found for schema {schema_name}")
                return None

            metadata = MetaData(schema=schema_name)
            metadata.reflect(bind=schema_engine, only=["rooms"])
            return metadata.tables[f"{schema_name}.rooms"]
        except Exception as exc:
            print(f"Error reflecting rooms table for schema {schema_name}: {exc}")
            return None

    # --------------------------------------------------------------------- #
    # CRUD operations                                                       #
    # --------------------------------------------------------------------- #
    def get_all_rooms(self, home_id: int) -> List[Room]:
        """Return a list of all rooms for the given home."""
        try:
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return []

            rooms_table = self._get_rooms_table(schema_name)
            if rooms_table is None:
                return []

            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                return []
            with schema_engine.connect() as conn:
                results = conn.execute(rooms_table.select()).fetchall()
                return [Room(id=row.id, room_name=row.room_name) for row in results]
        except Exception as exc:
            print(f"Error retrieving rooms for home {home_id}: {exc}")
            return []

    def create_room(self, room_data: RoomCreate, home_id: int) -> Optional[Room]:
        """Insert a new room; returns the created Room or None on failure."""
        try:
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return None

            rooms_table = self._get_rooms_table(schema_name)
            if rooms_table is None:
                return None

            # Generate GUID for room ID
            import uuid
            room_id = str(uuid.uuid4())

            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                return None
            with schema_engine.connect() as conn:
                conn.execute(
                    rooms_table.insert().values(
                        id=room_id,
                        room_name=room_data.room_name
                    )
                )
                conn.commit()

                # Fetch the newly created row
                new_row = conn.execute(
                    rooms_table.select().where(rooms_table.c.id == room_id)
                ).fetchone()

                if new_row:
                    return Room(id=new_row.id, room_name=new_row.room_name)
                return None
        except Exception as exc:
            print(f"Error creating room '{room_data.room_name}' for home {home_id}: {exc}")
            return None

    def delete_room(self, room_id: str, home_id: int) -> bool:
        """Delete room by ID; returns True if a row was removed."""
        try:
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return False

            rooms_table = self._get_rooms_table(schema_name)
            if rooms_table is None:
                return False

            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                return []
            with schema_engine.connect() as conn:
                result = conn.execute(
                    rooms_table.delete().where(rooms_table.c.id == room_id)
                )
                conn.commit()
                return result.rowcount > 0
        except Exception as exc:
            print(f"Error deleting room {room_id} for home {home_id}: {exc}")
            return False


# Global singleton instance
room_db = RoomDatabase()