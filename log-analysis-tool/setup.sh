#!/bin/bash

echo "Setting up Log Analysis System..."

# Check Python version
python_version=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
required_version="3.10"
if [ "$(printf '%s\n' "$required_version" "$python_version" | sort -V | head -n1)" != "$required_version" ]; then
    echo "Error: Python $required_version or higher is required (found Python $python_version)"
    echo "Please install Python $required_version or higher and try again"
    exit 1
fi

# Check if Ollama is installed
echo "Checking for Ollama..."
if command -v ollama >/dev/null 2>&1; then
    echo "✅ Ollama is installed!"
    # Check if Ollama is running
    if curl -s http://localhost:11434/api/version >/dev/null 2>&1; then
        echo "✅ Ollama server is running"
        
        # Check for required models
        echo "Checking for required models..."
        MODELS=("llama3.2" "llama3.1" "deepseek-r1")
        MISSING_MODELS=()
        
        for MODEL in "${MODELS[@]}"; do
            if ! curl -s "http://localhost:11434/api/tags" | grep -q "\"name\":\"$MODEL\""; then
                MISSING_MODELS+=("$MODEL")
            fi
        done
        
        if [ ${#MISSING_MODELS[@]} -eq 0 ]; then
            echo "✅ All required models are available"
        else
            echo "⚠️ Some required models are missing:"
            for MODEL in "${MISSING_MODELS[@]}"; do
                echo "   - $MODEL"
            done
            echo "You can pull them with: ollama pull MODEL_NAME"
        fi
    else
        echo "⚠️ Ollama is installed but not running"
        echo "Start it with: ollama serve"
    fi
else
    echo "⚠️ Ollama is not installed"
    echo "You can install it from: https://ollama.com"
    echo "The tool will fall back to basic analysis without AI enhancement"
fi

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Make scripts executable
echo "Setting up scripts..."
chmod +x run_analysis.sh
chmod +x run_ui.sh
chmod +x run_demo.sh
chmod +x analyze_logs.py

# Create data directories if they don't exist
mkdir -p data/logs

# Generate some sample log files
echo "Generating sample log files..."
python3 -c "
import os
import random
from datetime import datetime, timedelta

def generate_log_file(filename, log_type, entries=100):
    with open(filename, 'w') as f:
        timestamp = datetime.now() - timedelta(hours=random.randint(1, 24))
        
        for _ in range(entries):
            timestamp += timedelta(seconds=random.randint(1, 60))
            time_str = timestamp.strftime('%Y-%m-%d %H:%M:%S')
            
            if log_type == 'connection':
                if random.random() < 0.8:  # 80% are errors
                    component = random.choice(['NetworkService', 'DatabaseClient', 'AppServer'])
                    message = random.choice([
                        'Connection timeout to remote service',
                        'Failed to establish connection with server',
                        'Network connection interrupted',
                        'Database operation failed: could not connect to server',
                        'Failed to execute query: connection reset'
                    ])
                    severity = 'ERROR'
                else:
                    component = random.choice(['NetworkService', 'DatabaseClient', 'AppServer'])
                    message = random.choice([
                        'Connection established successfully',
                        'Query executed successfully',
                        'Network status: online'
                    ])
                    severity = random.choice(['INFO', 'DEBUG'])
                    
            elif log_type == 'permission':
                if random.random() < 0.8:  # 80% are errors
                    component = random.choice(['FileSystem', 'AppServer', 'SecurityManager'])
                    message = random.choice([
                        'Permission denied reading file /var/data/config.json',
                        'Access forbidden: insufficient privileges',
                        'Operation failed due to insufficient privileges',
                        'Permission denied reading file /data/users/profiles.db'
                    ])
                    severity = 'ERROR'
                else:
                    component = random.choice(['FileSystem', 'AppServer', 'SecurityManager'])
                    message = random.choice([
                        'Access granted to resource',
                        'File permissions updated successfully',
                        'User authenticated successfully'
                    ])
                    severity = random.choice(['INFO', 'DEBUG'])
            
            log_line = f'{time_str} {severity} [{component}]: {message}'
            f.write(log_line + '\\n')

# Generate files with current timestamp
timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
for log_type in ['connection', 'permission']:
    generate_log_file(f'data/logs/{log_type}_issue_{timestamp}.log', log_type)
"

echo "Setup complete!"
echo "To analyze logs, run: ./run_analysis.sh"
echo "To launch the web UI, run: ./run_ui.sh"
echo
if command -v ollama >/dev/null 2>&1; then
    echo "With Ollama integration! Your AI-enhanced analysis is ready to use."
else
    echo "⚠️ For AI-enhanced analysis, install Ollama from https://ollama.com"
fi 