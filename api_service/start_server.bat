@echo off
echo Starting Beresheet Events API Server...
echo.
echo Installing dependencies if needed...
echo pip install -r requirements.txt
echo.
echo Starting server on http://localhost:8000
echo API Documentation will be available at: http://localhost:8000/docs
echo.
echo Press Ctrl+C to stop the server
echo.

python start_server.py
pause