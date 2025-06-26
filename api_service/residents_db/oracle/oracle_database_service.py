"""
Oracle ATP (Autonomous Transaction Processing) database service implementation
"""

import os
from urllib.parse import quote_plus
from dotenv import load_dotenv

# Get configuration from environment variables to avoid circular imports
DATABASE_NAME = os.getenv("DATABASE_NAME")
SCHEMA_NAME = os.getenv("SCHEMA_NAME")


# Load environment variables
load_dotenv()

class OracleDatabaseService:
    """Oracle ATP database service"""
    
    def __init__(self):
        # Oracle ATP Configuration
        self.oracle_username = os.getenv("ORACLE_USER")
        self.oracle_password = os.getenv("ORACLE_ATP_PASSWORD")
        self.oracle_database_name = os.getenv("ORACLE_DATABASE_NAME", "residents")
        self.oracle_service_level = os.getenv("ORACLE_SERVICE_LEVEL", "residents_medium")
        
        # Validate required credentials
        if not self.oracle_username:
            raise ValueError("ORACLE_USER environment variable is required")
        if not self.oracle_password:
            raise ValueError("ORACLE_ATP_PASSWORD environment variable is required")
        
        # Oracle ATP Connection String (only residents_medium)
        self.oracle_atp_connection = "(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=adb.il-jerusalem-1.oraclecloud.com))(connect_data=(service_name=gb3f9204cbd02e0_residents_medium.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))"
        
        # Schema configuration
        self.oracle_schema_name = "RESIDENTS_SCHEMA"
        self.oracle_home_index_schema = "HOME_INDEX_SCHEMA"
        
        # Build connection strings
        self._build_connection_strings()
    
    def _build_connection_strings(self):
        """Build all Oracle connection strings"""
        # Use the residents_medium connection string
        oracle_tns = self.oracle_atp_connection
        
        # Main database connection string using oracledb driver
        self.oracle_connection_string = f"oracle+oracledb://{self.oracle_username}:{quote_plus(self.oracle_password)}@{oracle_tns}"
        
        # For Oracle, admin connection is typically the same as regular connection
        self.oracle_admin_connection_string = self.oracle_connection_string
        
        # Master connection (for schema/user creation) - same as admin in Oracle ATP
        self.oracle_master_connection_string = self.oracle_connection_string
        
        # Home Index connection strings - For Oracle, we can use the same connection but different schema
        self.oracle_home_index_connection_string = self.oracle_connection_string
    
    def get_connection_string(self):
        """Get the active Oracle connection string"""
        return self.oracle_connection_string
    
    def get_admin_connection_string(self):
        """Get the admin connection string (same as regular connection for Oracle ATP)"""
        return self.oracle_admin_connection_string
    
    def get_master_connection_string(self):
        """Get the master/system database connection string for database creation operations"""
        return self.oracle_master_connection_string
    
    def get_server_info(self):
        """Get Oracle ATP server information"""
        return {
            "type": "oracle_atp",
            "engine": "oracle",
            "service_level": self.oracle_service_level,
            "host": "adb.il-jerusalem-1.oraclecloud.com",
            "port": 1521,
            "protocol": "tcps",
            "connection_string": self.get_connection_string(),
            "description": f"Oracle Autonomous Transaction Processing - {self.oracle_service_level}"
        }
    
    def get_home_index_connection_string(self):
        """Get the home index connection string"""
        return self.oracle_home_index_connection_string
    
    def get_home_index_server_info(self):
        """Get home index server information"""
        return {
            "type": "oracle_atp",
            "engine": "oracle",
            "service_level": self.oracle_service_level,
            "host": "adb.il-jerusalem-1.oraclecloud.com",
            "port": 1521,
            "protocol": "tcps",
            "schema": self.oracle_home_index_schema,
            "connection_string": self.get_home_index_connection_string(),
            "description": f"Oracle ATP Home Index - {self.oracle_service_level}"
        }
    
    def get_oracle_service_level(self):
        """Get the configured Oracle service level"""
        return self.oracle_service_level
    
    def get_oracle_connection(self):
        """Get Oracle ATP connection string (residents_medium)"""
        return self.oracle_connection_string
    
    def get_tenant_connection_string(self, tenant_name: str):
        """Get connection string for a tenant using tenant-specific credentials"""
        from urllib.parse import quote_plus
        tenant_password = "TenantApp2025!@#"
        oracle_tns = self.oracle_atp_connection
        return f"oracle+oracledb://{tenant_name}:{quote_plus(tenant_password)}@{oracle_tns}"

def get_oracle_database_service():
    """Get Oracle database service instance"""
    return OracleDatabaseService()