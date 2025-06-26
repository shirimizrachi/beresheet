# Oracle ATP (Autonomous Transaction Processing) Setup Guide

This guide provides comprehensive instructions for connecting to Oracle Cloud ATP using SQLAlchemy and testing the connection with schema and table creation.

## Overview

The Oracle ATP test script demonstrates:
- ✅ Connection to Oracle Cloud ATP using TLS authentication
- ✅ Schema creation (user management in Oracle)
- ✅ Table creation using SQLAlchemy ORM
- ✅ Data insertion and query testing
- ✅ Multiple service level testing (High, Medium, Low, TP, TPUrgent)

## Files Created

- [`oracle_atp_config.py`](oracle_atp_config.py) - Oracle ATP connection configuration
- [`test_oracle_atp_connection.py`](test_oracle_atp_connection.py) - Main test script
- [`requirements_oracle.txt`](requirements_oracle.txt) - Oracle-specific Python dependencies
- [`.env.oracle`](.env.oracle) - Environment variables template
- [`run_oracle_test.bat`](run_oracle_test.bat) - Windows batch script to run tests
- [`run_oracle_test.sh`](run_oracle_test.sh) - Linux/Mac shell script to run tests

## Prerequisites

### 1. Oracle Cloud ATP Instance
- Active Oracle Cloud ATP database
- Database admin credentials
- Connection strings (provided in your Oracle Cloud console)

### 2. Python Environment
- Python 3.8 or higher
- pip package manager
- Virtual environment (recommended)

### 3. System Dependencies

#### Windows
- Microsoft Visual C++ Build Tools (for cx_Oracle compilation)
- Or use pre-compiled wheels: `pip install cx_Oracle --only-binary=all`

#### Linux/Ubuntu
```bash
sudo apt-get update
sudo apt-get install python3-dev gcc libaio1
```

#### macOS
```bash
# Install Xcode command line tools
xcode-select --install
```

## Quick Start

### 1. Install Dependencies

#### Option A: Using the provided scripts (Recommended)
```bash
# Windows
run_oracle_test.bat

# Linux/Mac
chmod +x run_oracle_test.sh
./run_oracle_test.sh
```

#### Option B: Manual installation
```bash
# Create virtual environment
python -m venv venv

# Activate virtual environment
# Windows:
venv\Scripts\activate
# Linux/Mac:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
pip install -r requirements_oracle.txt
```

### 2. Configure Environment Variables

Create a `.env` file or copy from template:
```bash
cp .env.oracle .env
```

Edit `.env` with your Oracle ATP credentials:
```env
# Oracle ATP Database Credentials
ORACLE_USERNAME=ADMIN
ORACLE_PASSWORD=YourActualPassword123!

# Oracle ATP Service Level
ORACLE_SERVICE_LEVEL=residents_medium

# Optional: Debug settings
ORACLE_ECHO_SQL=false
```

### 3. Run the Test

```bash
python test_oracle_atp_connection.py
```

## Oracle ATP Connection Strings

The configuration includes all provided connection strings:

### Service Levels Available:
- **`residents_high`** - High performance, higher cost
- **`residents_medium`** - Balanced performance and cost (default)
- **`residents_low`** - Lower performance, cost-effective
- **`residents_tp`** - Optimized for transaction processing
- **`residents_tpurgent`** - For urgent/critical workloads

### Connection String Format:
```
(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=adb.il-jerusalem-1.oraclecloud.com))(connect_data=(service_name=gb3f9204cbd02e0_residents_[SERVICE_LEVEL].adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))
```

## Authentication Methods

### TLS Authentication (Used in this setup)
- ✅ No client credentials (wallet) required
- ✅ Easier to use and configure
- ✅ Better connection latency
- ✅ Supported by python-oracledb driver

### Requirements for TLS:
- Python oracledb driver (used in this setup)
- Oracle Client libraries 19.14+ or 21.5+ (if using cx_Oracle)
- JDBC Thin Client 12.2.0.1+ with JDK 8(u163+)

## Test Script Features

### What the Test Script Does:

1. **Connection Testing**
   - Tests connection to Oracle ATP
   - Verifies Oracle version and user
   - Tests different service levels

2. **Schema Operations**
   - Attempts to create schema/user (if permissions allow)
   - Works with existing user schema
   - Validates schema access

3. **Table Creation**
   - Creates test tables using SQLAlchemy ORM:
     - `test_users` - User management table
     - `test_events` - Events table
     - `test_logs` - Application logs table

4. **Data Operations**
   - Inserts sample data
   - Tests various SQL queries (SELECT, JOIN, aggregate)
   - Validates data integrity

5. **Cleanup (Optional)**
   - Can remove test tables after testing
   - Configurable via `cleanup=True` parameter

### Sample Output:
```
============================================================
ORACLE ATP CONNECTION AND SCHEMA TEST
============================================================
Target: Oracle Autonomous Transaction Processing - residents_medium
Host: adb.il-jerusalem-1.oraclecloud.com:1521
------------------------------------------------------------
✅ Connection successful! Test query result: 1
Oracle Version: Oracle Database 19c Enterprise Edition Release 19.0.0.0.0
Connected as user: ADMIN
✅ Using existing schema for user: ADMIN
✅ Tables created successfully:
  - TEST_EVENTS
  - TEST_LOGS  
  - TEST_USERS
✅ Test data inserted successfully
✅ Query tests completed successfully
------------------------------------------------------------
TEST RESULTS: 5/5 tests passed
✅ ALL TESTS PASSED! Oracle ATP connection is working correctly.
============================================================
```

## Configuration Options

### Oracle ATP Configuration (`oracle_atp_config.py`)

```python
# Get connection string for specific service level
connection_string = get_oracle_connection_string("residents_high")

# Get server information
server_info = get_oracle_server_info("residents_medium")

# Connection pool settings
ORACLE_POOL_SETTINGS = {
    'pool_size': 5,
    'max_overflow': 10,
    'pool_pre_ping': True,
    'pool_recycle': 300,
}
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ORACLE_USERNAME` | `ADMIN` | Oracle ATP username |
| `ORACLE_PASSWORD` | - | Oracle ATP password |
| `ORACLE_SERVICE_LEVEL` | `residents_medium` | Service level to use |
| `ORACLE_SCHEMA_NAME` | `RESIDENTS_SCHEMA` | Schema name for operations |
| `ORACLE_ECHO_SQL` | `false` | Enable SQL query logging |

## Troubleshooting

### Common Issues and Solutions

#### 1. Connection Refused
```
ORA-12170: TNS:Connect timeout occurred
```
**Solutions:**
- Check network connectivity
- Verify connection string format
- Ensure Oracle ATP instance is running
- Check firewall settings

#### 2. Authentication Failed
```
ORA-01017: invalid username/password
```
**Solutions:**
- Verify username and password in `.env` file
- Check if user account is locked
- Ensure password meets Oracle requirements

#### 3. Missing Dependencies
```
ModuleNotFoundError: No module named 'oracledb'
```
**Solutions:**
```bash
pip install -r requirements_oracle.txt
# Or specifically:
pip install oracledb cx_Oracle
```

#### 4. SSL/TLS Issues
```
ORA-28759: failure to open file
```
**Solutions:**
- Ensure TLS authentication is enabled on ATP
- Check SSL certificate configuration
- Update Oracle client libraries

#### 5. Permission Denied for Schema Creation
```
ORA-01031: insufficient privileges
```
**Solutions:**
- Use existing user schema instead of creating new ones
- Contact Oracle Cloud administrator for user creation privileges
- The test script handles this by working with current user schema

### Performance Tips

1. **Choose Appropriate Service Level:**
   - `residents_high` - For high-performance applications
   - `residents_medium` - For balanced workloads (recommended)
   - `residents_low` - For development/testing

2. **Connection Pool Optimization:**
   ```python
   ORACLE_POOL_SETTINGS = {
       'pool_size': 10,        # Increase for high concurrency
       'max_overflow': 20,     # Allow burst connections
       'pool_recycle': 3600,   # Recycle connections hourly
   }
   ```

3. **Query Optimization:**
   - Use bind parameters to prevent SQL injection
   - Implement proper indexing
   - Use Oracle-specific features (hints, partitioning)

## Integration with Existing Code

### Adding to existing SQLAlchemy setup:

```python
from oracle_atp_config import get_oracle_connection_string
from sqlalchemy import create_engine

# Create Oracle engine
oracle_engine = create_engine(
    get_oracle_connection_string("residents_medium"),
    pool_size=5,
    max_overflow=10
)

# Use with existing models
Base.metadata.create_all(oracle_engine)
```

### Multi-database support:

```python
# Configure multiple databases
DATABASES = {
    'default': get_connection_string(),  # Existing SQL Server/MySQL
    'oracle': get_oracle_connection_string(),  # Oracle ATP
}
```

## Security Best Practices

1. **Environment Variables:**
   - Never commit credentials to version control
   - Use `.env` files for local development
   - Use cloud secret management for production

2. **Connection Security:**
   - Always use TLS/SSL connections
   - Rotate passwords regularly
   - Use least-privilege access

3. **Code Security:**
   - Use parameterized queries
   - Validate input data
   - Implement proper error handling

## Support and Resources

### Oracle Documentation:
- [Oracle Cloud ATP Documentation](https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/autonomous-connecting.html)
- [Python oracledb Driver](https://python-oracledb.readthedocs.io/)

### SQLAlchemy Resources:
- [SQLAlchemy Oracle Dialect](https://docs.sqlalchemy.org/en/20/dialects/oracle.html)
- [Connection Pool Configuration](https://docs.sqlalchemy.org/en/20/core/pooling.html)

### Troubleshooting:
- Check `oracle_atp_test.log` for detailed error messages
- Enable SQL logging with `ORACLE_ECHO_SQL=true`
- Use Oracle Cloud monitoring tools

## License

This Oracle ATP integration follows the same license as the main project.

---

For questions or issues, please check the test logs and refer to Oracle Cloud documentation.