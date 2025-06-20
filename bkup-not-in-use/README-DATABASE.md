# Home Database Setup

This document provides detailed information about the database setup for the Home application, supporting both local SQL Server and Azure SQL Database deployments.

## Database Information

- **Database Name**: `home`
- **Database User**: `home`
- **User Password**: `home2025!`
- **User Permissions**: Full database owner permissions (`db_owner` role)

## Deployment Options

### 1. Local SQL Server (SQL Server Express)

#### Prerequisites
- SQL Server Express installed with instance name `SQLEXPRESS`
- SQL Server Command Line Utilities (`sqlcmd`) installed
- Windows Authentication enabled

#### Quick Setup
Run the batch file for automatic setup:
```batch
setup_home_local.bat
```

#### Manual Setup
Execute the SQL script manually:
```batch
sqlcmd -S localhost\SQLEXPRESS -E -v DatabaseName="home" DeploymentTarget="local" -i setup_database.sql
```

#### Connection Strings
**Windows Authentication:**
```
Server=localhost\SQLEXPRESS;Database=home;Trusted_Connection=True;TrustServerCertificate=True;
```

**SQL Server Authentication:**
```
Server=localhost\SQLEXPRESS;Database=home;User Id=home;Password=home2025!;TrustServerCertificate=True;
```

### 2. Azure SQL Database

#### Prerequisites
- Azure SQL Server instance created
- Admin credentials for the Azure SQL Server
- SQL Server Command Line Utilities (`sqlcmd`) installed

#### Quick Setup
Run the batch file and follow prompts:
```batch
setup_home_azure.bat
```

#### Manual Setup
Execute the SQL script manually:
```batch
sqlcmd -S {your-server}.database.windows.net -U {admin-user} -P {admin-password} -v DatabaseName="home" DeploymentTarget="azure" -i setup_database.sql
```

#### Connection String
```
Server={your-server}.database.windows.net;Database=home;User Id=home;Password=home2025!;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;
```

## Database Schema

The setup script creates the following tables:

### 1. users
Stores user profile information.

| Column | Type | Description |
|--------|------|-------------|
| id | NVARCHAR(50) | Primary key |
| firebase_id | NVARCHAR(50) | Unique identifier (Firebase UID) |
| display_name | NVARCHAR(100) | User's display name |
| email | NVARCHAR(255) | User's email address |
| phone_number | NVARCHAR(20) | User's phone number |
| birth_date | DATE | User's birth date |
| gender | NVARCHAR(10) | User's gender |
| city | NVARCHAR(50) | User's city |
| address | NVARCHAR(255) | User's address |
| photo | NVARCHAR(500) | URL to profile photo |
| created_at | DATETIME2 | Record creation timestamp |
| updated_at | DATETIME2 | Record last update timestamp |

### 2. events
Stores event information.

| Column | Type | Description |
|--------|------|-------------|
| id | NVARCHAR(50) | Primary key |
| title | NVARCHAR(255) | Event title |
| description | NVARCHAR(MAX) | Event description |
| event_type | NVARCHAR(50) | Type of event |
| date_time | DATETIME2 | Event date and time |
| location | NVARCHAR(255) | Event location |
| max_participants | INT | Maximum number of participants |
| current_participants | INT | Current number of participants |
| price | DECIMAL(10,2) | Event price |
| image_url | NVARCHAR(500) | URL to event image |
| contact_info | NVARCHAR(255) | Contact information |
| is_active | BIT | Whether event is active |
| created_at | DATETIME2 | Record creation timestamp |
| updated_at | DATETIME2 | Record last update timestamp |

### 3. event_registrations
Stores event registration information.

| Column | Type | Description |
|--------|------|-------------|
| id | INT IDENTITY(1,1) | Primary key |
| event_id | NVARCHAR(50) | Foreign key to events table |
| user_id | NVARCHAR(50) | Foreign key to users table |
| registration_date | DATETIME2 | Registration timestamp |
| is_active | BIT | Whether registration is active |

## Indexes

The following indexes are created for optimal performance:

- `IX_users_firebase_id` - Non-clustered index on users.firebase_id
- `IX_events_date_time` - Non-clustered index on events.date_time
- `IX_events_type` - Non-clustered index on events.event_type
- `IX_event_registrations_event_id` - Non-clustered index on event_registrations.event_id
- `IX_event_registrations_user_id` - Non-clustered index on event_registrations.user_id

## Security Features

### Local SQL Server
- Dedicated SQL Server login and user created
- Password expiration and policy checks disabled for development
- Full database owner permissions granted

### Azure SQL Database
- Contained database user created (no server-level login required)
- Encrypted connections enforced
- Full database owner permissions granted

## Files Created

1. **`setup_database.sql`** - Main SQL script supporting both deployment targets
2. **`setup_home_local.bat`** - Batch file for local SQL Server setup
3. **`setup_home_azure.bat`** - Batch file for Azure SQL Database setup
4. **`README-DATABASE.md`** - This documentation file

## Usage in Application Code

### Python (using pyodbc or sqlalchemy)
```python
import pyodbc

# Local SQL Server
connection_string = "DRIVER={ODBC Driver 17 for SQL Server};Server=localhost\\SQLEXPRESS;Database=home;UID=home;PWD=home2025!;TrustServerCertificate=yes"

# Azure SQL Database
connection_string = "DRIVER={ODBC Driver 17 for SQL Server};Server={your-server}.database.windows.net;Database=home;UID=home;PWD=home2025!;Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30"

conn = pyodbc.connect(connection_string)
```

### .NET Core (using Entity Framework)
```csharp
// Local SQL Server
"Server=localhost\\SQLEXPRESS;Database=home;User Id=home;Password=home2025!;TrustServerCertificate=True;"

// Azure SQL Database
"Server={your-server}.database.windows.net;Database=home;User Id=home;Password=home2025!;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
```

## Troubleshooting

### Common Issues

1. **SQL Server Express not found**
   - Ensure SQL Server Express is installed with instance name `SQLEXPRESS`
   - Check Windows Services for "SQL Server (SQLEXPRESS)"

2. **Connection timeout to Azure**
   - Verify firewall rules allow your IP address
   - Check server name format (should include `.database.windows.net`)

3. **Authentication failed**
   - Verify admin credentials for Azure SQL Database
   - Ensure Windows Authentication is enabled for local SQL Server

4. **sqlcmd not found**
   - Install SQL Server Command Line Utilities
   - Add SQL Server tools to PATH environment variable

### Verification

To verify the database setup was successful, run:
```batch
sqlcmd -S localhost\SQLEXPRESS -E -d home -Q "SELECT name FROM sys.tables;"
```

Expected output should show: `users`, `events`, `event_registrations`

### Quick Setup (Recommended)

For immediate setup of the home database, use:
```batch
sqlcmd -S localhost\SQLEXPRESS -E -i setup_home_direct.sql
```

### Events Registration Table Setup

To set up the events_registration table for a specific schema (e.g., beresheet):
```batch
python create_events_registration_table.py beresheet
```

This will create the `events_registration` table with proper indexes and constraints for tracking event registrations.

### Support

For additional support, refer to:
- [SQL Server Express documentation](https://docs.microsoft.com/en-us/sql/database-engine/configure-windows/sql-server-express-localdb)
- [Azure SQL Database documentation](https://docs.microsoft.com/en-us/azure/azure-sql/database/)

### Notes

- If SQL Server Authentication fails, ensure Mixed Mode Authentication is enabled in SQL Server Configuration Manager
- Windows Authentication is always recommended for local development
- The user "home" has been created with full database owner permissions