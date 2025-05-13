#!/bin/bash

# First, explicitly unset OLLAMA_API_BASE to ensure we don't use any pre-existing value
unset OLLAMA_API_BASE

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    echo "Loading environment variables from .env file..."
    # Only export non-commented lines from .env file
    export $(grep -v '^#' .env | grep -v '^\s*$' | xargs -0 2>/dev/null || true)
fi

# Default values
VERBOSE=""
DISABLE_AI=""
DEBUG=""
# Set default only if variable is unset or empty
OLLAMA_API_BASE=${OLLAMA_API_BASE:-"http://localhost:11434"}

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
        --api-base)
            OLLAMA_API_BASE="$2"
            shift; shift
            ;;
        --debug)
            DEBUG="--debug"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "Log Analysis Tool UI"
echo "===================="
echo "Using Ollama API: $OLLAMA_API_BASE"

# Check virtual environment
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
    echo "Installing dependencies..."
    pip install -r requirements.txt > /dev/null
else
    source venv/bin/activate
fi

# Make scripts executable
chmod +x analyze_logs.py
chmod +x ui_app.py

# Pass API base and debug flag through environment variables
export OLLAMA_API_BASE="$OLLAMA_API_BASE"
if [ -n "$DEBUG" ]; then
    export DEBUG=1
    echo "Debug mode enabled"
fi

# Clear any cached data from previous runs
echo "Clearing Streamlit cache..."
rm -rf ~/.streamlit/cache 2>/dev/null

# Start Streamlit UI - add --server.port to ensure we use a fresh port
echo "Running Log Analysis UI..."
streamlit run ui_app.py --server.port=8503 -- $DEBUG

echo "UI stopped." 