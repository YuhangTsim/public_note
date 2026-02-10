# 09: Planning & ToDos

**Implicit vs. Structured Planning**

Unlike Roo Code or Oh-My-OpenCode, OpenHands does **not** have a native, structured ToDo system. It relies on the **CodeAct** philosophy where the plan is part of the conversation or the code itself.

---

## 1. No Native State

The `AgentState` object (`openhands/core/schema/agent.py`) tracks execution status (`RUNNING`, `PAUSED`, `STOPPED`) but has **no field** for a "Plan" or "Task List".

*   **Roo Code**: Has `tasks.json` / `update_todo_list`.
*   **OpenHands**: Has `history: List[Event]`.

## 2. The "Code to Plan" Philosophy

OpenHands follows the **CodeAct** paradigm.

*   **Logic**: "To plan, I write a file."
*   **Workflow**:
    1.  User: "Fix the bug."
    2.  Agent: `execute_bash("echo '1. Reproduce, 2. Fix' > plan.md")`
    3.  Agent: `execute_bash("python test.py")`
*   **Result**: The plan exists as a **File** (`plan.md`) in the sandbox, or as **Text** in the chat history. It is not a system-level construct.

## 3. Comparison

| Feature | OpenHands | Roo Code | Oh-My-OpenCode |
| :--- | :--- | :--- | :--- |
| **Plan Storage** | Chat History / Files | `tasks.json` / State | Session State |
| **Tooling** | None (Implicit) | `update_todo_list` | `todowrite` |
| **Visibility** | Buried in chat | Dedicated Sidebar | Toast Notifications |
| **Enforcement** | None | Passive | Aggressive (Hooks) |

## 4. Implications

*   **Pros**: Flexible. No rigid structure to fight against.
*   **Cons**: Easy for the agent to "forget" pending tasks if the context window gets truncated (Condensation).
*   **Risk**: If `plan.md` is not read frequently, the agent loses the big picture.
