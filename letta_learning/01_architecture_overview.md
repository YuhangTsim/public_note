# 01: High-Level Architecture & Design

**Letta AI (formerly MemGPT)** is designed around a core philosophy: **Stateful Memory Management**. Unlike standard agents that rely on a sliding context window, Letta treats memory as an operating system resource with distinct tiers (Core vs. Archival).

---

## 1. System Architecture

```mermaid
graph TD
    Client[Client / Web UI] <-->|REST API| Server[Letta Server (FastAPI)]
    
    subgraph "Letta Server"
        Server --> Controller[Agent Controller]
        Controller --> Runtime[Agent Runtime]
        
        Runtime --> CoreMem[Core Memory (In-Context)]
        Runtime --> ArchivalMem[Archival Memory (Vector DB)]
        
        Runtime --> Tools[Tool Executor]
        Tools --> Sandbox[Sandbox / MCP]
    end
```

### Core Components

1.  **Server (`letta/server/`)**:
    *   A FastAPI backend that exposes a REST API.
    *   Manages the lifecycle of agents, sources, and users.
    *   Handles authentication and multi-tenancy.

2.  **Agent Runtime (`letta/agents/`)**:
    *   The "Brain" of the operation.
    *   **`LettaAgent`**: The main class that orchestrates the loop.
    *   It does **not** run as a continuous background process by default; it steps in response to API triggers (like a serverless function).

3.  **Memory System (`letta/schemas/memory.py`)**:
    *   **Core Memory**: The "RAM". Small, highly accessible blocks (e.g., `persona`, `human`). Stored directly in the LLM's context window.
    *   **Archival Memory**: The "Hard Drive". Infinite storage backed by a Vector Database (pgvector/Chroma). Agents must explicitly search/retrieve from it.

---

## 2. Design Philosophy: "Memory as an OS"

Letta's defining feature is how it exposes memory to the agent.

*   **Standard Agents**: "Here is the chat history. Good luck."
*   **Letta**: "You have a `persona` block and a `human` block. You can edit them using tools."

### The "Self-Editing" Loop
The agent is explicitly aware of its memory limitations.
1.  **Input**: User says "My birthday is in June."
2.  **Reasoning**: "This is important. I should save it."
3.  **Action**: Calls `core_memory_append(block="human", value="Birthday: June")`.
4.  **Result**: The system prompt is updated *in real-time* for the next turn.

---

## 3. Tool Execution Architecture

Letta uses a **Sandboxed Tooling** model.

*   **Definition**: Tools are defined as Python functions or JSON schemas.
*   **Execution**:
    *   **Built-in**: Executed directly by the runtime (e.g., memory edits).
    *   **Custom/MCP**: Executed via `ToolExecutor` service.
    *   **Safety**: Tools can be restricted or require approval logic (managed by the Server).

---

## 4. Key Differentiators

| Feature | Letta AI | OpenHands | OpenCode (Sisyphus) |
| :--- | :--- | :--- | :--- |
| **Primary Goal** | **Long-term Memory** | Software Engineering | Autonomous Coding |
| **State Model** | **Tiered Memory** (RAM/Disk) | Event Stream | Session History |
| **Agent Loop** | **Reactive** (Step-based) | Continuous Loop | Task-Driven Loop |
| **Persistence** | **Database First** (Postgres) | Docker Container | Session Files |

Letta is optimized for **Persistent Identity** and **Long-Running Conversations**, whereas OpenHands/OpenCode are optimized for **Task Completion**.
