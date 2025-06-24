@echo off
echo ================================================
echo Residents Database Setup for Windows
echo ================================================
echo.

REM Change to the script directory
cd /d "%~dp0"

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python and try again
    pause
    exit /b 1
)

REM Check if required packages are installed
echo Checking Python dependencies...
python -c "import sqlalchemy, pyodbc" >nul 2>&1
if errorlevel 1 (
    echo Installing required Python packages...
    pip install sqlalchemy pyodbc
    if errorlevel 1 (
        echo ERROR: Failed to install required packages
        pause
        exit /b 1
    )
)

echo.
echo Starting residents database setup...
echo.

REM Run the setup script
python setup_residents_database.py

REM Check if setup was successful
if errorlevel 1 (
    echo.
    echo ================================================
    echo SETUP FAILED
    echo ================================================
    echo Please check the error messages above and try again
    pause
    exit /b 1
) else (
    echo.
    echo ================================================
    echo SETUP COMPLETED SUCCESSFULLY
    echo ================================================
    echo.
    echo Next steps:
    echo 1. Test your database connection with: python test_residents_database.py
    echo 2. Start your API service
    echo 3. Access your application
    echo.
    pause
)