# Residents Database Setup Guide

This guide explains how to set up the `residents` database with the `home` schema and user for your application.

## Overview

The setup script creates:
- **Database**: `residents`
- **Schema**: `home` 
- **User**: `home` (password: `home2025!`)
- **Table**: `home.home` (for managing all homes/tenants)
- **Configuration**: Connection strings for both local and Azure SQL Database

## Prerequisites

### For SQL Express Local
- SQL Server Express installed
- ODBC Driver 17 for SQL Server
- Windows Authentication or SQL Server Authentication

### For Azure SQL Database
- Azure SQL Database server created
- Admin credentials for the Azure SQL server
- Firewall rules configured to allow connections

## Required Variables for Azure SQL Database

When choosing Azure SQL Database, you'll need:

1. **Server Name**: Your Azure SQL server name (without `.database.windows.net`)
   - Example: `myserver` (not `myserver.database.windows.net`)

2. **Admin Username**: The admin username for your Azure SQL server
   - Example: `sqladmin`

3. **Admin Password**: The admin password for your Azure SQL server
   - This will be entered securely (hidden input)

## Running the Setup

1. **Navigate to the deployment admin directory:**
   ```bash
   cd deployment/admin
   ```

2. **Run the setup script:**
   ```bash
   python setup_residents_database.py
   ```

3. **Choose your database type:**
   - Option 1: SQL Express Local
   - Option 2: Azure SQL Database

4. **Provide the required information:**
   - For Local: SQL Server instance (default: `localhost\SQLEXPRESS`)
   - For Azure: Server name, admin username, admin password

5. **Confirm and proceed with the setup**

## What Gets Created

### Database Structure
```sql
-- Database: residents
-- Schema: home  
-- User: home (password: home2025!)

-- Table: home.home
CREATE TABLE [home].[home] (
    [id] INT IDENTITY(1,1) PRIMARY KEY,
    [name] NVARCHAR(50) NOT NULL UNIQUE,
    [database_name] NVARCHAR(50) NOT NULL,
    [database_type] NVARCHAR(20) NOT NULL DEFAULT 'mssql',
    [database_schema] NVARCHAR(50) NOT NULL,
    [admin_user_email] NVARCHAR(100) NOT NULL,
    [admin_user_password] NVARCHAR(100) NOT NULL,
    [created_at] DATETIME2 DEFAULT GETDATE(),
    [updated_at] DATETIME2 DEFAULT GETDATE()
)
```

### Configuration Files
- `api_service/residents_db_config.py` - Contains connection strings and configuration
- `api_service/residents_db_config_template.py` - Template for manual configuration

## Connection String Examples

### Local SQL Express
```python
LOCAL_CONNECTION_STRING = "mssql+pyodbc://home:home2025!@localhost\\SQLEXPRESS/residents?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"
```

### Azure SQL Database
```python
AZURE_CONNECTION_STRING = "mssql+pyodbc://home:home2025!@myserver.database.windows.net/residents?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"
```

## API Service Integration

The API service will automatically use the new configuration:

1. **Tenant Configuration**: Updated to use `residents.home` table
2. **Database Utilities**: Support both local and Azure connections
3. **Connection Management**: Automatic selection based on `DATABASE_TYPE`

## Switching Between Local and Azure

To switch between local and Azure SQL Database:

1. **Edit** `api_service/residents_db_config.py`
2. **Change** `DATABASE_TYPE` to either `"local"` or `"azure"`
3. **Update** the corresponding connection string if needed
4. **Restart** your API service

## Troubleshooting

### Common Issues

1. **"Login failed for user 'home'"**
   - Ensure the user was created correctly
   - Check if SQL Server allows SQL authentication (for local)
   - Verify firewall rules (for Azure)

2. **"Cannot open database 'residents'"**
   - Ensure the database was created
   - Check if the user has access to the database

3. **"Invalid object name 'residents.home'"**
   - Ensure the schema and table were created
   - Check if the user has permissions on the schema

### Manual Verification

**Test connection with SQL Server Management Studio or Azure Data Studio:**

- **Server**: Your server name
- **Database**: `residents`
- **Username**: `home`
- **Password**: `home2025!`

**Verify table exists:**
```sql
SELECT * FROM home.home;
```

## Security Notes

- The default password `home2025!` is for development purposes
- Change the password in production environments
- Use Azure Key Vault or environment variables for production passwords
- Ensure proper firewall and network security rules

## Next Steps

1. **Run the setup script** to create your database
2. **Verify the connection** using the test function
3. **Update your API service** configuration if needed
4. **Start your application** and test the functionality

## Support

If you encounter issues:
1. Check the error messages from the setup script
2. Verify your database server is running and accessible
3. Ensure you have the required permissions
4. Check the generated configuration file for accuracy