-- Create database user 'beresheet' with full permissions to 'beresheet' schema
-- This script should be run by a database administrator

USE master;
GO

-- Create login for 'beresheet' user
IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'beresheet')
BEGIN
    CREATE LOGIN [beresheet] WITH PASSWORD = 'beresheet2025!', 
                               DEFAULT_DATABASE = [home],
                               CHECK_EXPIRATION = OFF,
                               CHECK_POLICY = OFF;
    PRINT 'Login "beresheet" created successfully.';
END
ELSE
BEGIN
    PRINT 'Login "beresheet" already exists.';
END
GO

-- Switch to the home database
USE home;
GO

-- Create database user for the login
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'beresheet')
BEGIN
    CREATE USER [beresheet] FOR LOGIN [beresheet];
    PRINT 'User "beresheet" created successfully.';
END
ELSE
BEGIN
    PRINT 'User "beresheet" already exists.';
END
GO

-- Grant full permissions to beresheet schema
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[beresheet] TO [beresheet];
GRANT CREATE TABLE ON DATABASE::home TO [beresheet];
GRANT ALTER ON SCHEMA::[beresheet] TO [beresheet];
GRANT REFERENCES ON SCHEMA::[beresheet] TO [beresheet];
GRANT EXECUTE ON SCHEMA::[beresheet] TO [beresheet];

PRINT 'Full permissions granted to "beresheet" user for "beresheet" schema.';

-- Verify permissions
SELECT 
    dp.permission_name,
    dp.state_desc,
    o.name AS object_name,
    pr.name AS principal_name
FROM sys.database_permissions dp
LEFT JOIN sys.objects o ON dp.major_id = o.object_id
JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
WHERE pr.name = 'beresheet';

PRINT 'Database user "beresheet" setup completed.';