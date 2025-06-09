"""
Startup script for the Beresheet Events API
This script will start the FastAPI server with proper configuration
"""
import uvicorn
import os
import sys

def main():
    """Start the FastAPI server"""
    print("Starting Beresheet Events API...")
    print("API Documentation will be available at: http://localhost:8000/docs")
    print("API Root endpoint: http://localhost:8000")
    print("Health check: http://localhost:8000/health")
    print("\nPress Ctrl+C to stop the server")
    
    try:
        uvicorn.run(
            "main:app",
            host="0.0.0.0",
            port=8000,
            reload=True,
            log_level="info",
            access_log=True
        )
    except KeyboardInterrupt:
        print("\nShutting down server...")
        sys.exit(0)
    except Exception as e:
        print(f"Error starting server: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()