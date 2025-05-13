from smolagents import HfApiModel, CodeAgent, LiteLLMModel
from smolagents import tool
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def is_ai_enhancement_enabled():
    """Check if AI enhancement is enabled"""
    # Check for API key and the environment variable
    # has_api_key = bool(os.getenv("HF_API_KEY"))
    not_disabled = os.getenv("DISABLE_AI_ENHANCEMENT") != "true"
    
    # Check if the Ollama/OpenAI endpoint is configured
    ollama_configured = bool(os.getenv("OPENAI_API_BASE"))
    # return has_api_key and not_disabled
    return not_disabled and ollama_configured

@tool
def enhance_solution(problem_description: str, existing_solution: str, log_patterns: list) -> dict:
    """
    Generate an enhanced solution with better explanation for a log issue.
    
    Args:
        problem_description: Description of the identified problem
        existing_solution: Current solution suggestion
        log_patterns: Example log patterns related to the issue
    
    Returns:
        Enhanced solution with detailed explanation
    """
    # This is just a function signature - the LLM will implement the logic
    pass

def get_agent():
    """Initialize and return the solution enhancement agent"""
    
    api_base = os.getenv("OPENAI_API_BASE")
    if not api_base:
        # This case should ideally be caught by is_ai_enhancement_enabled,
        # but as a safeguard:
        raise ValueError("OPENAI_API_BASE environment variable is not set. Cannot connect to local LLM.")
    
    print(f"Attempting to connect to LLM via: {api_base}")
    
    # model = HfApiModel(
    model = LiteLLMModel(
        "openai/qwen3:30b-a3b",
        # "openai/deepseek-r1:latest",
        # "openai.llama3.2:latest",
        # "Qwen/Qwen2.5-7B-Instruct",  # A smaller model for faster response
        # provider="together",
        api_base=api_base,
        # api_key=os.getenv("HF_API_KEY")
        api_key=os.getenv("OPENAI_API_KEY")
    )
    
    agent = CodeAgent(
        model=model,
        tools=[enhance_solution]
    )
    
    return agent

def enhance_solutions(analysis_results):
    """
    Enhance the solutions in the analysis results with better explanations.
    
    Args:
        analysis_results: The original analysis results with basic solutions
        
    Returns:
        Updated analysis results with enhanced solutions
    """
    # Check if AI enhancement is enabled
    if not is_ai_enhancement_enabled():
        print("🔴 AI Enhancement is DISABLED (missing API key or explicitly disabled)")
        analysis_results["ai_enhancement_used"] = False
        return analysis_results
    
    try:
        print("🟢 AI Enhancement is ENABLED - Enhancing solutions...")
        agent = get_agent()
        enhanced_solutions = []
        
        for solution in analysis_results.get("solutions", []):
            # Extract required information
            problem = solution.get("problem", "")
            basic_solution = solution.get("solution", "")
            
            # Find related log patterns
            patterns = []
            for pattern in analysis_results.get("analysis", {}).get("error_patterns", []):
                if any(keyword in pattern.get("pattern", "").lower() for keyword in problem.lower().split()):
                    patterns.append(pattern.get("pattern", ""))
            
            # Only use the first 3 patterns to keep prompt size reasonable
            log_examples = patterns[:3]
            
            # Get enhanced solution
            log_examples_text = "\n".join(log_examples) if log_examples else "No log examples available"
            prompt = f"""Enhance this log analysis solution with more details:
                Problem: {problem}
                Basic solution: {basic_solution}
                Log patterns:
                {log_examples_text}

                Provide a more detailed explanation and specific steps to resolve the issue."""
            
            print(f"⚙️ Enhancing solution for: {problem}")
            result = agent.run(prompt)
            
            # Update the solution with enhanced content
            enhanced_solution = {
                "problem": problem,
                "solution": str(result),
                "explanation": "",
                "ai_enhanced": True
            }
            
            enhanced_solutions.append(enhanced_solution)
        
        # Replace original solutions with enhanced ones
        analysis_results["solutions"] = enhanced_solutions
        analysis_results["ai_enhancement_used"] = True
        print("✅ Solutions enhanced successfully with AI")
        return analysis_results
    
    except Exception as e:
        print(f"❌ Error enhancing solutions with AI: {e}")
        analysis_results["ai_enhancement_used"] = False
        return analysis_results  # Return original results on failure