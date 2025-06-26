"""
Oracle ATP Integration Example
Demonstrates how to integrate Oracle ATP with existing FastAPI application
"""

from fastapi import FastAPI, HTTPException, Depends
from sqlalchemy import create_engine, Column, Integer, String, DateTime, Boolean, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel
from datetime import datetime
from typing import List, Optional
import logging

# Import Oracle ATP configuration
from oracle_atp_config import get_oracle_connection_string, ORACLE_POOL_SETTINGS

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# SQLAlchemy setup for Oracle
oracle_connection_string = get_oracle_connection_string("residents_medium")
oracle_engine = create_engine(
    oracle_connection_string,
    **ORACLE_POOL_SETTINGS,
    echo=False  # Set to True for SQL debugging
)

OracleSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=oracle_engine)
OracleBase = declarative_base()

# Oracle Models
class OracleResident(OracleBase):
    """Resident model for Oracle ATP"""
    __tablename__ = 'residents'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    first_name = Column(String(50), nullable=False)
    last_name = Column(String(50), nullable=False)
    email = Column(String(100), unique=True, nullable=False)
    phone = Column(String(20))
    apartment_number = Column(String(10))
    building = Column(String(50))
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class OracleServiceRequest(OracleBase):
    """Service request model for Oracle ATP"""
    __tablename__ = 'service_requests'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    resident_id = Column(Integer, nullable=False)  # Foreign key to residents
    title = Column(String(200), nullable=False)
    description = Column(Text)
    category = Column(String(50))
    priority = Column(String(20), default='medium')
    status = Column(String(20), default='open')
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    resolved_at = Column(DateTime)

# Pydantic models for API
class ResidentCreate(BaseModel):
    first_name: str
    last_name: str
    email: str
    phone: Optional[str] = None
    apartment_number: Optional[str] = None
    building: Optional[str] = None

class ResidentResponse(BaseModel):
    id: int
    first_name: str
    last_name: str
    email: str
    phone: Optional[str]
    apartment_number: Optional[str]
    building: Optional[str]
    is_active: bool
    created_at: datetime
    
    class Config:
        from_attributes = True

class ServiceRequestCreate(BaseModel):
    resident_id: int
    title: str
    description: Optional[str] = None
    category: Optional[str] = None
    priority: str = 'medium'

class ServiceRequestResponse(BaseModel):
    id: int
    resident_id: int
    title: str
    description: Optional[str]
    category: Optional[str]
    priority: str
    status: str
    created_at: datetime
    
    class Config:
        from_attributes = True

# FastAPI app
app = FastAPI(title="Oracle ATP Integration Example", version="1.0.0")

# Database dependency
def get_oracle_db():
    """Get Oracle database session"""
    db = OracleSessionLocal()
    try:
        yield db
    finally:
        db.close()

# Initialize database
@app.on_event("startup")
async def startup_event():
    """Create tables on startup"""
    try:
        OracleBase.metadata.create_all(bind=oracle_engine)
        logger.info("Oracle ATP tables created successfully")
    except Exception as e:
        logger.error(f"Failed to create Oracle ATP tables: {str(e)}")

# Health check endpoints
@app.get("/health")
async def health_check():
    """Basic health check"""
    return {"status": "healthy", "database": "oracle_atp"}

@app.get("/health/database")
async def database_health_check(db: Session = Depends(get_oracle_db)):
    """Database connection health check"""
    try:
        # Test database connection
        db.execute("SELECT 1 FROM DUAL")
        return {"status": "healthy", "database": "oracle_atp", "connection": "active"}
    except Exception as e:
        logger.error(f"Database health check failed: {str(e)}")
        raise HTTPException(status_code=503, detail="Database connection failed")

# Resident endpoints
@app.post("/residents/", response_model=ResidentResponse)
async def create_resident(resident: ResidentCreate, db: Session = Depends(get_oracle_db)):
    """Create a new resident"""
    try:
        # Check if email already exists
        existing_resident = db.query(OracleResident).filter(
            OracleResident.email == resident.email
        ).first()
        
        if existing_resident:
            raise HTTPException(status_code=400, detail="Email already registered")
        
        # Create new resident
        db_resident = OracleResident(**resident.dict())
        db.add(db_resident)
        db.commit()
        db.refresh(db_resident)
        
        logger.info(f"Created resident: {db_resident.email}")
        return db_resident
        
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        logger.error(f"Failed to create resident: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to create resident")

@app.get("/residents/", response_model=List[ResidentResponse])
async def get_residents(
    skip: int = 0, 
    limit: int = 100, 
    active_only: bool = True,
    db: Session = Depends(get_oracle_db)
):
    """Get list of residents"""
    try:
        query = db.query(OracleResident)
        
        if active_only:
            query = query.filter(OracleResident.is_active == True)
        
        residents = query.offset(skip).limit(limit).all()
        return residents
        
    except Exception as e:
        logger.error(f"Failed to get residents: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to retrieve residents")

@app.get("/residents/{resident_id}", response_model=ResidentResponse)
async def get_resident(resident_id: int, db: Session = Depends(get_oracle_db)):
    """Get resident by ID"""
    try:
        resident = db.query(OracleResident).filter(
            OracleResident.id == resident_id
        ).first()
        
        if not resident:
            raise HTTPException(status_code=404, detail="Resident not found")
        
        return resident
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get resident {resident_id}: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to retrieve resident")

# Service Request endpoints
@app.post("/service-requests/", response_model=ServiceRequestResponse)
async def create_service_request(
    service_request: ServiceRequestCreate, 
    db: Session = Depends(get_oracle_db)
):
    """Create a new service request"""
    try:
        # Verify resident exists
        resident = db.query(OracleResident).filter(
            OracleResident.id == service_request.resident_id
        ).first()
        
        if not resident:
            raise HTTPException(status_code=404, detail="Resident not found")
        
        # Create service request
        db_request = OracleServiceRequest(**service_request.dict())
        db.add(db_request)
        db.commit()
        db.refresh(db_request)
        
        logger.info(f"Created service request: {db_request.id} for resident {resident.email}")
        return db_request
        
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        logger.error(f"Failed to create service request: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to create service request")

@app.get("/service-requests/", response_model=List[ServiceRequestResponse])
async def get_service_requests(
    resident_id: Optional[int] = None,
    status: Optional[str] = None,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_oracle_db)
):
    """Get list of service requests"""
    try:
        query = db.query(OracleServiceRequest)
        
        if resident_id:
            query = query.filter(OracleServiceRequest.resident_id == resident_id)
        
        if status:
            query = query.filter(OracleServiceRequest.status == status)
        
        requests = query.order_by(OracleServiceRequest.created_at.desc()).offset(skip).limit(limit).all()
        return requests
        
    except Exception as e:
        logger.error(f"Failed to get service requests: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to retrieve service requests")

# Analytics endpoints
@app.get("/analytics/residents/count")
async def get_resident_count(db: Session = Depends(get_oracle_db)):
    """Get resident statistics"""
    try:
        total_residents = db.query(OracleResident).count()
        active_residents = db.query(OracleResident).filter(OracleResident.is_active == True).count()
        
        return {
            "total_residents": total_residents,
            "active_residents": active_residents,
            "inactive_residents": total_residents - active_residents
        }
        
    except Exception as e:
        logger.error(f"Failed to get resident count: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to retrieve statistics")

@app.get("/analytics/service-requests/summary")
async def get_service_request_summary(db: Session = Depends(get_oracle_db)):
    """Get service request summary"""
    try:
        from sqlalchemy import func
        
        # Get counts by status
        status_counts = db.query(
            OracleServiceRequest.status,
            func.count(OracleServiceRequest.id).label('count')
        ).group_by(OracleServiceRequest.status).all()
        
        # Get counts by priority
        priority_counts = db.query(
            OracleServiceRequest.priority,
            func.count(OracleServiceRequest.id).label('count')
        ).group_by(OracleServiceRequest.priority).all()
        
        return {
            "by_status": {status: count for status, count in status_counts},
            "by_priority": {priority: count for priority, count in priority_counts},
            "total_requests": db.query(OracleServiceRequest).count()
        }
        
    except Exception as e:
        logger.error(f"Failed to get service request summary: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to retrieve summary")

# Oracle-specific endpoints
@app.get("/oracle/info")
async def get_oracle_info(db: Session = Depends(get_oracle_db)):
    """Get Oracle database information"""
    try:
        # Get Oracle version
        version_result = db.execute("SELECT BANNER FROM V$VERSION WHERE ROWNUM = 1")
        version = version_result.fetchone()[0]
        
        # Get current user
        user_result = db.execute("SELECT USER FROM DUAL")
        current_user = user_result.fetchone()[0]
        
        # Get session info
        session_result = db.execute("""
            SELECT SID, SERIAL#, USERNAME, STATUS, MACHINE, PROGRAM 
            FROM V$SESSION 
            WHERE USERNAME = USER
        """)
        session_info = session_result.fetchall()
        
        return {
            "oracle_version": version,
            "current_user": current_user,
            "active_sessions": len(session_info),
            "connection_status": "active"
        }
        
    except Exception as e:
        logger.error(f"Failed to get Oracle info: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to retrieve Oracle information")

if __name__ == "__main__":
    import uvicorn
    
    # Run the application
    uvicorn.run(
        "oracle_integration_example:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )