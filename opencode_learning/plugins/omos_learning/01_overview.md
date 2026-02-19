# oh-my-opencode-slim Overview

**oh-my-opencode-slim** (omos) is a lightweight, high-performance fork of `oh-my-opencode`. It transforms a single LLM session into a multi-agent powerhouse through intelligent task delegation and specialized agent orchestration.

## Core Philosophy: The Pantheon

> "Six divine beings emerged from the dawn of code, each an immortal master of their craft await your command to forge order from chaos."

The central philosophy of omos is **Specialization through Delegation**. Instead of relying on a single "jack-of-all-trades" model, omos breaks down complex tasks into domains handled by specialist agents.

### Why Specialization?

```
┌─────────────────────────────────────────────────────────────┐
│  Traditional Single-Agent Approach                          │
│  ┌─────────────┐                                            │
│  │  One Model  │─── Handles everything (bloated context)   │
│  │  (Generic)  │                                            │
│  └─────────────┘                                            │
│         │                                                   │
│         ▼                                                   │
│  • High token usage                                         │
│  • Context pollution                                        │
│  • No parallelization                                       │
│  • Expensive for simple tasks                               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  omos Multi-Agent Approach                                  │
│                                                             │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐                 │
│   │Explorer  │  │ Librarian│  │  Fixer   │                 │
│   │ (Fast)   │  │ (Research│  │ (Execute)│                 │
│   └──────────┘  └──────────┘  └──────────┘                 │
│         │            │            │                         │
│         └────────────┼────────────┘                         │
│                      ▼                                      │
│              ┌─────────────┐                                │
│              │Orchestrator │─── Coordinates & delegates    │
│              │ (Strategy)  │                                │
│              └─────────────┘                                │
│                      │                                      │
│         ┌────────────┼────────────┐                         │
│         ▼            ▼            ▼                         │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐                 │
│   │  Oracle  │  │ Designer │  │ Background│                │
│   │(High-IQ) │  │  (UI/UX) │  │  Tasks    │                │
│   └──────────┘  └──────────┘  └──────────┘                 │
│                                                             │
│  • Optimized cost/quality ratio                            │
│  • Parallel execution                                       │
│  • Isolated context per agent                              │
│  • Right tool for each job                                  │
└─────────────────────────────────────────────────────────────┘
```

## Key Design Principles

### 1. Understand → Delegate → Parallelize

The mandatory workflow enforced for the Orchestrator:

```
┌──────────────┐     ┌──────────────┐     ┌──────────────────┐
│  1. UNDERSTAND│────▶│ 2. DELEGATE  │────▶│ 3. PARALLELIZE   │
└──────────────┘     └──────────────┘     └──────────────────┘
       │                    │                       │
       ▼                    ▼                       ▼
• Analyze request    • Choose specialist    • Spawn background
• Identify domains   • Pass minimal context   agents
• Plan approach      • Set clear scope      • Monitor progress
```

### 2. Read-Only Research

Research agents (Explorer, Librarian) **never modify code**. They only gather and report information.

### 3. Execution Focus

Implementation agents (Fixer, Designer) work from **clear specifications** provided by the Orchestrator.

### 4. Real-Time Visibility

Tmux integration allows users to watch sub-agents work in parallel panes.

```
┌────────────────────────────────────────────────────────────────────┐
│  Tmux Layout Example                                               │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  ┌─────────────────────────────┐  ┌─────────────────────────────┐ │
│  │                             │  │                             │ │
│  │   Main Session              │  │   @explorer                 │ │
│  │   (Orchestrator)            │  │   Searching codebase...     │ │
│  │                             │  │   Files found: 23           │ │
│  │   Waiting for results...    │  │                             │ │
│  │                             │  │                             │ │
│  └─────────────────────────────┘  └─────────────────────────────┘ │
│                                                                    │
│  ┌─────────────────────────────┐  ┌─────────────────────────────┐ │
│  │                             │  │                             │ │
│  │   @librarian                │  │   @fixer                    │ │
│  │   Fetching docs...          │  │   Implementing changes...   │ │
│  │   Sources: 5                │  │   Progress: 67%             │ │
│  │                             │  │                             │ │
│  │                             │  │                             │ │
│  └─────────────────────────────┘  └─────────────────────────────┘ │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

## Tech Stack

| Component | Technology |
|-----------|------------|
| Language | TypeScript |
| Runtime | Bun |
| Linter/Formatter | Biome |
| Validation | Zod |
| MCP SDK | @modelcontextprotocol/sdk |
| OpenCode SDK | @opencode-ai/sdk |

## Comparison: oh-my-opencode vs oh-my-opencode-slim

| Feature | oh-my-opencode | oh-my-opencode-slim |
|---------|---------------|---------------------|
| Size | Full-featured | Lightweight |
| Agent Count | 10+ agents | 6 core agents |
| Skills System | Complex 5-tier | Streamlined |
| Hooks | 160+ hooks | Essential hooks only |
| Installation | Manual setup | Automated TUI installer |
| Model Selection | Static | Dynamic with external signals |
| Tmux Support | No | Yes |

## Quick Start

```bash
# Install via the automated installer
bunx oh-my-opencode-slim@latest install

# Authenticate with providers
opencode auth login

# Verify everything works
ping all agents
```

The installer automatically:
1. Detects available providers (Kimi, OpenAI, Anthropic, Copilot, etc.)
2. Discovers free and paid models
3. Fetches signals from Artificial Analysis and OpenRouter
4. Creates optimal agent-to-model mappings
5. Installs recommended skills
