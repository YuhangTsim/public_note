# 08: Observation System

**Formatting, Truncation, and Feedback Loops**

The "Output" of a tool is an **Observation**. This document explains how Observations are processed and fed back to the LLM.

---

## 1. Observation Types

Just as tools are Actions, results are Observations (`openhands/events/observation/`).

*   `CmdOutputObservation`: Stdout/Stderr from a shell command.
*   `FileReadObservation`: Content of a file.
*   `BrowserOutputObservation`: Screenshot + Accessibility Tree + URL.
*   `IPythonRunCellObservation`: Output of a Python cell.

## 2. Formatting (`observation_to_message`)

Before sending an observation to the LLM, it is converted into a chat message format.

**File:** `openhands/memory/conversation_memory.py`

*   **Command Output**: Prefixed with *"Observed result of command..."*.
*   **File Content**: Wrapped in code blocks.
*   **Browser**: Formatted as a text description of the page state.

## 3. Truncation Logic

To prevent context window overflow, OpenHands aggressively truncates large outputs.

*   **Config**: `max_message_chars` (Default: 30,000).
*   **Mechanism**: `truncate_content()` function.
*   **Strategy**:
    *   Keep the **Head** (start of output).
    *   Keep the **Tail** (end of output, usually most relevant).
    *   Replace the middle with `... [truncated] ...`.

**Why Tail?**
In shell commands and build logs, the error message or final status is usually at the very end. Keeping the tail is critical for debugging.
