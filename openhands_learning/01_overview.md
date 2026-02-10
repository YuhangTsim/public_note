# 01: OpenHands Overview

**Architecture, Core Components, and Workflow**

OpenHands (formerly OpenDevin) is a platform for autonomous AI software engineers. It features a React-based frontend and a Python-based backend that orchestrates agents within secure Docker sandboxes.

---

## 1. High-Level Architecture

```mermaid
graph TD
    User[User / UI] <-->|WebSocket| Server[Python Backend (FastAPI)]
    Server <-->|Event Stream| Controller[Agent Controller]
    Controller <-->|Actions/Obs| Agent[Agent Runtime]
    Agent <-->|Execute| Sandbox[Docker Sandbox]
```

### Core Components

1.  **Frontend (`frontend/`)**:
    *   React + TypeScript application.
    *   Provides the chat interface, workspace view, and terminal rendering.
    *   Communicates with the backend via WebSocket.

2.  **Backend (`openhands/server/`)**:
    *   Python FastAPI server.
    *   Manages sessions (`openhands/server/session/`).
    *   Handles WebSocket connections (`openhands/server/listen_socket.py`).

3.  **Agent Controller (`openhands/controller/`)**:
    *   **The Brain**. The `AgentController` manages the main loop:
        1.  Receive `State`.
        2.  Ask Agent for `Action`.
        3.  Execute `Action` in Sandbox.
        4.  Record `Observation`.
        5.  Repeat.

4.  **Sandbox (`openhands/runtime/`)**:
    *   **Docker-First**: The primary runtime is `DockerRuntime`.
    *   **Isolation**: Every agent session gets its own container.
    *   **Plugins**: Supports plugins like `JupyterPlugin` or `VSCodePlugin` to inject capabilities into the container.

---

## 2. The Agent Loop

The core of OpenHands is the **Event Stream**.

*   **Actions**: Emitted by the Agent (e.g., `CmdRunAction`, `FileWriteAction`, `AgentFinishAction`).
*   **Observations**: Emitted by the Sandbox/System (e.g., `CmdOutputObservation`, `FileReadObservation`).

### Step-by-Step Flow
1.  **User** sends a task ("Fix this bug").
2.  **Controller** initializes the `AgentState`.
3.  **Agent** (e.g., CodeActAgent) reads the state and prompts the LLM.
4.  **LLM** responds with a tool call (Action).
5.  **Controller** sends the Action to the **Runtime**.
6.  **Runtime** executes the command in Docker.
7.  **Runtime** returns an Observation (stdout/stderr).
8.  **Controller** adds the Observation to the Event Stream.
9.  **Agent** sees the result and decides the next step.

---

## 3. Key Concepts

### A. Agents (`openhands/agenthub/`)
Agents are Python classes defined in `agenthub`.
*   **CodeActAgent**: The default "Generalist" agent that uses executable code blocks (Python/Bash) to perform tasks.
*   **MicroAgents**: Specialized, prompt-driven agents for specific tasks.

### B. Memory
*   **`ConversationMemory`**: Manages the context window. It handles "condensing" (summarizing) history when it gets too long to fit in the LLM's window.

### C. Skills (Actions)
Skills are implemented as `Action` classes in `openhands/events/action/`.
*   `CmdRunAction`: Run a shell command.
*   `FileReadAction`: Read a file.
*   `BrowseInteractiveAction`: Browse the web.
*   `AgentFinishAction`: Signal completion.

---

## 4. Comparison to Other Tools

| Feature | OpenHands | OpenCode (Sisyphus) | OpenClaw |
| :--- | :--- | :--- | :--- |
| **Language** | Python | TypeScript | TypeScript/Python |
| **Sandbox** | Docker (Native) | Host (with approvals) | Docker (Optional) |
| **Model** | Event Stream (Action/Obs) | Tool Call Loop | Session Stream |
| **Focus** | End-to-End Dev | Coding Workflows | Personal Assistant |
