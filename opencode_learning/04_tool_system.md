# Tool System Architecture

## Overview

The tool system is OpenCode's extensible mechanism for enabling agents to interact with the environment. Tools provide capabilities like file operations, code search, shell commands, and external API access.

**Location**: `packages/opencode/src/tool/`

## Tool Architecture

### Tool Definition

```typescript
export namespace Tool {
  export type Info = {
    id: string
    init: (ctx?: InitContext) => Promise<{
      parameters: z.ZodObject // Zod schema for validation
      description: string // What the tool does
      execute: ExecuteFn // Tool implementation
    }>
  }

  type InitContext = {
    agent?: Agent.Info // Current agent context
  }

  type ExecuteFn = (
    args: any, // Validated tool arguments
    ctx: ExecuteContext, // Execution context
  ) => Promise<Result>

  type ExecuteContext = {
    sessionID: string // Current session
    model?: { providerID; modelID } // LLM model info
  }

  type Result = {
    title: string // Short result summary
    output: string // Main output content
    metadata?: Record<string, any> // Additional metadata
  }
}
```

## Built-in Tools

### File Operation Tools

#### 1. Read Tool (`read`)

```typescript
// Read file contents
{
  filePath: string,        // Absolute path
  offset?: number,         // Line offset (0-based)
  limit?: number,          // Max lines (default 2000)
}

// Returns: File contents with line numbers
```

**Purpose**: Read file contents safely with truncation
**Restrictions**: Respects permission rules (e.g., deny .env files)
**Truncation**: Long lines (>2000 chars) truncated automatically

#### 2. Edit Tool (`edit`)

```typescript
// Edit file via string replacement
{
  filePath: string,
  oldString: string,       // Exact string to replace
  newString: string,       // Replacement string
  replaceAll?: boolean,    // Replace all occurrences
}
```

**Purpose**: Precise file edits with exact string matching
**Safety**: Fails if oldString not found or ambiguous
**Validation**: Must read file first before editing

#### 3. Write Tool (`write`)

```typescript
// Write entire file contents
{
  filePath: string,
  content: string,
}
```

**Purpose**: Create new files or overwrite existing
**Safety**: Requires read first for existing files
**Use Case**: New files, complete rewrites

#### 4. Glob Tool (`glob`)

```typescript
// Find files by pattern
{
  pattern: string,         // Glob pattern (e.g., "**/*.ts")
  path?: string,           // Search directory
}

// Returns: List of matching file paths
```

**Purpose**: Fast file discovery by name pattern
**Performance**: 60s timeout, 100 file limit
**Sorting**: Results sorted by modification time

#### 5. Grep Tool (`grep`)

```typescript
// Search file contents
{
  pattern: string,         // Regex pattern
  path?: string,           // Search directory
  include?: string,        // File pattern filter
}

// Returns: Matches with context
```

**Purpose**: Content search using regular expressions
**Performance**: 60s timeout, 10MB output limit
**Features**: Full regex support, file filtering

### Execution Tools

#### 6. Bash Tool (`bash`)

```typescript
// Execute shell command
{
  command: string,
  workdir?: string,        // Working directory
  timeout?: number,        // Milliseconds (default 120s)
}
```

**Purpose**: Run shell commands, git operations, builds
**Safety**: Permission-controlled, timeout protection
**Quoting**: Auto-handles paths with spaces
**Restrictions**: Cannot use cd (use workdir instead)

### Agent Orchestration Tools

#### 7. Task Tool (`task`)

```typescript
// Spawn subagent
{
  agent: string,           // Agent type
  prompt: string,          // Task description
  description: string,     // Short summary (5 words)
  session_id?: string,     // Continue existing session
}
```

**Purpose**: Delegate work to specialized subagents
**Agents**: explore, librarian, oracle, general, etc.
**State**: Stateless unless session_id provided
**Return**: Single message with results

#### 8. Background Task Tool (`background_task`)

```typescript
// Async subagent execution
{
  agent: string,
  prompt: string,
  description: string,
}

// Returns: task_id for later retrieval
```

**Purpose**: Parallel agent execution
**Use Case**: Multiple searches, long-running research
**Retrieval**: Use `background_output(task_id)`

### Web Tools

#### 9. WebFetch Tool (`webfetch`)

```typescript
// Fetch web content
{
  url: string,
  format?: "markdown" | "text" | "html",
  timeout?: number,
}
```

**Purpose**: Fetch and convert web pages
**Conversion**: HTML → Markdown by default
**Safety**: HTTPS enforcement, timeout protection

#### 10. WebSearch Tool (`websearch`)

```typescript
// Search web via Exa AI
{
  query: string,
  numResults?: number,
  type?: "auto" | "fast" | "deep",
}
```

**Purpose**: Real-time web search with content extraction
**Provider**: Exa AI (requires opencode provider or flag)
**Availability**: Zen users or OPENCODE_ENABLE_EXA=1

#### 11. CodeSearch Tool (`codesearch`)

```typescript
// Search GitHub repositories
{
  query: string,           // Literal code pattern
  language?: string[],     // Filter by language
  repo?: string,           // Filter by repository
  path?: string,           // Filter by file path
  useRegexp?: boolean,
}
```

**Purpose**: Find real-world code examples from GitHub
**Database**: 1M+ public repositories
**Search Type**: Literal code patterns (not keywords)
**Availability**: Zen users or OPENCODE_ENABLE_EXA=1

### State Management Tools

#### 12. TodoWrite Tool (`todowrite`)

```typescript
// Update todo list
{
  todos: Array<{
    id: string
    content: string
    status: "pending" | "in_progress" | "completed" | "cancelled"
    priority: "high" | "medium" | "low"
  }>
}
```

**Purpose**: Track multi-step task progress
**Visibility**: User sees real-time updates
**Rules**: Only one in_progress at a time

#### 13. TodoRead Tool (`todoread`)

```typescript
// Read current todo list
{
}

// Returns: Current todos with statuses
```

**Purpose**: Check current task list state
**Isolation**: Subagents cannot access parent todos

### LSP Tools

#### 14. LSP Tool Suite (`lsp_*`)

```typescript
// Hover information
lsp_hover(filePath, line, character)

// Go to definition
lsp_goto_definition(filePath, line, character)

// Find references
lsp_find_references(filePath, line, character, includeDeclaration)

// Document symbols
lsp_document_symbols(filePath)

// Workspace symbols
lsp_workspace_symbols(filePath, query, limit)

// Diagnostics
lsp_diagnostics(filePath, severity)

// Code actions
lsp_code_actions(filePath, startLine, startCharacter, endLine, endCharacter, kind)

// Rename
lsp_rename(filePath, line, character, newName)
```

**Purpose**: Language-aware code operations
**Availability**: Requires OPENCODE_EXPERIMENTAL_LSP_TOOL=1
**Safety**: Type-safe refactoring, semantic understanding

### Interactive Tools

#### 15. Question Tool (`question`)

```typescript
// Ask user for input
{
  question: string,        // Question to ask
  options?: string[],      // Optional: choice list
}
```

**Purpose**: Interactive user input during execution
**Availability**: CLI only (Flag.OPENCODE_CLIENT === "cli")
**Permission**: Configurable per agent

#### 16. Skill Tool (`skill`)

```typescript
// Load skill workflow
{
  name: string,            // Skill identifier
}
```

**Purpose**: Execute predefined workflows
**Location**: `.opencode/skill/` or `~/.opencode/skill/`
**Format**: Markdown files with embedded instructions

### Utility Tools

#### 17. Batch Tool (`batch`)

```typescript
// Execute multiple tool calls atomically
{
  tools: Array<{
    tool: string
    args: Record<string, any>
  }>
}
```

**Purpose**: Atomic multi-tool execution
**Availability**: Experimental (config.experimental.batch_tool)
**Use Case**: Related operations that must succeed/fail together

## Tool Registry

### Registry Structure

```typescript
export namespace ToolRegistry {
  // Load custom tools from config directories
  const state = Instance.state(async () => {
    const custom = [] as Tool.Info[]

    // Load from .opencode/tool/*.ts
    for (const dir of await Config.directories()) {
      for await (const match of glob.scan("tool/*.{js,ts}")) {
        const mod = await import(match)
        custom.push(fromPlugin(id, mod))
      }
    }

    // Load from plugins
    const plugins = await Plugin.list()
    for (const plugin of plugins) {
      for (const [id, def] of Object.entries(plugin.tool)) {
        custom.push(fromPlugin(id, def))
      }
    }

    return { custom }
  })

  // Get all tools for agent
  async function tools(providerID: string, agent?: Agent.Info) {
    const allTools = [...builtinTools, ...customTools]

    // Filter based on provider and flags
    return allTools.filter((t) => shouldInclude(t, providerID, agent))
  }
}
```

### Tool Registration

```typescript
// Register custom tool
await ToolRegistry.register({
  id: "my_custom_tool",
  init: async (ctx) => ({
    parameters: z.object({
      input: z.string(),
    }),
    description: "My custom tool",
    execute: async (args, ctx) => {
      // Implementation
      return {
        title: "Success",
        output: result,
      }
    },
  }),
})
```

## Custom Tools

### Via Config Directory

Create `.opencode/tool/my_tool.ts`:

```typescript
import { Tool } from "@opencode-ai/plugin"

export default Tool.define({
  args: {
    query: { type: "string", description: "Search query" },
  },
  description: "Custom search tool",
  execute: async (args, ctx) => {
    // Implementation
    const result = await customSearch(args.query)
    return result
  },
})
```

### Via Plugin

Create `opencode-plugin-example/index.ts`:

```typescript
import { definePlugin } from "@opencode-ai/plugin"

export default definePlugin({
  name: "example",
  tool: {
    custom_tool: {
      args: {
        /* ... */
      },
      description: "...",
      execute: async (args, ctx) => {
        // Implementation
      },
    },
  },
})
```

## Permission System

### Tool-Level Permissions

```toml
# .opencode/config.toml

[permission]
bash = "ask"              # Always ask before bash
read = { "*" = "allow", "*.env" = "deny" }
edit = { "*" = "allow" }
websearch = "allow"
```

### Agent-Level Tool Filtering

```typescript
// Explore agent: only search tools
{
  permission: {
    "*": "deny",           // Deny all by default
    grep: "allow",
    glob: "allow",
    read: "allow",
    bash: "allow",
  }
}
```

### Runtime Permission Check

```typescript
async function executeTool(tool: string, args: any, ctx: Context) {
  // Check permission
  const action = await Permission.check({
    permission: tool,
    pattern: args.filePath || "*",
    ruleset: effectivePermissions,
  })

  if (action === "deny") {
    throw new Error("Permission denied")
  }

  if (action === "ask") {
    const approved = await askUser(`Allow ${tool} on ${args.filePath}?`)
    if (!approved) throw new Error("User declined")
  }

  // Execute
  return await tool.execute(args, ctx)
}
```

## Output Truncation

### Truncation Strategy

```typescript
namespace Truncate {
  const LIMITS = {
    bash: { maxLines: 2000, maxBytes: 51200 },
    read: { maxLines: 2000, maxBytes: 51200 },
    grep: { maxBytes: 10485760 }, // 10MB
  }

  async function output(content: string, limits: Limits) {
    if (shouldTruncate(content, limits)) {
      // Write to external file
      const path = await writeToExternal(content)
      return {
        truncated: true,
        outputPath: path,
        content: makeTruncatedSummary(content, limits),
      }
    }

    return {
      truncated: false,
      content,
    }
  }
}
```

### External Output Directory

```
~/.opencode/truncate/
├── session_abc123/
│   ├── tool_bash_001.txt
│   ├── tool_read_002.txt
│   └── ...
```

**Benefits**:

- Keeps LLM context clean
- Full output available if needed
- Use `Read` tool with offset/limit to explore

## Tool Execution Flow

```
LLM requests tool
    │
    ▼
ToolRegistry.lookup(toolName)
    │
    ▼
Permission.check(tool, args, agent)
    │
    ├─> Denied ──> Return error
    ├─> Ask ────> Prompt user ──> Approved?
    └─> Allowed ─┘                   │
                                     ▼
Tool.execute(args, context)
    │
    ├─> Success ──> Truncate output ──> Return result
    └─> Error ────> Format error ─────> Return error
                                             │
                                             ▼
                                    Result to LLM
```

## Tool Best Practices

### For Tool Users (Agents)

1. **Read Before Edit**: Always read file before editing
2. **Specific Patterns**: Use precise patterns for grep/glob
3. **Error Handling**: Check tool results, handle failures
4. **Truncation Awareness**: Know when output may be truncated
5. **Permission Respect**: Don't retry denied operations

### For Tool Developers

1. **Validate Input**: Use Zod schemas strictly
2. **Idempotent**: Tools should be safe to retry
3. **Descriptive Errors**: Return helpful error messages
4. **Timeout Protection**: Long operations need timeouts
5. **Resource Cleanup**: Clean up temp files, connections
6. **Truncation**: Large outputs should use Truncate.output

### Security

1. **Path Validation**: Validate all file paths
2. **Command Injection**: Sanitize bash inputs
3. **Secret Protection**: Never log secrets
4. **Permission Checks**: Always check before execution
5. **Sandboxing**: Consider containerization for risky tools

## Testing Tools

```bash
# Test in development
bun dev

# Then use tool in conversation
> Use the grep tool to find "export function" in src/

# Unit test tools
bun test test/tool/read.test.ts

# Integration test
bun test test/integration/tool-flow.test.ts
```

## Tool Performance

| Tool       | Typical Speed | Bottleneck            |
| ---------- | ------------- | --------------------- |
| read       | <100ms        | Disk I/O              |
| edit       | <200ms        | Disk I/O + validation |
| write      | <100ms        | Disk I/O              |
| glob       | <500ms        | Filesystem traversal  |
| grep       | 1-5s          | Content scanning      |
| bash       | Varies        | Command execution     |
| task       | 5-30s         | LLM inference         |
| websearch  | 2-10s         | Network + API         |
| codesearch | 1-5s          | API call              |

## Tool Observability

### Logging

```typescript
// Tools automatically log:
{
  service: "tool.<tool_name>",
  duration: 1234,
  success: true,
  args: { /* sanitized */ },
  result: { /* truncated */ }
}

// View logs:
tail -f ~/.opencode/log/opencode.log
```

### Metrics

```typescript
// Tool execution metrics
{
  tool: "bash",
  count: 142,
  avgDuration: 856,
  errors: 3,
  timeouts: 1,
}
```

## Next Steps

- [05_mcp_integration.md](./05_mcp_integration.md) - External tool integration via MCP
- [02_agent_system.md](./02_agent_system.md) - How agents use tools
- [03_session_management.md](./03_session_management.md) - Tools within session context
