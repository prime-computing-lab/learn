# Log Analysis System

A simple log analysis tool.

## Overview

This system helps with intelligent log analysis by:
- Finding and extracting relevant logs
- Analyzing patterns and anomalies
- Recommending solutions based on identified issues

## Architecture

The system uses the following components:

### Core Components
- **Log Finder**: Searches and finds log files matching specific criteria
- **Log Parser**: Extracts structured data from log files
- **Pattern Analyzer**: Identifies trends and patterns in logs
- **Solution Recommender**: Suggests fixes based on identified issues
- **AI Enhancement**: Uses SmoLAgents to provide improved solutions and recommendations

## Installation

### Requirements
- Python 3.9+

For Mac:
```bash
brew install python
```

### Setup

1. Clone the repository and run the setup script:
```bash
git clone https://github.com/yourusername/log-analysis-system.git
cd log-analysis-system
chmod +x setup.sh
./setup.sh
```

2. The setup script will:
   - Create a virtual environment
   - Install dependencies
   - Set up the directory structure
   - Generate sample log files

### AI Enhancement Setup

To enable AI enhancement for better solution recommendations:

1. Copy the example .env file and edit it:
```bash
cp .env.example .env
```

2. Edit the .env file to add your HuggingFace API key:
```
HF_API_KEY=your_huggingface_api_key
```

3. You can obtain a HuggingFace API key by:
   - Creating an account at [HuggingFace](https://huggingface.co)
   - Going to your profile settings and generating an API token

## Usage

### Log Analysis

For a comprehensive log analysis:
```bash
./run_simple_analysis.sh --logs data/logs --term error
```

#### Options
- `--logs PATH`: Directory containing log files
- `--term STRING`: Search term to look for in logs
- `--output FILE`: Write results to a JSON file
- `--verbose`: Enable detailed output
- `--disable-ai`: Disable AI enhancement even if API key is present

### Web Interface

To launch the Streamlit web UI:
```bash
./run_ui.sh
```

In the web UI, you can:
- Configure log source directories
- Set search terms
- Enable/disable AI enhancement
- View enhanced solution recommendations

### Demo Mode

To run a demonstration with automatically generated logs:
```bash
./run_demo.sh
```

## AI Enhancement Features

When AI enhancement is enabled:

- Solutions will be more detailed and customized to your specific log patterns
- You'll see additional contextual information and explanation for each solution
- Both the UI and command-line output will clearly indicate when AI is being used
- Each enhanced solution will be marked with "✨ AI Enhanced"

You can tell if AI enhancement is active by:
1. The status banner at the top of the UI
2. The "✨ AI Enhanced" indicator on solutions
3. The terminal output showing "AI ENHANCEMENT IS ENABLED"

## Extending the System

### Adding New Log Sources

1. Update the log parsing functions in `analyze_logs.py` to support new log formats
2. Add new regex patterns to extract data from different log formats

### Adding New Solution Patterns

1. Enhance the `suggest_solutions` function in `analyze_logs.py`
2. Add new pattern matching logic for different types of issues
