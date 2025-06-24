@echo off
echo Building and Serving Beresheet Community App
echo.

echo Step 1: Building Flutter Web App...
echo
flutter build web --target lib/main_web.dart --output build/web-tenant

echo Step 2: Building Flutter Admin App...
flutter build web --target lib/main_admin.dart --output build/web-admin


if %errorlevel% neq 0 (
    echo Error: Flutter build failed
    pause
    exit /b 1
)

echo.
echo Step 2: Setting up Python environment...
cd api_service

if not exist "venv" (
    echo Creating Python virtual environment...
    python -m venv venv
)

echo Activating virtual environment...
call venv\Scripts\activate

echo Installing/updating Python dependencies...
echo install -r requirements.txt

echo.
echo Step 3: Starting combined API and Web server...
echo.
echo Server will be available at:
echo   - API: http://localhost:8000/api
echo   - Web App: http://localhost:8000/web
echo   - API Docs: http://localhost:8000/docs
echo.


python start_server.py
pause