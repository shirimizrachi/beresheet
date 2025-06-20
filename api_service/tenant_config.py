"""
Tenant configuration models and database operations
Handles loading tenant configurations from the admin database
"""

from pydantic import BaseModel
from typing import Optional, List, Dict
from sqlalchemy import create_engine, text
from datetime import datetime
import logging
from residents_db_config import get_connection_string, SCHEMA_NAME, DATABASE_NAME

# Admin database connection string
ADMIN_CONNECTION_STRING = get_connection_string()
ADMIN_SCHEMA = SCHEMA_NAME
ADMIN_DATABASE = DATABASE_NAME

# Set up logging
logger = logging.getLogger(__name__)

class TenantConfig(BaseModel):
    """Model for tenant configuration"""
    id: int
    name: str
    database_name: str
    database_type: str
    database_schema: str
    admin_user_email: str
    admin_user_password: str
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True

class TenantCreate(BaseModel):
    """Model for creating a new tenant"""
    name: str
    database_name: str
    database_type: str = "mssql"
    database_schema: str
    admin_user_email: str
    admin_user_password: str

class TenantUpdate(BaseModel):
    """Model for updating a tenant"""
    database_name: Optional[str] = None
    database_type: Optional[str] = None
    database_schema: Optional[str] = None
    admin_user_email: Optional[str] = None
    admin_user_password: Optional[str] = None

class TenantConfigDatabase:
    """Database operations for tenant configurations"""
    
    def __init__(self):
        self._engine = None
    
    @property
    def engine(self):
        """Get or create the admin database engine"""
        if self._engine is None:
            try:
                self._engine = create_engine(ADMIN_CONNECTION_STRING)
                logger.info("Connected to admin database for tenant configurations")
            except Exception as e:
                logger.error(f"Failed to connect to admin database: {e}")
                raise
        return self._engine
    
    def load_tenant_config_from_db(self, tenant_id: str) -> Optional[TenantConfig]:
        """
        Load tenant configuration from the admin database
        
        Args:
            tenant_id: The tenant name/ID to load
            
        Returns:
            TenantConfig if found, None otherwise
        """
        try:
            with self.engine.connect() as conn:
                select_sql = text(f"""
                    SELECT
                        [id],
                        [name],
                        [database_name],
                        [database_type],
                        [database_schema],
                        [admin_user_email],
                        [admin_user_password],
                        [created_at],
                        [updated_at]
                    FROM [{ADMIN_DATABASE}].[{ADMIN_SCHEMA}].[home]
                    WHERE [name] = :tenant_id
                """)
                
                result = conn.execute(select_sql, {"tenant_id": tenant_id}).fetchone()
                
                if result:
                    return TenantConfig(
                        id=result[0],
                        name=result[1],
                        database_name=result[2],
                        database_type=result[3],
                        database_schema=result[4],
                        admin_user_email=result[5],
                        admin_user_password=result[6],
                        created_at=result[7],
                        updated_at=result[8]
                    )
                
                logger.warning(f"Tenant '{tenant_id}' not found in admin database")
                return None
                
        except Exception as e:
            logger.error(f"Error loading tenant config for '{tenant_id}': {e}")
            return None
    
    def get_all_tenants(self) -> List[TenantConfig]:
        """
        Get all tenant configurations
        
        Returns:
            List of all tenant configurations
        """
        try:
            with self.engine.connect() as conn:
                select_sql = text(f"""
                    SELECT
                        [id],
                        [name],
                        [database_name],
                        [database_type],
                        [database_schema],
                        [admin_user_email],
                        [admin_user_password],
                        [created_at],
                        [updated_at]
                    FROM [{ADMIN_DATABASE}].[{ADMIN_SCHEMA}].[home]
                    ORDER BY [id]
                """)
                
                result = conn.execute(select_sql).fetchall()
                
                tenants = []
                for row in result:
                    tenants.append(TenantConfig(
                        id=row[0],
                        name=row[1],
                        database_name=row[2],
                        database_type=row[3],
                        database_schema=row[4],
                        admin_user_email=row[5],
                        admin_user_password=row[6],
                        created_at=row[7],
                        updated_at=row[8]
                    ))
                
                return tenants
                
        except Exception as e:
            logger.error(f"Error getting all tenants: {e}")
            return []
    
    def create_tenant(self, tenant: TenantCreate) -> Optional[TenantConfig]:
        """
        Create a new tenant configuration
        
        Args:
            tenant: Tenant configuration to create
            
        Returns:
            Created TenantConfig if successful, None otherwise
        """
        try:
            with self.engine.connect() as conn:
                insert_sql = text(f"""
                    INSERT INTO [{ADMIN_DATABASE}].[{ADMIN_SCHEMA}].[home] (
                        [name],
                        [database_name],
                        [database_type],
                        [database_schema],
                        [admin_user_email],
                        [admin_user_password]
                    ) OUTPUT INSERTED.id
                    VALUES (
                        :name,
                        :database_name,
                        :database_type,
                        :database_schema,
                        :admin_user_email,
                        :admin_user_password
                    )
                """)
                
                result = conn.execute(insert_sql, {
                    "name": tenant.name,
                    "database_name": tenant.database_name,
                    "database_type": tenant.database_type,
                    "database_schema": tenant.database_schema,
                    "admin_user_email": tenant.admin_user_email,
                    "admin_user_password": tenant.admin_user_password
                }).fetchone()
                
                if result:
                    conn.commit()
                    tenant_id = result[0]
                    logger.info(f"Created tenant '{tenant.name}' with ID {tenant_id}")
                    
                    # Return the created tenant
                    return self.load_tenant_config_from_db(tenant.name)
                
                return None
                
        except Exception as e:
            logger.error(f"Error creating tenant '{tenant.name}': {e}")
            return None
    
    def update_tenant(self, tenant_id: int, tenant_update: TenantUpdate) -> Optional[TenantConfig]:
        """
        Update a tenant configuration
        
        Args:
            tenant_id: ID of tenant to update
            tenant_update: Fields to update
            
        Returns:
            Updated TenantConfig if successful, None otherwise
        """
        try:
            # Build dynamic update query
            update_fields = []
            update_params = {"tenant_id": tenant_id}
            
            for field, value in tenant_update.dict(exclude_unset=True).items():
                if value is not None:
                    update_fields.append(f"[{field}] = :{field}")
                    update_params[field] = value
            
            if not update_fields:
                logger.warning("No fields to update")
                return None
            
            with self.engine.connect() as conn:
                update_sql = text(f"""
                    UPDATE [{ADMIN_DATABASE}].[{ADMIN_SCHEMA}].[home]
                    SET {', '.join(update_fields)}
                    WHERE [id] = :tenant_id
                """)
                
                result = conn.execute(update_sql, update_params)
                
                if result.rowcount > 0:
                    conn.commit()
                    logger.info(f"Updated tenant with ID {tenant_id}")
                    
                    # Get the tenant name to return the updated config
                    name_sql = text(f"SELECT [name] FROM [{ADMIN_DATABASE}].[{ADMIN_SCHEMA}].[home] WHERE [id] = :tenant_id")
                    name_result = conn.execute(name_sql, {"tenant_id": tenant_id}).fetchone()
                    
                    if name_result:
                        return self.load_tenant_config_from_db(name_result[0])
                
                return None
                
        except Exception as e:
            logger.error(f"Error updating tenant with ID {tenant_id}: {e}")
            return None
    
    def delete_tenant(self, tenant_id: int) -> bool:
        """
        Delete a tenant configuration
        
        Args:
            tenant_id: ID of tenant to delete
            
        Returns:
            True if successful, False otherwise
        """
        try:
            with self.engine.connect() as conn:
                delete_sql = text(f"DELETE FROM [{ADMIN_DATABASE}].[{ADMIN_SCHEMA}].[home] WHERE [id] = :tenant_id")
                result = conn.execute(delete_sql, {"tenant_id": tenant_id})
                
                if result.rowcount > 0:
                    conn.commit()
                    logger.info(f"Deleted tenant with ID {tenant_id}")
                    return True
                
                return False
                
        except Exception as e:
            logger.error(f"Error deleting tenant with ID {tenant_id}: {e}")
            return False

def get_tenant_connection_string(tenant_config: TenantConfig) -> str:
    """
    Generate connection string for a tenant
    Uses schema name as username and schema name + "2025!" as password
    
    Args:
        tenant_config: Tenant configuration
        
    Returns:
        Connection string for the tenant's database
    """
    if tenant_config.database_type == "mssql":
        username = tenant_config.database_schema
        password = tenant_config.database_schema + "2025!"
        return f"mssql+pyodbc://{username}:{password}@localhost\\SQLEXPRESS/{tenant_config.database_name}?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"
    else:
        raise ValueError(f"Unsupported database type: {tenant_config.database_type}")

def get_tenant_connection_string_by_home_id(home_id: int) -> Optional[str]:
    """
    Generate connection string for a tenant by home ID
    
    Args:
        home_id: The home/tenant ID
        
    Returns:
        Connection string for the tenant's database if found, None otherwise
    """
    # First try to find tenant by ID
    all_tenants = get_all_tenants()
    for tenant in all_tenants:
        if tenant.id == home_id:
            return get_tenant_connection_string(tenant)
    return None

def get_schema_name_by_home_id(home_id: int) -> Optional[str]:
    """
    Get schema name for a tenant by home ID
    
    Args:
        home_id: The home/tenant ID
        
    Returns:
        Schema name if found, None otherwise
    """
    # First try to find tenant by ID
    all_tenants = get_all_tenants()
    for tenant in all_tenants:
        if tenant.id == home_id:
            return tenant.database_schema
    return None

# Global instance for tenant configuration operations
tenant_config_db = TenantConfigDatabase()

# Convenience functions
def load_tenant_config_from_db(tenant_id: str) -> Optional[TenantConfig]:
    """Load tenant configuration from database"""
    return tenant_config_db.load_tenant_config_from_db(tenant_id)

def get_all_tenants() -> List[TenantConfig]:
    """Get all tenant configurations"""
    return tenant_config_db.get_all_tenants()

def get_all_homes() -> List[Dict[str, any]]:
    """
    Get all available homes with their IDs and names (compatible with home_mapping format)
    
    Returns:
        List of dictionaries containing home information
    """
    homes = []
    all_tenants = get_all_tenants()
    for tenant in all_tenants:
        homes.append({
            "id": tenant.id,
            "name": tenant.name,
            "schema": tenant.database_schema
        })
    return homes