-- Direct Home Database Setup Script
-- Creates the 'home' database and 'home' user with full permissions

USE master;
GO

-- Create the database if it doesn't exist
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'home')
BEGIN
    CREATE DATABASE home;
    PRINT 'Database "home" created successfully.';
END
ELSE
BEGIN
    PRINT 'Database "home" already exists.';
END
GO

-- Create login for the home user (SQL Server Authentication)
IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'home')
BEGIN
    CREATE LOGIN home WITH PASSWORD = 'home2025!', 
                               DEFAULT_DATABASE = home,
                               CHECK_EXPIRATION = OFF,
                               CHECK_POLICY = OFF;
    PRINT 'Login "home" created successfully.';
END
ELSE
BEGIN
    PRINT 'Login "home" already exists.';
END
GO

-- Switch to the home database
USE home;
GO

-- Create database user for the login
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'home')
BEGIN
    CREATE USER home FOR LOGIN home;
    PRINT 'User "home" created successfully.';
END
ELSE
BEGIN
    PRINT 'User "home" already exists.';
END
GO

-- Grant full permissions to the user
ALTER ROLE db_owner ADD MEMBER home;
PRINT 'Full permissions granted to "home".';
GO

-- Create basic tables for the application
-- Users table
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'users')
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
        photo NVARCHAR(500),
        created_at DATETIME2 DEFAULT GETDATE(),
        updated_at DATETIME2 DEFAULT GETDATE()
    );
    PRINT 'Table "users" created successfully.';
END
GO

-- Events table
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'events')
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
    PRINT 'Table "events" created successfully.';
END
GO

-- Event registrations table
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'event_registrations')
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
    PRINT 'Table "event_registrations" created successfully.';
END
GO

-- Create indexes for better performance
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_users_firebase_id' AND object_id = OBJECT_ID('users'))
    CREATE NONCLUSTERED INDEX IX_users_firebase_id ON users(firebase_id);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_events_date_time' AND object_id = OBJECT_ID('events'))
    CREATE NONCLUSTERED INDEX IX_events_date_time ON events(date_time);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_events_type' AND object_id = OBJECT_ID('events'))
    CREATE NONCLUSTERED INDEX IX_events_type ON events(event_type);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_event_registrations_event_id' AND object_id = OBJECT_ID('event_registrations'))
    CREATE NONCLUSTERED INDEX IX_event_registrations_event_id ON event_registrations(event_id);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_event_registrations_user_id' AND object_id = OBJECT_ID('event_registrations'))
    CREATE NONCLUSTERED INDEX IX_event_registrations_user_id ON event_registrations(user_id);

PRINT 'Indexes created successfully.';
GO

PRINT '=== Database Setup Completed Successfully! ===';
PRINT 'Database: home';
PRINT 'User: home';
PRINT 'Password: home2025!';
PRINT 'Connection String (Windows Auth): Server=localhost\SQLEXPRESS;Database=home;Trusted_Connection=True;TrustServerCertificate=True;';
PRINT 'Connection String (SQL Auth): Server=localhost\SQLEXPRESS;Database=home;User Id=home;Password=home2025!;TrustServerCertificate=True;';