# Residents MySQL Database Setup

This directory contains scripts to set up the residents MySQL database with the required schemas, users, and tables.

## Prerequisites

1. **MySQL Server**: MySQL 5.7+ or MySQL 8.0+ installed and running
2. **Python**: Python 3.7+ with pip
3. **Python Packages**: SQLAlchemy and PyMySQL
4. **MySQL Admin Access**: Root or admin user credentials for database creation

## Quick Setup (Windows)

Run the batch file for automatic setup:

```bash
setup_residents_database.bat
```

## Manual Setup

1. **Install Python dependencies**:
   ```bash
   pip install sqlalchemy pymysql
   ```

2. **Run the setup script**:
   ```bash
   python setup_residents_database.py
   ```

## What Gets Created

### Main Database
- **Database**: `residents` (configurable in residents_db_config.py)
- **User**: `residents_user` with full permissions on the database
- **Table**: `home` - stores tenant/home configurations

### Home Index Database  
- **Database**: `home_index` (configurable in residents_db_config.py)
- **User**: `home_index_user` with limited permissions (SELECT, INSERT, UPDATE, DELETE only)
- **Table**: `home_index` - maps phone numbers to home IDs for tenant routing

## Configuration

All configuration is managed through `api_service/residents_db_config.py`:

- Database names and credentials
- Connection strings
- Server configuration (local vs cloud)

## Database Structure

### residents.home Table
```sql
CREATE TABLE `home` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(50) NOT NULL UNIQUE,
    `database_name` VARCHAR(50) NOT NULL,
    `database_type` VARCHAR(20) NOT NULL DEFAULT 'mysql',
    `database_schema` VARCHAR(50) NOT NULL,
    `admin_user_email` VARCHAR(100) NOT NULL,
    `admin_user_password` VARCHAR(100) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;
```

### home_index.home_index Table
```sql
CREATE TABLE `home_index` (
    `phone_number` VARCHAR(20) PRIMARY KEY,
    `home_id` INT NOT NULL,
    `home_name` VARCHAR(50) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;
```

## Differences from SQL Server Version

1. **Database vs Schema**: MySQL uses databases instead of schemas
2. **User Management**: Different user creation and permission syntax
3. **Data Types**: Uses VARCHAR instead of NVARCHAR, TIMESTAMP instead of DATETIME2
4. **Auto Increment**: Uses AUTO_INCREMENT instead of IDENTITY
5. **Triggers**: Automatic timestamp updates using ON UPDATE CURRENT_TIMESTAMP
6. **Character Set**: UTF8MB4 for proper Unicode support

## Security Notes

- Users are created with '%' host access (can connect from any host)
- In production, restrict host access to specific IPs/hostnames
- Use strong passwords (default pattern: {schema_name}2025!)
- The home_index user has minimal permissions (no DDL operations)

## Troubleshooting

### Common Issues

1. **Connection refused**: Check if MySQL server is running
2. **Access denied**: Verify admin credentials
3. **Database exists**: Script will skip creation if already exists
4. **Character encoding**: UTF8MB4 is used for proper Unicode support

### Manual Cleanup (if needed)

```sql
-- Drop databases
DROP DATABASE IF EXISTS `residents`;
DROP DATABASE IF EXISTS `home_index`;

-- Drop users
DROP USER IF EXISTS 'residents_user'@'%';
DROP USER IF EXISTS 'home_index_user'@'%';
```

## Connection Testing

After setup, test connections:

```python
# Test main connection
from residents_db_config import get_connection_string
from sqlalchemy import create_engine

engine = create_engine(get_connection_string())
with engine.connect() as conn:
    result = conn.execute("SELECT COUNT(*) FROM home")
    print("Connection successful!")

# Test home_index connection  
from residents_db_config import get_home_index_connection_string

home_index_engine = create_engine(get_home_index_connection_string())
with home_index_engine.connect() as conn:
    result = conn.execute("SELECT COUNT(*) FROM home_index")
    print("Home index connection successful!")