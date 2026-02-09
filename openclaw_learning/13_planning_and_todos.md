# 13: Planning & ToDo Systems

**Comparative Analysis: Roo Code vs. OpenClaw vs. Oh-My-OpenCode**

This document compares how these three systems handle **Planning**, **Task Tracking**, and **State Management**.

---

## 1. High-Level Comparison

| Feature | **Roo Code** | **Oh-My-OpenCode (Sisyphus)** | **OpenClaw** | **OpenCode (Core)** |
| :--- | :--- | :--- | :--- | :--- |
| **Philosophy** | **Project Manager**<br>(Structured, Explicit) | **Relentless Taskmaster**<br>(Enforced, Looping) | **Checklist Operator**<br>(Periodic, Stateless) | **Basic Utility**<br>(API-based, Simple) |
| **Tooling** | `update_todo_list` | `todowrite` | `HEARTBEAT.md` (Implicit) | `todowrite` / `todoread` |
| **State** | Session + Checkpoints | Session + Hook State | Ephemeral Context | Session Memory |
| **Enforcement** | **Passive**<br>(Agent chooses to update) | **Aggressive**<br>(System wakes agent up) | **None**<br>(Agent sleeps after run) | **Passive**<br>(Tool available) |
| **UI** | Dedicated Panel | Toast Notifications | Chat Only | Web UI Components |

---

## 2. Roo Code: The Structured Project Manager

Roo Code treats planning as a **User Interface** feature.

*   **Mechanism:** `update_todo_list` tool.
*   **Structure:**
    ```typescript
    { type: "todo", content: "Fix bug", status: "pending" }
    ```
*   **User Experience:**
    *   The agent updates the list.
    *   The user sees a nice checklist in the sidebar.
    *   It is **not** a hard constraint. If the agent forgets to check a box, the system doesn't stop it.
*   **Integration:** Closely tied to **Checkpoints**. Before starting a big todo item, it saves a git snapshot.

## 3. Oh-My-OpenCode: The Relentless Taskmaster

OMO treats planning as a **Contract**.

*   **Mechanism:** `todowrite` tool + **`todo-continuation-enforcer` Hook**.
*   **The Enforcer Hook:**
    *   Monitors the session state.
    *   **Idle Detection:** If the agent stops outputting tokens but has `pending` tasks, the hook triggers.
    *   **Injection:** It injects a system message: *"Wait, you are not done. 3 items pending. Continuing..."*
*   **Effect:** The agent enters an **Infinite Loop** of work that only breaks when the todo list is clean.
*   **Ultrawork:** In `/ulw` mode, this logic is even stricter, forbidding human handoff until verifying completion.

## 4. OpenClaw: The Checklist Operator

OpenClaw treats planning as **Periodic Maintenance**.

*   **Mechanism:** `HEARTBEAT.md`.
*   **Logic:**
    *   There is no "Project State" that persists for days.
    *   Instead, there is a **Recipe** (`HEARTBEAT.md`) that runs every few minutes/hours.
*   **Usage:** "Check email", "Backup database", "Sync calendar".
*   **Completion:** Once the checklist is run, the agent outputs `HEARTBEAT_OK` (or `¿¿silent`) and goes back to sleep. It doesn't "remember" that it checked email yesterday; it just checks again today.

## 5. OpenCode (Core): The Basic Utility

The core OpenCode repository provides the foundational tools that OMO builds upon.

*   **Mechanism:** `todowrite` and `todoread` tools.
*   **Implementation:**
    *   Backed by an in-memory session store (or simple file persistence).
    *   Exposed via REST API (`GET /session/:id/todo`).
*   **UI:** Renders simple checklist components in the shared web UI (`part.tsx`).
*   **Limitation:** It has **no enforcement logic**. It relies entirely on the agent (or the user) to read/write the list. OMO adds the "Brain" (Enforcer Hook) to this "Body" (Todo Tools).

---

## Summary

*   **Want a Coding Partner?** Use **Roo Code**. It keeps a nice list for you but lets you drive.
*   **Want an Autonomous Agent?** Use **Oh-My-OpenCode**. It forces the agent to finish what it started.
*   **Want a Personal Assistant?** Use **OpenClaw**. It runs your daily checklists reliably.
