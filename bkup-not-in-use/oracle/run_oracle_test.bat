@echo off
echo ========================================
echo Oracle ATP Connection Test Script
echo ========================================
echo.

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.8+ and try again
    
    exit /b 1
)

echo Python is available
echo.

REM Check if virtual environment exists
if not exist "venv" (
    echo Creating virtual environment...
    python -m venv venv
    if errorlevel 1 (
        echo ERROR: Failed to create virtual environment
        
        exit /b 1
    )
    echo Virtual environment created successfully
    echo.
)

REM Activate virtual environment
echo Activating virtual environment...
call venv\Scripts\activate.bat
if errorlevel 1 (
    echo ERROR: Failed to activate virtual environment
    
    exit /b 1
)

echo Virtual environment activated
echo.

REM Install base requirements
echo Installing base requirements...
pip install -r requirements.txt
if errorlevel 1 (
    echo ERROR: Failed to install base requirements
    
    exit /b 1
)


echo All requirements installed successfully
echo.

REM Check if .env file exists and contains Oracle settings
if not exist ".env" (
    echo ERROR: .env file not found in oracle directory
    echo Please ensure .env file exists with Oracle ATP credentials
    echo Check the .env file in the oracle folder
    exit /b 1
)

REM Run the Oracle ATP test
echo Running Oracle ATP connection test...
echo ========================================
python test_oracle_atp_connection.py

echo.
echo ========================================
echo Test completed. Check oracle_atp_test.log for detailed results.
echo.

REM Keep window open
