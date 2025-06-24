# Admin Schema Management

This directory contains tools for managing database schemas for both SQL Server and MySQL databases in the multi-tenant system.

## 🛠️ Available Operations

### Schema Creation
- **SQL Server**: Creates schema, login, user, and sets permissions
- **MySQL**: Creates database, user, and sets permissions

### Schema Deletion
- **SQL Server**: Drops all tables, schema, user, and login
- **MySQL**: Drops database (including all tables) and user

## 📁 Directory Structure

```
admin/
├── README.md                    # This file
├── delete_schema_manual.py      # Manual schema deletion script
├── sqlserver/
│   └── schema_operations.py     # SQL Server operations
└── mysql/
    └── schema_operations.py     # MySQL operations
```

## 🚀 Manual Schema Deletion

### Prerequisites
1. Make sure you're in the `api_service` directory
2. Ensure Python environment has required dependencies (`sqlalchemy`, `pyodbc`, etc.)
3. Database connection must be configured in `residents_db_config.py`

### Usage

```bash
# Navigate to the api_service directory
cd api_service

# Run the deletion script
python deployment/admin/delete_schema_manual.py <schema_name>
```

### Examples

#### Delete a SQL Server schema named "demo":
```bash
python deployment/admin/delete_schema_manual.py demo
```

#### Delete a MySQL database named "test_tenant":
```bash
python deployment/admin/delete_schema_manual.py test_tenant
```

### What the Script Does

The deletion script will:

1. **Validate** the schema name (alphanumeric with optional hyphens/underscores)
2. **Detect** the database engine (SQL Server or MySQL)
3. **Ask for confirmation** before proceeding
4. **Delete in order**:
   - All tables in the schema/database
   - The schema/database itself
   - Associated database user
   - Associated login (SQL Server only)
5. **Verify** that deletion was successful
6. **Report** detailed results

### Sample Output

```
🗑️  Starting deletion process for schema: demo
============================================================
📊 Database Engine: mssql
🔗 Admin Connection: localhost\SQLEXPRESS/residents

⚠️  Are you sure you want to PERMANENTLY DELETE schema 'demo'? (yes/no): yes

🔥 Deleting SQL Server schema 'demo'...

============================================================
📋 DELETION RESULTS
============================================================
✅ Status: SUCCESS
📝 Message: Schema 'demo' and associated user/login deleted successfully
🗃️  Schema: demo
📊 Tables dropped: 8
👤 User dropped: Yes
🔐 Login dropped: Yes

🎉 Schema 'demo' has been completely deleted!
```

## ⚠️ Important Notes

### Safety Considerations
- **This operation is IRREVERSIBLE** - all data will be permanently lost
- Always backup important data before deletion
- The script asks for confirmation before proceeding
- Schema names must be alphanumeric (with optional hyphens and underscores)

### Troubleshooting

#### Permission Errors
- Ensure the admin connection string has sufficient privileges
- For SQL Server: Requires `sysadmin` or `dbcreator` rights
- For MySQL: Requires `DROP`, `CREATE USER`, and `RELOAD` privileges

#### Connection Issues
- Verify `residents_db_config.py` is properly configured
- Check that database server is running and accessible
- Ensure firewall allows database connections

#### Import Errors
- Run the script from the `api_service` directory
- Ensure all Python dependencies are installed
- Check that the database driver is available (`pyodbc` for SQL Server, `PyMySQL` for MySQL)

## 🔧 Using Functions Programmatically

You can also import and use the deletion functions directly in your Python code:

### SQL Server
```python
from deployment.admin.sqlserver.schema_operations import delete_schema_and_user_sqlserver
from residents_db_config import get_admin_connection_string

admin_conn_str = get_admin_connection_string()
result = delete_schema_and_user_sqlserver("schema_name", admin_conn_str)

if result["status"] == "success":
    print(f"Deleted schema successfully: {result['message']}")
else:
    print(f"Deletion failed: {result['message']}")
```

### MySQL
```python
from deployment.admin.mysql.schema_operations import delete_schema_and_user_mysql
from residents_db_config import get_admin_connection_string

admin_conn_str = get_admin_connection_string()
result = delete_schema_and_user_mysql("database_name", admin_conn_str)

if result["status"] == "success":
    print(f"Deleted database successfully: {result['message']}")
else:
    print(f"Deletion failed: {result['message']}")
```

## 📝 Function Return Values

Both deletion functions return a dictionary with:

```python
{
    "status": "success" | "warning" | "error",
    "message": "Description of what happened",
    "schema_name": "name_of_schema",
    "tables_dropped": 5,  # Number of tables that were dropped
    "user_dropped": True,  # Whether user was dropped
    "login_dropped": True  # Whether login was dropped (SQL Server only)
}
```

## 🆘 Support

If you encounter issues:

1. Check the console output for specific error messages
2. Verify database connectivity and permissions
3. Ensure schema name follows naming conventions
4. Check that all dependencies are installed
5. Review the logs for detailed error information

For persistent issues, check the application logs or contact your database administrator.