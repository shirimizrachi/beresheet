"""
Home ID to Database Schema Mapping
This file maps home IDs to their corresponding database schemas
"""

from typing import Dict, Optional, List

# Base connection string template - username will be dynamically determined
CONNECTION_STRING_TEMPLATE = "mssql+pyodbc://{username}:{password}@localhost\\SQLEXPRESS/home?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"

# Schema to database user mapping - each schema has its own database user
SCHEMA_USER_MAPPING: Dict[str, Dict[str, str]] = {
    "beresheet": {
        "username": "beresheet",
        "password": "beresheet2025!"
    },
    # Add more schema users as needed
}

# Home ID to Schema mapping
HOME_SCHEMA_MAPPING: Dict[int, str] = {
    1: "beresheet",
    # Add more mappings as needed
    # 2: "another_schema",
    # 3: "third_schema",
}

# Home ID to Home Name mapping for display purposes
HOME_NAME_MAPPING: Dict[int, str] = {
    1: "Beresheet Community",
    # Add more mappings as needed
    # 2: "Another Community",
    # 3: "Third Community",
}

def get_schema_for_home(home_id: int) -> Optional[str]:
    """
    Get the database schema name for a given home ID
    
    Args:
        home_id: The home ID number
        
    Returns:
        Schema name if found, None otherwise
    """
    return HOME_SCHEMA_MAPPING.get(home_id)

def get_name_for_home(home_id: int) -> Optional[str]:
    """
    Get the display name for a given home ID
    
    Args:
        home_id: The home ID number
        
    Returns:
        Home name if found, None otherwise
    """
    return HOME_NAME_MAPPING.get(home_id)

def get_connection_string() -> str:
    """
    Get the default database connection string (fallback to beresheet user)
    
    Returns:
        Connection string for the home database
    """
    beresheet_config = SCHEMA_USER_MAPPING.get("beresheet", {
        "username": "beresheet",
        "password": "beresheet2025!"
    })
    return CONNECTION_STRING_TEMPLATE.format(
        username=beresheet_config["username"],
        password=beresheet_config["password"]
    )

def get_connection_string_for_home(home_id: int) -> Optional[str]:
    """
    Get the connection string for a specific home's schema using schema-specific user
    
    Args:
        home_id: The home ID number
        
    Returns:
        Connection string with schema-specific user if found, None otherwise
    """
    schema = get_schema_for_home(home_id)
    if schema and schema in SCHEMA_USER_MAPPING:
        user_config = SCHEMA_USER_MAPPING[schema]
        return CONNECTION_STRING_TEMPLATE.format(
            username=user_config["username"],
            password=user_config["password"]
        )
    return None

def get_connection_string_for_schema(schema_name: str) -> Optional[str]:
    """
    Get the connection string for a specific schema using schema-specific user
    
    Args:
        schema_name: The schema name
        
    Returns:
        Connection string with schema-specific user if found, None otherwise
    """
    if schema_name in SCHEMA_USER_MAPPING:
        user_config = SCHEMA_USER_MAPPING[schema_name]
        return CONNECTION_STRING_TEMPLATE.format(
            username=user_config["username"],
            password=user_config["password"]
        )
    return None

def add_home_mapping(home_id: int, schema_name: str, home_name: str) -> None:
    """
    Add a new home to schema mapping
    
    Args:
        home_id: The home ID number
        schema_name: The database schema name
        home_name: The display name for the home
    """
    HOME_SCHEMA_MAPPING[home_id] = schema_name
    HOME_NAME_MAPPING[home_id] = home_name
    print(f"Added mapping: Home {home_id} ({home_name}) -> Schema {schema_name}")

def get_all_homes() -> List[Dict[str, any]]:
    """
    Get all available homes with their IDs and names
    
    Returns:
        List of dictionaries containing home information
    """
    homes = []
    for home_id, schema_name in HOME_SCHEMA_MAPPING.items():
        home_name = HOME_NAME_MAPPING.get(home_id, f"Home {home_id}")
        homes.append({
            "id": home_id,
            "name": home_name,
            "schema": schema_name
        })
    return homes

def list_all_mappings() -> Dict[int, str]:
    """
    Get all current home to schema mappings
    
    Returns:
        Dictionary of all mappings
    """
    return HOME_SCHEMA_MAPPING.copy()

# Legacy function names for backward compatibility
def get_schema_for_resident(home_id: int) -> Optional[str]:
    """Legacy function name - use get_schema_for_home instead"""
    return get_schema_for_home(home_id)

def get_connection_string_for_resident(home_id: int) -> Optional[str]:
    """Legacy function name - use get_connection_string_for_home instead"""
    return get_connection_string_for_home(home_id)

def add_resident_mapping(home_id: int, schema_name: str) -> None:
    """Legacy function name - use add_home_mapping instead"""
    add_home_mapping(home_id, schema_name, f"Home {home_id}")