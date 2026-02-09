# 14: Subtasks & Job Spawning

**Fire-and-Forget Architecture**

---

## The Spawning Model

OpenClaw treats subtasks as **Independent Sessions**.

### 1. The `sessions_spawn` Tool
*   **Action:** Creates a completely new session with its own `sessionId`.
*   **Linkage:** The new session knows its `parentSessionId`, but they run independently.
*   **Blocking:** **Non-blocking**. The parent agent receives an "Accepted" status immediately and continues its own loop.

### 2. Execution Flow
1.  **Parent:** `sessions_spawn(agent: "researcher", task: "Find specs for X")`
2.  **System:** Spawns session `ses_123`.
3.  **Parent:** Receives `{"status": "accepted", "childSession": "ses_123"}`.
4.  **Child:** Runs independently (streaming, tool use).
5.  **Parent:** Can handle other user messages in the meantime.

### 3. Completion (Announcements)
*   **Mechanism:** The child agent does *not* "return" a value to the parent's code execution stack.
*   **Output:** Instead, it posts a message to the **Channel** (Discord/Slack/etc.).
*   **Effect:** The user sees the result. The parent agent *might* see it if it's monitoring the channel, but it's not a direct function return.

## Use Cases

This architecture is optimized for **Long-Running Jobs**:
*   "Monitor this URL for changes."
*   "Summarize the last 100 messages in #general."
*   "Run a daily health check."

It is **not** optimized for tight feedback loops (like "Write this function, then I will write the test"). For that, you would keep it in the single session.
