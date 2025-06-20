@echo off
echo Setting up Beresheet Database on Azure SQL Database...
echo.

REM Prompt for Azure SQL Server details
set /p SERVER_NAME="Enter Azure SQL Server name (without .database.windows.net): "
set /p ADMIN_USER="Enter Azure SQL Server admin username: "
set /p ADMIN_PASSWORD="Enter Azure SQL Server admin password: "

echo.
echo Connecting to: %SERVER_NAME%.database.windows.net
echo Admin User: %ADMIN_USER%
echo.

REM Execute the SQL script with parameters for Azure deployment
sqlcmd -S %SERVER_NAME%.database.windows.net -U %ADMIN_USER% -P %ADMIN_PASSWORD% -v DatabaseName="beresheet" DeploymentTarget="azure" -i setup_database.sql

if %ERRORLEVEL% EQU 0 (
    echo.
    echo =====================================
    echo Database setup completed successfully!
    echo =====================================
    echo Database: beresheet
    echo User: beresheet
    echo Password: beresheet2025!
    echo.
    echo Azure SQL Database Connection String:
    echo Server=%SERVER_NAME%.database.windows.net;Database=beresheet;User Id=beresheet;Password=beresheet2025!;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;
) else (
    echo.
    echo =====================================
    echo Database setup failed!
    echo =====================================
    echo Please check the error messages above.
)

pause