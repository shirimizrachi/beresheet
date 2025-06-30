"""
Oracle ATP (Autonomous Transaction Processing) Configuration
Configuration for connecting to Oracle Cloud ATP database
"""

import os
from urllib.parse import quote_plus
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Oracle ATP Database Configuration
ORACLE_USERNAME = os.getenv("ORACLE_USERNAME", "ADMIN")  # Default ATP admin user
ORACLE_PASSWORD = os.getenv("ORACLE_PASSWORD", "YourPassword123!")  # Set your ATP password
ORACLE_DATABASE_NAME = os.getenv("ORACLE_DATABASE_NAME", "residents")  # Database name

# Oracle ATP Connection Strings (provided by user)
ORACLE_ATP_CONNECTIONS = {
    "residents_high": "(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=adb.il-jerusalem-1.oraclecloud.com))(connect_data=(service_name=gb3f9204cbd02e0_residents_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))",
    "residents_low": "(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=adb.il-jerusalem-1.oraclecloud.com))(connect_data=(service_name=gb3f9204cbd02e0_residents_low.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))",
    "residents_medium": "(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=adb.il-jerusalem-1.oraclecloud.com))(connect_data=(service_name=gb3f9204cbd02e0_residents_medium.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))",
    "residents_tp": "(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=adb.il-jerusalem-1.oraclecloud.com))(connect_data=(service_name=gb3f9204cbd02e0_residents_tp.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))",
    "residents_tpurgent": "(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=adb.il-jerusalem-1.oraclecloud.com))(connect_data=(service_name=gb3f9204cbd02e0_residents_tpurgent.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))"
}

# Default service level (can be changed based on workload requirements)
DEFAULT_SERVICE_LEVEL = "residents_medium"  # Medium service level for balanced performance

# Build Oracle SQLAlchemy connection strings
def get_oracle_connection_string(service_level=DEFAULT_SERVICE_LEVEL):
    """
    Get Oracle SQLAlchemy connection string for specified service level
    
    Args:
        service_level (str): The service level to use (residents_high, residents_medium, etc.)
    
    Returns:
        str: SQLAlchemy connection string for Oracle
    """
    if service_level not in ORACLE_ATP_CONNECTIONS:
        raise ValueError(f"Invalid service level: {service_level}. Available: {list(ORACLE_ATP_CONNECTIONS.keys())}")
    
    connection_string = ORACLE_ATP_CONNECTIONS[service_level]
    # Create SQLAlchemy connection string using oracledb (python-oracledb driver)
    # Format: oracle+oracledb://username:password@connection_string
    return f"oracle+oracledb://{ORACLE_USERNAME}:{quote_plus(ORACLE_PASSWORD)}@{connection_string}"

# Alternative connection string using cx_Oracle (if needed)
def get_oracle_cx_connection_string(service_level=DEFAULT_SERVICE_LEVEL):
    """
    Get Oracle SQLAlchemy connection string using cx_Oracle driver
    
    Args:
        service_level (str): The service level to use
    
    Returns:
        str: SQLAlchemy connection string for Oracle using cx_Oracle
    """
    if service_level not in ORACLE_ATP_CONNECTIONS:
        raise ValueError(f"Invalid service level: {service_level}. Available: {list(ORACLE_ATP_CONNECTIONS.keys())}")
    
    connection_string = ORACLE_ATP_CONNECTIONS[service_level]
    # Format: oracle+cx_oracle://username:password@connection_string
    return f"oracle+cx_oracle://{ORACLE_USERNAME}:{quote_plus(ORACLE_PASSWORD)}@{connection_string}"

# Helper functions for different service levels
def get_high_performance_connection():
    """Get connection string for high performance workloads"""
    return get_oracle_connection_string("residents_high")

def get_low_cost_connection():
    """Get connection string for low-cost workloads"""
    return get_oracle_connection_string("residents_low")

def get_balanced_connection():
    """Get connection string for balanced workloads"""
    return get_oracle_connection_string("residents_medium")

def get_transaction_processing_connection():
    """Get connection string optimized for transaction processing"""
    return get_oracle_connection_string("residents_tp")

def get_urgent_connection():
    """Get connection string for urgent/critical workloads"""
    return get_oracle_connection_string("residents_tpurgent")

# Schema and user configuration
ORACLE_SCHEMA_NAME = "home"
ORACLE_TEST_USER = "TEST_USER"

# Connection pool settings for SQLAlchemy
ORACLE_POOL_SETTINGS = {
    'pool_size': 5,
    'max_overflow': 10,
    'pool_pre_ping': True,
    'pool_recycle': 300,  # 5 minutes
}

# Oracle-specific settings
ORACLE_SETTINGS = {
    'echo': False,  # Set to True for SQL debugging
    'echo_pool': False,  # Set to True for connection pool debugging
    'future': True,  # Use SQLAlchemy 2.0 style
}

def get_oracle_server_info(service_level=DEFAULT_SERVICE_LEVEL):
    """
    Get Oracle ATP server information
    
    Args:
        service_level (str): The service level to use
    
    Returns:
        dict: Server information
    """
    return {
        "type": "oracle_atp",
        "engine": "oracle",
        "service_level": service_level,
        "host": "adb.il-jerusalem-1.oraclecloud.com",
        "port": 1521,
        "protocol": "tcps",
        "connection_string": get_oracle_connection_string(service_level),
        "description": f"Oracle Autonomous Transaction Processing - {service_level}"
    }

# Environment variables template (add to .env file)
ENV_TEMPLATE = """
# Oracle ATP Configuration
ORACLE_USERNAME=ADMIN
ORACLE_PASSWORD=YourPassword123!
ORACLE_SERVICE_LEVEL=residents_medium
"""

def print_env_template():
    """Print environment variables template"""
    print("Add these environment variables to your .env file:")
    print(ENV_TEMPLATE)