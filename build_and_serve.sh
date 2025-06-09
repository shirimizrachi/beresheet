#!/bin/bash

echo "Building and Serving Beresheet Community App"
echo ""

echo "Step 1: Building Flutter Web App..."
echo ""
flutter build web --target lib/main_web.dart --base-href /web/
if [ $? -ne 0 ]; then
    echo "Error: Flutter build failed"
    exit 1
fi

echo ""
echo "Step 2: Setting up Python environment..."
cd api_service

if [ ! -d "venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv venv
fi

echo "Activating virtual environment..."
source venv/bin/activate

echo "Installing/updating Python dependencies..."
pip install -r requirements.txt

echo ""
echo "Step 3: Starting combined API and Web server..."
echo ""
echo "Server will be available at:"
echo "  - API: http://localhost:8000/api"
echo "  - Web App: http://localhost:8000/web"
echo "  - API Docs: http://localhost:8000/docs"
echo ""

python main.py