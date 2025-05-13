#!/bin/bash

# Default values
LOGS_DIR="./data/logs"
SEARCH_TERM="error"
OUTPUT=""
VERBOSE=""

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
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "Analyzing logs in $LOGS_DIR for term '$SEARCH_TERM'"

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi
source venv/bin/activate
echo "Installing dependencies..."
pip install -r requirements.txt > /dev/null

# Make script executable
chmod +x analyze_logs.py

# Run the script
echo "Running Log Analysis..."
./analyze_logs.py --logs "$LOGS_DIR" --term "$SEARCH_TERM" $OUTPUT $VERBOSE

echo "Analysis complete." 