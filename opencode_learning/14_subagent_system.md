# Subagent System

This document explains OpenCode's subagent orchestration architecture - how parent agents delegate work to specialized child agents, manage their lifecycle, and collect results.

## Overview

Subagents are specialized agents invoked by a parent agent to handle complex, multi-step, or domain-specific tasks. They operate in isolated sessions with restricted permissions, preventing infinite recursion while enabling powerful delegation patterns.

```
┌─────────────────────────────────────────────────────────────────┐
│                     Parent Session (build)                       │
│                                                                  │
│  User: "Search for auth implementations and summarize them"     │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Assistant thinking: This requires multi-file search...     │ │
│  │ I'll delegate to the explore subagent.                     │ │
│  │                                                             │ │
│  │ [Tool Call: task]                                          │ │
│  │   subagent_type: "explore"                                 │ │
│  │   prompt: "Find all auth implementations..."               │ │
│  │   description: "Search auth code"                          │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              │                                   │
│                              ▼                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              Child Session (explore)                        │ │
│  │              parentID: parent_session_id                    │ │
│  │                                                             │ │
│  │  [Grep] → [Read] → [Read] → [Analyze]                      │ │
│  │                                                             │ │
│  │  Result: "Found 3 auth implementations:                    │ │
│  │           1. JWT in /src/auth/jwt.ts                       │ │
│  │           2. OAuth in /src/auth/oauth.ts                   │ │
│  │           3. API Key in /src/auth/apikey.ts"               │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              │                                   │
│                              ▼                                   │
│  [Tool Result received with session_id metadata]                │
│  Assistant: "Based on the search, here's a summary..."          │
└─────────────────────────────────────────────────────────────────┘
```

## Core Architecture

### The Task Tool

The `task` tool (`packages/opencode/src/tool/task.ts`) is the primary mechanism for subagent invocation:

```typescript
// Tool parameters
const parameters = z.object({
  description: z.string().describe("A short (3-5 words) description of the task"),
  prompt: z.string().describe("The task for the agent to perform"),
  subagent_type: z.string().describe("The type of specialized agent to use for this task"),
  session_id: z.string().describe("Existing Task session to continue").optional(),
  command: z.string().describe("The command that triggered this task").optional(),
})
```

### Session Creation with Parent Link

When a subagent is invoked, a new session is created with explicit parent linkage:

```typescript
// From task.ts - Session creation
const session = await Session.create({
  parentID: ctx.sessionID, // Links to parent session
  title: params.description + ` (@${agent.name} subagent)`,
  permission: [
    // Restrict subagent capabilities
    { permission: "todowrite", pattern: "*", action: "deny" },
    { permission: "todoread", pattern: "*", action: "deny" },
    { permission: "task", pattern: "*", action: "deny" }, // Prevents recursion!
  ],
})
```

### Permission Isolation

Subagents have restricted permissions to prevent:

1. **Infinite recursion**: Cannot spawn sub-subagents (`task: deny`)
2. **State pollution**: Cannot modify parent's TODO list (`todowrite: deny`, `todoread: deny`)
3. **Scope creep**: Focused on their specific task

```
┌─────────────────────────────────────────────────────┐
│                   Permission Model                   │
├─────────────────────────────────────────────────────┤
│                                                      │
│  Parent Agent (build/plan)                          │
│  ├── read: allow                                    │
│  ├── edit: allow                                    │
│  ├── bash: allow                                    │
│  ├── task: allow          ◄── Can spawn subagents  │
│  ├── todowrite: allow                               │
│  └── todoread: allow                                │
│                                                      │
│  Subagent (explore/oracle/librarian)                │
│  ├── read: allow                                    │
│  ├── edit: allow (varies by agent)                  │
│  ├── bash: allow (varies by agent)                  │
│  ├── task: DENY           ◄── Cannot spawn children │
│  ├── todowrite: DENY      ◄── Cannot touch parent's │
│  └── todoread: DENY           TODO state            │
│                                                      │
└─────────────────────────────────────────────────────┘
```

## Built-in Subagents

OpenCode includes several specialized subagents:

### 1. Explore Agent

**Purpose**: Contextual code search across the codebase

```typescript
// From agent.ts
{
  name: "explore",
  description: "Contextual grep for codebases...",
  mode: "subagent",
  // Has access to: read, grep, glob, LSP tools
}
```

**Use Cases**:

- "Find all usages of function X"
- "Where is the auth logic?"
- "Search for error handling patterns"

### 2. General Agent

**Purpose**: Complex multi-step research and analysis

```typescript
{
  name: "general",
  description: "General-purpose agent for researching complex questions...",
  mode: "subagent",
  // Has broad tool access for flexibility
}
```

**Use Cases**:

- "Analyze the codebase architecture"
- "Research how feature X works across multiple files"
- "Gather context from various sources"

### 3. Oracle Agent

**Purpose**: Expert technical advisor for architecture decisions

```typescript
{
  name: "oracle",
  description: "Expert technical advisor with deep reasoning...",
  mode: "subagent",
  // Focused on analysis, less on file modification
}
```

**Use Cases**:

- "Review my implementation approach"
- "Help debug this complex issue"
- "Advise on architecture tradeoffs"

### 4. Librarian Agent

**Purpose**: External documentation and OSS research

```typescript
{
  name: "librarian",
  description: "Specialized codebase understanding agent...",
  mode: "subagent",
  // Has access to: web search, GitHub CLI, Context7
}
```

**Use Cases**:

- "How does library X work?"
- "Find official docs for API Y"
- "Search OSS examples of pattern Z"

## Execution Flow

### Synchronous Task Execution

```
┌──────────────────────────────────────────────────────────────┐
│                    Task Tool Execution Flow                   │
└──────────────────────────────────────────────────────────────┘

1. VALIDATE
   ├── Check subagent_type exists
   ├── Verify caller has permission
   └── Get agent configuration

2. CREATE SESSION
   ├── If session_id provided → Resume existing session
   └── Else → Create new session with parentID

3. SETUP STREAMING
   ├── Subscribe to Bus for PartUpdated events
   ├── Filter events matching subagent's sessionID
   └── Forward tool progress to parent via ctx.metadata()

4. EXECUTE
   ├── Call SessionPrompt.prompt() with:
   │   ├── messageID (new)
   │   ├── sessionID (child session)
   │   ├── model (inherited or agent-specific)
   │   ├── agent name
   │   └── tools config (restricted)
   └── AWAIT completion (synchronous from parent's view)

5. COLLECT RESULTS
   ├── Get all messages from child session
   ├── Extract final text response
   ├── Build tool usage summary
   └── Append task_metadata with session_id

6. RETURN
   └── { title, output, metadata: { summary, sessionId } }
```

### Real-time Progress Streaming

While the task executes synchronously, progress is streamed in real-time:

```typescript
// From task.ts - Progress streaming setup
const unsub = Bus.subscribe(MessageV2.Event.PartUpdated, async (evt) => {
  if (evt.properties.part.sessionID !== session.id) return
  if (evt.properties.part.type !== "tool") return

  const part = evt.properties.part
  parts[part.id] = {
    id: part.id,
    tool: part.tool,
    state: {
      status: part.state.status,
      title: part.state.status === "completed" ? part.state.title : undefined,
    },
  }

  // Update parent's view of subagent progress
  ctx.metadata({
    title: params.description,
    metadata: {
      summary: Object.values(parts).sort((a, b) => a.id.localeCompare(b.id)),
      sessionId: session.id,
    },
  })
})
```

This allows the parent (and user) to see what the subagent is doing in real-time:

```
┌─────────────────────────────────────────────────┐
│ Task: Search auth code                          │
│ Status: Running...                              │
│                                                 │
│ Progress:                                       │
│   ✓ grep: Found 12 matches                     │
│   ✓ read: /src/auth/jwt.ts                     │
│   ● read: /src/auth/oauth.ts (running)         │
│   ○ read: /src/auth/apikey.ts (pending)        │
└─────────────────────────────────────────────────┘
```

## Stateful vs Stateless Subagents

### Stateless (Default)

Each task invocation creates a fresh session:

```typescript
// Parent calls task without session_id
await task({
  subagent_type: "explore",
  prompt: "Find auth implementations",
  description: "Search auth",
})
// Creates new session: ses_abc123

// Later, another call creates ANOTHER new session
await task({
  subagent_type: "explore",
  prompt: "Find database queries",
  description: "Search DB",
})
// Creates new session: ses_def456 (no memory of previous)
```

### Stateful (with session_id)

Pass the returned `session_id` to continue a conversation:

```typescript
// First call
const result1 = await task({
  subagent_type: "explore",
  prompt: "Find auth implementations",
  description: "Search auth",
})
// Returns: session_id: ses_abc123

// Continue the same session
const result2 = await task({
  subagent_type: "explore",
  prompt: "Now find where those are called from",
  description: "Find callers",
  session_id: "ses_abc123", // Continues previous context!
})
// Subagent remembers the auth files from first search
```

**Stateful Use Cases**:

- Multi-turn research conversations
- Iterative refinement of searches
- Building on previous analysis

## Result Format

### Tool Output Structure

```typescript
// What the task tool returns
{
  title: "Search auth code",  // Short description
  output: `
    Found 3 authentication implementations:

    1. **JWT Authentication** (/src/auth/jwt.ts)
       - Token generation and validation
       - Refresh token support

    2. **OAuth 2.0** (/src/auth/oauth.ts)
       - Google, GitHub providers
       - State parameter handling

    3. **API Key** (/src/auth/apikey.ts)
       - Header-based authentication
       - Rate limiting integration

    <task_metadata>
    session_id: ses_abc123
    </task_metadata>
  `,
  metadata: {
    summary: [
      { id: "part_1", tool: "grep", state: { status: "completed", title: "Found 12 matches" } },
      { id: "part_2", tool: "read", state: { status: "completed", title: "/src/auth/jwt.ts" } },
      { id: "part_3", tool: "read", state: { status: "completed", title: "/src/auth/oauth.ts" } },
      { id: "part_4", tool: "read", state: { status: "completed", title: "/src/auth/apikey.ts" } },
    ],
    sessionId: "ses_abc123"
  }
}
```

### Error Handling

If a subagent fails:

```typescript
// Error is caught and reported back to parent
try {
  const result = await SessionPrompt.prompt({ ... })
} catch (error) {
  // Parent receives error in tool output
  return {
    title: params.description,
    output: `Error: ${error.message}`,
    metadata: { error: true }
  }
}
```

## Oh-My-OpenCode Enhancements

Oh-My-OpenCode extends the base subagent system with asynchronous execution:

### Background Tasks

```typescript
// Launch subagent in background (non-blocking)
const taskId = await background_task({
  agent: "explore",
  prompt: "Search for auth implementations",
  description: "Auth search",
})
// Returns immediately with task_id

// Continue other work...

// Later, retrieve results
const result = await background_output({ task_id: taskId })
```

### Parallel Orchestration

```
┌─────────────────────────────────────────────────────────────┐
│              Oh-My-OpenCode Parallel Pattern                 │
└─────────────────────────────────────────────────────────────┘

// Fire multiple agents in parallel
background_task("explore", "Find auth implementations...")  → task_1
background_task("explore", "Find error handlers...")        → task_2
background_task("librarian", "Lookup JWT best practices...")→ task_3

// Continue immediate work while they run
// ...

// Collect results as they complete
background_output(task_1) → Auth findings
background_output(task_2) → Error handling findings
background_output(task_3) → JWT documentation

// Synthesize all results
```

### Agent Types in Oh-My-OpenCode

| Agent                     | Purpose                    | Typical Use                       |
| ------------------------- | -------------------------- | --------------------------------- |
| `explore`                 | Contextual grep (internal) | Find code in THIS repo            |
| `librarian`               | Reference grep (external)  | Find docs, OSS examples           |
| `oracle`                  | Expert advisor             | Architecture decisions, debugging |
| `general`                 | Multi-step research        | Complex analysis tasks            |
| `frontend-ui-ux-engineer` | UI/UX implementation       | Visual changes                    |
| `document-writer`         | Documentation              | READMEs, guides                   |

## Session Hierarchy

### Parent-Child Relationships

```
┌────────────────────────────────────────────────────────┐
│                   Session Hierarchy                     │
└────────────────────────────────────────────────────────┘

ses_main_001 (Primary Session - build agent)
├── ses_child_001 (explore subagent)
│   └── parentID: ses_main_001
├── ses_child_002 (oracle subagent)
│   └── parentID: ses_main_001
└── ses_child_003 (explore subagent - continued from ses_child_001)
    └── parentID: ses_main_001
```

### Lifecycle Management

- **Creation**: Child session created when task tool executes
- **Isolation**: Each child has independent message history
- **Persistence**: Child sessions persist for continuation
- **Cleanup**: Deleting parent can cascade to children (configurable)

## Best Practices

### When to Use Subagents

| Scenario              | Subagent    | Why                             |
| --------------------- | ----------- | ------------------------------- |
| Multi-file search     | `explore`   | Handles complex search patterns |
| Library documentation | `librarian` | Access to external resources    |
| Architecture review   | `oracle`    | Deep reasoning capabilities     |
| Complex research      | `general`   | Flexible multi-step execution   |

### When NOT to Use Subagents

| Scenario            | Better Approach    |
| ------------------- | ------------------ |
| Single file read    | Direct `read` tool |
| Simple grep         | Direct `grep` tool |
| Known file location | Direct tool access |
| Trivial operations  | Direct execution   |

### Delegation Prompt Best Practices

```typescript
// GOOD: Specific, actionable prompt
await task({
  subagent_type: "explore",
  prompt: `Find all implementations of the AuthService interface.
           Look for:
           1. Classes implementing AuthService
           2. Mock implementations in tests
           3. Related factory functions
           Return file paths and brief descriptions.`,
  description: "Find AuthService impls",
})

// BAD: Vague prompt
await task({
  subagent_type: "explore",
  prompt: "Find auth stuff",
  description: "Search",
})
```

## Code References

| File                                          | Purpose                        |
| --------------------------------------------- | ------------------------------ |
| `packages/opencode/src/tool/task.ts`          | Task tool implementation       |
| `packages/opencode/src/tool/task.txt`         | Tool description/instructions  |
| `packages/opencode/src/session/index.ts`      | Session creation with parentID |
| `packages/opencode/src/session/prompt.ts`     | Session execution loop         |
| `packages/opencode/src/session/processor.ts`  | Tool result processing         |
| `packages/opencode/src/session/message-v2.ts` | Message/part data structures   |
| `packages/opencode/src/agent/agent.ts`        | Subagent definitions           |

## Next Steps

- See [02_agent_system.md](./02_agent_system.md) for agent configuration details
- See [03_session_management.md](./03_session_management.md) for session internals
- See [04_tool_system.md](./04_tool_system.md) for available tools
- See [07_opencode_vs_oh_my_opencode.md](./07_opencode_vs_oh_my_opencode.md) for background task patterns
