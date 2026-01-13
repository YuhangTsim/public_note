# OpenCode Architecture Overview

## What is OpenCode?

OpenCode is an **open-source AI coding agent** built to be:

- **Provider-agnostic**: Works with Claude, OpenAI, Google, local models, and more
- **Terminal-first**: Built by neovim users with a focus on TUI (Terminal User Interface)
- **Client/server architecture**: Enables remote access and multiple frontend options
- **LSP-integrated**: Out-of-the-box Language Server Protocol support

## Key Differentiators

1. **100% Open Source** - MIT licensed
2. **Not coupled to any provider** - Works with any LLM provider
3. **LSP Support** - First-class language server integration
4. **TUI Focus** - Built by terminal.shop creators, pushing terminal UI limits
5. **Client/Server Architecture** - Run on computer, drive from mobile app or web

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Clients                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │   CLI    │  │   TUI    │  │   Web    │  │ Desktop  │   │
│  │  (yargs) │  │(SolidJS) │  │(SolidJS) │  │ (Tauri)  │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
└───────┼─────────────┼─────────────┼─────────────┼──────────┘
        │             │             │             │
        └─────────────┴─────────────┴─────────────┘
                      │
        ┌─────────────▼─────────────────────────────────────┐
        │         OpenCode Server (Hono)                    │
        │         packages/opencode/src/server              │
        └─────────────┬─────────────────────────────────────┘
                      │
        ┌─────────────▼─────────────────────────────────────┐
        │              Core System                          │
        │                                                   │
        │  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
        │  │  Agent   │  │ Session  │  │  Tool    │       │
        │  │ System   │  │ Manager  │  │ Registry │       │
        │  └──────────┘  └──────────┘  └──────────┘       │
        │                                                   │
        │  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
        │  │   MCP    │  │   LSP    │  │ Provider │       │
        │  │Integration│ │ Support  │  │  Layer   │       │
        │  └──────────┘  └──────────┘  └──────────┘       │
        └───────────────────────────────────────────────────┘
                      │
        ┌─────────────▼─────────────────────────────────────┐
        │          External Integrations                    │
        │                                                   │
        │  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
        │  │   LLM    │  │   MCP    │  │  Git/    │       │
        │  │Providers │  │ Servers  │  │ GitHub   │       │
        │  └──────────┘  └──────────┘  └──────────┘       │
        └───────────────────────────────────────────────────┘
```

## Project Structure

```
opencode/
├── packages/
│   ├── opencode/          # Core business logic & server
│   │   ├── src/
│   │   │   ├── agent/     # Agent system
│   │   │   ├── session/   # Session management
│   │   │   ├── tool/      # Tool registry & implementations
│   │   │   ├── mcp/       # Model Context Protocol integration
│   │   │   ├── lsp/       # Language Server Protocol
│   │   │   ├── provider/  # LLM provider abstraction
│   │   │   ├── server/    # Hono HTTP server
│   │   │   ├── cli/       # CLI commands
│   │   │   │   └── cmd/tui/ # Terminal UI (SolidJS)
│   │   │   └── ...
│   │   └── bin/opencode   # Entry point
│   ├── app/               # Shared web UI components (SolidJS)
│   ├── desktop/           # Native desktop app (Tauri)
│   ├── sdk/js/            # TypeScript SDK for clients
│   ├── plugin/            # Plugin system (@opencode-ai/plugin)
│   └── util/              # Shared utilities
├── sdks/
│   └── vscode/            # VS Code extension
└── ...
```

## Technology Stack

- **Runtime**: Bun (TypeScript ESM modules)
- **Server**: Hono (lightweight HTTP framework)
- **TUI**: SolidJS + OpenTUI
- **Desktop**: Tauri (Rust + Web)
- **Web**: SolidJS + Vite
- **Validation**: Zod schemas
- **Terminal**: bun-pty for PTY management
- **AI SDK**: Vercel AI SDK (provider-agnostic)

## Core Concepts

### 1. Agents

- **Primary Agents**: `build` (full access), `plan` (read-only)
- **Subagents**: `general`, `explore`, `oracle`, `librarian`, etc.
- Each agent has configurable permissions, prompts, and models
- Defined in `src/agent/agent.ts`

### 2. Sessions

- Manages conversation state and context
- Stores messages, tool calls, and history
- Supports forking and compaction
- Parent-child session relationships

### 3. Tools

- Extensible tool system (bash, edit, read, grep, etc.)
- MCP server integration for external tools
- Plugin-based architecture
- Permission-based access control

### 4. Providers

- Abstraction layer for LLM providers
- Supports 15+ providers (Anthropic, OpenAI, Google, etc.)
- Provider-specific authentication and configuration
- Model capability detection

### 5. MCP (Model Context Protocol)

- Client implementation for MCP servers
- OAuth support for authenticated servers
- Tool, resource, and prompt integration
- Notification handling

### 6. LSP (Language Server Protocol)

- Integrated language server support
- Hover, definition, references, diagnostics
- Workspace symbols and code actions
- Rename support

## Data Flow

### Message Processing Flow

```
User Input
    │
    ▼
CLI/TUI/Web Client
    │
    ▼
HTTP Request (via SDK)
    │
    ▼
Server Endpoint (Hono)
    │
    ▼
Session.process()
    │
    ├─> Load Session State
    ├─> Build System Prompt
    ├─> Gather Tool Definitions
    ├─> Call LLM Provider
    │       │
    │       ▼
    │   Stream Response
    │       │
    │       ├─> Tool Calls?
    │       │   └─> Execute Tools
    │       │       └─> Return Results
    │       │           └─> Continue LLM
    │       │
    │       └─> Text Response
    │           └─> Return to Client
    │
    └─> Store in Session
```

### Tool Execution Flow

```
LLM requests tool
    │
    ▼
Tool Registry lookup
    │
    ▼
Permission check
    │
    ├─> Allowed? ──> Execute tool
    ├─> Denied? ──> Return error
    └─> Ask? ────> Prompt user
                       │
                       ▼
                   Execute if approved
```

## Installation & Development

### Install Dependencies

```bash
bun install
```

### Run Development Server

```bash
bun dev                    # Run in packages/opencode
bun dev <directory>        # Run against specific directory
bun dev .                  # Run in repo root
```

### Build Executable

```bash
./packages/opencode/script/build.ts --single
./packages/opencode/dist/opencode-<platform>/bin/opencode
```

### Run Tests

```bash
bun test                   # All tests
bun test test/tool/tool.test.ts  # Specific test
```

### Regenerate SDK

When modifying server endpoints:

```bash
./script/generate.ts
```

## Configuration

Configuration files in priority order:

1. `.opencode/config.toml` (project-level)
2. `~/.opencode/config.toml` (user-level)

Key configuration areas:

- Agent definitions
- Provider credentials
- Tool permissions
- MCP server configurations
- Custom prompts

## Next Steps

- [02_agent_system.md](./02_agent_system.md) - Deep dive into agent architecture
- [03_session_management.md](./03_session_management.md) - Session lifecycle and state
- [04_tool_system.md](./04_tool_system.md) - Tool registry and execution
- [05_mcp_integration.md](./05_mcp_integration.md) - Model Context Protocol
- [06_provider_layer.md](./06_provider_layer.md) - LLM provider abstraction
- [07_client_server.md](./07_client_server.md) - Client/server communication
