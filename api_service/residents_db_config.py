"""
Template configuration for residents database connection
Copy this file to residents_db_config.py and update with your settings
"""

import os
from urllib.parse import quote_plus

# Database Configuration for residents database
# Choose one configuration type and update the corresponding settings

# Database engine type: "sqlserver" or "mysql"
DATABASE_ENGINE = os.getenv("DATABASE_ENGINE", "sqlserver")  # Default: sqlserver

# Storage provider configuration: "azure" or "cloudflare"
STORAGE_PROVIDER = os.getenv("STORAGE_PROVIDER", "azure")  # Default: azure

# Connection configuration type: "local" or "azure"/"cloud"
DATABASE_TYPE = "local"  # Change to "azure" for Azure SQL Database or "cloud" for cloud MySQL
DATABASE_NAME = "residents"
SCHEMA_NAME = "home"
USER_NAME = "home"
USER_PASSWORD = "home2025!"

# SQL Server configuration
SQLSERVER_LOCAL_SERVER = "localhost\\SQLEXPRESS"
SQLSERVER_AZURE_SERVER = "your-server.database.windows.net"  # Update with your Azure SQL server

# MySQL configuration
MYSQL_LOCAL_SERVER = "localhost"
MYSQL_LOCAL_PORT = "3306"
MYSQL_CLOUD_SERVER = "your-mysql-server.com"  # Update with your cloud MySQL server
MYSQL_CLOUD_PORT = "3306"

# Build connection strings based on database engine
if DATABASE_ENGINE == "mysql":
    # MySQL connection strings
    if DATABASE_TYPE == "cloud":
        MYSQL_SERVER = f"{MYSQL_CLOUD_SERVER}:{MYSQL_CLOUD_PORT}"
        LOCAL_CONNECTION_STRING = f"mysql+pymysql://{USER_NAME}:{quote_plus(USER_PASSWORD)}@{MYSQL_SERVER}/{DATABASE_NAME}"
        LOCAL_ADMIN_CONNECTION_STRING = f"mysql+pymysql://root:{quote_plus('admin_password')}@{MYSQL_SERVER}"  # Update with actual admin password
        AZURE_CONNECTION_STRING = LOCAL_CONNECTION_STRING  # Same for cloud MySQL
    else:
        MYSQL_SERVER = f"{MYSQL_LOCAL_SERVER}:{MYSQL_LOCAL_PORT}"
        LOCAL_CONNECTION_STRING = f"mysql+pymysql://{USER_NAME}:{quote_plus(USER_PASSWORD)}@{MYSQL_SERVER}/{DATABASE_NAME}"
        LOCAL_ADMIN_CONNECTION_STRING = f"mysql+pymysql://root:{quote_plus('admin_password')}@{MYSQL_SERVER}"  # Update with actual admin password
        AZURE_CONNECTION_STRING = LOCAL_CONNECTION_STRING  # Same for local MySQL
else:
    # SQL Server connection strings (default)
    LOCAL_CONNECTION_STRING = f"mssql+pyodbc://{USER_NAME}:{quote_plus(USER_PASSWORD)}@{SQLSERVER_LOCAL_SERVER}/{DATABASE_NAME}?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"
    LOCAL_ADMIN_CONNECTION_STRING = f"mssql+pyodbc://{SQLSERVER_LOCAL_SERVER}/{DATABASE_NAME}?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes&Trusted_Connection=yes"
    AZURE_CONNECTION_STRING = f"mssql+pyodbc://{USER_NAME}:{quote_plus(USER_PASSWORD)}@{SQLSERVER_AZURE_SERVER}/{DATABASE_NAME}?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"

# Helper function to get the active connection string
def get_connection_string():
    """Get the active connection string based on DATABASE_TYPE"""
    if DATABASE_TYPE in ["azure", "cloud"]:
        return AZURE_CONNECTION_STRING
    else:
        return LOCAL_CONNECTION_STRING

# Helper function to get the admin connection string (for schema creation)
def get_admin_connection_string():
    """Get the admin connection string with elevated privileges based on DATABASE_TYPE"""
    if DATABASE_TYPE in ["azure", "cloud"]:
        return AZURE_CONNECTION_STRING  # For cloud, admin user already has schema creation permissions
    else:
        return LOCAL_ADMIN_CONNECTION_STRING  # For local, use admin authentication for elevated privileges

# Helper function to get master/system connection string (for database creation)
def get_master_connection_string():
    """Get the master/system database connection string for database creation operations"""
    if DATABASE_ENGINE == "mysql":
        # For MySQL, connect to mysql system database for database creation
        if DATABASE_TYPE == "cloud":
            return f"mysql+pymysql://root:{quote_plus('admin_password')}@{MYSQL_SERVER}/mysql"  # Update with actual admin password
        else:
            return f"mysql+pymysql://root:{quote_plus('admin_password')}@{MYSQL_SERVER}/mysql"  # Update with actual admin password
    else:
        # For SQL Server, connect to master database
        if DATABASE_TYPE == "azure":
            return f"mssql+pyodbc://{USER_NAME}:{quote_plus(USER_PASSWORD)}@{SQLSERVER_AZURE_SERVER}/master?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"
        else:
            return f"mssql+pyodbc://{SQLSERVER_LOCAL_SERVER}/master?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes&Trusted_Connection=yes"

# Helper function to get server info
def get_server_info():
    """Get server information based on DATABASE_ENGINE and DATABASE_TYPE"""
    if DATABASE_ENGINE == "mysql":
        if DATABASE_TYPE == "cloud":
            server = MYSQL_CLOUD_SERVER
        else:
            server = f"{MYSQL_LOCAL_SERVER}:{MYSQL_LOCAL_PORT}"
        return {
            "type": DATABASE_TYPE,
            "engine": "mysql",
            "server": server,
            "connection_string": get_connection_string()
        }
    else:
        if DATABASE_TYPE == "azure":
            server = SQLSERVER_AZURE_SERVER
        else:
            server = SQLSERVER_LOCAL_SERVER
        return {
            "type": DATABASE_TYPE,
            "engine": "sqlserver",
            "server": server,
            "connection_string": get_connection_string()
        }

# Home Index Configuration
HOME_INDEX_SCHEMA_NAME = "home_index"
HOME_INDEX_USER_NAME = "home_index"
HOME_INDEX_USER_PASSWORD = "HomeIndex2025!@#"

# Build Home Index connection strings based on database engine
if DATABASE_ENGINE == "mysql":
    # For MySQL, home_index is a separate database
    if DATABASE_TYPE == "cloud":
        LOCAL_HOME_INDEX_CONNECTION_STRING = f"mysql+pymysql://{HOME_INDEX_USER_NAME}:{quote_plus(HOME_INDEX_USER_PASSWORD)}@{MYSQL_SERVER}/{HOME_INDEX_SCHEMA_NAME}"
        AZURE_HOME_INDEX_CONNECTION_STRING = LOCAL_HOME_INDEX_CONNECTION_STRING
    else:
        LOCAL_HOME_INDEX_CONNECTION_STRING = f"mysql+pymysql://{HOME_INDEX_USER_NAME}:{quote_plus(HOME_INDEX_USER_PASSWORD)}@{MYSQL_SERVER}/{HOME_INDEX_SCHEMA_NAME}"
        AZURE_HOME_INDEX_CONNECTION_STRING = LOCAL_HOME_INDEX_CONNECTION_STRING
else:
    # For SQL Server, home_index is a schema in the same database
    LOCAL_HOME_INDEX_CONNECTION_STRING = f"mssql+pyodbc://{HOME_INDEX_USER_NAME}:{quote_plus(HOME_INDEX_USER_PASSWORD)}@{SQLSERVER_LOCAL_SERVER}/{DATABASE_NAME}?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"
    AZURE_HOME_INDEX_CONNECTION_STRING = f"mssql+pyodbc://{HOME_INDEX_USER_NAME}:{quote_plus(HOME_INDEX_USER_PASSWORD)}@{SQLSERVER_AZURE_SERVER}/{DATABASE_NAME}?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"

# Helper function to get the home index connection string
def get_home_index_connection_string():
    """Get the home index connection string based on DATABASE_TYPE"""
    if DATABASE_TYPE in ["azure", "cloud"]:
        return AZURE_HOME_INDEX_CONNECTION_STRING
    else:
        return LOCAL_HOME_INDEX_CONNECTION_STRING

# Helper function to get home index server info
def get_home_index_server_info():
    """Get home index server information based on DATABASE_ENGINE and DATABASE_TYPE"""
    if DATABASE_ENGINE == "mysql":
        if DATABASE_TYPE == "cloud":
            server = MYSQL_CLOUD_SERVER
        else:
            server = f"{MYSQL_LOCAL_SERVER}:{MYSQL_LOCAL_PORT}"
        return {
            "type": DATABASE_TYPE,
            "engine": "mysql",
            "server": server,
            "connection_string": get_home_index_connection_string()
        }
    else:
        if DATABASE_TYPE == "azure":
            server = SQLSERVER_AZURE_SERVER
        else:
            server = SQLSERVER_LOCAL_SERVER
        return {
            "type": DATABASE_TYPE,
            "engine": "sqlserver",
            "server": server,
            "connection_string": get_home_index_connection_string()
        }

# Storage configuration
def get_storage_provider():
    """Get the configured storage provider"""
    return STORAGE_PROVIDER.lower()

def get_storage_config():
    """Get storage configuration information"""
    provider = get_storage_provider()
    
    if provider == "cloudflare":
        return {
            "provider": "cloudflare",
            "type": "r2",
            "description": "Cloudflare R2 Storage"
        }
    else:
        return {
            "provider": "azure",
            "type": "blob",
            "description": "Azure Blob Storage"
        }

# Additional configuration constants for compatibility
ADMIN_CONNECTION_STRING = get_connection_string()
ADMIN_SCHEMA = SCHEMA_NAME
ADMIN_DATABASE = DATABASE_NAME