# 01: Roo-Code Overview

**Roo-Code Architecture & Core Concepts**

---

## What is Roo-Code?

Roo-Code is a **VSCode extension** that provides an AI-powered coding assistant with agentic capabilities. Unlike standalone CLI tools, Roo-Code integrates deeply with VSCode to provide:

- **Direct IDE Integration**: Webview panels, terminal control, diff views, file system access
- **Mode-Based Workflows**: Different AI personas for different tasks (Code, Architect, Ask, Debug, Orchestrator)
- **Skills System**: Extensible capabilities via filesystem-based skill definitions
- **Task Delegation**: Hierarchical task management with parent/child relationships
- **Dual-Protocol Support**: Both XML (legacy) and Native JSON tool calling
- **40+ LLM Providers**: Support for Anthropic, OpenAI, Gemini, DeepSeek, and many more

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     VSCode Extension                        │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              ClineProvider (Webview Bridge)          │  │
│  │  - Manages React frontend communication              │  │
│  │  - Handles postMessage protocol                      │  │
│  │  - Coordinates task state updates                    │  │
│  └─────────────────┬────────────────────────────────────┘  │
│                    │                                        │
│  ┌─────────────────▼────────────────────────────────────┐  │
│  │                 Task Orchestrator                    │  │
│  │  - Main agentic loop (recursivelyMakeClineRequests)  │  │
│  │  - Dual history management (UI + API)               │  │
│  │  - Tool execution & validation                       │  │
│  │  - Context management & condensation                 │  │
│  └─────────────────┬────────────────────────────────────┘  │
│                    │                                        │
│  ┌─────────────────▼────────────────────────────────────┐  │
│  │            Protocol Layer                            │  │
│  │  ┌──────────────────┬──────────────────────────┐    │  │
│  │  │  XML Protocol    │  Native Protocol         │    │  │
│  │  │  (Legacy)        │  (Current Standard)      │    │  │
│  │  └──────────────────┴──────────────────────────┘    │  │
│  └─────────────────┬────────────────────────────────────┘  │
│                    │                                        │
│  ┌─────────────────▼────────────────────────────────────┐  │
│  │              ApiHandler Interface                    │  │
│  │  - Unified abstraction for 40+ providers            │  │
│  │  - Streaming via ApiStream                          │  │
│  │  - Format conversions (Anthropic ↔ OpenAI ↔ Gemini) │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Core Components

### 1. Task System (`src/core/task/Task.ts`)

The **Task** class is the heart of Roo-Code. Each conversation is a "task" with:

- **Unique Identifiers**: `taskId`, `instanceId`, `rootTaskId`, `parentTaskId`
- **Dual History**: Maintains both UI messages (for display) and API messages (for LLM)
- **Agentic Loop**: `recursivelyMakeClineRequests()` - the main execution loop
- **State Management**: Mode, tools, todos, checkpoints, context window

**Key Characteristics**:
- Tasks can delegate to child tasks (via `new_task` tool)
- Tasks persist to disk and can be resumed
- Tasks maintain their own conversation history
- Tasks can be interrupted, paused, or abandoned

### 2. Dual History System (`src/core/task-persistence/`)

Roo-Code maintains **two separate message histories**:

| History Type | File | Format | Purpose |
|--------------|------|--------|---------|
| **UI Messages** | `ui_messages.json` | `ClineMessage[]` | Frontend display, user interaction |
| **API Messages** | `api_conversation_history.json` | `ApiMessage[]` | LLM context (Anthropic format) |

**Why Two Histories?**
- UI needs rich metadata (timestamps, approval states, partial content)
- API needs clean, standardized format for LLM consumption
- Allows independent evolution of UI and API concerns

**Synchronization**:
- Managed by `MessageManager` (`src/core/message-manager/index.ts`)
- Ensures consistency when rewinding, truncating, or condensing
- Critical for checkpoint restoration and history replay

### 3. Mode System (`src/shared/modes.ts`)

Modes tailor the AI's behavior and tool access for specific workflows:

| Mode | Purpose | Tool Groups | File Restrictions |
|------|---------|-------------|-------------------|
| **Code** | Implementation | `read`, `edit`, `command`, `browser`, `mcp`, `modes` | None |
| **Architect** | Planning & design | `read`, `modes` | Can only edit `.md` files |
| **Ask** | Q&A, explanations | `read`, `modes` | No edit tools |
| **Debug** | Issue diagnosis | `read`, `command`, `modes` | Read-only + command execution |
| **Orchestrator** | Multi-task coordination | All + task delegation | None |
| **Custom** | User-defined | Configurable | Configurable |

**Mode Switching**:
- Use `switch_mode` tool to change mode mid-conversation
- Mode persists with task history
- Custom modes defined via `CustomModesManager` (`src/core/config/CustomModesManager.ts`)

### 4. Skills System (`src/services/skills/SkillsManager.ts`)

Skills are **filesystem-based capability extensions** following the [Agent Skills specification](https://agentskills.io/):

```
~/.roo/skills/                    # Global skills
  └── my-skill/
      └── SKILL.md                # Skill definition

.roo/skills/                      # Project skills (override global)
  └── project-specific-skill/
      └── SKILL.md
```

**Mandatory Precondition Check**:
- Before every response, the model MUST evaluate if a skill applies
- If a match is found, model MUST use `read_file` to load the skill
- Skills inject specialized instructions dynamically

**Example**: A "React Testing" skill would inject test-writing patterns only when relevant.

### 5. Tool System (`src/core/tools/`)

Tools are **actions the AI can take**. Each tool inherits from `BaseTool`:

**Tool Categories**:
- **Read**: `read_file`, `list_files`, `search_files`, `codebase_search`
- **Edit**: `write_to_file`, `search_and_replace`, `apply_diff`, `edit_file`
- **Command**: `execute_command`
- **Browser**: `browser_action`
- **MCP**: Dynamic tools from MCP servers
- **Meta**: `switch_mode`, `new_task`, `attempt_completion`

**Validation Flow** (`src/core/tools/validateToolUse.ts`):
1. Check if tool exists
2. Check if tool is allowed in current mode
3. Check file path restrictions (if applicable)
4. Validate parameters
5. Execute or request user approval

---

## Key Differences from Other AI Coding Assistants

### vs. Cursor/GitHub Copilot
| Feature | Roo-Code | Cursor/Copilot |
|---------|----------|----------------|
| Architecture | Agentic (multi-step reasoning) | Completion-based (single-shot) |
| Tool Access | Full file system, terminal, browser | Limited to editor context |
| Task Delegation | Hierarchical task trees | No delegation |
| Modes | 5 built-in + custom | Single mode |

### vs. Aider/Continue
| Feature | Roo-Code | Aider/Continue |
|---------|----------|----------------|
| Platform | VSCode extension | CLI/Editor plugin |
| UI | Rich webview panels | Terminal/sidebar |
| History | Dual (UI + API) | Single history |
| Checkpoints | Full workspace snapshots | Git-based only |

### vs. OpenCode (Cline ancestor)
| Feature | Roo-Code | OpenCode |
|---------|----------|----------|
| Persistence | Task-based | Session-based |
| Skills | Filesystem (agentskills.io) | Built-in only |
| Modes | 5 + custom | Fixed modes |
| Marketplace | Extension marketplace | N/A |

---

## The Agentic Loop

Roo-Code's core execution is a **recursive turn-based loop**:

```typescript
// Simplified pseudocode
async function recursivelyMakeClineRequests() {
  while (true) {
    // 1. Build API request with system prompt + conversation history
    const systemPrompt = await generateSystemPrompt(mode, skills, ...)
    const apiMessages = getEffectiveApiHistory()
    
    // 2. Stream LLM response
    const stream = apiHandler.createMessage(systemPrompt, apiMessages, { tools })
    
    // 3. Parse streaming chunks (text + tool calls)
    for await (const chunk of stream) {
      if (chunk.type === 'text') {
        // Display to user incrementally
      } else if (chunk.type === 'tool_call_start') {
        // Begin tool execution
      }
    }
    
    // 4. Execute tool calls (with user approval if needed)
    const toolResults = await executeToolCalls(toolCalls)
    
    // 5. If attempt_completion, exit loop. Otherwise, continue.
    if (toolCalls.some(call => call.name === 'attempt_completion')) {
      await handleCompletion()
      break
    }
    
    // 6. Add tool results to history and recurse
    apiMessages.push({ role: 'user', content: toolResults })
  }
}
```

**Key Points**:
- Each turn adds to the conversation history
- Context window managed via condensation/truncation
- Loop continues until `attempt_completion` tool is called and approved
- User can interrupt, provide feedback, or abort at any time

---

## File System Organization

```
src/
├── core/                       # Core agentic logic
│   ├── task/                   # Task orchestration
│   ├── prompts/                # System prompt generation
│   ├── tools/                  # Tool implementations
│   ├── assistant-message/      # Message parsing (XML + Native)
│   ├── context-management/     # Context window handling
│   ├── webview/                # VSCode webview integration
│   └── ...
├── api/                        # LLM provider abstraction
│   ├── index.ts                # ApiHandler interface
│   ├── providers/              # 40+ provider implementations
│   └── transform/              # Format conversions
├── services/                   # Supporting services
│   ├── skills/                 # Skills system
│   ├── mcp/                    # MCP integration
│   ├── browser/                # Browser automation
│   └── ...
├── shared/                     # Shared types and utilities
│   ├── modes.ts                # Mode definitions
│   ├── tools.ts                # Tool types
│   └── ...
└── integrations/               # VSCode integrations
    ├── terminal/               # Terminal management
    ├── editor/                 # Diff views
    └── ...

packages/
├── types/                      # Shared TypeScript types
│   └── src/mode.ts             # Mode and tool group types
└── core/                       # Shared core utilities
```

---

## Protocol Transition: XML → Native

Roo-Code supports **two tool calling protocols**:

### XML Protocol (Legacy)
- Tools described in system prompt as XML tags
- Model outputs: `<read_file><path>file.ts</path></read_file>`
- Parsed via `AssistantMessageParser.ts`
- **Still supported** for resumed tasks from older versions

### Native Protocol (Current Standard)
- Tools passed as separate JSON schema in API request
- Model outputs: `{ tool_calls: [{ id: "...", function: { name: "read_file", arguments: "{...}" } }] }`
- Parsed via `NativeToolCallParser.ts`
- **Benefits**: 2000-5000 token savings, better type safety, native provider support

**Protocol Detection**:
```typescript
// If tool_use block has an 'id' field → Native protocol
// If no 'id' field → XML protocol
const isNative = block.id !== undefined
```

---

## Next Steps

Now that you understand Roo-Code's high-level architecture, explore these topics:

- **[02: Mode System](./02_mode_system.md)** - Deep dive into modes and tool groups
- **[03: Task Lifecycle](./03_task_lifecycle.md)** - How tasks are created, executed, and completed
- **[04: Tool System](./04_tool_system.md)** - Tool validation, execution, and error handling
- **[05: Dual History](./05_dual_history.md)** - UI vs API messages with concrete examples
- **[06: Skills System](./06_skills_system.md)** - How skills extend Roo-Code's capabilities

---

## Key Source Files

| Component | File Path | Purpose |
|-----------|-----------|---------|
| Task Orchestrator | `src/core/task/Task.ts` | Main agentic loop |
| System Prompt | `src/core/prompts/system.ts` | Prompt assembly |
| Native Parser | `src/core/assistant-message/NativeToolCallParser.ts` | JSON tool parsing |
| XML Parser | `src/core/assistant-message/AssistantMessageParser.ts` | XML tool parsing |
| Tool Execution | `src/core/assistant-message/presentAssistantMessage.ts` | Tool executor |
| Mode Definitions | `src/shared/modes.ts`, `packages/types/src/mode.ts` | Mode configs |
| Skills Manager | `src/services/skills/SkillsManager.ts` | Skills discovery |
| Dual History | `src/core/task-persistence/taskMessages.ts`, `apiMessages.ts` | Persistence |

---

**Version**: Roo-Code v3.39+ (January 2026)
**Based on**: Comprehensive codebase analysis of latest main branch
