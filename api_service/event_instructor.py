"""
Event Instructor management using SQLAlchemy
Provides CRUD (Create, Read, Update, Delete) operations on the **event_instructor** table.
"""

from typing import List, Optional

from sqlalchemy import create_engine, MetaData, Table, text
from models import EventInstructor, EventInstructorCreate, EventInstructorUpdate
from home_mapping import get_connection_string, get_schema_for_home
from database_utils import get_schema_engine, get_engine_for_home


class EventInstructorDatabase:
    """
    Handles all event instructor-related database operations.
    Similar structure to rooms.py but with additional photo field handling.
    """

    def __init__(self):
        # Generic connection string (server-level); most ops will use schema-specific engines
        self.connection_string = get_connection_string()
        self.engine = create_engine(self.connection_string)

    # --------------------------------------------------------------------- #
    # Table reflection helper                                               #
    # --------------------------------------------------------------------- #
    def _get_event_instructor_table(self, schema_name: str) -> Optional[Table]:
        """
        Reflect the **event_instructor** table from the specified schema and return it.
        """
        try:
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                print(f"No engine found for schema {schema_name}")
                return None

            metadata = MetaData(schema=schema_name)
            metadata.reflect(bind=schema_engine, only=["event_instructor"])
            return metadata.tables[f"{schema_name}.event_instructor"]
        except Exception as exc:
            print(f"Error reflecting event_instructor table for schema {schema_name}: {exc}")
            return None

    # --------------------------------------------------------------------- #
    # CRUD operations                                                       #
    # --------------------------------------------------------------------- #
    def get_all_event_instructors(self, home_id: int) -> List[EventInstructor]:
        """Return a list of all event instructors for the given home."""
        try:
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return []

            event_instructor_table = self._get_event_instructor_table(schema_name)
            if event_instructor_table is None:
                return []

            with self.engine.connect() as conn:
                results = conn.execute(event_instructor_table.select()).fetchall()
                return [
                    EventInstructor(
                        id=row.id,
                        name=row.name,
                        description=row.description,
                        photo=row.photo
                    )
                    for row in results
                ]
        except Exception as exc:
            print(f"Error retrieving event instructors for home {home_id}: {exc}")
            return []

    def get_event_instructor_by_id(self, instructor_id: int, home_id: int) -> Optional[EventInstructor]:
        """Get a specific event instructor by ID."""
        try:
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return None

            event_instructor_table = self._get_event_instructor_table(schema_name)
            if event_instructor_table is None:
                return None

            with self.engine.connect() as conn:
                result = conn.execute(
                    event_instructor_table.select().where(event_instructor_table.c.id == instructor_id)
                ).fetchone()
                
                if result:
                    return EventInstructor(
                        id=result.id,
                        name=result.name,
                        description=result.description,
                        photo=result.photo
                    )
                return None
        except Exception as exc:
            print(f"Error retrieving event instructor {instructor_id} for home {home_id}: {exc}")
            return None

    def create_event_instructor(self, instructor_data: EventInstructorCreate, home_id: int) -> Optional[EventInstructor]:
        """Insert a new event instructor; returns the created EventInstructor or None on failure."""
        try:
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return None

            event_instructor_table = self._get_event_instructor_table(schema_name)
            if event_instructor_table is None:
                return None

            with self.engine.connect() as conn:
                insert_result = conn.execute(
                    event_instructor_table.insert().values(
                        name=instructor_data.name,
                        description=instructor_data.description,
                        photo=None  # Will be updated separately if needed
                    )
                )
                conn.commit()

                # Fetch the newly created row (identity value)
                new_id = insert_result.inserted_primary_key[0]
                new_row = conn.execute(
                    event_instructor_table.select().where(event_instructor_table.c.id == new_id)
                ).fetchone()

                if new_row:
                    return EventInstructor(
                        id=new_row.id,
                        name=new_row.name,
                        description=new_row.description,
                        photo=new_row.photo
                    )
                return None
        except Exception as exc:
            print(f"Error creating event instructor '{instructor_data.name}' for home {home_id}: {exc}")
            return None

    def update_event_instructor(self, instructor_id: int, instructor_data: EventInstructorUpdate, home_id: int) -> Optional[EventInstructor]:
        """Update an existing event instructor; returns the updated EventInstructor or None on failure."""
        try:
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return None

            event_instructor_table = self._get_event_instructor_table(schema_name)
            if event_instructor_table is None:
                return None

            # Prepare update values - only include non-None fields
            update_values = {}
            if instructor_data.name is not None:
                update_values['name'] = instructor_data.name
            if instructor_data.description is not None:
                update_values['description'] = instructor_data.description
            if instructor_data.photo is not None:
                update_values['photo'] = instructor_data.photo

            # Always update the updated_at timestamp
            update_values['updated_at'] = text('GETDATE()')

            if not update_values:
                # No fields to update
                return self.get_event_instructor_by_id(instructor_id, home_id)

            with self.engine.connect() as conn:
                result = conn.execute(
                    event_instructor_table.update()
                    .where(event_instructor_table.c.id == instructor_id)
                    .values(**update_values)
                )
                conn.commit()

                if result.rowcount > 0:
                    # Fetch and return the updated row
                    return self.get_event_instructor_by_id(instructor_id, home_id)
                return None
        except Exception as exc:
            print(f"Error updating event instructor {instructor_id} for home {home_id}: {exc}")
            return None

    def delete_event_instructor(self, instructor_id: int, home_id: int) -> bool:
        """Delete event instructor by ID; returns True if a row was removed."""
        try:
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return False

            event_instructor_table = self._get_event_instructor_table(schema_name)
            if event_instructor_table is None:
                return False

            with self.engine.connect() as conn:
                result = conn.execute(
                    event_instructor_table.delete().where(event_instructor_table.c.id == instructor_id)
                )
                conn.commit()
                return result.rowcount > 0
        except Exception as exc:
            print(f"Error deleting event instructor {instructor_id} for home {home_id}: {exc}")
            return False


# Global singleton instance
event_instructor_db = EventInstructorDatabase()