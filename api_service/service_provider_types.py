"""
Service Provider Types management using SQLAlchemy
Provides CRUD (Create, Read, Update, Delete) operations on the **service_provider_types** table.
"""

from typing import List, Optional

from sqlalchemy import create_engine, MetaData, Table, text
from models import ServiceProviderType, ServiceProviderTypeCreate, ServiceProviderTypeUpdate
from home_mapping import get_connection_string, get_schema_for_home
from database_utils import get_schema_engine, get_engine_for_home


class ServiceProviderTypeDatabase:
    """
    Handles all service provider type-related database operations.
    Mirrors the structure of `rooms.py` but with CRUD operations for service provider types.
    """

    def __init__(self):
        # Generic connection string (server-level); most ops will use schema-specific engines
        self.connection_string = get_connection_string()
        self.engine = create_engine(self.connection_string)

    # --------------------------------------------------------------------- #
    # Table reflection helper                                               #
    # --------------------------------------------------------------------- #
    def _get_service_provider_types_table(self, schema_name: str) -> Optional[Table]:
        """
        Reflect the **service_provider_types** table from the specified schema and return it.
        """
        try:
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                print(f"No engine found for schema {schema_name}")
                return None

            metadata = MetaData(schema=schema_name)
            metadata.reflect(bind=schema_engine, only=["service_provider_types"])
            return metadata.tables[f"{schema_name}.service_provider_types"]
        except Exception as exc:
            print(f"Error reflecting service_provider_types table for schema {schema_name}: {exc}")
            return None

    # --------------------------------------------------------------------- #
    # CRUD operations                                                       #
    # --------------------------------------------------------------------- #
    def get_all_service_provider_types(self, home_id: int) -> List[ServiceProviderType]:
        """Return a list of all service provider types for the given home."""
        try:
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return []

            types_table = self._get_service_provider_types_table(schema_name)
            if types_table is None:
                return []

            with self.engine.connect() as conn:
                results = conn.execute(types_table.select().order_by(types_table.c.name)).fetchall()
                return [
                    ServiceProviderType(
                        id=row.id, 
                        name=row.name, 
                        description=row.description
                    ) for row in results
                ]
        except Exception as exc:
            print(f"Error retrieving service provider types for home {home_id}: {exc}")
            return []

    def get_service_provider_type_by_id(self, type_id: int, home_id: int) -> Optional[ServiceProviderType]:
        """Get a single service provider type by ID."""
        try:
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return None

            types_table = self._get_service_provider_types_table(schema_name)
            if types_table is None:
                return None

            with self.engine.connect() as conn:
                result = conn.execute(
                    types_table.select().where(types_table.c.id == type_id)
                ).fetchone()
                
                if result:
                    return ServiceProviderType(
                        id=result.id,
                        name=result.name,
                        description=result.description
                    )
                return None
        except Exception as exc:
            print(f"Error retrieving service provider type {type_id} for home {home_id}: {exc}")
            return None

    def create_service_provider_type(self, type_data: ServiceProviderTypeCreate, home_id: int) -> Optional[ServiceProviderType]:
        """Insert a new service provider type; returns the created ServiceProviderType or None on failure."""
        try:
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return None

            types_table = self._get_service_provider_types_table(schema_name)
            if types_table is None:
                return None

            with self.engine.connect() as conn:
                insert_result = conn.execute(
                    types_table.insert().values(
                        name=type_data.name,
                        description=type_data.description
                    )
                )
                conn.commit()

                # Fetch the newly created row (identity value)
                new_id = insert_result.inserted_primary_key[0]
                new_row = conn.execute(
                    types_table.select().where(types_table.c.id == new_id)
                ).fetchone()

                if new_row:
                    return ServiceProviderType(
                        id=new_row.id,
                        name=new_row.name,
                        description=new_row.description
                    )
                return None
        except Exception as exc:
            print(f"Error creating service provider type '{type_data.name}' for home {home_id}: {exc}")
            return None

    def update_service_provider_type(self, type_id: int, type_data: ServiceProviderTypeUpdate, home_id: int) -> Optional[ServiceProviderType]:
        """Update a service provider type (only description can be updated); returns updated ServiceProviderType or None on failure."""
        try:
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return None

            types_table = self._get_service_provider_types_table(schema_name)
            if types_table is None:
                return None

            with self.engine.connect() as conn:
                # Update the record
                update_data = {}
                if type_data.description is not None:
                    update_data['description'] = type_data.description
                
                if not update_data:
                    # No data to update, just return the existing record
                    return self.get_service_provider_type_by_id(type_id, home_id)

                result = conn.execute(
                    types_table.update()
                    .where(types_table.c.id == type_id)
                    .values(**update_data)
                )
                conn.commit()

                if result.rowcount > 0:
                    # Fetch the updated row
                    updated_row = conn.execute(
                        types_table.select().where(types_table.c.id == type_id)
                    ).fetchone()
                    
                    if updated_row:
                        return ServiceProviderType(
                            id=updated_row.id,
                            name=updated_row.name,
                            description=updated_row.description
                        )
                return None
        except Exception as exc:
            print(f"Error updating service provider type {type_id} for home {home_id}: {exc}")
            return None

    def delete_service_provider_type(self, type_id: int, home_id: int) -> bool:
        """Delete service provider type by ID; returns True if a row was removed."""
        try:
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return False

            types_table = self._get_service_provider_types_table(schema_name)
            if types_table is None:
                return False

            with self.engine.connect() as conn:
                result = conn.execute(
                    types_table.delete().where(types_table.c.id == type_id)
                )
                conn.commit()
                return result.rowcount > 0
        except Exception as exc:
            print(f"Error deleting service provider type {type_id} for home {home_id}: {exc}")
            return False


# Global singleton instance
service_provider_type_db = ServiceProviderTypeDatabase()