#!/bin/bash

echo "========================================"
echo "Oracle ATP Connection Test Script"
echo "========================================"
echo

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is not installed or not in PATH"
    echo "Please install Python 3.8+ and try again"
    exit 1
fi

echo "Python 3 is available"
echo

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to create virtual environment"
        exit 1
    fi
    echo "Virtual environment created successfully"
    echo
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to activate virtual environment"
    exit 1
fi

echo "Virtual environment activated"
echo

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip setuptools wheel

# Install base requirements
echo "Installing base requirements..."
pip install -r requirements.txt
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install base requirements"
    exit 1
fi

# Install Oracle requirements
echo "Installing Oracle database requirements..."
pip install -r requirements_oracle.txt
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install Oracle requirements"
    echo
    echo "Common solutions:"
    echo "1. Make sure you have build tools installed (gcc, python3-dev)"
    echo "2. Try: pip install --upgrade pip setuptools wheel"
    echo "3. Try: pip install oracledb cx_Oracle --no-cache-dir"
    exit 1
fi

echo "All requirements installed successfully"
echo

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "WARNING: .env file not found"
    echo "Please create .env file with Oracle ATP credentials"
    echo "You can use .env.oracle as a template"
    echo
    read -p "Do you want to copy .env.oracle to .env? (y/n): " choice
    if [[ $choice =~ ^[Yy]$ ]]; then
        cp .env.oracle .env
        echo ".env file created from template"
        echo "Please edit .env file with your actual Oracle ATP credentials"
        echo
        read -p "Press Enter to continue..."
    fi
fi

# Run the Oracle ATP test
echo "Running Oracle ATP connection test..."
echo "========================================"
python test_oracle_atp_connection.py

echo
echo "========================================"
echo "Test completed. Check oracle_atp_test.log for detailed results."
echo