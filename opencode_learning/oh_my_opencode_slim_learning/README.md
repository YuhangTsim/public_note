# Oh My OpenCode Slim Research Notes

This directory contains in-depth research notes on the **oh-my-opencode-slim** project, a lightweight agent orchestration plugin for OpenCode.

## Contents

1.  **[01_Overview](01_overview.md)**: Project philosophy, key features, and differences from the original Oh My OpenCode.
2.  **[02_Architecture and Agents](02_architecture_and_agents.md)**: Deep dive into The Pantheon (the 6 specialized agents) and the system's modular architecture.
3.  **[03_Installation and Configuration](03_installation_and_config.md)**: Guide to the CLI installer, model providers, and configuration options.
4.  **[04_Features and Workflows](04_features_and_workflows.md)**: Exploration of parallel execution, tmux integration, and the autonomous task completion loop.

## Quick Reference: The Pantheon

| Agent | Role | Key Tool |
|-------|------|----------|
| **Orchestrator** | Master Delegator | Background Task Manager |
| **Explorer** | Codebase Recon | Glob, Grep, AST-Grep |
| **Oracle** | Strategic Advisor | High-IQ Reasoning |
| **Librarian** | Knowledge Retrieval | Documentation MCPs |
| **Designer** | UI/UX Specialist | Visual Polish |
| **Fixer** | Fast Implementation | Parallel Execution |

## Key Commands

- **Install**: `bunx oh-my-opencode-slim@latest install`
- **Update Models**: `bunx oh-my-opencode-slim models`
- **Verify**: `ping all agents`
- **Build**: `bun run build`
- **Check**: `bun run check`

## Project Links
- **Repository**: [github.com/alvinunreal/oh-my-opencode-slim](https://github.com/alvinunreal/oh-my-opencode-slim)
- **Base Project**: [github.com/code-yeongyu/oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode)
