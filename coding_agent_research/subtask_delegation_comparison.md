# Subtasks & Delegation Systems

**Comparative Analysis: Roo Code vs. Oh-My-OpenCode vs. Oh-My-OpenCode-Slim vs. OpenClaw**

This document compares how these four systems handle **Multi-Agent Orchestration**, **Subtasks**, and **Parallelism**.

---

## 1. High-Level Comparison

| Feature | **Roo Code** | **Oh-My-OpenCode (Sisyphus)** | **Oh-My-OpenCode-Slim** | **OpenClaw** |
| :--- | :--- | :--- | :--- | :--- |
| **Model** | **Recursive Delegation** | **Async Orchestration** | **Lightweight Async** | **Job Spawning** |
| **Tool** | `new_task` | `delegate_task` | `@agent` mention / tools | `sessions_spawn` |
| **Concurrency** | **Serial** (Parent pauses) | **Parallel** (Background Async) | **Parallel** (Event-driven) | **Parallel** (Non-blocking) |
| **Context** | Child inherits workspace | Isolated (Prompt-only) | Isolated (Prompt-only) | Isolated (Task-only) |
| **Return Flow** | Synthetic Message injection | Notification + Polling | Notification + Event-driven | Announcement to Chat |
| **Philosophy** | "Break it down, solve one by one." | "Delegate research, keep coding." | "Lightweight multi-agent powerhouse." | "Start a background job." |

---

## 2. Roo Code: The Recursive Delegator

Roo Code uses a **Depth-First Search (DFS)** approach to problem solving.

*   **Mechanism:** `new_task` tool.
*   **Flow:**
    1.  **Pause:** When a parent spawns a child, the parent task is **suspended**.
    2.  **Focus:** The UI switches entirely to the Child Task. The user interacts *only* with the child.
    3.  **Return:** When the child calls `attempt_completion`, the result is injected into the Parent's history as a synthetic `subtask_result` message.
    4.  **Resume:** The parent wakes up, sees the result, and continues.
*   **Pros:** Deep focus, easy for humans to follow.
*   **Cons:** No parallelism. The parent cannot do anything while the child is working.

## 3. Oh-My-OpenCode: The Async Orchestrator

OMO uses a **Breadth-First / Parallel** approach optimized for throughput.

*   **Mechanism:** `delegate_task(run_in_background=true)`.
*   **Flow:**
    1.  **Launch:** Sisyphus spawns a sub-agent (e.g., `librarian` to research docs).
    2.  **Continue:** Sisyphus **immediately** gets a `task_id` and continues working on other things (e.g., writing code that doesn't depend on the docs yet).
    3.  **Notify:** When the sub-agent finishes, Sisyphus receives a system notification.
    4.  **Retrieve:** Sisyphus calls `background_output(task_id)` to read the result.
*   **Pros:** High efficiency. Can run 5+ research agents while coding.
*   **Cons:** Complex context management. Sisyphus must manage the state of multiple pending tasks.

## 4. Oh-My-OpenCode-Slim: The Streamlined Orchestrator

Oh-My-OpenCode-Slim (OMOS) is a **lightweight fork** of OMO, optimized for simplicity and performance.

*   **Mechanism:** `@agent` mentions with event-driven `background_task` tools.
*   **Flow:**
    1.  **Launch:** Orchestrator spawns sub-agents (Explorer, Librarian, Oracle, Designer, Fixer) via `@agent` mentions.
    2.  **Continue:** Orchestrator **immediately** continues. Tasks run in background sessions with event-driven completion detection.
    3.  **Notify:** When a sub-agent finishes, the orchestrator receives a system notification via `session.status` events.
    4.  **Retrieve:** Orchestrator calls `background_output(task_id)` to read results and integrate them.
*   **Agent Pantheon:** 6 specialized agents (Orchestrator + 5 subagents) with distinct roles and temperature settings.
*   **Pros:** Same parallel efficiency as OMO but with reduced complexity. Uses OpenCode SDK native agent system.
*   **Cons:** Requires OpenCode SDK. Less customizable than full OMO for advanced use cases.

## 5. OpenClaw: The Job Spawner

OpenClaw uses a **Worker Pool** approach.

*   **Mechanism:** `sessions_spawn`.
*   **Flow:**
    1.  **Spawn:** The main agent spins up a new session for a specific task.
    2.  **Forget:** The main agent often doesn't wait. It goes back to handling other user messages.
    3.  **Announce:** When the sub-agent finishes, it posts a message to the shared channel (e.g., Discord/Slack) announcing completion.
*   **Pros:** Great for long-running tasks (e.g., "Monitor this website for changes").
*   **Cons:** Less cohesive. The result appears as a new message, not necessarily integrated into the original train of thought.

---

## Summary

*   **Complex Problem Solving?** Use **Roo Code** (Recursive breakdown).
*   **High-Volume Coding?** Use **Oh-My-OpenCode** (Parallel research).
*   **Lightweight Multi-Agent?** Use **Oh-My-OpenCode-Slim** (Streamlined parallel orchestration).
*   **Background Maintenance?** Use **OpenClaw** (Fire-and-forget jobs).
