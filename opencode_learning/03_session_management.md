# Session Management Architecture

## Overview

Sessions are the fundamental unit of conversation state in OpenCode. Each session manages:

- Message history (user, assistant, tool calls)
- Project context and directory
- Parent-child relationships (for spawned subagents)
- Snapshots and diffs
- Summaries and metadata

**Location**: `packages/opencode/src/session/index.ts`

## Session Schema

```typescript
export const Info = z.object({
  id: Identifier.schema("session"), // Unique session ID
  projectID: z.string(), // Associated project
  directory: z.string(), // Working directory
  parentID: Identifier.schema("session").optional(), // Parent session (for subagents)

  summary: z
    .object({
      additions: z.number(), // Lines added
      deletions: z.number(), // Lines deleted
      files: z.number(), // Files changed
      diffs: Snapshot.FileDiff.array().optional(),
    })
    .optional(),

  share: z
    .object({
      url: z.string(), // Shareable URL
    })
    .optional(),

  title: z.string(), // Session title
  version: z.string(), // OpenCode version

  time: z.object({
    created: z.number(), // Creation timestamp
    updated: z.number(), // Last update
    compacting: z.number().optional(), // Compaction timestamp
    archived: z.number().optional(), // Archive timestamp
  }),

  permission: PermissionNext.Ruleset.optional(), // Session-level permissions

  revert: z
    .object({
      messageID: z.string(), // Revert to this message
      partID: z.string().optional(),
      snapshot: z.string().optional(), // Snapshot reference
      diff: z.string().optional(), // Diff content
    })
    .optional(),
})
```

## Session Lifecycle

### 1. Creation

```typescript
// Create new session
const session = await Session.create({
  parentID: "session_xyz123",  // Optional: for child sessions
  title: "Custom Title",       // Optional: auto-generated if omitted
  permission: ruleset,         // Optional: session-specific permissions
})

// Returns:
{
  id: "session_abc123",
  projectID: "proj_xyz",
  directory: "/path/to/project",
  parentID: undefined,
  title: "New session - 2025-01-12T19:17:38.000Z",
  version: "1.1.14",
  time: {
    created: 1736708258000,
    updated: 1736708258000,
  }
}
```

### 2. Message Processing

```typescript
// Process user input
await Session.process({
  sessionID: "session_abc123",
  agent: "build",
  input: "Add authentication to the API",
  model: { providerID: "anthropic", modelID: "claude-3-5-sonnet" }
})

// This triggers:
1. Load session state
2. Append user message
3. Build system prompt
4. Call LLM with tools
5. Process tool calls
6. Stream response
7. Store assistant message
8. Update session metadata
```

### 3. Forking

```typescript
// Fork session to explore alternative approach
const forked = await Session.fork({
  sessionID: "session_abc123",
  messageID: "msg_xyz", // Fork from specific message
})

// Creates new session with history up to messageID
// Useful for:
// - Trying different approaches
// - Reverting to earlier state
// - Parallel exploration
```

### 4. Compaction

```typescript
// Compact message history when context gets too large
await Session.compact({
  sessionID: "session_abc123",
  force: false  // Optional: force compaction even if not needed
})

// Process:
1. Detect long message history
2. Summarize old messages via compaction agent
3. Replace old messages with summary
4. Maintain recent messages verbatim
5. Preserve critical context
```

### 5. Archival

```typescript
// Archive inactive session
await Session.archive("session_abc123")

// Marks session as archived:
session.time.archived = Date.now()

// Archived sessions:
// - Not shown in active list
// - Still accessible by ID
// - Can be restored
```

### 6. Deletion

```typescript
// Delete session permanently
await Session.remove("session_abc123")

// Removes:
// - Session metadata
// - Message history
// - Associated snapshots
// - Todo lists
```

## Message Storage

### Message Schema (V2)

```typescript
// User message
{
  id: "msg_abc",
  role: "user",
  time: { created: 1736708258000 },
  content: [
    { type: "text", text: "Add authentication" }
  ]
}

// Assistant message
{
  id: "msg_xyz",
  role: "assistant",
  time: { created: 1736708260000 },
  content: [
    { type: "text", text: "I'll add authentication..." },
    {
      type: "tool_use",
      id: "tool_123",
      name: "mcp_edit",
      input: { /* tool parameters */ }
    }
  ],
  usage: {
    promptTokens: 1234,
    completionTokens: 567,
  },
  finish_reason: "tool_use"
}

// Tool result
{
  id: "msg_tool",
  role: "tool",
  time: { created: 1736708261000 },
  content: [
    {
      type: "tool_result",
      toolUseId: "tool_123",
      result: "File updated successfully",
      isError: false
    }
  ]
}
```

### Storage Structure

```
~/.opencode/session/
├── session_abc123/
│   ├── meta.json              # Session metadata
│   ├── message/
│   │   ├── msg_001.json
│   │   ├── msg_002.json
│   │   └── ...
│   ├── snapshot/
│   │   ├── snap_001.json
│   │   └── ...
│   └── todo.json              # Session todo list
└── session_xyz456/
    └── ...
```

## Session State Management

### State Components

```typescript
// Session state includes:
{
  info: Session.Info,              // Metadata
  messages: MessageV2.Info[],      // Message history
  todos: Todo.Info[],              // Task list
  snapshots: Snapshot.Info[],      // Code snapshots
  permissions: PermissionNext.Ruleset,  // Effective permissions
}
```

### State Loading

```typescript
// Lazy loading strategy
const state = Instance.state(async () => {
  const sessions = await Storage.list("session")
  const map = new Map()

  for (const sessionID of sessions) {
    const info = await Storage.read(Storage.path("session", sessionID, "meta.json"))
    map.set(sessionID, info)
  }

  return map
})

// Messages loaded on-demand when session accessed
```

## Parent-Child Relationships

### Child Session Creation

```typescript
// When subagent spawned, create child session
const child = await Session.create({
  parentID: parent.id,
  title: "Child session - Research authentication patterns",
  permission: agentPermissions,
})

// Child session:
// - Has own message history
// - Cannot access parent's todos
// - Isolated state
// - Returns result to parent via single message
```

### Use Cases for Child Sessions

1. **Subagent Execution**
   - explore agent searching codebase
   - librarian agent fetching docs
   - general agent doing research

2. **Parallel Tasks**
   - Multiple search angles simultaneously
   - Independent investigations
   - Isolated context per task

3. **Sandboxed Operations**
   - Risky operations in isolated session
   - Test different approaches
   - Rollback-friendly

## Snapshot System

### Snapshot Creation

```typescript
// Capture current project state
const snapshot = await Snapshot.create({
  sessionID: "session_abc123",
  messageID: "msg_xyz",
})

// Stores:
{
  id: "snap_123",
  sessionID: "session_abc123",
  messageID: "msg_xyz",
  time: { created: 1736708258000 },
  files: [
    {
      path: "src/auth.ts",
      content: "...",
      hash: "sha256...",
    }
  ]
}
```

### Diff Generation

```typescript
// Generate diff between snapshots
const diff = await Snapshot.diff({
  sessionID: "session_abc123",
  from: "snap_123",
  to: "snap_456",
})

// Returns:
{
  additions: 42,
  deletions: 18,
  files: 3,
  diffs: [
    {
      path: "src/auth.ts",
      diff: "unified diff format...",
      additions: 42,
      deletions: 18,
    }
  ]
}
```

### Revert Functionality

```typescript
// Revert to earlier snapshot
await Session.revert({
  sessionID: "session_abc123",
  messageID: "msg_xyz",
  snapshot: "snap_123",
})

// Process:
1. Load snapshot
2. Restore file contents
3. Update session metadata
4. Truncate message history
5. Mark revert point
```

## Session Events

### Event System

```typescript
// Session events published to Bus
export const Event = {
  Created: BusEvent.define("session.created", { info }),
  Updated: BusEvent.define("session.updated", { info }),
  Deleted: BusEvent.define("session.deleted", { info }),
  Diff: BusEvent.define("session.diff", { sessionID, diff }),
  Error: BusEvent.define("session.error", { sessionID, error }),
}

// Subscribers:
Bus.subscribe(Session.Event.Created, async (event) => {
  console.log("New session created:", event.info.id)
})

Bus.subscribe(Session.Event.Diff, async (event) => {
  // Update UI with diff visualization
  renderDiff(event.diff)
})
```

## Session Permissions

### Permission Inheritance

```typescript
// Permission resolution order:
1. Agent default permissions
2. User config overrides
3. Session-specific overrides

// Example:
const effectivePermissions = PermissionNext.merge(
  agentPermissions,
  userPermissions,
  session.permission ?? []
)
```

### Session-Level Permission Override

```toml
# .opencode/config.toml
[permission]
bash = "ask"  # Global: ask before bash

# Can be overridden per-session:
session = await Session.create({
  permission: [
    { permission: "bash", pattern: "*", action: "allow" }
  ]
})
```

## Session Sharing

### Share Generation

```typescript
// Generate shareable link
const share = await Session.share({
  sessionID: "session_abc123",
  include: ["messages", "diffs"],  // What to include
})

// Returns:
{
  secret: "share_secret_xyz",
  url: "https://opencode.ai/share/session_abc123?secret=..."
}

// Session share includes:
// - Anonymized message history
// - Code diffs (sanitized)
// - Tool calls (sanitized)
// - No credentials or secrets
```

### Share Access

```typescript
// Access shared session
const shared = await Session.getShared({
  sessionID: "session_abc123",
  secret: "share_secret_xyz",
})

// Read-only access to:
// - Conversation flow
// - Code changes
// - Tool usage patterns
```

## Session Compaction Strategy

### When to Compact

```typescript
// Compact when:
1. Token count exceeds threshold (e.g., 50k tokens)
2. Message count very high (>100 messages)
3. Context window approaching limit
4. User manually requests compaction
```

### Compaction Process

```typescript
async function compact(sessionID: string) {
  // 1. Load full message history
  const messages = await Session.messages(sessionID)

  // 2. Identify compaction boundary
  // Keep recent N messages, compact older ones
  const recentMessages = messages.slice(-20)
  const oldMessages = messages.slice(0, -20)

  // 3. Summarize old messages using compaction agent
  const summary = await Agent.run({
    agent: "compaction",
    input: oldMessages,
    prompt: PROMPT_COMPACTION,
  })

  // 4. Replace old messages with summary
  const compacted = [
    {
      role: "user",
      content: "Previous conversation summary: " + summary,
    },
    ...recentMessages,
  ]

  // 5. Update session
  await Session.update(sessionID, {
    messages: compacted,
    time: { compacting: Date.now() },
  })
}
```

## Best Practices

### Session Management

1. **Title Early**: Set meaningful titles to avoid clutter
2. **Compact Regularly**: Don't let context bloat
3. **Fork Strategically**: Use forks for experiments, not normal flow
4. **Archive Completed**: Archive finished sessions to reduce list size

### Performance

1. **Lazy Load**: Don't load all sessions upfront
2. **Message Pagination**: Load messages in chunks for long sessions
3. **Snapshot Sparingly**: Snapshots are expensive, use judiciously
4. **Clean Old Sessions**: Periodically delete ancient sessions

### Child Sessions

1. **Clear Purpose**: Each child should have one clear task
2. **Minimal Context**: Only pass necessary information to child
3. **Result Extraction**: Child returns concise findings to parent
4. **No Deep Nesting**: Avoid child-of-child-of-child patterns

## CLI Commands

```bash
# List sessions
opencode session list

# View session details
opencode session show <session_id>

# Fork session
opencode session fork <session_id>

# Archive session
opencode session archive <session_id>

# Delete session
opencode session delete <session_id>

# Compact session
opencode session compact <session_id>

# Export session
opencode session export <session_id> --output session.json

# Import session
opencode session import session.json
```

## Next Steps

- [04_tool_system.md](./04_tool_system.md) - How tools are executed within sessions
- [07_client_server.md](./07_client_server.md) - How clients interact with sessions
- [02_agent_system.md](./02_agent_system.md) - How agents manage sessions
