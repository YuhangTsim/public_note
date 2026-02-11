# 03: Agent Loop & Completion

**The Step Cycle and Stop Reasons**

Letta's runtime is driven by a `step()` loop that processes inputs, thinks, executes tools, and updates state.

---

## 1. The Execution Loop

**Class**: `LettaAgentV3` (`letta/agents/letta_agent_v3.py`)

The `step()` method is the engine.

**Flow:**
1.  **Load State**: Fetch current Memory, Messages, and Tools.
2.  **Compile Prompt**: Use `PromptGenerator` to build the context.
3.  **LLM Call**: Send request to the provider (OpenAI, etc.).
4.  **Parse Response**:
    *   **Content**: A text reply to the user.
    *   **Tool Call**: A request to use a function.
5.  **Execute (if Tool)**:
    *   Run the tool.
    *   **Update Memory**: If the tool was `core_memory_replace`, update the DB immediately.
    *   **Recurse**: Feed the tool output back into the LLM (Chain of Thought).
6.  **Yield**: Return the result to the server/user.

---

## 2. Task Completion (Stop Reasons)

How does the loop end? Letta uses `LettaStopReason` (`letta/schemas/letta_stop_reason.py`).

| Reason | Meaning |
| :--- | :--- |
| `end_turn` | The agent decided to stop and yield control to the user. |
| `max_steps` | The agent hit the loop limit (preventing infinite loops). |
| `tool_rule` | A security rule prevented further execution. |
| `requires_approval` | The agent wants to run a sensitive tool (Human-in-the-loop). |

**Contrast with Others:**
*   **OpenHands**: Emits `AgentFinishAction`.
*   **Letta**: Emits `end_turn` status. It effectively "pauses" until the next user input.

---

## 3. Planning Capabilities

**Status: No Built-in Planner**

Letta does **not** have a dedicated "Planning Module" or "Task Queue".
*   **Philosophy**: The agent "plans" by editing its `CoreMemory`.
*   **Pattern**:
    1.  Agent writes a plan to `core_memory_append(name="current_task", value="1. Do A, 2. Do B")`.
    2.  In the next step, it sees this plan in its System Prompt.
    3.  It executes Step 1.
    4.  It updates the memory block to mark Step 1 done.

This is a powerful, flexible way to handle state without a rigid "Task Management" subsystem.
