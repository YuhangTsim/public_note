# 02: Prompt & Tool System

**Dynamic Generation and Memory Injection**

Letta does not use static `.txt` or `.j2` templates in the traditional sense. Instead, it **compiles** the system prompt dynamically based on the current state of the agent's memory.

---

## 1. Dynamic Prompt Generation

**Class**: `PromptGenerator` (`letta/prompts/prompt_generator.py`)

The system prompt is constructed at runtime by assembling various "Blocks":

1.  **Identity Block**: Who the agent is (from `CoreMemory.persona`).
2.  **User Block**: Who the user is (from `CoreMemory.human`).
3.  **Tool Block**: Definitions of available functions (JSON Schema).
4.  **Context Block**: Recent message history (Context Window management).
5.  **Archival Block**: Relevant snippets fetched from the Vector DB.

### XML-Style Injection
Letta uses XML tags to structure this data for the LLM:

```xml
<system_instructions>
You are Letta. You have access to the following memory blocks:
<memory_block name="persona">
  Name: Letta
  Role: AI Assistant
</memory_block>
<memory_block name="human">
  Name: User
</memory_block>
</system_instructions>
```

This structured approach helps the LLM distinguish between "Instructions", "Memory", and "Conversation".

---

## 2. Tool Definition & Schema

**Schema**: `Tool` (`letta/schemas/tool.py`)

Tools in Letta are first-class citizens stored in the database.

*   **Source Code**: The actual Python code of the tool is stored.
*   **JSON Schema**: The OpenAI-compatible function signature.
*   **Permissions**: Which agents are allowed to use this tool.

### Memory Tools (Built-in)
Letta injects these tools into *every* agent by default:
*   `core_memory_append(name, content)`: Add to a block.
*   `core_memory_replace(name, content)`: Overwrite a block.
*   `archival_memory_insert(content)`: Save to Vector DB.
*   `archival_memory_search(query)`: Retrieve from Vector DB.

---

## 3. Context Window Management

**Service**: `ContextWindowCalculator`

Letta aggressively manages the token budget.
1.  **Reserve**: Reserves space for the System Prompt (which grows as Memory grows).
2.  **Reserve**: Reserves space for Tool Definitions.
3.  **Fill**: Fills the rest with Conversation History.
4.  **Summarize**: If history is too long, it injects a **Summary** at the top of the context window (recursively summarized).

This ensures the agent never "crashes" due to context overflow; it just "forgets" older exact phrasing while retaining the Memory Blocks.
