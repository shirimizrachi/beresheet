"""
Azure SQL Server database service implementation
"""

import os
from urllib.parse import quote_plus

# Get configuration from environment variables to avoid circular imports
DATABASE_TYPE = os.getenv("DATABASE_TYPE", "local")
DATABASE_NAME = os.getenv("DATABASE_NAME", "residents")
SCHEMA_NAME = os.getenv("SCHEMA_NAME", "home")
USER_NAME = os.getenv("USER_NAME")
USER_PASSWORD = os.getenv("USER_PASSWORD")
home_index_NAME = os.getenv("home_index_NAME", "home_index")
HOME_INDEX_USER_NAME = os.getenv("HOME_INDEX_USER_NAME")
HOME_INDEX_USER_PASSWORD = os.getenv("HOME_INDEX_USER_PASSWORD")

# SQL Server admin credentials for setup operations
SQLSERVER_USER = os.getenv("SQLSERVER_USER", "ADMIN")
SQLSERVER_PASSWORD = os.getenv("SQLSERVER_PASSWORD", "home2025!")

class AzureDatabaseService:
    """Azure SQL Server database service"""
    
    def __init__(self):
        # SQL Server configuration
        self.sqlserver_local_server = "localhost\\SQLEXPRESS"
        self.sqlserver_azure_server = "your-server.database.windows.net"  # Update with your Azure SQL server
        
        # Build connection strings
        self._build_connection_strings()
    
    def _build_connection_strings(self):
        """Build all connection strings"""
        # Main database connection strings
        self.local_connection_string = f"mssql+pyodbc://{USER_NAME}:{quote_plus(USER_PASSWORD)}@{self.sqlserver_local_server}/{DATABASE_NAME}?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"
        self.local_admin_connection_string = f"mssql+pyodbc://{SQLSERVER_USER}:{quote_plus(SQLSERVER_PASSWORD)}@{self.sqlserver_local_server}/{DATABASE_NAME}?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"
        self.azure_connection_string = f"mssql+pyodbc://{USER_NAME}:{quote_plus(USER_PASSWORD)}@{self.sqlserver_azure_server}/{DATABASE_NAME}?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"
        
        # Home Index connection strings - For SQL Server, home_index is a schema in the same database
        self.local_home_index_connection_string = f"mssql+pyodbc://{HOME_INDEX_USER_NAME}:{quote_plus(HOME_INDEX_USER_PASSWORD)}@{self.sqlserver_local_server}/{DATABASE_NAME}?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"
        self.azure_home_index_connection_string = f"mssql+pyodbc://{HOME_INDEX_USER_NAME}:{quote_plus(HOME_INDEX_USER_PASSWORD)}@{self.sqlserver_azure_server}/{DATABASE_NAME}?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"
    
    def get_connection_string(self):
        """Get the active connection string based on DATABASE_TYPE"""
        if DATABASE_TYPE in ["azure", "cloud"]:
            return self.azure_connection_string
        else:
            return self.local_connection_string
    
    def get_admin_connection_string(self):
        """Get the admin connection string with elevated privileges based on DATABASE_TYPE"""
        if DATABASE_TYPE in ["azure", "cloud"]:
            return self.azure_connection_string  # For cloud, admin user already has schema creation permissions
        else:
            return self.local_admin_connection_string  # For local, use admin authentication for elevated privileges
    
    def get_master_connection_string(self):
        """Get the master/system database connection string for database creation operations"""
        if DATABASE_TYPE == "azure":
            return f"mssql+pyodbc://{SQLSERVER_USER}:{quote_plus(SQLSERVER_PASSWORD)}@{self.sqlserver_azure_server}/master?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"
        else:
            return f"mssql+pyodbc://{SQLSERVER_USER}:{quote_plus(SQLSERVER_PASSWORD)}@{self.sqlserver_local_server}/master?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"
    
    def get_server_info(self):
        """Get server information based on DATABASE_TYPE"""
        if DATABASE_TYPE == "azure":
            server = self.sqlserver_azure_server
        else:
            server = self.sqlserver_local_server
        return {
            "type": DATABASE_TYPE,
            "engine": "sqlserver",
            "server": server,
            "connection_string": self.get_connection_string()
        }
    
    def get_home_index_connection_string(self):
        """Get the home index connection string based on DATABASE_TYPE"""
        if DATABASE_TYPE in ["azure", "cloud"]:
            return self.azure_home_index_connection_string
        else:
            return self.local_home_index_connection_string
    
    def get_home_index_server_info(self):
        """Get home index server information based on DATABASE_TYPE"""
        if DATABASE_TYPE == "azure":
            server = self.sqlserver_azure_server
        else:
            server = self.sqlserver_local_server
        return {
            "type": DATABASE_TYPE,
            "engine": "sqlserver",
            "server": server,
            "connection_string": self.get_home_index_connection_string()
        }
    
    def get_tenant_connection_string(self, tenant_name: str):
        """Get connection string for a tenant using tenant-specific credentials"""
        tenant_password = "TenantApp2025!@#"
        if DATABASE_TYPE in ["azure", "cloud"]:
            return f"mssql+pyodbc://{tenant_name}:{quote_plus(tenant_password)}@{self.sqlserver_azure_server}/{DATABASE_NAME}?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"
        else:
            return f"mssql+pyodbc://{tenant_name}:{quote_plus(tenant_password)}@{self.sqlserver_local_server}/{DATABASE_NAME}?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"

def get_azure_database_service():
    """Get Azure database service instance"""
    return AzureDatabaseService()