#!/bin/bash

# Function to display usage/help information
display_help() {
    echo "Log Analysis Tool - Help"
    echo "======================="
    echo "Usage: ./run_analysis.sh [options]"
    echo ""
    echo "Options:"
    echo "  --logs DIR         Directory containing log files (default: ./data/logs)"
    echo "  --term TERM        Search term to look for in logs (default: error)"
    echo "  -o, --output FILE  Output file for results in JSON format"
    echo "  -v, --verbose      Enable verbose output"
    echo "  --disable-ai       Disable AI enhancement"
    echo "  --model MODEL      Specify Ollama model to use (default: llama3.2)"
    echo "  --timeout SECONDS  Set timeout for Ollama API requests in seconds (default: 300)"
    echo "  --debug            Enable debug output"
    echo "  -h, --help         Display this help message"
    echo ""
    echo "Example: ./run_analysis.sh --logs ./my_logs --term exception --timeout 600"
    exit 0
}

# Unset any existing OLLAMA_API_BASE to ensure we use the one from .env
unset OLLAMA_API_BASE

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    echo "Loading environment variables from .env file..."
    export $(grep -v '^#' .env | xargs)
fi

# Debug output
echo "OLLAMA_API_BASE is set to: $OLLAMA_API_BASE"

# Default values
LOGS_DIR="./data/logs"
SEARCH_TERM="error"
OUTPUT=""
VERBOSE=""
DISABLE_AI=""
DEBUG_FLAG=""
OLLAMA_MODEL=${OLLAMA_MODEL:-"llama3.2"}  # Default to llama3.2 or use env var if set
OLLAMA_TIMEOUT=${OLLAMA_TIMEOUT:-"300"}   # Default timeout is 300 seconds (5 minutes)

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --logs)
            LOGS_DIR="$2"
            shift; shift
            ;;
        --term)
            SEARCH_TERM="$2"
            shift; shift
            ;;
        -o|--output)
            OUTPUT="--output $2"
            shift; shift
            ;;
        -v|--verbose)
            VERBOSE="--verbose"
            shift
            ;;
        --disable-ai)
            DISABLE_AI="--disable-ai"
            shift
            ;;
        --model)
            OLLAMA_MODEL="$2"
            shift; shift
            ;;
        --timeout)
            OLLAMA_TIMEOUT="$2"
            shift; shift
            ;;
        --debug)
            DEBUG_FLAG="--debug"
            export DEBUG=1
            shift
            ;;
        -h|--help)
            display_help
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help to display available options"
            exit 1
            ;;
    esac
done

echo "Log Analysis Tool"
echo "================="
echo "Analyzing logs in $LOGS_DIR for term '$SEARCH_TERM'"

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

# Make script executable
chmod +x analyze_logs.py

# Check if Ollama AI is being used
if [ -z "$DISABLE_AI" ]; then
    echo "Using Ollama model: $OLLAMA_MODEL (timeout: ${OLLAMA_TIMEOUT}s)"
    export OLLAMA_MODEL="$OLLAMA_MODEL"
    export OLLAMA_TIMEOUT="$OLLAMA_TIMEOUT"
else
    echo "AI enhancement is disabled"
fi

# Run the script
echo "Running Log Analysis..."
echo "Command: ./analyze_logs.py --logs \"$LOGS_DIR\" --term \"$SEARCH_TERM\" $OUTPUT $VERBOSE $DISABLE_AI $DEBUG_FLAG"
./analyze_logs.py --logs "$LOGS_DIR" --term "$SEARCH_TERM" $OUTPUT $VERBOSE $DISABLE_AI $DEBUG_FLAG

echo "Analysis complete." 