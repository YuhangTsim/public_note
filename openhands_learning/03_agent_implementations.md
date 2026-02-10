# 03: Agent Implementations

**Deep Dive into CodeActAgent and BrowsingAgent**

OpenHands defines agents as Python classes in `openhands/agenthub`. This document explores the internal logic of the two primary agents.

---

## 1. CodeActAgent (`openhands/agenthub/codeact_agent/`)

The **CodeActAgent** is the default "Generalist" agent. It follows the **CodeAct** philosophy: using executable code blocks to perform actions.

### A. The "Brain" (Switching Logic)
The agent decides between talking and coding using a **Function Calling** interface.

*   **Mechanism**: `function_calling.py`
*   **Tools Provided**:
    *   `execute_bash(command)`: Run shell commands.
    *   `execute_ipython_cell(code)`: Run Python code.
    *   `str_replace_editor(...)`: Edit files.
    *   `send_message(content)`: Talk to the user.
*   **Logic**:
    1.  Agent sends conversation history + tools to LLM.
    2.  **LLM Decision**:
        *   If it calls `execute_bash`, the agent emits a `CmdRunAction`.
        *   If it calls `send_message`, the agent emits a `MessageAction`.
    3.  **Result**: The sandbox executes the code, and the observation is fed back.

### B. Prompt Templates
Prompts are stored as **Jinja2 templates** in `openhands/agenthub/codeact_agent/prompts/`.

*   `system_prompt.j2`: The core identity and instruction set.
*   `user_prompt.j2`: Formats the user's latest message.
*   `microagent_info.j2`: Injects specialized capabilities (MicroAgents) if relevant.

---

## 2. BrowsingAgent (`openhands/agenthub/browsing_agent/`)

This agent is specialized for web interaction, leveraging the **BrowserGym** ecosystem.

### A. Action Space
It uses a structured action space defined by BrowserGym:
*   **`chat`**: Send message to user.
*   **`bid`**: Interact with elements via **Bid IDs** (e.g., `click("12")`).
*   **`nav`**: Navigation (e.g., `goto("https://google.com")`).

### B. Execution Flow
1.  **State**: The agent receives the current **Accessibility Tree** and URL.
2.  **Prompt**: It constructs a prompt with the browser state and history.
3.  **Parser**: `response_parser.py` converts the LLM's text response into `BrowseInteractiveAction` objects.
4.  **Runtime**: The runtime executes the browser command (likely via Playwright).

---

## 3. MicroAgents

MicroAgents are **Prompt Fragments** that inject specialized knowledge for specific tasks (e.g., "How to use Hugo", "How to fix React bugs").

*   **Definition**: They are YAML/Markdown files in the `microagents/` directory.
*   **Injection**: The `PromptManager` dynamically selects relevant MicroAgents based on keywords in the user's task and injects them into `microagent_info.j2`.
