import streamlit as st
import pandas as pd
import os
import json
import subprocess
import tempfile
import requests
from datetime import datetime
import sys
import argparse
from dotenv import load_dotenv
from agent_helper import is_ollama_available, get_available_ollama_models

# Reset environment variables before anything else
# This ensures VSCode's injected values don't interfere
if 'OLLAMA_API_BASE' in os.environ:
    print("Removing existing OLLAMA_API_BASE from environment")
    del os.environ['OLLAMA_API_BASE']

# Force reload environment variables from .env file
load_dotenv(override=True)

# Set page config as the first Streamlit command
st.set_page_config(
    page_title="Log Analysis System",
    page_icon="📊",
    layout="wide"
)

# Log Analysis Tool UI Application
#
# This Streamlit application provides an interface for analyzing log files.
# It can be run in normal or debug mode.
#
# Debug mode can be enabled in three ways:
# 1. Command-line flag: --debug
# 2. Environment variable: DEBUG=1
# 3. URL parameter: ?debug=1
#
# In debug mode, additional information is displayed in the UI and console.

# Global debug flag
DEBUG_MODE = False

def log(message, level="INFO"):
    """
    Logging utility that respects the debug flag
    
    Args:
        message: The message to log
        level: Log level (DEBUG, INFO, WARNING, ERROR)
    """
    if level == "DEBUG" and not DEBUG_MODE:
        # Skip debug messages when not in debug mode
        return
        
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] [{level}] {message}")

def is_debug_mode():
    """
    Check if debug mode is enabled through any of the supported methods:
    - Command line flag (--debug)
    - Environment variable (DEBUG=1)
    - URL parameter (?debug=1)
    """
    # Check command line arguments
    parser = argparse.ArgumentParser(description="Log Analysis Tool")
    parser.add_argument("--debug", action="store_true", 
                        help="Enable debug mode - shows additional information in UI and console")
    
    # Parse known args only (to avoid conflicts with streamlit's own args)
    args, _ = parser.parse_known_args()
    
    # Check environment variable
    env_debug = os.getenv("DEBUG", "0").lower() in ("1", "true", "yes", "on")
    
    # Check URL parameter (for Streamlit)
    # This will be checked in the main function using st.experimental_get_query_params
    
    return args.debug or env_debug

# Modified caching function to include api_base as part of the cache key
# This ensures it refreshes when the api_base changes
@st.cache_data(ttl=1, show_spinner=False)
def check_ollama_connection(api_base):
    """Check if Ollama is available with caching for better performance"""
    log(f"Checking Ollama connection to {api_base}", "DEBUG")
    return is_ollama_available(api_base)

# Set debug mode
DEBUG_MODE = is_debug_mode()

# Only show startup logs in debug mode
if DEBUG_MODE:
    log("Loading environment variables...", "INFO")
    log(f"OLLAMA_API_BASE={os.getenv('OLLAMA_API_BASE', 'Not set')}", "INFO")

def run_analysis(log_dir, search_term, verbose=False, disable_ai=False, ollama_model=None):
    """Run the log analysis and return results"""
    # Create a temporary file to store the JSON results
    with tempfile.NamedTemporaryFile(suffix='.json', delete=False) as tmp:
        tmp_path = tmp.name
    
    # Build the command
    cmd = [
        './analyze_logs.py',
        '--logs', log_dir,
        '--term', search_term,
        '--output', tmp_path
    ]
    
    if verbose:
        cmd.append('--verbose')
        
    if disable_ai:
        cmd.append('--disable-ai')
        
    # Add debug flag if in debug mode
    if DEBUG_MODE:
        cmd.append('--debug')

    # Set Ollama model as environment variable    
    env = os.environ.copy()
    if ollama_model and not disable_ai:
        env["OLLAMA_MODEL"] = ollama_model
    
    # Ensure DEBUG flag is preserved in the environment
    if DEBUG_MODE:
        env["DEBUG"] = "1"
    
    # Run the analysis
    try:
        log(f"Running command: {' '.join(cmd)}", "DEBUG")
        result = subprocess.run(cmd, check=True, capture_output=True, env=env)
        
        # Read the results
        with open(tmp_path, 'r') as f:
            results = json.load(f)
        
        # Clean up
        os.unlink(tmp_path)
        return results, None
    
    except subprocess.CalledProcessError as e:
        error_message = f"Error running analysis: {e}"
        error_details = e.stderr.decode()
        log(error_message, "ERROR")
        log(error_details, "ERROR")
        return None, (error_message, error_details)
    except Exception as e:
        error_message = f"Unexpected error: {e}"
        log(error_message, "ERROR")
        return None, (error_message, None)

def main():
    # Check for URL parameter debug flag
    url_debug = "debug" in st.query_params and st.query_params["debug"] in ("1", "true")
    
    # Update global debug flag to include URL parameter
    global DEBUG_MODE
    if url_debug:
        DEBUG_MODE = True
    
    # Reload environment variables before getting the API base
    load_dotenv(override=True)
    
    # Get Ollama API base URL
    api_base = os.getenv("OLLAMA_API_BASE", "http://localhost:11434")
    
    if DEBUG_MODE:
        log(f"Using Ollama API base: {api_base}", "INFO")
    
    # Only show debug expander when in debug mode
    if DEBUG_MODE:
        with st.expander("Debug Environment", expanded=False):
            st.write("Environment Variables:")
            st.code(f"OLLAMA_API_BASE={api_base}")
            st.write("Working Directory:")
            st.code(os.getcwd())
            
            # Add Ollama connection status
            st.subheader("Ollama Connection Status")
            
            # Check Ollama connection
            if check_ollama_connection(api_base):
                st.success(f"✅ Successfully connected to Ollama")
                try:
                    response = requests.get(f"{api_base}/api/version", timeout=5)
                    st.json(response.json())
                except Exception:
                    st.warning("Connected but couldn't retrieve version info")
            else:
                st.error(f"❌ Failed to connect to Ollama at {api_base}")
    
    st.title("📊 Log Analysis System")
    st.write("A simple but powerful tool for analyzing log files")
    
    # Show debug mode indicator if active
    if DEBUG_MODE:
        st.caption("🐞 Debug Mode Active")
    
    # Sidebar configuration
    st.sidebar.header("Configuration")
    log_source = st.sidebar.text_input("Log Source Directory", value="./data/logs")
    search_term = st.sidebar.text_input("Search Term", value="error")
    verbose = st.sidebar.checkbox("Verbose Output")
    disable_ai = st.sidebar.checkbox("Disable AI Enhancement")
    
    # Show debug toggle in sidebar when in debug mode
    if DEBUG_MODE:
        st.sidebar.markdown("---")
        st.sidebar.subheader("Debug Options")
        st.sidebar.info("Debug mode is active via: " + 
                      ("Command line" if "--debug" in sys.argv else 
                       "Environment variable" if os.getenv("DEBUG") == "1" else 
                       "URL parameter"))
        
        # Add a link to disable debug mode by removing the parameter
        if "debug" in st.query_params:
            st.sidebar.markdown("[Disable Debug Mode](?)")
    else:
        # Add a subtle link to enable debug mode
        with st.sidebar.expander("Advanced Options", expanded=False):
            st.markdown("[Enable Debug Mode](?debug=1)")
    
    # Get available Ollama models using the cache function
    ollama_models = get_available_ollama_models(api_base)
    
    # Ollama model selection (only shown if AI is enabled)
    ollama_model = None
    if not disable_ai:
        st.sidebar.subheader("Ollama Configuration")
        
        # Check Ollama connection with cached result
        ollama_available = check_ollama_connection(api_base)
        if ollama_available:
            st.sidebar.success(f"✓ Connected to Ollama")
            
            # Model selection
            current_model = os.getenv("OLLAMA_MODEL", "llama3.2")
            ollama_model = st.sidebar.selectbox("Select Ollama Model", 
                                               options=ollama_models,
                                               index=ollama_models.index(current_model) if current_model in ollama_models else 0)
            
            st.sidebar.info(f"Using model: {ollama_model}")
        else:
            st.sidebar.error("❌ Cannot connect to Ollama")
            st.sidebar.warning("AI Enhancement will be disabled")
            disable_ai = True
    
    # Run analysis button
    if st.sidebar.button("Analyze Logs"):
        if not os.path.exists(log_source):
            st.error(f"Log source directory '{log_source}' does not exist!")
        else:
            with st.spinner("Analyzing logs..."):
                results, error = run_analysis(
                    log_dir=log_source,
                    search_term=search_term,
                    verbose=verbose,
                    disable_ai=disable_ai,
                    ollama_model=ollama_model
                )
                
                if error:
                    error_message, error_details = error
                    st.error(error_message)
                    if error_details:
                        with st.expander("Error Details"):
                            st.code(error_details)
                else:
                    display_results(results, ollama_model)
                    
def display_results(results, ollama_model=None):
    """Display the analysis results in the Streamlit UI"""
    
    matches = results.get("matches", [])
    analysis = results.get("analysis", {})
    solutions = results.get("solutions", [])
    ai_enhancement_used = results.get("ai_enhancement_used", False)
    ai_error = results.get("ai_error", None)
    ollama_model_used = results.get("ollama_model_used", ollama_model or os.getenv("OLLAMA_MODEL", "llama3.2"))
    
    # Display status
    st.header("Analysis Results")
    
    # Show AI enhancement status
    if ai_enhancement_used:
        st.success(f"✨ AI Enhancement: ENABLED (using Ollama model: {ollama_model_used})")
    elif ai_error:
        st.warning(f"⚠️ AI Enhancement: FAILED - {ai_error}")
    else:
        st.info("ℹ️ AI Enhancement: DISABLED")
    
    # Create tabs for different sections of the analysis
    tabs = st.tabs(["Suggested Solutions", "Analysis Overview", "Log Matches"])
    
    # Tab 1: Suggested Solutions
    with tabs[0]:
        if solutions:
            for i, solution in enumerate(solutions):
                with st.expander(f"Solution {i+1}: {solution.get('problem', 'Unknown Problem')}", expanded=True):
                    # Add AI badge if this solution was enhanced
                    if ai_enhancement_used:
                        st.markdown(f"**{solution.get('problem', 'Unknown Problem')}** ✨")
                    else:
                        st.markdown(f"**{solution.get('problem', 'Unknown Problem')}**")
                    
                    st.markdown(solution.get('solution', 'No solution provided'))
                    
                    if solution.get('explanation'):
                        st.markdown("---")
                        st.markdown("**Additional Context:**")
                        st.markdown(solution.get('explanation'))
        else:
            st.info("No solutions suggested. The logs may not contain significant issues.")
    
    # Tab 2: Analysis Overview
    with tabs[1]:
        col1, col2 = st.columns(2)
        
        # Column 1: Basic stats
        with col1:
            st.subheader("Basic Statistics")
            st.metric("Total Matches", analysis.get("total_entries", 0))
            
            # Severity distribution
            st.subheader("Severity Distribution")
            severities = analysis.get("severity_distribution", {})
            if severities:
                # Convert to DataFrame for display
                df_severity = pd.DataFrame({
                    'Severity': list(severities.keys()),
                    'Count': list(severities.values())
                })
                st.dataframe(df_severity, use_container_width=True)
            else:
                st.info("No severity information found")
        
        # Column 2: Components
        with col2:
            st.subheader("Component Analysis")
            components = analysis.get("components", {})
            if components:
                # Convert to DataFrame for display
                df_components = pd.DataFrame({
                    'Component': list(components.keys()),
                    'Count': list(components.values())
                })
                # Sort by count descending
                df_components = df_components.sort_values('Count', ascending=False)
                st.dataframe(df_components, use_container_width=True)
            else:
                st.info("No component information found")
        
        # Error patterns
        st.subheader("Common Error Patterns")
        error_patterns = analysis.get("error_patterns", [])
        if error_patterns:
            for i, pattern in enumerate(error_patterns):
                with st.expander(f"Pattern {i+1}: {pattern.get('component', 'Unknown Component')}", expanded=i<3):
                    st.markdown(f"**Component:** {pattern.get('component', 'Unknown')}")
                    st.markdown(f"**Count:** {pattern.get('count', 0)}")
                    st.markdown(f"**Pattern:**")
                    st.code(pattern.get('pattern', 'No pattern available'))
        else:
            st.info("No error patterns identified")
    
    # Tab 3: Log Matches
    with tabs[2]:
        st.subheader(f"Raw Log Entries ({len(matches)} matches)")
        
        if matches:
            # Create a DataFrame for the matches
            df_matches = pd.DataFrame(matches)
            
            # Display only the first 100 matches to avoid overloading the UI
            st.dataframe(df_matches.head(100), use_container_width=True)
            
            if len(matches) > 100:
                st.info(f"Showing 100 of {len(matches)} matches. Filter results for more specific analysis.")
                
            # Display a few sample matches
            st.subheader("Sample Log Entries")
            for i, match in enumerate(matches[:5]):  # Show first 5 matches
                with st.expander(f"Log Entry {i+1} - {match.get('file', 'unknown')}"):
                    st.text(match.get('content', 'No content available'))
        else:
            st.info("No log matches found for the search term.")

if __name__ == "__main__":
    main() 