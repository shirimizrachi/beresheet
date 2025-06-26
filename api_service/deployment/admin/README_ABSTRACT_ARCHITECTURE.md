# Abstract Database Architecture

This directory implements an abstract factory pattern for database setup and schema operations, supporting multiple database engines through a unified interface.

## Architecture Overview

The system uses abstract base classes to define common interfaces, with concrete implementations for each supported database engine. The appropriate implementation is automatically selected based on the `DATABASE_ENGINE` configuration in `residents_config.py`.

## Supported Database Engines

- **Oracle**: Oracle Autonomous Transaction Processing (ATP) and standard Oracle databases
- **SQL Server**: Microsoft SQL Server (Express and Azure SQL Database)

## Core Components

### Abstract Base Classes

#### `setup_residents_database.py`
- **Class**: `DatabaseSetupBase`
- **Purpose**: Abstract base class for database setup operations
- **Factory Function**: `get_database_setup()` - Returns appropriate implementation based on `DATABASE_ENGINE`

#### `schema_operations.py`
- **Class**: `SchemaOperationsBase`
- **Purpose**: Abstract base class for schema operations (create/delete schemas and users)
- **Factory Function**: `get_schema_operations()` - Returns appropriate implementation based on `DATABASE_ENGINE`
- **Convenience Functions**: 
  - `create_schema_and_user(schema_name, admin_connection_string)`
  - `delete_schema_and_user(schema_name, admin_connection_string)`

### Concrete Implementations

#### Oracle Implementation
- **Location**: `oracle/`
- **Setup**: `oracle/setup_residents_database.py` - `OracleDatabaseSetup`
- **Schema Ops**: `oracle/schema_operations.py` - `OracleSchemaOperations`

#### SQL Server Implementation
- **Location**: `sqlserver/`
- **Setup**: `sqlserver/setup_residents_database.py` - `SqlServerDatabaseSetup`
- **Schema Ops**: `sqlserver/schema_operations.py` - `SqlServerSchemaOperations`

## Usage Examples

### Database Setup

```python
from setup_residents_database import get_database_setup

# Automatically selects Oracle or SQL Server implementation
# based on DATABASE_ENGINE in residents_config
setup = get_database_setup()
setup.run_setup()
```

### Schema Operations

```python
from schema_operations import create_schema_and_user, delete_schema_and_user
from residents_config import get_admin_connection_string

admin_conn = get_admin_connection_string()

# Create a new tenant schema
result = create_schema_and_user("tenant_demo", admin_conn)
if result["status"] == "success":
    print(f"Created schema: {result['schema_name']}")

# Delete a tenant schema
result = delete_schema_and_user("tenant_demo", admin_conn)
if result["status"] == "success":
    print(f"Deleted schema: {result['schema_name']}")
```

### Direct Implementation Access

```python
# For Oracle-specific operations
from oracle.setup_residents_database import OracleDatabaseSetup
from oracle.schema_operations import OracleSchemaOperations

oracle_setup = OracleDatabaseSetup()
oracle_ops = OracleSchemaOperations()

# For SQL Server-specific operations
from sqlserver.setup_residents_database import SqlServerDatabaseSetup
from sqlserver.schema_operations import SqlServerSchemaOperations

sqlserver_setup = SqlServerDatabaseSetup()
sqlserver_ops = SqlServerSchemaOperations()
```

## Configuration

The system automatically determines which implementation to use based on the `DATABASE_ENGINE` setting in `residents_config.py`:

```python
# In residents_config.py
DATABASE_ENGINE = os.getenv("DATABASE_ENGINE")  # "sqlserver" or "oracle"
```

## Database Setup Methods

All implementations provide these methods:

- `get_connection_config()` - Get database connection configuration
- `create_database()` - Create the residents database
- `create_schema()` - Create the home schema
- `create_user_and_permissions()` - Create user and grant permissions
- `create_home_table()` - Create the home table
- `test_user_connection()` - Test connection with created user
- `display_connection_info()` - Display connection information
- `create_home_index_schema()` - Create the home_index schema
- `create_home_index_user_and_permissions()` - Create home_index user
- `create_home_index_table()` - Create the home_index table
- `test_home_index_connection()` - Test home_index connection
- `run_setup()` - Run complete setup process

## Schema Operations Methods

All implementations provide these methods:

- `create_schema_and_user(schema_name, admin_connection_string)` - Create schema and user
- `delete_schema_and_user(schema_name, admin_connection_string)` - Delete schema and user

## Database Engine Differences

### Oracle
- **User = Schema**: In Oracle, creating a user automatically creates a schema
- **Permissions**: Uses Oracle-specific grants and privileges
- **Objects**: Dropping user with CASCADE removes all schema objects
- **Connection**: Uses Oracle connection string format

### SQL Server
- **Separate Concepts**: Schema and user are separate entities
- **Login vs User**: Requires both server login and database user
- **Permissions**: Uses SQL Server schema permissions
- **Objects**: Must drop tables, constraints, views, functions, and procedures before schema
- **Connection**: Uses SQL Server connection string format

## Testing

Use the test script to verify the abstract factory pattern:

```bash
python test_abstract_setup.py
```

This will test:
- Database setup factory functionality
- Schema operations factory functionality
- Convenience function imports

## Backward Compatibility

The system maintains backward compatibility by providing the original function names in each implementation:

### SQL Server
- `create_schema_and_user_sqlserver()`
- `delete_schema_and_user_sqlserver()`

### Oracle
- `create_schema_and_user_oracle()`
- `delete_schema_and_user_oracle()`

## File Structure

```
api_service/deployment/admin/
├── setup_residents_database.py          # Abstract base class and factory
├── schema_operations.py                 # Abstract base class and factory
├── delete_schema_manual.py             # Updated to use abstract interface
├── test_abstract_setup.py              # Test script
├── README_ABSTRACT_ARCHITECTURE.md     # This documentation
├── oracle/
│   ├── setup_residents_database.py     # Oracle implementation
│   └── schema_operations.py            # Oracle schema operations
└── sqlserver/
    ├── setup_residents_database.py     # SQL Server implementation
    └── schema_operations.py            # SQL Server schema operations
```

## Benefits

1. **Unified Interface**: Same API regardless of database engine
2. **Easy Extension**: Add new database engines by implementing the abstract classes
3. **Configuration-Driven**: Automatically selects implementation based on config
4. **Type Safety**: Abstract base classes ensure consistent method signatures
5. **Backward Compatibility**: Existing code continues to work
6. **Testability**: Easy to mock and test different implementations