# Oh My OpenCode Slim Overview

**Oh My OpenCode Slim** (OMOS) is a lightweight, high-performance agent orchestration plugin for OpenCode. It is a slimmed-down fork of the original Oh My OpenCode, redesigned for speed, efficiency, and clarity. While the original focused on the "Sisyphus" persona and relentless looping, the Slim version introduces **The Pantheon**—a team of six "divine beings" specialized in specific domains of software development.

## Core Philosophy

> "Forging order from chaos."

OMOS shifts the focus from raw persistence to **strategic delegation** and **parallel execution**. It aims to provide a lean yet powerful multi-agent environment where the Orchestrator manages complexity by summoning the right specialist for every task.

Key philosophical pillars:
- **Order over Chaos**: The Orchestrator acts as the embodiment of order, ensuring every action is purposeful.
- **Specialization**: Each agent is a master of its craft, delivering 10x results in its specific domain.
- **Parallelism**: Tasks are broken down and executed simultaneously whenever possible to maximize speed.
- **Transparency**: Real-time monitoring via tmux integration allows users to see exactly what background agents are doing.

## Key Differences from Original (Oh My OpenCode)

| Feature | Oh My OpenCode (Original) | Oh My OpenCode Slim |
|---------|---------------------------|----------------------|
| **Primary Identity** | Sisyphus (The Ultraworker) | Orchestrator (The Embodiment of Order) |
| **Theme** | Greek Mythology (Sisyphus) | The Pantheon (Six Divine Beings) |
| **Workflow** | "Ultrawork" (ulw) keyword-driven loop | Strategic delegation & parallel execution |
| **Agents** | Sisyphus, Oracle, Librarian, Explore, UI/UX | Orchestrator, Explorer, Oracle, Librarian, Designer, Fixer |
| **New Agent** | - | **Fixer**: Specialized for fast, parallel implementation |
| **Installation** | Manual / Script-based | Dedicated CLI installer (`bunx oh-my-opencode-slim install`) |
| **Monitoring** | Standard logs | **Tmux integration** for real-time pane monitoring |
| **Footprint** | "Battery-included" (heavy) | Lightweight and optimized |

## Key Features

### 1. The Pantheon
A pre-configured team of 6 specialized agents, each with unique prompts, tools, and recommended models.

### 2. Background Task Management
Enables fire-and-forget task execution. The Orchestrator can spawn multiple background agents to perform research or implementation while the main session remains responsive.

### 3. Tmux Integration
A standout feature that spawns tmux panes for background tasks, providing a "mission control" view of the entire agent team in action.

### 4. Cartography Skill
A custom skill for repository mapping and codemap generation, helping agents understand large codebases quickly.

### 5. Hybrid Model Support
Seamlessly combines OpenCode free models with external providers (OpenAI, Kimi, Antigravity, Chutes) to balance cost and performance.
