import streamlit as st
import pandas as pd
import os
import json
import subprocess
import tempfile
from datetime import datetime

def run_analysis(log_dir, search_term, verbose=False, disable_ai=False):
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
    
    # Run the analysis
    try:
        subprocess.run(cmd, check=True, capture_output=True)
        
        # Read the results
        with open(tmp_path, 'r') as f:
            results = json.load(f)
        
        # Clean up
        os.unlink(tmp_path)
        return results
    
    except subprocess.CalledProcessError as e:
        st.error(f"Error running analysis: {e}")
        st.code(e.stderr.decode())
        return None
    except Exception as e:
        st.error(f"Unexpected error: {e}")
        return None

def main():
    st.set_page_config(
        page_title="Log Analysis System",
        page_icon="📊",
        layout="wide"
    )
    
    st.title("📊 Log Analysis System")
    st.write("A simple but powerful tool for analyzing log files")
    
    # Sidebar configuration
    st.sidebar.header("Configuration")
    log_source = st.sidebar.text_input("Log Source Directory", value="./data/logs")
    search_term = st.sidebar.text_input("Search Term", value="error")
    verbose = st.sidebar.checkbox("Verbose Output")
    disable_ai = st.sidebar.checkbox("Disable AI Enhancement")
    
    # Run analysis button
    if st.sidebar.button("Run Analysis", type="primary"):
        with st.spinner("Analyzing logs..."):
            results = run_analysis(log_source, search_term, verbose, disable_ai)
            if results:
                display_results(results)
    
    # Information about the system
    with st.sidebar.expander("Help"):
        st.write("""
        This tool analyzes log files to find patterns and suggest solutions.
        
        1. Enter the directory containing your log files
        2. Enter a search term to filter logs (e.g., "error")
        3. Click "Run Analysis"
        """)

def display_results(results):
    # Display tabs for different sections
    tab1, tab2, tab3 = st.tabs(["📋 Summary", "📊 Analysis", "🔧 Solutions"])
    
    # Metadata
    metadata = results.get("metadata", {})
    timestamp = metadata.get("timestamp", datetime.now().isoformat())
    
    # Display AI enhancement status
    ai_status = results.get("ai_enhancement_used", False)
    if ai_status:
        st.success("✨ AI Enhancement: ENABLED - Solutions enhanced with SmoLAgent")
    else:
        st.warning("⚠️ AI Enhancement: DISABLED - Using basic solutions only")
    
    with tab1:
        # Summary information
        st.header("Summary")
        col1, col2 = st.columns(2)
        
        with col1:
            st.metric("Total Files Searched", metadata.get("total_files_searched", 0))
            st.metric("Total Matches", metadata.get("total_matches", 0))
        
        with col2:
            analysis = results.get("analysis", {})
            st.metric("Log Entries Analyzed", analysis.get("total_entries", 0))
            
            # Count of errors
            error_count = analysis.get("severity_distribution", {}).get("ERROR", 0)
            st.metric("Error Count", error_count)
        
        # Components table
        st.subheader("Affected Components")
        components = analysis.get("components", {})
        if components:
            component_df = pd.DataFrame({
                "Component": list(components.keys()),
                "Count": list(components.values())
            })
            component_df = component_df.sort_values("Count", ascending=False)
            st.dataframe(component_df, use_container_width=True)
        else:
            st.info("No components found")
    
    with tab2:
        # Analysis results
        st.header("Analysis Results")
        
        # Error patterns
        st.subheader("Error Patterns")
        patterns = analysis.get("error_patterns", [])
        if patterns:
            for i, pattern in enumerate(patterns, 1):
                with st.expander(f"{i}. {pattern['component']} ({pattern['count']} occurrences)"):
                    st.code(pattern["pattern"])
        else:
            st.info("No error patterns found")
        
        # Time pattern
        st.subheader("Time Distribution")
        time_pattern = analysis.get("time_pattern")
        if time_pattern:
            st.write(f"First occurrence: {time_pattern.get('first_occurrence')}")
            st.write(f"Last occurrence: {time_pattern.get('last_occurrence')}")
            st.write(f"Total occurrences: {time_pattern.get('total_occurrences')}")
        else:
            st.info("No time pattern data available")
    
    with tab3:
        # Solutions
        st.header("Suggested Solutions")
        solutions = results.get("solutions", [])
        
        if solutions:
            for i, solution in enumerate(solutions, 1):
                with st.expander(f"{i}. {solution['problem']}"):
                    st.write(solution["solution"])
                    
                    # Display explanation if available (from AI enhancement)
                    if "explanation" in solution and solution["explanation"]:
                        st.markdown("---")
                        st.markdown("**Additional Context:**")
                        st.write(solution["explanation"])
                        
                        # Show AI badge if it was enhanced
                        if solution.get("ai_enhanced"):
                            st.markdown("**<span style='color:#4CAF50'>✨ AI Enhanced</span>**", unsafe_allow_html=True)
        else:
            st.info("No solutions found")

if __name__ == "__main__":
    main() 