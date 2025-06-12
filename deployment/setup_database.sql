-- Database Setup Script for Local SQL Server or Azure SQL Database
-- Parameters:
--   DatabaseName: Name of the database to create
--   DeploymentTarget: 'local' for local SQL Server, 'azure' for Azure SQL Database
--   ServerName: Server name (for Azure, include .database.windows.net)
--   AdminUser: Admin username (for Azure)
--   AdminPassword: Admin password (for Azure)
-- 
-- Usage Examples:
-- Local SQL Server:
--   sqlcmd -S localhost\SQLEXPRESS -E -v DatabaseName="beresheet" DeploymentTarget="local" -i setup_database.sql
-- 
-- Azure SQL Database:
--   sqlcmd -S yourserver.database.windows.net -U admin_user -P admin_password -v DatabaseName="beresheet" DeploymentTarget="azure" -i setup_database.sql

DECLARE @DatabaseName NVARCHAR(128) = '$(DatabaseName)';
DECLARE @DeploymentTarget NVARCHAR(20) = '$(DeploymentTarget)';
DECLARE @UserName NVARCHAR(128) = '$(DatabaseName)';
DECLARE @Password NVARCHAR(128) = '$(DatabaseName)2025!';
DECLARE @SQL NVARCHAR(MAX);
DECLARE @IsAzure BIT = 0;

-- Validate parameters
IF @DatabaseName IS NULL OR @DatabaseName = '$(DatabaseName)' OR LEN(@DatabaseName) = 0
BEGIN
    RAISERROR('DatabaseName parameter is required.', 16, 1);
    RETURN;
END

IF @DeploymentTarget IS NULL OR @DeploymentTarget = '$(DeploymentTarget)' OR LEN(@DeploymentTarget) = 0
BEGIN
    SET @DeploymentTarget = 'local'; -- Default to local
END

-- Determine if we're deploying to Azure
IF LOWER(@DeploymentTarget) = 'azure'
    SET @IsAzure = 1;

PRINT 'Deployment Target: ' + @DeploymentTarget;
PRINT 'Setting up database: ' + @DatabaseName;
PRINT 'Creating user: ' + @UserName;

-- Check if we're already connected to Azure SQL Database
IF @IsAzure = 1 AND SERVERPROPERTY('EngineEdition') = 5
BEGIN
    PRINT 'Detected Azure SQL Database environment';
    SET @IsAzure = 1;
END
ELSE IF @IsAzure = 0
BEGIN
    PRINT 'Detected Local SQL Server environment';
    USE master;
END

-- Create database (different approach for Azure vs Local)
IF @IsAzure = 1
BEGIN
    -- For Azure SQL Database, we need to be connected to master first
    PRINT 'Creating Azure SQL Database...';
    
    -- Check if database exists
    IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = @DatabaseName)
    BEGIN
        SET @SQL = 'CREATE DATABASE [' + @DatabaseName + '] 
                   (EDITION = ''Basic'', 
                    SERVICE_OBJECTIVE = ''Basic'', 
                    MAXSIZE = 2 GB)';
        EXEC sp_executesql @SQL;
        PRINT 'Azure SQL Database "' + @DatabaseName + '" created successfully.';
    END
    ELSE
    BEGIN
        PRINT 'Azure SQL Database "' + @DatabaseName + '" already exists.';
    END
    
    -- Create contained database user (Azure SQL Database approach)
    SET @SQL = 'USE [' + @DatabaseName + '];
    IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = ''' + @UserName + ''')
    BEGIN
        CREATE USER [' + @UserName + '] WITH PASSWORD = ''' + @Password + ''';
        PRINT ''User "' + @UserName + '" created successfully in Azure SQL Database.'';
    END
    ELSE
    BEGIN
        PRINT ''User "' + @UserName + '" already exists in Azure SQL Database.'';
    END';
    EXEC sp_executesql @SQL;
END
ELSE
BEGIN
    -- Local SQL Server approach
    PRINT 'Creating Local SQL Server Database...';
    
    -- Create the database if it doesn't exist
    SET @SQL = 'IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = ''' + @DatabaseName + ''')
    BEGIN
        CREATE DATABASE [' + @DatabaseName + '];
        PRINT ''Database "' + @DatabaseName + '" created successfully.'';
    END
    ELSE
    BEGIN
        PRINT ''Database "' + @DatabaseName + '" already exists.'';
    END';
    EXEC sp_executesql @SQL;
    
    -- Create login for the user (SQL Server Authentication)
    SET @SQL = 'IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = ''' + @UserName + ''')
    BEGIN
        CREATE LOGIN [' + @UserName + '] WITH PASSWORD = ''' + @Password + ''', 
                                     DEFAULT_DATABASE = [' + @DatabaseName + '],
                                     CHECK_EXPIRATION = OFF,
                                     CHECK_POLICY = OFF;
        PRINT ''Login "' + @UserName + '" created successfully.'';
    END
    ELSE
    BEGIN
        PRINT ''Login "' + @UserName + '" already exists.'';
    END';
    EXEC sp_executesql @SQL;
    
    -- Create database user for the login
    SET @SQL = 'USE [' + @DatabaseName + '];
    IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = ''' + @UserName + ''')
    BEGIN
        CREATE USER [' + @UserName + '] FOR LOGIN [' + @UserName + '];
        PRINT ''User "' + @UserName + '" created successfully.'';
    END
    ELSE
    BEGIN
        PRINT ''User "' + @UserName + '" already exists.'';
    END';
    EXEC sp_executesql @SQL;
END

-- Grant full permissions to the user (works for both Azure and Local)
SET @SQL = 'USE [' + @DatabaseName + '];
ALTER ROLE db_owner ADD MEMBER [' + @UserName + '];
PRINT ''Full permissions granted to "' + @UserName + '".'';';
EXEC sp_executesql @SQL;

-- Create application tables (works for both Azure and Local)
SET @SQL = 'USE [' + @DatabaseName + '];

-- Users table
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = ''users'')
BEGIN
    CREATE TABLE users (
        id NVARCHAR(50) PRIMARY KEY,
        firebase_id NVARCHAR(50) UNIQUE NOT NULL,
        display_name NVARCHAR(100),
        email NVARCHAR(255),
        phone_number NVARCHAR(20),
        birth_date DATE,
        gender NVARCHAR(10),
        city NVARCHAR(50),
        address NVARCHAR(255),
        profile_photo_url NVARCHAR(500),
        created_at DATETIME2 DEFAULT GETDATE(),
        updated_at DATETIME2 DEFAULT GETDATE()
    );
    PRINT ''Table "users" created successfully.'';
END

-- Events table
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = ''events'')
BEGIN
    CREATE TABLE events (
        id NVARCHAR(50) PRIMARY KEY,
        title NVARCHAR(255) NOT NULL,
        description NVARCHAR(MAX),
        event_type NVARCHAR(50),
        date_time DATETIME2 NOT NULL,
        location NVARCHAR(255),
        max_participants INT,
        current_participants INT DEFAULT 0,
        price DECIMAL(10,2) DEFAULT 0,
        image_url NVARCHAR(500),
        contact_info NVARCHAR(255),
        is_active BIT DEFAULT 1,
        created_at DATETIME2 DEFAULT GETDATE(),
        updated_at DATETIME2 DEFAULT GETDATE()
    );
    PRINT ''Table "events" created successfully.'';
END

-- Event registrations table
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = ''event_registrations'')
BEGIN
    CREATE TABLE event_registrations (
        id INT IDENTITY(1,1) PRIMARY KEY,
        event_id NVARCHAR(50) NOT NULL,
        user_id NVARCHAR(50) NOT NULL,
        registration_date DATETIME2 DEFAULT GETDATE(),
        is_active BIT DEFAULT 1,
        FOREIGN KEY (event_id) REFERENCES events(id),
        FOREIGN KEY (user_id) REFERENCES users(id),
        UNIQUE(event_id, user_id)
    );
    PRINT ''Table "event_registrations" created successfully.'';
END

-- Create indexes for better performance
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = ''IX_users_firebase_id'' AND object_id = OBJECT_ID(''users''))
    CREATE NONCLUSTERED INDEX IX_users_firebase_id ON users(firebase_id);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = ''IX_events_date_time'' AND object_id = OBJECT_ID(''events''))
    CREATE NONCLUSTERED INDEX IX_events_date_time ON events(date_time);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = ''IX_events_type'' AND object_id = OBJECT_ID(''events''))
    CREATE NONCLUSTERED INDEX IX_events_type ON events(event_type);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = ''IX_event_registrations_event_id'' AND object_id = OBJECT_ID(''event_registrations''))
    CREATE NONCLUSTERED INDEX IX_event_registrations_event_id ON event_registrations(event_id);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = ''IX_event_registrations_user_id'' AND object_id = OBJECT_ID(''event_registrations''))
    CREATE NONCLUSTERED INDEX IX_event_registrations_user_id ON event_registrations(user_id);

PRINT ''Indexes created successfully.'';';
EXEC sp_executesql @SQL;

-- Display connection information
PRINT '=== Database Setup Completed Successfully! ===';
PRINT 'Deployment Target: ' + @DeploymentTarget;
PRINT 'Database: ' + @DatabaseName;
PRINT 'User: ' + @UserName;
PRINT 'Password: ' + @Password;

IF @IsAzure = 1
BEGIN
    PRINT 'Azure SQL Database Connection String:';
    PRINT 'Server={YourServer}.database.windows.net;Database=' + @DatabaseName + ';User Id=' + @UserName + ';Password=' + @Password + ';Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;';
END
ELSE
BEGIN
    PRINT 'Local SQL Server Connection String (Windows Auth):';
    PRINT 'Server=localhost\SQLEXPRESS;Database=' + @DatabaseName + ';Trusted_Connection=True;TrustServerCertificate=True;';
    PRINT 'Local SQL Server Connection String (SQL Auth):';
    PRINT 'Server=localhost\SQLEXPRESS;Database=' + @DatabaseName + ';User Id=' + @UserName + ';Password=' + @Password + ';TrustServerCertificate=True;';
END