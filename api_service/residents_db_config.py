"""
Template configuration for residents database connection
Copy this file to residents_db_config.py and update with your settings
"""

from urllib.parse import quote_plus

# Database Configuration for residents database
# Choose one configuration type and update the corresponding settings

# Connection configuration type: "local" or "azure"
DATABASE_TYPE = "local"  # Change to "azure" for Azure SQL Database
DATABASE_NAME = "residents"
SCHEMA_NAME = "home"
USER_NAME = "home"
USER_PASSWORD = "home2025!"

# Local SQL Express configuration
LOCAL_SERVER = "localhost\\SQLEXPRESS"
LOCAL_CONNECTION_STRING = f"mssql+pyodbc://{USER_NAME}:{quote_plus(USER_PASSWORD)}@{LOCAL_SERVER}/{DATABASE_NAME}?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"
LOCAL_ADMIN_CONNECTION_STRING = f"mssql+pyodbc://{LOCAL_SERVER}/{DATABASE_NAME}?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes&Trusted_Connection=yes"

# Azure SQL Database configuration
AZURE_SERVER = "your-server.database.windows.net"  # Update with your Azure SQL server
AZURE_CONNECTION_STRING = f"mssql+pyodbc://{USER_NAME}:{quote_plus(USER_PASSWORD)}@{AZURE_SERVER}/{DATABASE_NAME}?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"

# Helper function to get the active connection string
def get_connection_string():
    """Get the active connection string based on DATABASE_TYPE"""
    if DATABASE_TYPE == "azure":
        return AZURE_CONNECTION_STRING
    else:
        return LOCAL_CONNECTION_STRING

# Helper function to get the admin connection string (for schema creation)
def get_admin_connection_string():
    """Get the admin connection string with elevated privileges based on DATABASE_TYPE"""
    if DATABASE_TYPE == "azure":
        return AZURE_CONNECTION_STRING  # For Azure, admin user already has schema creation permissions
    else:
        return LOCAL_ADMIN_CONNECTION_STRING  # For local, use Windows Authentication for elevated privileges

# Helper function to get server info
def get_server_info():
    """Get server information based on DATABASE_TYPE"""
    if DATABASE_TYPE == "azure":
        return {
            "type": "azure",
            "server": AZURE_SERVER,
            "connection_string": AZURE_CONNECTION_STRING
        }
    else:
        return {
            "type": "local",
            "server": LOCAL_SERVER,
            "connection_string": LOCAL_CONNECTION_STRING
        }

# Home Index Configuration
HOME_INDEX_SCHEMA_NAME = "home_index"
HOME_INDEX_USER_NAME = "home_index"
HOME_INDEX_USER_PASSWORD = "HomeIndex2025!@#"

# Home Index connection strings
LOCAL_HOME_INDEX_CONNECTION_STRING = f"mssql+pyodbc://{HOME_INDEX_USER_NAME}:{quote_plus(HOME_INDEX_USER_PASSWORD)}@{LOCAL_SERVER}/{DATABASE_NAME}?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"
AZURE_HOME_INDEX_CONNECTION_STRING = f"mssql+pyodbc://{HOME_INDEX_USER_NAME}:{quote_plus(HOME_INDEX_USER_PASSWORD)}@{AZURE_SERVER}/{DATABASE_NAME}?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"

# Helper function to get the home index connection string
def get_home_index_connection_string():
    """Get the home index connection string based on DATABASE_TYPE"""
    if DATABASE_TYPE == "azure":
        return AZURE_HOME_INDEX_CONNECTION_STRING
    else:
        return LOCAL_HOME_INDEX_CONNECTION_STRING

# Helper function to get home index server info
def get_home_index_server_info():
    """Get home index server information based on DATABASE_TYPE"""
    if DATABASE_TYPE == "azure":
        return {
            "type": "azure",
            "server": AZURE_SERVER,
            "connection_string": AZURE_HOME_INDEX_CONNECTION_STRING
        }
    else:
        return {
            "type": "local",
            "server": LOCAL_SERVER,
            "connection_string": LOCAL_HOME_INDEX_CONNECTION_STRING
        }

# Additional configuration constants for compatibility
ADMIN_CONNECTION_STRING = get_connection_string()
ADMIN_SCHEMA = SCHEMA_NAME
ADMIN_DATABASE = DATABASE_NAME