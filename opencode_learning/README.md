# OpenCode Learning Guide

This directory contains comprehensive documentation on OpenCode's architecture and design.

## Documentation Structure

### Core Architecture

1. **[01_overview.md](./01_overview.md)** - High-level architecture and project structure
   - What OpenCode is and how it differs from alternatives
   - Technology stack and project organization
   - Data flow and core concepts
   - Installation and development setup

2. **[02_agent_system.md](./02_agent_system.md)** - Agent system architecture
   - Built-in agents (build, plan, explore, oracle, librarian)
   - Agent types and lifecycle
   - Permission system
   - Custom agent creation
   - Agent orchestration patterns

3. **[03_session_management.md](./03_session_management.md)** - Session lifecycle and state
   - Session creation, forking, and deletion
   - Message storage and history
   - Parent-child relationships
   - Snapshot and diff system
   - Session compaction strategy

4. **[04_tool_system.md](./04_tool_system.md)** - Tool registry and execution
   - Built-in tools (read, edit, bash, grep, etc.)
   - Tool execution flow and permissions
   - Custom tool development
   - Output truncation
   - LSP tools integration

5. **[05_mcp_integration.md](./05_mcp_integration.md)** - Model Context Protocol
   - MCP client implementation
   - Tool, resource, and prompt integration
   - OAuth authentication
   - Custom MCP server development
   - Performance considerations

6. **[06_prompt_design.md](./06_prompt_design.md)** - Prompt design and system architecture
   - System prompt structure and assembly
   - Provider-specific headers
   - Core agent prompts (build, plan, explore)
   - Dynamic context generation
   - Prompt optimization strategies

7. **[07_opencode_vs_oh_my_opencode.md](./07_opencode_vs_oh_my_opencode.md)** - OpenCode vs Oh-My-OpenCode comparison
   - Architecture comparison (base vs enhanced)
   - Agent differences (4 agents vs 7+ specialized agents)
   - Tool enhancements (LSP, AST-grep, background tasks, sessions)
   - MCP configuration (user vs curated)
   - Hook system (basic vs extensive)
   - Workflow patterns (sequential vs parallel orchestrated)

8. **[08_prompt_examples.md](./08_prompt_examples.md)** - Complete system prompt examples
   - Prompt assembly flow (6-layer construction)
   - Full OpenCode base prompt example
   - Full Oh-My-OpenCode Sisyphus prompt example
   - Key differences between base and OMO prompts
   - Provider-specific variations
   - Dynamic component injection

9. **[09_task_completion_detection.md](./09_task_completion_detection.md)** - Task completion and finish logic
   - LLM finish reasons (stop, tool-calls, length, error)
   - Streaming architecture (event types and processing)
   - Message lifecycle (start → stream → decision → completion)
   - Decision logic (continue vs stop vs compact)
   - Session status management (idle, busy, retry)
   - Oh-My-OpenCode TODO continuation enforcer
   - Complete flow diagrams

10. **[10_todo_system.md](./10_todo_system.md)** - TODO tracking and completion enforcement
    - TODO schema and data model
    - Tool definitions (todowrite, todoread)
    - Storage and persistence mechanism
    - Permission system
    - Event bus integration
    - Prompt instructions for LLM usage
    - Oh-My-OpenCode mandatory completion enforcement
    - TODO lifecycle and workflow examples

### Implementation Deep Dives

11. **[11_tool_calling_system.md](./11_tool_calling_system.md)** - Tool calling architecture
    - Zod schema definitions
    - Vercel AI SDK integration
    - Tool execution pipeline
    - Type-safe tool development

12. **[12_conversation_history.md](./12_conversation_history.md)** - Conversation flow
    - Message formats and structure
    - History management
    - Context window handling
    - Message compaction

13. **[13_direct_api_calls.md](./13_direct_api_calls.md)** - Direct API examples
    - Raw Python SDK examples
    - OpenAI, Anthropic, Gemini integration
    - Manual tool calling patterns

14. **[14_subagent_system.md](./14_subagent_system.md)** - Subagent orchestration
    - Task tool implementation
    - Parent-child session architecture
    - Permission isolation model
    - Built-in subagents (explore, oracle, librarian, general)
    - Stateful vs stateless execution
    - Real-time progress streaming
    - Result format and error handling
    - Oh-My-OpenCode parallel patterns

### Additional Topics (Coming Soon)

15. **15_provider_layer.md** - LLM provider abstraction
    - Provider architecture
    - Supported providers (15+)
    - Model selection and configuration
    - Authentication patterns

16. **16_client_server.md** - Client/server communication
    - HTTP API (Hono server)
    - SDK generation
    - WebSocket streaming
    - Multiple client types (CLI, TUI, Web, Desktop)

17. **17_tui_architecture.md** - Terminal UI implementation
    - SolidJS + OpenTUI architecture
    - Rendering strategy
    - State management
    - Terminal capabilities

18. **18_lsp_integration.md** - Language Server Protocol
    - LSP client implementation
    - Supported operations
    - Multi-language support
    - Type-safe refactoring

19. **19_plugin_system.md** - Plugin architecture
    - Plugin API
    - Custom tool development
    - Custom agent creation
    - Distribution and installation

## Quick Navigation by Role

### For Contributors

Start with:

1. [01_overview.md](./01_overview.md) - Understand the big picture
2. [04_tool_system.md](./04_tool_system.md) - Most common contribution area
3. [02_agent_system.md](./02_agent_system.md) - If working on agent behavior

### For Agent Developers

Start with:

1. [02_agent_system.md](./02_agent_system.md) - Agent system fundamentals
2. [04_tool_system.md](./04_tool_system.md) - Available tools
3. [03_session_management.md](./03_session_management.md) - Session context

### For Plugin Developers

Start with:

1. [04_tool_system.md](./04_tool_system.md) - Custom tools
2. [05_mcp_integration.md](./05_mcp_integration.md) - MCP servers
3. [11_plugin_system.md](./11_plugin_system.md) - Plugin API (coming soon)

### For Advanced Users

Start with:

1. [01_overview.md](./01_overview.md) - Architecture overview
2. [02_agent_system.md](./02_agent_system.md) - Customize agents
3. [06_prompt_design.md](./06_prompt_design.md) - Customize prompts
4. [05_mcp_integration.md](./05_mcp_integration.md) - Extend with MCP

## Key Concepts Summary

### Agents

Configurable AI entities with specific permissions, prompts, and capabilities:

- **Primary agents**: User-facing (build, plan)
- **Subagents**: Specialized helpers (explore, oracle, librarian)
- **Custom agents**: User-defined via config

### Sessions

Conversation state management:

- Message history and tool calls
- Parent-child relationships
- Snapshots and diffs
- Compaction for long conversations

### Tools

Extensible capability system:

- Built-in tools (file ops, shell, search)
- MCP tools (external integrations)
- Custom tools (user-defined)
- Permission-based access control

### MCP (Model Context Protocol)

Standard protocol for external context:

- Tools from external servers
- Resources (files, APIs, databases)
- OAuth authentication
- Hot-reload capabilities

### Providers

LLM provider abstraction:

- 15+ supported providers
- Unified API via Vercel AI SDK
- Model capability detection
- Authentication management

## Development Workflow

```bash
# 1. Install dependencies
bun install

# 2. Run development server
bun dev

# 3. Make changes to code

# 4. Test changes
bun test

# 5. Build executable (optional)
./packages/opencode/script/build.ts --single
```

## Architecture Principles

1. **Provider Agnostic**: Not coupled to any specific LLM provider
2. **Extensible**: Plugin system, custom tools, MCP integration
3. **Permission-Based**: Fine-grained access control
4. **Client/Server**: Run anywhere, access from anywhere
5. **Terminal First**: Built for power users
6. **Type Safe**: TypeScript throughout, Zod validation

## Technology Stack Summary

- **Runtime**: Bun (fast JavaScript runtime)
- **Language**: TypeScript (type safety)
- **Server**: Hono (lightweight HTTP)
- **UI**: SolidJS (reactive framework)
- **Desktop**: Tauri (Rust + Web)
- **Validation**: Zod (schema validation)
- **AI SDK**: Vercel AI SDK (provider abstraction)
- **Terminal**: bun-pty (PTY management)

## Getting Help

- **GitHub Issues**: https://github.com/anomalyco/opencode/issues
- **Discord**: https://opencode.ai/discord
- **Documentation**: https://opencode.ai/docs
- **Contributing Guide**: [../CONTRIBUTING.md](../CONTRIBUTING.md)

## Contributing to Documentation

Found an error or want to improve these docs?

1. Fork the repository
2. Edit files in `opencode_learning/`
3. Submit a pull request

Keep documentation:

- **Accurate**: Reflects current codebase
- **Clear**: Easy to understand
- **Comprehensive**: Covers edge cases
- **Examples**: Show practical usage

## Next Steps

- Read [01_overview.md](./01_overview.md) for the big picture
- Explore specific topics based on your needs
- Try developing a custom tool or agent
- Join the community and ask questions
