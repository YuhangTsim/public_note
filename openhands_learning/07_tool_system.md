# 07: Tool System

**Action Definitions and Function Calling**

OpenHands uses an **Action-First** architecture where "Tools" are defined as Python classes (`Action`) and exposed to the LLM via **Function Calling**.

---

## 1. Tool Definition

Tools are defined as `ChatCompletionToolParam` objects (OpenAI standard).

**File:** `openhands/agenthub/codeact_agent/function_calling.py`

```python
{
    "name": "execute_bash",
    "description": "Execute a bash command...",
    "parameters": {
        "type": "object",
        "properties": {
            "command": {"type": "string"},
            "security_risk": {"enum": ["LOW", "MEDIUM", "HIGH"]}
        },
        "required": ["command"]
    }
}
```

## 2. Action Mapping

When the LLM calls a function, it is mapped to an internal `Action` class.

| LLM Function | Action Class | Purpose |
| :--- | :--- | :--- |
| `execute_bash` | `CmdRunAction` | Run shell command |
| `execute_ipython_cell` | `IPythonRunCellAction` | Run Python code |
| `str_replace_editor` | `FileEditAction` | Edit file content |
| `send_message` | `MessageAction` | Talk to user |

## 3. Parsing Logic

The `response_to_actions` function parses the LLM's response.

1.  **Iterate**: Loop through `tool_calls` in the response.
2.  **Match**: Match function name to Action class.
3.  **Validate**: Ensure required parameters exist.
4.  **Instantiate**: Create the `Action` object.
5.  **Return**: Return list of Actions to the Controller.
