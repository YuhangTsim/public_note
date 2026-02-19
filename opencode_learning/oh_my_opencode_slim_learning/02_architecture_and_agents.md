# Architecture and The Pantheon

Oh My OpenCode Slim is built on a modular architecture that separates orchestration, task management, and specialized execution.

## The Pantheon: Six Divine Beings

The core of the system is a team of six specialized agents, each designed for a specific phase of the development lifecycle.

### 01. Orchestrator: The Embodiment of Order
- **Role**: Master delegator and strategic coordinator.
- **Responsibility**: Analyzes the user request, determines the optimal path, and summons specialists.
- **Philosophy**: Forged in the void of complexity to forge order from chaos.
- **Workflow**: Understand → Path Analysis → Delegation Check → Parallelize → Execute → Verify.

### 02. Explorer: The Eternal Wanderer
- **Role**: Codebase reconnaissance.
- **Capabilities**: Fast search using glob, grep, and AST-grep.
- **Usage**: Discovering unknowns, locating symbols, and mapping patterns across the codebase.
- **Rule of thumb**: "Where is X?" or "Find all Y" → @explorer.

### 03. Oracle: The Guardian of Paths
- **Role**: Strategic advisor and debugger of last resort.
- **Capabilities**: Deep architectural reasoning and complex debugging.
- **Usage**: High-stakes decisions, multi-system refactors, and persistent bugs that resist standard fixes.
- **Rule of thumb**: "Should we do X or Y?" or "Why is this still failing?" → @oracle.

### 04. Librarian: The Weaver of Knowledge
- **Role**: External knowledge retrieval.
- **Capabilities**: Fetches latest official docs, API signatures, and examples via MCPs (like grep.app).
- **Usage**: Researching unfamiliar libraries, checking version-specific behavior, and finding best practices.
- **Rule of thumb**: "How does this library work?" → @librarian.

### 05. Designer: The Guardian of Aesthetics
- **Role**: UI/UX implementation and visual excellence.
- **Capabilities**: Visual direction, responsive layouts, and micro-interactions.
- **Usage**: Polishing user-facing interfaces and ensuring design consistency.
- **Rule of thumb**: "Make this look professional" → @designer.

### 06. Fixer: The Last Builder
- **Role**: Fast implementation specialist.
- **Capabilities**: Efficient execution of well-defined tasks.
- **Usage**: Parallel implementation of independent changes once the plan is clear.
- **Rule of thumb**: "Implement this specific change" → @fixer.

---

## System Architecture

### 1. Plugin Initialization
When OpenCode loads the plugin, it initializes the configuration, agent definitions, background manager, MCPs, and hooks.

### 2. Background Task Manager (`src/background/`)
Manages long-running tasks in isolated sessions.
- **Fire-and-forget**: Returns a `task_id` immediately.
- **Concurrency**: Configurable limit for simultaneous task starts.
- **Lifecycle**: Creation → Running → Completion Detection (via `session.status`) → Result Extraction → Cleanup.

### 3. Tmux Integration (`src/utils/tmux.ts`)
Orchestrates tmux panes for visual tracking.
- Spawns a new pane for each background task.
- Automatically closes the pane when the task completes or is cancelled.
- Provides real-time visibility into sub-agent progress.

### 4. Hook System (`src/hooks/`)
Intercepts and modifies messages to enhance the workflow:
- **Phase Reminder**: Injects workflow reminders into Orchestrator messages.
- **Post-Read Nudge**: Appends delegation suggestions after a file is read.
- **Auto-Update Checker**: Ensures the plugin is always running the latest version.

### 5. Tool Registry (`src/tools/`)
Provides the agents with powerful capabilities:
- **Code Search**: Ripgrep and AST-grep integration.
- **LSP Client**: Diagnostics, references, and renaming.
- **Background Task Tool**: Allows agents to spawn other agents.
