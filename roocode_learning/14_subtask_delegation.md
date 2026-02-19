# 14: Subtasks & Delegation

**Recursive Delegation Implementation**

---

## The Delegation Pattern

Roo Code implements delegation as a **Stack**.

```
[ Root Task ] (Paused)
    └── [ Child Task 1 ] (Active)
            └── [ Grandchild Task A ] (Completed)
```

### 1. Creation (`new_task`)
*   **Tool:** `new_task(mode, message)`.
*   **State:** The parent task's state is saved, and `isPaused` is set to `true`.
*   **Context:** The child inherits the workspace path but starts with a fresh conversation history (except for the prompt).

### 2. Execution (User Interaction)
*   **UI:** The webview swaps to display the Child Task.
*   **Interaction:** The user can guide the child task just like a normal task.
*   **Isolation:** The parent is effectively "frozen".

### 3. Completion & Return
*   **Child Action:** Calls `attempt_completion(result)`.
*   **System Action:**
    1.  Closes the child task.
    2.  Locates the parent task.
    3.  **Synthetic Injection:** Injects a fake `tool_result` message into the parent's API history containing the child's output.
    4.  **Resume:** Unpauses the parent.

### Code Reference
*   **Creation:** `src/core/tools/NewTaskTool.ts`
*   **Return:** `src/core/webview/ClineProvider.ts` (`reopenParentFromDelegation`)

## Comparison with Async Systems

Unlike OMO and oh-my-opencode-slim (which run in background), Roo Code's subtasks are **Modal**. You cannot interact with the parent until the child is done (or cancelled). This aligns with its "Co-Pilot" philosophy: one driver, one navigator, one focus at a time.
