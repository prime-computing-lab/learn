#!/bin/bash

# Default values
VERBOSE=""
DISABLE_AI=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE="--verbose"
            shift
            ;;
        --disable-ai)
            DISABLE_AI="--disable-ai"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "Starting Log Analysis UI..."

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi
source venv/bin/activate
echo "Installing dependencies..."
pip install -r requirements.txt > /dev/null

# Make scripts executable
chmod +x analyze_logs.py
chmod +x ui_app.py

# Start Streamlit UI
echo "Running Log Analysis UI..."
streamlit run ui_app.py

echo "UI stopped." 