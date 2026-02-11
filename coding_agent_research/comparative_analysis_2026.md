# Comparative Analysis: Open Source Agent Architectures

**Date:** January 2026
**Repositories:** Roo Code, Oh-My-OpenCode (Sisyphus), OpenClaw, OpenHands, Letta AI

This document provides a side-by-side comparison of the five major agent architectures analyzed in this repository.

---

## 1. High-Level Architecture

| Feature | **Roo Code** | **Oh-My-OpenCode** | **OpenClaw** | **OpenHands** | **Letta AI** |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Primary Role** | Coding Co-Pilot | Autonomous Coder | Personal Assistant | Software Engineer | Memory-Centric Agent |
| **Language** | TypeScript | TypeScript | TypeScript / Python | Python | Python |
| **Architecture** | VS Code Extension | Plugin Architecture | Gateway Service | Event Stream | REST API Server |
| **Sandbox** | Local System | Local System | Docker (Optional) | **Docker (Native)** | **Sandboxed Tools** |
| **State** | Session + Git | Session + Hooks | Ephemeral | Event History | **Vector DB (Archival)** |

---

## 2. Task Completion Models

| Feature | **Roo Code** | **Oh-My-OpenCode** | **OpenClaw** | **OpenHands** | **Letta AI** |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Signal** | `attempt_completion` | **Evidence-Based** | Implicit Text | `AgentFinishAction` | `stop_reason="end_turn"` |
| **Logic** | "I think I'm done." | "Tests passed? Todos done?" | "Here is the answer." | "Action: Finish." | "Yielding control." |
| **Enforcement**| User Review | **Ralph Loop Hook** | None | Controller Check | Step Limit |

---

## 3. Planning & ToDo Systems

| Feature | **Roo Code** | **Oh-My-OpenCode** | **OpenClaw** | **OpenHands** | **Letta AI** |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Model** | **Explicit UI** | **Enforced Contract** | **Checklist** | **Implicit** | **Memory-Based** |
| **Tool** | `update_todo_list` | `todowrite` | `HEARTBEAT.md` | None (Code comments) | `core_memory_append` |
| **Storage** | `tasks.json` | Session State | Stateless File | Chat History | `CoreMemory` Block |
| **Philosophy**| "Visualize progress." | "Don't stop 'til done." | "Run maintenance." | "Code IS the plan." | "Remember the plan." |

---

## 4. Subtasks & Delegation

| Feature | **Roo Code** | **Oh-My-OpenCode** | **OpenClaw** | **OpenHands** | **Letta AI** |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Model** | **Recursive** | **Parallel Orchestration**| **Job Spawning** | **Single Thread** | **Reactive Steps** |
| **Tool** | `new_task` | `delegate_task` | `sessions_spawn` | N/A | N/A |
| **Flow** | Serial (Pause Parent) | Async (Background) | Fire-and-Forget | Iterative Loop | Step-by-Step |
| **Result** | Synthetic Message | Notification + Poll | Chat Announcement | Observation | Memory Update |

---

## 5. Memory Management

| Feature | **Roo Code** | **Oh-My-OpenCode** | **OpenClaw** | **OpenHands** | **Letta AI** |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Context** | Sliding Window | Compressed History | Sliding Window | **Condensation** | **Tiered** |
| **Long-Term** | None (Git History) | None | `MEMORY.md` (File) | Vector (Experimental)| **Archival (Vector DB)**|
| **Injection** | System Prompt | Context Injection | File Read | `RuntimeInfo` | **Dynamic XML Blocks** |
| **Unique** | Checkpoints | Context Gate | Memory Wall (DM vs Group)| Event Stream | **Self-Editing Memory**|

---

## Summary of Best Use Cases

*   **Roo Code**: Best for **Interactive Dev**. You want to watch the agent work and steer it.
*   **Oh-My-OpenCode**: Best for **Bulk Work**. You want to fire off a complex refactor and walk away.
*   **OpenClaw**: Best for **Life Ops**. You want a bot to manage your calendar, servers, and messages.
*   **OpenHands**: Best for **Sandboxed Dev**. You want an agent to act as a full employee in a secure container.
*   **Letta AI**: Best for **Long-Term Persona**. You want an agent that remembers you forever and evolves over time.
