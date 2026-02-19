# Oh My OpenCode Overview

**Oh My OpenCode** (OMO) is a "battery-included," highly opinionated configuration and enhancement suite for OpenCode. If OpenCode is the bare-metal engine, Oh My OpenCode is the luxury sports car built on top of it. It redefines the agent experience by introducing **Sisyphus**, a relentless orchestrator agent.

## Core Philosophy

> "If OpenCode is Debian/Arch, Oh My OpenCode is Ubuntu."

OMO aims to provide a zero-configuration, high-performance agent experience out of the box. It focuses on:
- **Orchestration**: Automatically delegating tasks to specialized sub-agents.
- **Persistence**: "Todo Continuation Enforcer" ensures tasks are completed, not just attempted.
- **Quality**: Enforcing coding standards (like "no AI slop" comments) and utilizing LSP/AST tools.

## Key Features

### 1. Sisyphus: The Orchestrator
Sisyphus is the primary identity of the agent. Unlike a generic coding assistant, Sisyphus is designed to:
- **Delegate first**: Recognize when a task requires a specialist (e.g., UI design, deep debugging) and call them immediately.
- **Manage Context**: Keep its own context lean by offloading research to background agents.
- **Roll the Boulder**: Work relentlessly until the task is done, driven by the "Ultrawork" workflow.

### 2. Specialized Team (Sub-Agents)
Sisyphus comes with a pre-assembled team:
- **Oracle**: High-IQ reasoning agent (often GPT-5 class) for architecture and debugging.
- **Librarian**: Research agent for external documentation and GitHub examples.
- **Explore**: Fast codebase "contextual grep" agent.
- **Frontend UI/UX**: Specialized design agent.

### 3. "Ultrawork" Mode
Triggered by the keyword `ultrawork` (or `ulw`), this mode engages the full autonomous loop:
1.  Analyze structure.
2.  Gather context via background agents.
3.  Execute relentlessly until the TODO list is clear.

### 4. Claude Code Compatibility
OMO includes a compatibility layer for Claude Code features, including:
- Command structure compatibility.
- Hook system (PreToolUse, PostToolUse, etc.).
- MCP integration.

## Installation & Structure

OMO is typically installed as a plugin or configuration set on top of OpenCode. It leverages OpenCode's extensibility (custom agents, prompt files like `AGENTS.md`) to inject its behaviors.

### Directory Structure
- `AGENTS.md`: Defines the Sisyphus persona and rules.
- `sisyphus-prompt.md`: The raw system prompt source.
- `packages/`: Custom extensions and tools.
- `src/`: Source code for custom behaviors.
