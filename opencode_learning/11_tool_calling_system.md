# Tool Calling System Architecture

## Overview

OpenCode implements a sophisticated tool calling system that bridges Zod-based type-safe tool definitions with the Vercel AI SDK's tool execution model. The system features:

- **Type-safe definitions** using Zod schemas
- **Permission-based access control** with user-in-the-loop approval
- **Streaming state management** for real-time UI updates
- **Automatic output truncation** to prevent context overflow
- **Doom loop detection** to prevent infinite tool call cycles

**Key Files**:

- `packages/opencode/src/tool/tool.ts` - Tool definition interface
- `packages/opencode/src/tool/registry.ts` - Tool discovery and registration
- `packages/opencode/src/session/prompt.ts` - AI SDK integration
- `packages/opencode/src/session/processor.ts` - Tool execution orchestration
- `packages/opencode/src/session/message-v2.ts` - Message and tool part schemas

## Tool Definition Schema

### Basic Tool Structure

Tools are defined using the `Tool.define` helper which enforces a specific schema:

```typescript
// packages/opencode/src/tool/tool.ts

export namespace Tool {
  export type Info = {
    id: string
    init: (ctx?: InitContext) => Promise<{
      parameters: z.ZodObject // Zod schema for validation
      description: string // What the tool does
      execute: ExecuteFn // Tool implementation
    }>
  }

  export type InitContext = {
    agent?: Agent.Info // Current agent context
  }

  export type ExecuteFn = (
    args: any, // Validated tool arguments
    ctx: ExecuteContext, // Execution context
  ) => Promise<Result>

  export type ExecuteContext = {
    sessionID: string // Current session
    model?: { providerID; modelID } // LLM model info
    ask: (params) => Promise<void> // Request permission
    metadata: (data) => Promise<void> // Push progress updates
  }

  export type Result = {
    title: string // Short result summary
    output: string // Main output content
    metadata?: Record<string, any> // Additional metadata
    attachments?: FilePart[] // File attachments
  }
}
```

### Example: Bash Tool

```typescript
// packages/opencode/src/tool/bash.ts

export const BashTool = Tool.define("bash", async () => {
  return {
    description: "Execute bash commands",
    parameters: z.object({
      command: z.string().describe("The command to execute"),
      timeout: z.number().optional().describe("Timeout in milliseconds"),
      workdir: z.string().optional().describe("Working directory"),
      description: z.string().describe("Clear description of what this command does"),
    }),

    async execute(params, ctx) {
      // Permission check
      await ctx.ask({
        permission: "bash",
        patterns: [params.command],
      })

      // Execute command
      const result = await execCommand(params.command, {
        cwd: params.workdir,
        timeout: params.timeout,
      })

      return {
        title: `Executed: ${params.description}`,
        output: result.stdout + result.stderr,
        metadata: {
          exitCode: result.exitCode,
          duration: result.duration,
        },
      }
    },
  }
})
```

## Tool Registration Flow

### 1. Discovery Phase

The `ToolRegistry` discovers tools from multiple sources:

```typescript
// packages/opencode/src/tool/registry.ts

export const state = Instance.state(async () => {
  const custom = [] as Tool.Info[]

  // 1. Scan .opencode/tool/*.{js,ts}
  for (const dir of await Config.directories()) {
    for await (const match of glob.scan("tool/*.{js,ts}")) {
      const namespace = path.basename(match, path.extname(match))
      const mod = await import(match)
      for (const [id, def] of Object.entries(mod)) {
        custom.push(fromPlugin(id === "default" ? namespace : `${namespace}_${id}`, def))
      }
    }
  }

  // 2. Load from plugins
  const plugins = await Plugin.list()
  for (const plugin of plugins) {
    for (const [id, def] of Object.entries(plugin.tool ?? {})) {
      custom.push(fromPlugin(id, def))
    }
  }

  return { custom }
})
```

### 2. Tool Listing

Built-in and custom tools are combined:

```typescript
async function all(): Promise<Tool.Info[]> {
  const custom = await state().then((x) => x.custom)
  const config = await Config.get()

  return [
    InvalidTool,
    QuestionTool,
    BashTool,
    ReadTool,
    GlobTool,
    GrepTool,
    EditTool,
    WriteTool,
    TaskTool,
    WebFetchTool,
    TodoWriteTool,
    TodoReadTool,
    WebSearchTool,
    CodeSearchTool,
    SkillTool,
    LspTool, // if experimental flag enabled
    BatchTool, // if experimental.batch_tool enabled
    ...custom,
  ]
}
```

## AI SDK Integration

### Converting to AI SDK Format

Tools are converted to Vercel AI SDK format in `resolveTools`:

```typescript
// packages/opencode/src/session/prompt.ts

async function resolveTools(input: LLM.StreamInput) {
  const tools: Record<string, AiTool> = {}
  const registry = await ToolRegistry.tools(input.model.providerID, input.agent)

  for (const item of registry) {
    // Skip if disabled by permissions
    if (PermissionNext.disabled(item.id, input.agent.permission)) {
      continue
    }

    // Convert to AI SDK tool
    tools[item.id] = tool({
      id: item.id,
      description: item.description,

      // Convert Zod schema to JSON Schema
      inputSchema: jsonSchema(ProviderTransform.schema(input.model, z.toJSONSchema(item.parameters))),

      // Wrap execution
      async execute(args, options) {
        const ctx = createContext(args, options, input)
        const result = await item.execute(args, ctx)

        // Truncate if needed
        const truncated = await Truncate.output(result.output, {}, input.agent)

        return {
          title: result.title,
          output: truncated.truncated ? truncated.content : result.output,
          metadata: {
            ...result.metadata,
            truncated: truncated.truncated,
            outputPath: truncated.outputPath,
          },
          attachments: result.attachments,
        }
      },
    })
  }

  return tools
}
```

### Passing to LLM

```typescript
// packages/opencode/src/session/llm.ts

export async function stream(input: StreamInput) {
  const tools = await resolveTools(input)

  return streamText({
    model: language,
    system: systemPrompt,
    messages: input.messages,
    tools, // Tools available to the model
    maxSteps: input.agent.steps ?? 100,
    onError(error) {
      /* ... */
    },
    // ... other options
  })
}
```

## Message Format and Tool Parts

### Tool Part Schema

Tool calls are stored as `ToolPart` in the message:

```typescript
// packages/opencode/src/session/message-v2.ts

export const ToolPart = PartBase.extend({
  type: z.literal("tool"),
  callID: z.string(), // Unique call ID from LLM
  tool: z.string(), // Tool name
  state: ToolState, // Current state
  metadata: z.record(z.string(), z.any()).optional(),
})

// Tool states
export const ToolState = z.discriminatedUnion("status", [
  ToolStatePending, // Input being streamed
  ToolStateRunning, // Execution in progress
  ToolStateCompleted, // Successfully completed
  ToolStateError, // Execution failed
])
```

### State Transitions

```typescript
// Pending -> Running -> Completed/Error

// 1. PENDING: LLM starts streaming tool input
{
  status: "pending",
  input: {},           // Being accumulated
  raw: "",            // Raw JSON string
}

// 2. RUNNING: Execution started
{
  status: "running",
  input: { command: "ls -la" },
  title: "Listing directory",
  time: { start: 1736708258000 },
}

// 3. COMPLETED: Execution finished
{
  status: "completed",
  input: { command: "ls -la" },
  output: "total 48\ndrwxr-xr-x ...",
  title: "Listed directory contents",
  metadata: { exitCode: 0 },
  time: { start: 1736708258000, end: 1736708259500 },
  attachments: [],
}

// 3. ERROR: Execution failed
{
  status: "error",
  input: { command: "invalid-command" },
  error: "Command not found: invalid-command",
  time: { start: 1736708258000, end: 1736708258100 },
}
```

## Tool Execution Flow

### Complete Execution Lifecycle

```
1. LLM generates tool call
    │
    ▼
2. AI SDK receives tool call
    │
    ▼
3. SessionProcessor intercepts "tool-call" event
    │
    ├─> Creates ToolPart with status "pending"
    ├─> Checks for doom loop (3+ identical calls)
    └─> Updates session database
    │
    ▼
4. AI SDK calls tool.execute()
    │
    ├─> Validates input with Zod schema
    ├─> Creates execution context
    └─> Calls tool's execute function
        │
        ├─> Tool checks permissions via ctx.ask()
        │   └─> If denied: throw error
        │       If ask: wait for user approval
        │       If allowed: continue
        │
        ├─> Tool executes logic
        ├─> Tool can call ctx.metadata() for progress
        └─> Tool returns result
    │
    ▼
5. Result wrapper applies truncation
    │
    ▼
6. SessionProcessor receives "tool-result" event
    │
    ├─> Updates ToolPart to status "completed"
    ├─> Stores output in database
    └─> Returns to LLM
    │
    ▼
7. LLM receives tool result
    │
    └─> Continues generation or calls more tools
```

### Code Flow in SessionProcessor

```typescript
// packages/opencode/src/session/processor.ts

for await (const value of stream.fullStream) {
  switch (value.type) {
    case "tool-input-start":
      // Create pending tool part
      const part = await Session.updatePart({
        id: Identifier.ascending("part"),
        messageID: assistantMessage.id,
        sessionID: assistantMessage.sessionID,
        type: "tool",
        tool: value.toolName,
        callID: value.id,
        state: { status: "pending", input: {}, raw: "" },
      })
      toolcalls[value.id] = part
      break

    case "tool-call":
      // Update to running
      await Session.updatePart({
        ...match,
        state: {
          status: "running",
          input: value.input,
          time: { start: Date.now() },
        },
        metadata: value.providerMetadata,
      })

      // Doom loop detection
      const lastThree = parts.slice(-3)
      if (
        lastThree.every(
          (p) =>
            p.type === "tool" &&
            p.tool === value.toolName &&
            JSON.stringify(p.state.input) === JSON.stringify(value.input),
        )
      ) {
        await PermissionNext.ask({
          permission: "doom_loop",
          patterns: [value.toolName],
          sessionID: assistantMessage.sessionID,
        })
      }
      break

    case "tool-result":
      // Update to completed
      await Session.updatePart({
        ...match,
        state: {
          status: "completed",
          input: value.input,
          output: value.output.output,
          metadata: value.output.metadata,
          title: value.output.title,
          time: { start: match.state.time.start, end: Date.now() },
          attachments: value.output.attachments,
        },
      })
      break

    case "tool-error":
      // Update to error
      await Session.updatePart({
        ...match,
        state: {
          status: "error",
          input: value.input,
          error: value.error,
          time: { start: match.state.time.start, end: Date.now() },
        },
      })
      break
  }
}
```

## Permission System Integration

### Permission Checking

Tools request permissions via the execution context:

```typescript
// Inside tool execute function
await ctx.ask({
  permission: "bash", // Permission name
  patterns: ["/etc/hosts"], // Patterns to check
  always: ["sensitive-file"], // Always ask for these
})
```

### Permission Resolution

```typescript
// packages/opencode/src/permission/next.ts

export async function ask(params: {
  permission: string
  patterns: string[]
  sessionID: string
  ruleset: PermissionNext.Ruleset
}) {
  // Check each pattern against ruleset
  for (const pattern of params.patterns) {
    const action = check({
      permission: params.permission,
      pattern,
      ruleset: params.ruleset,
    })

    if (action === "deny") {
      throw new Error(`Permission denied: ${params.permission} for ${pattern}`)
    }

    if (action === "ask") {
      // Suspend execution, wait for user response
      const approved = await waitForUserApproval({
        permission: params.permission,
        pattern,
        sessionID: params.sessionID,
      })

      if (!approved) {
        throw new Error(`User denied: ${params.permission} for ${pattern}`)
      }
    }

    // "allow" - continue
  }
}
```

## Doom Loop Detection

### The Problem

An LLM might call the same tool repeatedly with identical arguments, creating an infinite loop.

### The Solution

```typescript
// Track last 3 tool calls
const lastThree = parts.slice(-DOOM_LOOP_THRESHOLD) // THRESHOLD = 3

if (
  lastThree.length === DOOM_LOOP_THRESHOLD &&
  lastThree.every(
    (p) =>
      p.type === "tool" &&
      p.tool === value.toolName &&
      p.state.status !== "pending" &&
      JSON.stringify(p.state.input) === JSON.stringify(value.input),
  )
) {
  // Trigger permission check - user must approve to continue
  await PermissionNext.ask({
    permission: "doom_loop",
    patterns: [value.toolName],
    sessionID: assistantMessage.sessionID,
    metadata: { tool: value.toolName, input: value.input },
  })
}
```

## Output Truncation

### Why Truncation?

Tool output can be massive (e.g., `npm install` logs). Without truncation, the LLM context window fills up quickly.

### How It Works

```typescript
// packages/opencode/src/tool/truncation.ts

export namespace Truncate {
  const LIMITS = {
    bash: { maxLines: 2000, maxBytes: 51200 },
    read: { maxLines: 2000, maxBytes: 51200 },
    grep: { maxBytes: 10485760 }, // 10MB
  }

  async function output(content: string, limits: Limits, agent: Agent.Info) {
    if (shouldTruncate(content, limits)) {
      // Write full output to external file
      const outputPath = path.join(Truncate.DIR, `${sessionID}/tool_${toolName}_${timestamp}.txt`)
      await Bun.write(outputPath, content)

      // Return truncated summary
      return {
        truncated: true,
        outputPath,
        content: makeSummary(content, limits), // First N lines + message
      }
    }

    return { truncated: false, content }
  }
}
```

### Truncated Output Example

```
[First 2000 lines of output]
...

[Output truncated after 2000 lines. Full output (12,458 lines, 512 KB) written to:
~/.opencode/truncate/session_abc123/tool_bash_001.txt

Use the Read tool to view specific sections:
  read(filePath="~/.opencode/truncate/session_abc123/tool_bash_001.txt", offset=2000, limit=100)
]
```

## Design Principles

### 1. Type Safety

- **Zod schemas** validate input at runtime
- **TypeScript** provides compile-time safety
- **JSON Schema** communicates types to LLM

### 2. Separation of Concerns

- **Tool definition**: What the tool does (tool files)
- **Tool registration**: Making tools available (registry)
- **Tool execution**: Running the tool (processor)
- **Permission control**: Security layer (permission system)

### 3. Streaming First

- Tools update UI in real-time via `ctx.metadata()`
- State transitions visible to user
- Progress bars, logs streamed live

### 4. User in the Loop

- Permission system allows user approval/denial
- Doom loop detection prevents runaway execution
- Questions can be asked mid-execution

### 5. Provider Agnostic

- Tools work with any LLM provider
- Schema transformation handles provider quirks
- Same tool definitions across all models

## Adding a Custom Tool

### Step 1: Define the Tool

Create `.opencode/tool/my_tool.ts`:

```typescript
import { Tool } from "@opencode-ai/plugin"
import z from "zod"

export default Tool.define("my_custom_tool", async () => {
  return {
    description: "Does something custom",
    parameters: z.object({
      input: z.string().describe("Input parameter"),
      option: z.boolean().optional(),
    }),

    async execute(params, ctx) {
      // Request permission if needed
      await ctx.ask({
        permission: "my_custom_tool",
        patterns: [params.input],
      })

      // Do work
      const result = await doCustomWork(params.input)

      // Push progress updates
      await ctx.metadata({ progress: 50 })

      // More work
      const final = await finishWork(result)

      return {
        title: "Custom work completed",
        output: final,
        metadata: { status: "success" },
      }
    },
  }
})
```

### Step 2: Configure Permissions

In `.opencode/config.toml`:

```toml
[permission]
my_custom_tool = "ask"  # Always ask before running
```

### Step 3: Use the Tool

The tool is automatically registered and available to all agents:

```
User: Use my_custom_tool with input "test"
```
