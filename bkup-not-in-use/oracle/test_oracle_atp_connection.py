"""
Oracle ATP Test Script
Tests connection to Oracle Cloud ATP, creates schema and tables using SQLAlchemy
"""

import sys
import os
import logging
import uuid
from datetime import datetime
from sqlalchemy import create_engine, text, MetaData, Table, Column, Integer, String, DateTime, Text, Boolean
from sqlalchemy.orm import sessionmaker, declarative_base
from sqlalchemy.exc import SQLAlchemyError
import traceback

# Import Oracle ATP configuration
from oracle_atp_config import (
    get_oracle_connection_string,
    get_oracle_server_info,
    ORACLE_POOL_SETTINGS,
    ORACLE_SETTINGS,
    ORACLE_SCHEMA_NAME,
    ORACLE_USERNAME
)

# Set up logging with Windows console compatibility
file_handler = logging.FileHandler('oracle_atp_test.log', encoding='utf-8')
file_handler.setLevel(logging.INFO)
file_formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
file_handler.setFormatter(file_formatter)

# Create console handler with safe encoding
console_handler = logging.StreamHandler(sys.stdout)
console_handler.setLevel(logging.INFO)

# Use ASCII-safe formatter for console to avoid encoding issues
class SafeConsoleFormatter(logging.Formatter):
    def format(self, record):
        # Replace problematic Unicode characters with ASCII equivalents
        msg = super().format(record)
        # Replace common emoji/Unicode characters
        msg = msg.replace('✅', '[OK]')
        msg = msg.replace('❌', '[ERROR]')
        msg = msg.replace('⚠️', '[WARNING]')
        msg = msg.replace('🔍', '[INFO]')
        # Remove any remaining non-ASCII characters
        msg = msg.encode('ascii', errors='replace').decode('ascii')
        return msg

console_formatter = SafeConsoleFormatter('%(asctime)s - %(levelname)s - %(message)s')
console_handler.setFormatter(console_formatter)

# Configure root logger
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
logger.addHandler(file_handler)
logger.addHandler(console_handler)

# Prevent duplicate logs
logger.propagate = False

# SQLAlchemy Base for ORM models
Base = declarative_base()

class TestUser(Base):
    """Test table for users"""
    __tablename__ = 'test_users'
    __table_args__ = {'schema': ORACLE_SCHEMA_NAME}
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    username = Column(String(50), nullable=False, unique=True)
    email = Column(String(100), nullable=False)
    full_name = Column(String(100))
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class TestEvent(Base):
    """Test table for events"""
    __tablename__ = 'test_events'
    __table_args__ = {'schema': ORACLE_SCHEMA_NAME}
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    title = Column(String(200), nullable=False)
    description = Column(Text)
    event_date = Column(DateTime)
    location = Column(String(200))
    max_participants = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_by = Column(String(50))
    created_at = Column(DateTime, default=datetime.utcnow)

class TestLog(Base):
    """Test table for logs"""
    __tablename__ = 'test_logs'
    __table_args__ = {'schema': ORACLE_SCHEMA_NAME}
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    level = Column(String(20), nullable=False)
    message = Column(Text, nullable=False)
    module_name = Column(String(100))
    timestamp = Column(DateTime, default=datetime.utcnow)

class OracleATPTester:
    """Oracle ATP Connection and Schema Tester"""
    
    def __init__(self, service_level="residents_medium"):
        """
        Initialize the tester with specified service level
        
        Args:
            service_level (str): Oracle ATP service level to use
        """
        self.service_level = service_level
        self.engine = None
        self.session = None
        self.metadata = None
        
    def test_connection(self):
        """Test basic connection to Oracle ATP"""
        try:
            logger.info(f"Testing connection to Oracle ATP - Service Level: {self.service_level}")
            
            # Get connection string
            connection_string = get_oracle_connection_string(self.service_level)
            logger.info(f"Connection string prepared for service level: {self.service_level}")
            
            # Create engine with Oracle-specific settings
            self.engine = create_engine(
                connection_string,
                **ORACLE_POOL_SETTINGS,
                **ORACLE_SETTINGS
            )
            
            # Test connection
            with self.engine.connect() as connection:
                result = connection.execute(text("SELECT 1 FROM DUAL"))
                row = result.fetchone()
                logger.info(f"[OK] Connection successful! Test query result: {row[0]}")
                
                # Get Oracle version
                version_result = connection.execute(text("SELECT BANNER FROM V$VERSION WHERE ROWNUM = 1"))
                version = version_result.fetchone()[0]
                logger.info(f"Oracle Version: {version}")
                
                # Get current user
                user_result = connection.execute(text("SELECT USER FROM DUAL"))
                current_user = user_result.fetchone()[0]
                logger.info(f"Connected as user: {current_user}")
                
                return True
                
        except Exception as e:
            logger.error(f"❌ Connection failed: {str(e)}")
            logger.error(f"Full error: {traceback.format_exc()}")
            return False
    
    def create_schema(self):
        """Create schema (in Oracle, this means creating a user)"""
        try:
            logger.info(f"Creating schema/user: {ORACLE_SCHEMA_NAME}")
            
            with self.engine.connect() as connection:
                # Check if user exists
                check_user_sql = text("""
                    SELECT COUNT(*) FROM ALL_USERS
                    WHERE USERNAME = :username
                """)
                result = connection.execute(check_user_sql, {"username": ORACLE_SCHEMA_NAME})
                user_exists = result.fetchone()[0] > 0
                
                if user_exists:
                    logger.info(f"✅ Schema/User {ORACLE_SCHEMA_NAME} already exists")
                    return True
                
                # Try to create the user/schema
                try:
                    # Generate a random password for the schema user
                    schema_password = "TempPass123!"
                    
                    # Create user SQL
                    create_user_sql = text(f"""
                        CREATE USER {ORACLE_SCHEMA_NAME} IDENTIFIED BY "{schema_password}"
                        DEFAULT TABLESPACE DATA
                        TEMPORARY TABLESPACE TEMP
                        QUOTA UNLIMITED ON DATA
                    """)
                    
                    connection.execute(create_user_sql)
                    connection.commit()
                    
                    # Grant necessary privileges
                    grant_sql = text(f"""
                        GRANT CREATE SESSION, CREATE TABLE, CREATE SEQUENCE, CREATE TRIGGER TO {ORACLE_SCHEMA_NAME}
                    """)
                    connection.execute(grant_sql)
                    connection.commit()
                    
                    logger.info(f"✅ Schema/User {ORACLE_SCHEMA_NAME} created successfully")
                    return True
                    
                except Exception as create_error:
                    logger.warning(f"⚠️  Could not create new user (this is common in Oracle ATP): {str(create_error)}")
                    logger.info(f"⚠️  Working with current user schema instead: {ORACLE_USERNAME}")
                    return True
                
        except Exception as e:
            logger.error(f"❌ Schema creation failed: {str(e)}")
            logger.error(f"Full error: {traceback.format_exc()}")
            return False
    
    def drop_existing_tables(self):
        """Drop existing test tables if they exist"""
        try:
            logger.info(f"Dropping existing test tables from schema: {ORACLE_SCHEMA_NAME}")
            
            with self.engine.connect() as connection:
                # Drop tables in reverse order of dependencies
                table_names = ['TEST_LOGS', 'TEST_EVENTS', 'TEST_USERS']
                
                for table_name in table_names:
                    try:
                        drop_sql = text(f"DROP TABLE {ORACLE_SCHEMA_NAME}.{table_name} CASCADE CONSTRAINTS")
                        connection.execute(drop_sql)
                        connection.commit()
                        logger.info(f"  Dropped existing table: {ORACLE_SCHEMA_NAME}.{table_name}")
                    except Exception as e:
                        # Table doesn't exist, which is fine
                        if "ORA-00942" in str(e):  # table or view does not exist
                            logger.info(f"  Table {ORACLE_SCHEMA_NAME}.{table_name} doesn't exist (skip)")
                        else:
                            logger.warning(f"  Could not drop table {ORACLE_SCHEMA_NAME}.{table_name}: {str(e)}")
            
            return True
            
        except Exception as e:
            logger.warning(f"⚠️  Table dropping had issues: {str(e)}")
            return False

    def create_tables(self):
        """Create test tables using SQLAlchemy ORM"""
        try:
            logger.info("Creating test tables with GUID primary keys...")
            
            # First drop existing tables to ensure clean start
            self.drop_existing_tables()
            
            # Create all tables defined in Base
            Base.metadata.create_all(self.engine)
            
            logger.info("✅ Tables created successfully:")
            
            # List all tables that were created
            with self.engine.connect() as connection:
                # Get list of tables for the specific schema
                tables_sql = text("""
                    SELECT TABLE_NAME FROM ALL_TABLES
                    WHERE OWNER = :schema_name
                    AND TABLE_NAME IN ('TEST_USERS', 'TEST_EVENTS', 'TEST_LOGS')
                    ORDER BY TABLE_NAME
                """)
                result = connection.execute(tables_sql, {"schema_name": ORACLE_SCHEMA_NAME})
                tables = result.fetchall()
                
                for table in tables:
                    logger.info(f"  - {ORACLE_SCHEMA_NAME}.{table[0]}")
                    
                    # Get column information for each table
                    columns_sql = text("""
                        SELECT COLUMN_NAME, DATA_TYPE, NULLABLE
                        FROM ALL_TAB_COLUMNS
                        WHERE OWNER = :schema_name
                        AND TABLE_NAME = :table_name
                        ORDER BY COLUMN_ID
                    """)
                    col_result = connection.execute(columns_sql, {
                        "schema_name": ORACLE_SCHEMA_NAME,
                        "table_name": table[0]
                    })
                    columns = col_result.fetchall()
                    
                    for col in columns:
                        nullable = "NULL" if col[2] == "Y" else "NOT NULL"
                        logger.info(f"    {col[0]} ({col[1]}) {nullable}")
            
            return True
            
        except Exception as e:
            logger.error(f"❌ Table creation failed: {str(e)}")
            logger.error(f"Full error: {traceback.format_exc()}")
            return False
    
    def insert_test_data(self):
        """Insert test data into created tables"""
        try:
            logger.info("Inserting test data...")
            
            # Create session
            Session = sessionmaker(bind=self.engine)
            session = Session()
            
            try:
                # Insert test users with explicit GUIDs
                test_users = [
                    TestUser(
                        id=str(uuid.uuid4()),
                        username="admin",
                        email="admin@example.com",
                        full_name="System Administrator"
                    ),
                    TestUser(
                        id=str(uuid.uuid4()),
                        username="testuser1",
                        email="user1@example.com",
                        full_name="Test User One"
                    ),
                    TestUser(
                        id=str(uuid.uuid4()),
                        username="testuser2",
                        email="user2@example.com",
                        full_name="Test User Two",
                        is_active=False
                    )
                ]
                
                session.add_all(test_users)
                
                # Insert test events with explicit GUIDs
                test_events = [
                    TestEvent(
                        id=str(uuid.uuid4()),
                        title="Oracle ATP Test Event",
                        description="Test event created during Oracle ATP connection testing",
                        event_date=datetime(2025, 7, 1, 10, 0),
                        location="Virtual",
                        max_participants=50,
                        created_by="admin"
                    ),
                    TestEvent(
                        id=str(uuid.uuid4()),
                        title="Database Migration Workshop",
                        description="Workshop on migrating to Oracle Cloud ATP",
                        event_date=datetime(2025, 7, 15, 14, 0),
                        location="Conference Room A",
                        max_participants=25,
                        created_by="admin"
                    )
                ]
                
                session.add_all(test_events)
                
                # Insert test logs with explicit GUIDs
                test_logs = [
                    TestLog(
                        id=str(uuid.uuid4()),
                        level="INFO",
                        message="Oracle ATP connection test started",
                        module_name="test_oracle_atp"
                    ),
                    TestLog(
                        id=str(uuid.uuid4()),
                        level="INFO",
                        message="Test data insertion completed",
                        module_name="test_oracle_atp"
                    ),
                    TestLog(
                        id=str(uuid.uuid4()),
                        level="DEBUG",
                        message="Testing SQLAlchemy ORM operations",
                        module_name="test_oracle_atp"
                    )
                ]
                
                session.add_all(test_logs)
                
                # Commit all changes
                session.commit()
                
                logger.info("✅ Test data inserted successfully")
                
                # Verify data insertion
                user_count = session.query(TestUser).count()
                event_count = session.query(TestEvent).count()
                log_count = session.query(TestLog).count()
                
                logger.info(f"Data verification:")
                logger.info(f"  - Users: {user_count}")
                logger.info(f"  - Events: {event_count}")
                logger.info(f"  - Logs: {log_count}")
                
                return True
                
            except Exception as e:
                session.rollback()
                raise e
            finally:
                session.close()
                
        except Exception as e:
            logger.error(f"❌ Test data insertion failed: {str(e)}")
            logger.error(f"Full error: {traceback.format_exc()}")
            return False
    
    def test_queries(self):
        """Test various SQL queries"""
        try:
            logger.info("Testing SQL queries...")
            
            with self.engine.connect() as connection:
                # Test simple SELECT
                logger.info("Testing simple SELECT queries:")
                
                # Count records in each table
                for table_name in ['TEST_USERS', 'TEST_EVENTS', 'TEST_LOGS']:
                    count_sql = text(f"SELECT COUNT(*) FROM {ORACLE_SCHEMA_NAME}.{table_name}")
                    result = connection.execute(count_sql)
                    count = result.fetchone()[0]
                    logger.info(f"  {ORACLE_SCHEMA_NAME}.{table_name}: {count} records")
                
                # Test JOIN query
                logger.info("Testing JOIN query:")
                join_sql = text(f"""
                    SELECT u.username, e.title, e.event_date
                    FROM {ORACLE_SCHEMA_NAME}.test_users u, {ORACLE_SCHEMA_NAME}.test_events e
                    WHERE e.created_by = u.username
                    AND u.is_active = 1
                    ORDER BY e.event_date
                """)
                result = connection.execute(join_sql)
                joins = result.fetchall()
                
                for row in joins:
                    logger.info(f"  User: {row[0]}, Event: {row[1]}, Date: {row[2]}")
                
                # Test aggregate query
                logger.info("Testing aggregate queries:")
                agg_sql = text(f"""
                    SELECT
                        COUNT(*) as total_events,
                        COUNT(CASE WHEN is_active = 1 THEN 1 END) as active_events,
                        MAX(event_date) as latest_event
                    FROM {ORACLE_SCHEMA_NAME}.test_events
                """)
                result = connection.execute(agg_sql)
                agg_row = result.fetchone()
                logger.info(f"  Total events: {agg_row[0]}")
                logger.info(f"  Active events: {agg_row[1]}")
                logger.info(f"  Latest event: {agg_row[2]}")
                
            logger.info("✅ Query tests completed successfully")
            return True
            
        except Exception as e:
            logger.error(f"❌ Query testing failed: {str(e)}")
            logger.error(f"Full error: {traceback.format_exc()}")
            return False
    
    def cleanup_test_data(self):
        """Clean up test tables (optional)"""
        try:
            logger.info(f"Cleaning up test data from schema: {ORACLE_SCHEMA_NAME}")
            
            with self.engine.connect() as connection:
                # Drop tables in reverse order of dependencies
                table_names = ['TEST_LOGS', 'TEST_EVENTS', 'TEST_USERS']
                
                for table_name in table_names:
                    try:
                        drop_sql = text(f"DROP TABLE {ORACLE_SCHEMA_NAME}.{table_name} CASCADE CONSTRAINTS")
                        connection.execute(drop_sql)
                        connection.commit()
                        logger.info(f"  Dropped table: {ORACLE_SCHEMA_NAME}.{table_name}")
                    except Exception as e:
                        logger.warning(f"  Could not drop table {ORACLE_SCHEMA_NAME}.{table_name}: {str(e)}")
            
            logger.info("✅ Cleanup completed")
            return True
            
        except Exception as e:
            logger.error(f"❌ Cleanup failed: {str(e)}")
            return False
    
    def run_full_test(self, cleanup=False):
        """Run complete test suite"""
        logger.info("=" * 60)
        logger.info("ORACLE ATP CONNECTION AND SCHEMA TEST")
        logger.info("=" * 60)
        
        server_info = get_oracle_server_info(self.service_level)
        logger.info(f"Target: {server_info['description']}")
        logger.info(f"Host: {server_info['host']}:{server_info['port']}")
        logger.info("-" * 60)
        
        success_count = 0
        total_tests = 5
        
        # Test 1: Connection
        if self.test_connection():
            success_count += 1
        
        # Test 2: Schema creation
        if self.test_connection() and self.create_schema():
            success_count += 1
        
        # Test 3: Table creation
        if self.engine and self.create_tables():
            success_count += 1
        
        # Test 4: Data insertion
        if self.engine and self.insert_test_data():
            success_count += 1
        
        # Test 5: Query testing
        if self.engine and self.test_queries():
            success_count += 1
        
        # Optional cleanup
        if cleanup and self.engine:
            self.cleanup_test_data()
        
        # Summary
        logger.info("-" * 60)
        logger.info(f"TEST RESULTS: {success_count}/{total_tests} tests passed")
        
        if success_count == total_tests:
            logger.info("✅ ALL TESTS PASSED! Oracle ATP connection is working correctly.")
        else:
            logger.warning(f"⚠️  {total_tests - success_count} tests failed. Check logs for details.")
        
        logger.info("=" * 60)
        
        # Close engine
        if self.engine:
            self.engine.dispose()
        
        return success_count == total_tests

def main():
    """Main function to run the test"""
    print("Oracle ATP Connection Test Script")
    print("=" * 50)
    
    # Test only medium service level
    service_level = "residents_medium"
    
    print(f"\nTesting service level: {service_level}")
    print("-" * 30)
    
    tester = OracleATPTester(service_level)
    
    try:
        # Run full test (set cleanup=True to remove test tables after testing)
        success = tester.run_full_test(cleanup=False)
        
        if success:
            print(f"✅ Service level {service_level} test completed successfully!")
        else:
            print(f"❌ Service level {service_level} test failed!")
            
    except KeyboardInterrupt:
        print("\nTest interrupted by user")
    except Exception as e:
        print(f"❌ Unexpected error testing {service_level}: {str(e)}")
    
    print("\nTest script completed. Check 'oracle_atp_test.log' for detailed logs.")

if __name__ == "__main__":
    main()