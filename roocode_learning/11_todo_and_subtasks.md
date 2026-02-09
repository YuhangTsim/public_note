# 11: ToDo and Planning Systems

**Task Delegation, Planning, and State Management**

---

## 1. The Planning Philosophy: Structured Project Management

Roo Code handles planning through a combination of **Explicit Tooling**, **UI Visualization**, and **Stateful Checkpoints**. Unlike other systems that might use implicit text lists or aggressive enforcement hooks, Roo Code relies on a cooperative "Project Manager" model.

### Key Components
1.  **`update_todo_list` Tool**: The primary mechanism for creating and modifying the plan.
2.  **Tasks UI**: A dedicated side panel that renders the structured todo list.
3.  **Checkpoints**: Integrated git-based snapshots to save state before major tasks.
4.  **Subtasks**: Hierarchical task delegation.

---

## 2. The ToDo Lifecycle

### A. Creation & Update
The agent uses the `update_todo_list` tool to manage the plan.

```typescript
{
  name: "update_todo_list",
  input: {
    todos: [
      { id: "1", content: "Design database schema", status: "pending" },
      { id: "2", content: "Implement API", status: "in_progress" }
    ]
  }
}
```

*   **UI Effect**: This updates the React-based "Tasks" panel in the webview.
*   **Enforcement**: **Passive**. The system does *not* force the agent to update this list. It relies on system prompts to encourage discipline.

### B. Checkpoints (State Management)
Roo Code tightly couples planning with state management.
*   **Trigger**: Before starting a complex task (or subtask), the system often captures a **Checkpoint**.
*   **Mechanism**: Uses `git` to create a temporary snapshot.
*   **Benefit**: If a plan fails, the user can "Rewind" to the state before that specific todo item was started.

---

## 3. Subtasks (Delegation)

Roo Code supports a recursive task structure.

### Delegation Flow
1.  **Parent Task**: Decides a specific todo item is complex enough to be its own "Task".
2.  **Action**: Calls `new_task` (or `startSubtask`).
3.  **Child Task**: Spawned with its own context and todo list.
4.  **Completion**: Child calls `attempt_completion`, returning results to the parent.

```typescript
// Parent Delegate
{
  name: "new_task",
  input: {
    mode: "architect",
    message: "Design database schema for user auth system"
  }
}
```

### Hierarchy Visualization
```
Root Task (Active)
  ├─ [x] Setup Project
  ├─ [>] Implement Auth (Active Subtask)
  │       ├─ [x] Design Schema
  │       └─ [ ] Create API Routes
  └─ [ ] Deploy
```

---

## 4. Comparison with Other Systems

| Feature | Roo Code | Oh-My-OpenCode | OpenClaw |
| :--- | :--- | :--- | :--- |
| **Model** | **UI-Driven Project Manager** | **Enforced Contract** | **Periodic Checklist** |
| **Tool** | `update_todo_list` | `todowrite` | `HEARTBEAT.md` |
| **Enforcement** | **Passive** (Agent driven) | **Aggressive** (Hook wakes agent) | **None** (Stateless) |
| **State** | Session + Checkpoints | Session + Hook State | Ephemeral |
| **Best For** | Collaborative Development | Autonomous Loops | Maintenance Scripts |

**Key Takeaway:** Roo Code is best when you want to *see* the plan and *manage* the agent. OMO is best when you want the agent to *manage itself*.
