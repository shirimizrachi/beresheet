"""
Tenant configuration models and database operations
Handles loading tenant configurations from the admin database
"""

from pydantic import BaseModel
from typing import Optional, List, Dict
from sqlalchemy import create_engine, Column, Integer, String, DateTime, func
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from datetime import datetime
import logging
from residents_config import get_connection_string, SCHEMA_NAME, DATABASE_NAME

# Admin database connection string
ADMIN_CONNECTION_STRING = get_connection_string()
ADMIN_SCHEMA = SCHEMA_NAME
ADMIN_DATABASE = DATABASE_NAME

# Set up logging
logger = logging.getLogger(__name__)

# SQLAlchemy Base and Model
Base = declarative_base()

class HomeTable(Base):
    """SQLAlchemy model for the home table"""
    __tablename__ = 'home'
    __table_args__ = {'schema': ADMIN_SCHEMA}
    
    id = Column(Integer, primary_key=True)
    name = Column(String(50), nullable=False, unique=True)
    database_name = Column(String(50), nullable=False)
    database_type = Column(String(20), nullable=False, default='mssql')
    database_schema = Column(String(50), nullable=False)
    admin_user_email = Column(String(100), nullable=False)
    admin_user_password = Column(String(100), nullable=False)
    created_at = Column(DateTime, nullable=False, default=func.now())
    updated_at = Column(DateTime, nullable=False, default=func.now(), onupdate=func.now())

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

class TenantCreateInternal(BaseModel):
    """Internal model for creating a new tenant with all fields"""
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
        self._session_factory = None
    
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
    
    @property
    def session_factory(self):
        """Get or create the session factory"""
        if self._session_factory is None:
            self._session_factory = sessionmaker(bind=self.engine)
        return self._session_factory
    
    def get_session(self):
        """Get a new database session"""
        return self.session_factory()
    
    def load_tenant_config_from_db(self, tenant_id: str) -> Optional[TenantConfig]:
        """
        Load tenant configuration from the admin database
        
        Args:
            tenant_id: The tenant name/ID to load
            
        Returns:
            TenantConfig if found, None otherwise
        """
        try:
            session = self.get_session()
            try:
                home = session.query(HomeTable).filter(HomeTable.name == tenant_id).first()
                
                if home:
                    return TenantConfig(
                        id=home.id,
                        name=home.name,
                        database_name=home.database_name,
                        database_type=home.database_type,
                        database_schema=home.database_schema,
                        admin_user_email=home.admin_user_email,
                        admin_user_password=home.admin_user_password,
                        created_at=home.created_at,
                        updated_at=home.updated_at
                    )
                
                logger.warning(f"Tenant '{tenant_id}' not found in admin database")
                return None
            finally:
                session.close()
                
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
            session = self.get_session()
            try:
                homes = session.query(HomeTable).order_by(HomeTable.id).all()
                
                tenants = []
                for home in homes:
                    tenants.append(TenantConfig(
                        id=home.id,
                        name=home.name,
                        database_name=home.database_name,
                        database_type=home.database_type,
                        database_schema=home.database_schema,
                        admin_user_email=home.admin_user_email,
                        admin_user_password=home.admin_user_password,
                        created_at=home.created_at,
                        updated_at=home.updated_at
                    ))
                
                return tenants
            finally:
                session.close()
                
        except Exception as e:
            logger.error(f"Error getting all tenants: {e}")
            return []
    
    def create_tenant(self, tenant: TenantCreateInternal) -> Optional[TenantConfig]:
        """
        Create a new tenant configuration
        
        Args:
            tenant: Tenant configuration to create
            
        Returns:
            Created TenantConfig if successful, None otherwise
        """
        try:
            session = self.get_session()
            try:
                # Get the next ID by finding the maximum existing ID and adding 1
                # If there are no rows in home table, ID will be 1
                max_id_result = session.query(func.max(HomeTable.id)).scalar()
                next_id = (max_id_result or 0) + 1
                
                # Create new home record using SQLAlchemy ORM with manual ID assignment
                new_home = HomeTable(
                    id=next_id,
                    name=tenant.name,
                    database_name=tenant.database_name,
                    database_type=tenant.database_type,
                    database_schema=tenant.database_schema,
                    admin_user_email=tenant.admin_user_email,
                    admin_user_password=tenant.admin_user_password
                )
                
                session.add(new_home)
                session.commit()
                
                tenant_id = new_home.id
                logger.info(f"Created tenant '{tenant.name}' with ID {tenant_id}")
                
                # Return the created tenant
                return self.load_tenant_config_from_db(tenant.name)
                
            except Exception as e:
                session.rollback()
                raise e
            finally:
                session.close()
                
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
            session = self.get_session()
            try:
                home = session.query(HomeTable).filter(HomeTable.id == tenant_id).first()
                
                if not home:
                    logger.warning(f"Tenant with ID {tenant_id} not found")
                    return None
                
                # Update fields
                update_data = tenant_update.dict(exclude_unset=True)
                if not update_data:
                    logger.warning("No fields to update")
                    return None
                
                for field, value in update_data.items():
                    if value is not None:
                        setattr(home, field, value)
                
                session.commit()
                logger.info(f"Updated tenant with ID {tenant_id}")
                
                # Return the updated tenant
                return self.load_tenant_config_from_db(home.name)
                
            except Exception as e:
                session.rollback()
                raise e
            finally:
                session.close()
                
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
            session = self.get_session()
            try:
                home = session.query(HomeTable).filter(HomeTable.id == tenant_id).first()
                
                if home:
                    session.delete(home)
                    session.commit()
                    logger.info(f"Deleted tenant with ID {tenant_id}")
                    return True
                
                return False
                
            except Exception as e:
                session.rollback()
                raise e
            finally:
                session.close()
                
        except Exception as e:
            logger.error(f"Error deleting tenant with ID {tenant_id}: {e}")
            return False

def get_tenant_connection_string(tenant_config: TenantConfig) -> str:
    """
    Get tenant-specific connection string using the database service
    
    Args:
        tenant_config: Tenant configuration
        
    Returns:
        Connection string with tenant credentials
    """
    try:
        from residents_db.database_service import get_database_service
        
        # Get the database service
        db_service = get_database_service()
        
        # Use the tenant name as the username (schema name)
        tenant_connection = db_service.get_tenant_connection_string(tenant_config.database_schema)
        
        logger.info(f"Generated tenant connection string for schema '{tenant_config.database_schema}'")
        return tenant_connection
        
    except Exception as e:
        logger.error(f"Error creating tenant connection string: {e}")
        # Fallback to admin connection if there's an issue
        return ADMIN_CONNECTION_STRING

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