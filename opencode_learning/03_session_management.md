# Session Management Architecture

## Overview

Sessions are the fundamental unit of conversation state in OpenCode. Each session manages:

- Message history (user, assistant, tool calls)
- Project context and directory
- Parent-child relationships (for spawned subagents)
- Snapshots and diffs
- Summaries and metadata

**Location**: `packages/opencode/src/session/index.ts`

## Session Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SESSION ARCHITECTURE                                 │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                         USER INTERFACE                                       │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  CLI / GUI / VS Code Extension                                        │  │
│  │  - Create sessions                                                    │  │
│  │  - Send messages                                                      │  │
│  │  - View history                                                       │  │
│  └────────────────────────┬──────────────────────────────────────────────┘  │
└───────────────────────────┼─────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SESSION MANAGER                                      │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  Session API                                                          │  │
│  │  ┌──────────┬──────────┬──────────┬──────────┬──────────┐            │  │
│  │  │ create() │ process()│  fork()  │ compact()│ archive()│            │  │
│  │  └──────────┴──────────┴──────────┴──────────┴──────────┘            │  │
│  │                                                                       │  │
│  │  State: Map<sessionID, SessionInfo>                                   │  │
│  │  - Lazy loading                                                       │  │
│  │  - Event publishing                                                   │  │
│  │  - Permission resolution                                              │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         STORAGE LAYER                                        │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  ~/.opencode/session/                                                 │  │
│  │                                                                       │  │
│  │  session_abc123/                                                      │  │
│  │  ├── meta.json              (Session metadata)                        │  │
│  │  ├── message/                                                         │  │
│  │  │   ├── msg_001.json       (User message)                           │  │
│  │  │   ├── msg_002.json       (Assistant message)                      │  │
│  │  │   └── msg_003.json       (Tool result)                            │  │
│  │  ├── snapshot/                                                        │  │
│  │  │   └── snap_001.json      (Code snapshot)                         │  │
│  │  └── todo.json              (Task list)                             │  │
│  │                                                                       │  │
│  │  session_xyz456/                                                      │  │
│  │  └── ...                                                              │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SUBAGENT SYSTEM                                      │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  Parent-Child Session Tree                                            │  │
│  │                                                                       │  │
│  │                    ┌──────────────┐                                   │  │
│  │                    │ Main Session │                                   │  │
│  │                    │  (parentID:  │                                   │  │
│  │                    │    null)     │                                   │  │
│  │                    └──────┬───────┘                                   │  │
│  │                           │                                           │  │
│  │         ┌─────────────────┼─────────────────┐                         │  │
│  │         ▼                 ▼                 ▼                         │  │
│  │   ┌──────────┐      ┌──────────┐      ┌──────────┐                   │  │
│  │   │ Child 1  │      │ Child 2  │      │ Child 3  │                   │  │
│  │   │(explorer)│      │(librarian│      │ (fixer)  │                   │  │
│  │   │          │      │          │      │          │                   │  │
│  │   │Isolated  │      │Isolated  │      │Isolated  │                   │  │
│  │   │context   │      │context   │      │context   │                   │  │
│  │   └────┬─────┘      └────┬─────┘      └────┬─────┘                   │  │
│  │        │                 │                 │                          │  │
│  │        └─────────────────┴─────────────────┘                          │  │
│  │                          │                                            │  │
│  │                          ▼                                            │  │
│  │              Return results to parent                                  │  │
│  │              (single message)                                          │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

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

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SESSION LIFECYCLE FLOW                               │
└─────────────────────────────────────────────────────────────────────────────┘

    ┌──────────┐
    │  CREATE  │
    └────┬─────┘
         │
         ▼
    ┌──────────┐
    │ PROCESS  │◄─────────────────────────┐
    └────┬─────┘                          │
         │                                │
         ▼                                │
   ┌────────────┐     ┌──────────┐       │
   │   FORK     │────▶│  PROCESS │       │
   └────────────┘     └────┬─────┘       │
         ▲                  │             │
         │                  ▼             │
         │            ┌──────────┐        │
         │            │ COMPACT  │        │
         │            └────┬─────┘        │
         │                  │              │
         │                  ▼              │
         │            ┌──────────┐        │
         │            │ ARCHIVE  │        │
         │            └────┬─────┘        │
         │                  │              │
         │                  ▼              │
         │            ┌──────────┐        │
         └────────────│  DELETE  │        │
                      └──────────┘        │
                           │              │
                           └──────────────┘
                           (New messages)
```

### 1. Creation

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SESSION CREATION FLOW                                │
└─────────────────────────────────────────────────────────────────────────────┘

User Action: Start new session
         │
         ▼
┌─────────────────┐
│ Session.create()│
│                 │
│ 1. Generate ID  │
│ 2. Set metadata │
│ 3. Create files │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────┐
│ Storage Layer                       │
│                                     │
│ ~/.opencode/session/                │
│ └── session_{id}/                   │
│     ├── meta.json    (metadata)     │
│     ├── message/     (empty)        │
│     ├── snapshot/    (empty)        │
│     └── todo.json    (empty array)  │
│                                     │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│ Event Bus                           │
│                                     │
│ Publish: session.created            │
│   { info: SessionInfo }             │
│                                     │
│ Subscribers:                        │
│ - UI updates sidebar                │
│ - Analytics tracking                │
│ - Logging                           │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│ Return SessionInfo                  │
│                                     │
│ {                                   │
│   id: "session_abc123",             │
│   projectID: "proj_xyz",            │
│   directory: "/path/to/project",    │
│   parentID: null,                   │
│   title: "New session - ...",       │
│   version: "1.1.14",                │
│   time: {                           │
│     created: 1736708258000,         │
│     updated: 1736708258000          │
│   }                                 │
│ }                                   │
└─────────────────────────────────────┘
```

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

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         MESSAGE PROCESSING FLOW                              │
└─────────────────────────────────────────────────────────────────────────────┘

User Input: "Add authentication to the API"
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. LOAD SESSION STATE                                                        │
│    - Read meta.json                                                          │
│    - Load recent messages                                                    │
│    - Check permissions                                                       │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 2. APPEND USER MESSAGE                                                       │
│                                                                              │
│    Message Store:                                                            │
│    ┌─────────────────────────────────────────────────────────────────────┐   │
│    │ ~/.opencode/session/session_abc123/message/                         │   │
│    │                                                                     │   │
│    │ msg_001.json  ──▶  { role: "user", content: "Hello" }              │   │
│    │ msg_002.json  ──▶  { role: "assistant", ... }                      │   │
│    │ msg_003.json  ──▶  { role: "user", content: "Add auth..." }  ◀── NEW│   │
│    │                                                                     │   │
│    └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 3. BUILD SYSTEM PROMPT                                                       │
│    - Load AGENTS.md                                                          │
│    - Add tool definitions                                                    │
│    - Inject context from messages                                            │
│                                                                              │
│    Prompt Structure:                                                         │
│    ┌─────────────────────────────────────────────────────────────────────┐   │
│    │ System: You are a coding assistant...                               │   │
│    │                                                                     │   │
│    │ Tools: [tool definitions]                                           │   │
│    │                                                                     │   │
│    │ User: Hello                                                         │   │
│    │ Assistant: Hi!                                                      │   │
│    │ User: Add authentication to the API                                 │   │
│    └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 4. CALL LLM WITH TOOLS                                                       │
│                                                                              │
│    ┌─────────────────────┐         ┌─────────────────────┐                   │
│    │   Anthropic API     │◄───────▶│   OpenCode Agent    │                   │
│    │   claude-3-5-sonnet │         │   (with tools)      │                   │
│    └─────────────────────┘         └─────────────────────┘                   │
│                                                                              │
│    Request:  { prompt, tools, model }                                        │
│    Response: { content, tool_calls?, usage }                                 │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 5. PROCESS TOOL CALLS (if any)                                               │
│                                                                              │
│    ┌─────────────────────────────────────────────────────────────────────┐   │
│    │ Tool Call Loop                                                      │   │
│    │                                                                     │   │
│    │ ┌─────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐        │   │
│    │ │mcp_read │───▶│  Result  │───▶│  LLM     │───▶│  Next    │        │   │
│    │ │         │    │          │    │  Call    │    │  Tool?   │        │   │
│    │ └─────────┘    └──────────┘    └──────────┘    └────┬─────┘        │   │
│    │                                                    │ YES            │   │
│    │                                                    └────────────────┤   │
│    │                                                    NO               │   │
│    │                                                    ▼                 │   │
│    │                                              [Continue to step 6]   │   │
│    └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 6. STREAM RESPONSE                                                           │
│    - Token-by-token streaming                                                │
│    - Real-time UI updates                                                    │
│    - Cancelable                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 7. STORE ASSISTANT MESSAGE                                                   │
│                                                                              │
│    New message added:                                                        │
│    {                                                                         │
│      id: "msg_004",                                                          │
│      role: "assistant",                                                      │
│      content: [{ type: "text", text: "I'll add..." }],                      │
│      tool_calls: [...],  // If tools were used                              │
│      usage: {                                                                │
│        promptTokens: 1234,                                                   │
│        completionTokens: 567                                                 │
│      },                                                                      │
│      finish_reason: "tool_use"                                               │
│    }                                                                         │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 8. UPDATE SESSION METADATA                                                   │
│    - Update session.time.updated                                             │
│    - Calculate token usage totals                                            │
│    - Publish session.updated event                                           │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
    [Complete]
```

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

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SESSION FORKING                                      │
└─────────────────────────────────────────────────────────────────────────────┘

Original Session: session_abc123
┌─────────────────────────────────────────────────────────────────────────────┐
│ Message History                                                              │
│                                                                              │
│  msg_001  ──▶  User: "Create a React app"                                    │
│  msg_002  ──▶  Assistant: [creates app]                                      │
│  msg_003  ──▶  User: "Add routing"                                           │
│  msg_004  ──▶  Assistant: [adds react-router]  ◀── FORK POINT               │
│  msg_005  ──▶  User: "Now add Redux"                                         │
│  msg_006  ──▶  Assistant: [adds Redux]                                       │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                            │
                            │ Session.fork({
                            │   sessionID: "session_abc123",
                            │   messageID: "msg_004"
                            │ })
                            ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Forked Session: session_fork_789                                            │
│                                                                              │
│ Message History (copied up to fork point):                                  │
│                                                                              │
│  msg_001  ──▶  User: "Create a React app"                                    │
│  msg_002  ──▶  Assistant: [creates app]                                      │
│  msg_003  ──▶  User: "Add routing"                                           │
│  msg_004  ──▶  Assistant: [adds react-router]                                │
│                                                                              │
│  NEW: User: "Add Zustand instead"                                           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

Fork Use Cases:
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  1. TRYING DIFFERENT APPROACHES                                              │
│     ┌──────────────┐          ┌──────────────┐                              │
│     │ Main Session │          │ Fork Session │                              │
│     │ (Redux path) │          │(Zustand path)│                              │
│     └──────────────┘          └──────────────┘                              │
│           │                            │                                     │
│           ▼                            ▼                                     │
│     [Compare results, choose best]                                           │
│                                                                              │
│  2. REVERTING TO EARLIER STATE                                               │
│     ┌──────────────┐                                                         │
│     │ Session with │  ◀── Something went wrong                              │
│     │   errors     │                                                         │
│     └──────┬───────┘                                                         │
│            │                                                                 │
│            │ Fork from before errors                                         │
│            ▼                                                                 │
│     ┌──────────────┐                                                         │
│     │ Clean fork   │  ◀── Fresh start from good state                        │
│     └──────────────┘                                                         │
│                                                                              │
│  3. PARALLEL EXPLORATION                                                     │
│     ┌──────────────┐                                                         │
│     │   Original   │                                                         │
│     └──────┬───────┘                                                         │
│            │                                                                 │
│     ┌──────┼──────┐                                                          │
│     ▼      ▼      ▼                                                          │
│  ┌────┐ ┌────┐ ┌────┐                                                        │
│  │Fork│ │Fork│ │Fork│  ◀── Multiple approaches simultaneously                │
│  │ #1 │ │ #2 │ │ #3 │                                                        │
│  └────┘ └────┘ └────┘                                                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

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

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SESSION COMPACTION                                   │
└─────────────────────────────────────────────────────────────────────────────┘

BEFORE Compaction (Token limit exceeded):
┌─────────────────────────────────────────────────────────────────────────────┐
│ Session: session_abc123                                                      │
│ Total Messages: 120 (Token count: 52,000 / 50,000 limit)                   │
│                                                                              │
│  msg_001-100  ──▶  [Old conversation history]                               │
│                      (40,000 tokens)                                         │
│  msg_101-110  ──▶  [Recent context]                                         │
│                      (8,000 tokens)                                          │
│  msg_111-120  ──▶  [Current working messages]                               │
│                      (4,000 tokens)                                          │
│                                                                              │
│  ⚠️  Token limit exceeded! Context window full.                             │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         │ Session.compact({ sessionID: "session_abc123" })
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Compaction Process                                                           │
│                                                                              │
│ Step 1: Identify Boundary                                                    │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │  Keep recent:  msg_101-120 (20 messages, ~12K tokens)                   │ │
│ │  Compact old:  msg_001-100 (100 messages, ~40K tokens)                  │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│ Step 2: Summarize Old Messages                                               │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │ Agent.run({                                                             │ │
│ │   agent: "compaction",                                                  │ │
│ │   input: msg_001-100,                                                   │ │
│ │   prompt: "Summarize key decisions, code changes, and context"          │ │
│ │ })                                                                      │ │
│ │                                                                         │ │
│ │ Result: "Created React app with TypeScript. Added routing using         │ │
│ │ React Router v6. Implemented authentication with JWT tokens.            │ │
│ │ Current working on dashboard components..."                             │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│ Step 3: Replace and Store                                                    │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │                                                                         │ │
│ │  NEW msg_summary_001:                                                   │ │
│ │  {                                                                      │ │
│ │    role: "user",                                                        │ │
│ │    content: "Previous conversation summary: Created React app with      │ │
│ │               TypeScript. Added routing using React Router v6..."       │ │
│ │  }                                                                      │ │
│ │                                                                         │ │
│ │  ┌─────────────────────────────────────────────────────────────────┐   │ │
│ │  │  msg_summary_001  ──▶  Summary (~500 tokens)                   │   │ │
│ │  │  msg_101-110      ──▶  Recent context (~8K tokens)             │   │ │
│ │  │  msg_111-120      ──▶  Current working (~4K tokens)            │   │ │
│ │  │                                                                  │   │ │
│ │  │  Total: ~12.5K tokens ✓ (Well under limit)                     │   │ │
│ │  └─────────────────────────────────────────────────────────────────┘   │ │
│ │                                                                         │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ AFTER Compaction                                                             │
│ Total Messages: 21 (Token count: ~12,500 / 50,000 limit)                   │
│                                                                              │
│  msg_summary_001  ──▶  [Condensed summary of first 100 messages]           │
│  msg_101-110      ──▶  [Recent context preserved verbatim]                 │
│  msg_111-120      ──▶  [Current working messages]                          │
│                                                                              │
│  session.time.compacting = Date.now()                                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

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

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SESSION ARCHIVAL                                     │
└─────────────────────────────────────────────────────────────────────────────┘

Session List Before Archival:
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  Active Sessions:                                                            │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │ ▶ session_abc123  Auth implementation (2 days ago)                    │ │
│  │ ▶ session_def456  Bug fix - login flow (1 week ago)                   │ │
│  │ ▶ session_ghi789  Refactor database layer (completed)        ◀── ARCHIVE│ │
│  │ ▶ session_jkl012  Documentation updates (completed)          ◀── ARCHIVE│ │
│  │ ▶ session_mno345  Current session (active)                            │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         │ Session.archive("session_ghi789")
         │ Session.archive("session_jkl012")
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Archival Process                                                             │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  session_ghi789:                                                    │    │
│  │    time.archived = Date.now()  ◀── Soft delete marker               │    │
│  │                                                                     │    │
│  │  session_jkl012:                                                    │    │
│  │    time.archived = Date.now()                                       │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  Event: session.updated published                                           │
│  - UI refreshes sidebar                                                      │
│  - Archived sessions filtered from active list                               │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Session List After Archival                                                  │
│                                                                              │
│  Active Sessions:                                                            │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │ ▶ session_abc123  Auth implementation (2 days ago)                    │ │
│  │ ▶ session_def456  Bug fix - login flow (1 week ago)                   │ │
│  │ ▶ session_mno345  Current session (active)                            │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  [Show Archived (2)]  ◀── Click to expand                                   │
│                                                                              │
│  Archived Sessions:                                                          │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │ ○ session_ghi789  Refactor database layer (archived)                  │ │
│  │ ○ session_jkl012  Documentation updates (archived)                    │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

Archival vs Deletion:
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  Feature          │  Archival          │  Deletion                           │
│  ─────────────────┼────────────────────┼───────────────────                  │
│  Data preserved   │  ✓ Yes             │  ✗ No                               │
│  Accessible by ID │  ✓ Yes             │  ✗ No                               │
│  Shows in list    │  ✗ Hidden/Filtered │  ✗ Gone                             │
│  Can restore      │  ✓ Yes             │  ✗ No                               │
│  Storage used     │  ✓ Yes             │  ✗ Freed                            │
│                                                                              │
│  Use archival for completed projects you might reference later.             │
│  Use deletion for sessions you definitely don't need.                       │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

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

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SESSION DELETION                                     │
└─────────────────────────────────────────────────────────────────────────────┘

Before Deletion:
┌─────────────────────────────────────────────────────────────────────────────┐
│ Storage: ~/.opencode/session/session_abc123/                                 │
│                                                                              │
│ session_abc123/                                                              │
│ ├── meta.json              2.3 KB                                          │
│ ├── message/                                                                 │
│ │   ├── msg_001.json       1.2 KB                                          │
│ │   ├── msg_002.json       0.8 KB                                          │
│ │   ├── msg_003.json       2.1 KB                                          │
│ │   └── ...                ~150 KB total                                   │
│ ├── snapshot/                                                                │
│ │   ├── snap_001.json      45 KB                                           │
│ │   └── snap_002.json      42 KB                                           │
│ └── todo.json              0.5 KB                                          │
│                                                                              │
│ Total: ~244 KB                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         │ Session.remove("session_abc123")
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Deletion Process                                                             │
│                                                                              │
│ Step 1: Publish Event                                                        │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │ Event Bus: session.deleted                                              │ │
│ │   { sessionID: "session_abc123" }                                       │ │
│ │                                                                         │ │
│ │ Subscribers:                                                            │ │
│ │ - UI removes from sidebar                                               │ │
│ │ - Analytics records deletion                                            │ │
│ │ - Cleanup tasks triggered                                               │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│ Step 2: Delete Files                                                         │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │ rm -rf ~/.opencode/session/session_abc123/                              │ │
│ │                                                                         │ │
│ │ ✓ meta.json        DELETED                                              │ │
│ │ ✓ message/         DELETED                                              │ │
│ │ ✓ snapshot/        DELETED                                              │ │
│ │ ✓ todo.json        DELETED                                              │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│ Step 3: Update Index                                                         │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │ sessionMap.delete("session_abc123")                                     │ │
│ │                                                                         │ │
│ │ In-memory cache cleared                                                 │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ After Deletion                                                               │
│                                                                              │
│ Storage: ~/.opencode/session/session_abc123/                                 │
│                                                                              │
│ ls: No such file or directory                                                │
│                                                                              │
│ Space Freed: ~244 KB                                                         │
│                                                                              │
│ ⚠️  This action is irreversible!                                            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

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

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PARENT-CHILD SESSION HIERARCHY                            │
└─────────────────────────────────────────────────────────────────────────────┘

Session Tree Structure:
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│                         ┌──────────────────┐                                 │
│                         │  Main Session    │                                 │
│                         │  session_main    │                                 │
│                         │  parentID: null  │                                 │
│                         └────────┬─────────┘                                 │
│                                  │                                           │
│              ┌───────────────────┼───────────────────┐                       │
│              │                   │                   │                       │
│              ▼                   ▼                   ▼                       │
│     ┌──────────────┐   ┌──────────────┐   ┌──────────────┐                  │
│     │ Child 1      │   │ Child 2      │   │ Child 3      │                  │
│     │ session_c1   │   │ session_c2   │   │ session_c3   │                  │
│     │ parentID:    │   │ parentID:    │   │ parentID:    │                  │
│     │ session_main │   │ session_main │   │ session_main │                  │
│     └──────┬───────┘   └──────┬───────┘   └──────┬───────┘                  │
│            │                  │                  │                          │
│     @explorer          @librarian          @fixer                           │
│     (Code search)      (Doc research)    (Implementation)                   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Child Session Creation

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CHILD SESSION CREATION FLOW                               │
└─────────────────────────────────────────────────────────────────────────────┘

Parent Session Flow:
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│ User: "Implement authentication"                                             │
│      │                                                                       │
│      ▼                                                                       │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │ Main Session (Orchestrator)                                             │ │
│ │                                                                         │ │
│ │ Decision: Need to research auth patterns and find examples              │ │
│ │                                                                         │ │
│ │ "I'll delegate this to specialist agents..."                            │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
│      │                                                                       │
│      ├──────────────────────────────────────────────────────────────────┐   │
│      │                                                                  │   │
│      ▼                                                                  ▼   │
│ ┌────────────────────┐                                      ┌────────────┐│ │
│ │ Session.create({   │                                      │ Session.create││ │
│ │   parentID:        │                                      │({            ││ │
│ │   session_main,    │                                      │   parentID:  ││ │
│ │   title:           │                                      │   session_   ││ │
│ │   "Explore auth",  │                                      │   main,      ││ │
│ │   agent: "explorer│                                      │   title:     ││ │
│ │ "                  │                                      │   "Research   ││ │
│ │ })                 │                                      │   auth",     ││ │
│ └────────┬───────────┘                                      │   agent:     ││ │
│          │                                                  │   "librarian"││ │
│          │                                                  │ })           ││ │
│          │                                                  └──────┬───────┘│ │
│          │                                                         │        │ │
│          ▼                                                         ▼        │ │
│ ┌────────────────────┐                                  ┌────────────┐    │ │
│ │ Child Session 1    │                                  │ Child      │    │ │
│ │ session_explore    │                                  │ Session 2  │    │ │
│ │                    │                                  │ session_lib│    │ │
│ │ Isolated context:  │                                  │            │    │ │
│ │ • Own messages     │                                  │ Isolated   │    │ │
│ │ • Own permissions  │                                  │ context:   │    │ │
│ │ • No parent todos  │                                  │ • Own msgs │    │ │
│ └────────┬───────────┘                                  └─────┬──────┘    │ │
│          │                                                   │           │ │
│          │ [Search codebase]                                 │ [Fetch docs]│ │
│          │                                                   │           │ │
│          ▼                                                   ▼           │ │
│ ┌────────────────────┐                                  ┌────────────┐   │ │
│ │ Result:            │                                  │ Result:    │   │ │
│ │ "Found auth        │                                  │ "Best       │   │ │
│ │ patterns in        │                                  │ practices:  │   │ │
│ │ src/auth/*"        │                                  │ JWT +       │   │ │
│ └────────┬───────────┘                                  │ refresh     │   │ │
│          │                                              │ tokens"     │   │ │
│          │                                              └─────┬──────┘   │ │
│          │                                                    │          │ │
│          └────────────────────┬───────────────────────────────┘          │ │
│                               │                                          │ │
│                               ▼                                          │ │
│                    ┌────────────────────┐                                │ │
│                    │ Results returned   │                                │ │
│                    │ to parent as       │                                │ │
│                    │ single message     │                                │ │
│                    └────────┬───────────┘                                │ │
│                             │                                            │ │
│                             ▼                                            │ │
│              ┌──────────────────────────────────────┐                    │ │
│              │ Main Session receives:               │                    │ │
│              │ @explorer: Found patterns in...      │                    │ │
│              │ @librarian: Best practices are...    │                    │ │
│              │                                      │                    │ │
│              │ [Synthesizes and continues]          │                    │ │
│              └──────────────────────────────────────┘                    │ │
│                                                                          │ │
└──────────────────────────────────────────────────────────────────────────┘ │
```

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

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CHILD SESSION USE CASES                                   │
└─────────────────────────────────────────────────────────────────────────────┘

1. SUBAGENT EXECUTION
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│   Main (Orchestrator)                                                        │
│        │                                                                     │
│        ├───────────▶ @explorer  (Child session)                             │
│        │              "Search codebase"                                       │
│        │                                                                     │
│        ├───────────▶ @librarian  (Child session)                            │
│        │              "Fetch docs"                                            │
│        │                                                                     │
│        └───────────▶ @fixer  (Child session - after research)               │
│                       "Implement feature"                                    │
│                                                                              │
│   Benefit: Each agent has isolated context, no pollution                     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

2. PARALLEL TASKS
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│   Main Session                                                               │
│        │                                                                     │
│        ├───▶ Child A: "Search for API endpoints"    ──┐                     │
│        │                                              │                     │
│        ├───▶ Child B: "Check database schema"         │──▶ Parallel execution│
│        │                                              │                     │
│        └───▶ Child C: "Review test coverage"     ─────┘                     │
│                                                                              │
│   All three searches happen simultaneously!                                  │
│   Results aggregated when all complete.                                      │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

3. SANDBOXED OPERATIONS
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│   Main Session                                                               │
│        │                                                                     │
│        │  "Try experimental refactor"                                        │
│        ▼                                                                     │
│   ┌──────────────────┐                                                       │
│   │ Child Session    │  ◀── Isolated environment                             │
│   │ (Sandbox)        │                                                       │
│   │                  │                                                       │
│   │ If it works:     │                                                       │
│   │   Return results │──▶ Apply to main                                      │
│   │                  │                                                       │
│   │ If it breaks:    │                                                       │
│   │   Just delete    │──▶ No harm done!                                      │
│   │   child session  │                                                       │
│   └──────────────────┘                                                       │
│                                                                              │
│   Benefit: Safe experimentation without risk                                 │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

Key Properties:
1. **Subagent Execution** - explore agent searching codebase, librarian agent fetching docs, general agent doing research
2. **Parallel Tasks** - Multiple search angles simultaneously, independent investigations, isolated context per task
3. **Sandboxed Operations** - Risky operations in isolated session, test different approaches, rollback-friendly

## Snapshot System

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SNAPSHOT SYSTEM                                      │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  SNAPSHOT CREATION FLOW                                                      │
└─────────────────────────────────────────────────────────────────────────────┘

Session: Working on feature
┌─────────────────────────────────────────────────────────────────────────────┐
│ Message History                                                              │
│                                                                              │
│ msg_001  User: "Add authentication"                                          │
│ msg_002  Assistant: [creates auth.ts]                                        │
│ msg_003  User: "Add tests"                                                   │
│ msg_004  Assistant: [creates auth.test.ts]   ◀── SNAPSHOT POINT             │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         │ Snapshot.create({
         │   sessionID: "session_abc123",
         │   messageID: "msg_004"
         │ })
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Capture Project State                                                        │
│                                                                              │
│ Scanning working directory...                                                │
│                                                                              │
│ Files captured:                                                              │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │ src/auth.ts              4.2 KB    hash: a3f7d2...                       │ │
│ │ src/auth.test.ts         2.1 KB    hash: b8e9c1...                       │ │
│ │ src/utils/helpers.ts     1.5 KB    hash: c5d2a8...                       │ │
│ │ package.json             0.8 KB    hash: d1e4f7...                       │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│ Total: 4 files, 8.6 KB                                                       │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Store Snapshot                                                               │
│                                                                              │
│ ~/.opencode/session/session_abc123/snapshot/snap_001.json                    │
│                                                                              │
│ {                                                                            │
│   id: "snap_001",                                                            │
│   sessionID: "session_abc123",                                               │
│   messageID: "msg_004",                                                      │
│   time: { created: 1736708258000 },                                          │
│   files: [                                                                   │
│     { path: "src/auth.ts", content: "...", hash: "a3f7d2..." },              │
│     { path: "src/auth.test.ts", content: "...", hash: "b8e9c1..." },         │
│     { path: "src/utils/helpers.ts", content: "...", hash: "c5d2a8..." },     │
│     { path: "package.json", content: "...", hash: "d1e4f7..." }              │
│   ]                                                                          │
│ }                                                                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

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

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SNAPSHOT DIFF & COMPARE                              │
└─────────────────────────────────────────────────────────────────────────────┘

Compare Two Snapshots:
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  Snapshot A (Before)          Snapshot B (After)                            │
│  snap_001                     snap_002                                       │
│  10:00 AM                     11:30 AM                                       │
│                                                                              │
│  src/auth.ts                  src/auth.ts                                    │
│  ────────────────             ────────────────                               │
│  export function              export function                                │
│  login(user) {                login(user, options) {  ◀── MODIFIED          │
│    // TODO                    const token = ...                              │
│  }                              ...                                          │
│                                                                              │
│  src/new.ts                   src/new.ts          ◀── ADDED                  │
│  (not present)                export const helper...                         │
│                                                                              │
│  src/old.ts                   src/old.ts          ◀── DELETED                │
│  export const util...         (not present)                                  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         │ Snapshot.diff({ from: "snap_001", to: "snap_002" })
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Diff Result                                                                  │
│                                                                              │
│ {                                                                            │
│   additions: 42,                                                             │
│   deletions: 18,                                                             │
│   files: 3,                                                                  │
│   diffs: [                                                                   │
│     {                                                                        │
│       path: "src/auth.ts",                                                   │
│       diff: "@@ -1,5 +1,8 @@...",  ◀── Unified diff format                   │
│       additions: 12,                                                         │
│       deletions: 3,                                                          │
│       status: "modified"                                                     │
│     },                                                                       │
│     {                                                                        │
│       path: "src/new.ts",                                                    │
│       additions: 28,                                                         │
│       deletions: 0,                                                          │
│       status: "added"                                                        │
│     },                                                                       │
│     {                                                                        │
│       path: "src/old.ts",                                                    │
│       additions: 0,                                                          │
│       deletions: 15,                                                         │
│       status: "deleted"                                                      │
│     }                                                                        │
│   ]                                                                          │
│ }                                                                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

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

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SESSION REVERT FLOW                                  │
└─────────────────────────────────────────────────────────────────────────────┘

Before Revert (something went wrong):
┌─────────────────────────────────────────────────────────────────────────────┐
│ Session: session_abc123                                                      │
│                                                                              │
│ Current State (Broken):                                                      │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │ src/app.ts        ❌ Broken - errors everywhere                         │ │
│ │ src/utils.ts      ❌ Modified incorrectly                               │ │
│ │ src/config.ts     ❌ Wrong values                                       │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│ Message History:                                                             │
│ msg_001-010: [Initial work]                                                  │
│ msg_011-015: [Good changes]         ◀── REVERT TO HERE (snapshot snap_003)  │
│ msg_016-020: [Recent bad changes]   ◀── Current (broken)                    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         │ Session.revert({
         │   sessionID: "session_abc123",
         │   messageID: "msg_015",
         │   snapshot: "snap_003"
         │ })
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Revert Process                                                               │
│                                                                              │
│ Step 1: Load Snapshot                                                        │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │ Loading snap_003 (from msg_015)                                         │ │
│ │                                                                         │ │
│ │ Files in snapshot:                                                      │ │
│ │ ✓ src/app.ts         (working version)                                  │ │
│ │ ✓ src/utils.ts       (correct implementation)                           │ │
│ │ ✓ src/config.ts      (proper values)                                    │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│ Step 2: Restore Files                                                        │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │ Writing snapshot contents to working directory...                       │ │
│ │                                                                         │ │
│ │ ✓ src/app.ts        RESTORED                                            │ │
│ │ ✓ src/utils.ts      RESTORED                                            │ │
│ │ ✓ src/config.ts     RESTORED                                            │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │ │
│                                                                              │
│ Step 3: Update Metadata                                                      │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │ session.revert = {                                                      │ │
│ │   messageID: "msg_015",                                                 │ │
│ │   snapshot: "snap_003",                                                 │ │
│ │   time: Date.now()                                                      │ │
│ │ }                                                                       │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│ Step 4: Truncate Messages                                                    │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │ BEFORE:                        AFTER:                                   │ │
│ │                                                                         │ │
│ │ msg_001-010: [Initial work]    msg_001-010: [Initial work]              │ │
│ │ msg_011-015: [Good changes]    msg_011-015: [Good changes]              │ │
│ │ msg_016-020: [Bad changes]  ❌  (deleted)                               │ │
│ │ msg_021: Revert message       msg_021: "Reverted to msg_015"            │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ After Revert                                                                 │
│                                                                              │
│ Current State (Restored):                                                    │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │ src/app.ts        ✓ Working correctly                                   │ │
│ │ src/utils.ts      ✓ Correct implementation                              │ │
│ │ src/config.ts     ✓ Proper values                                       │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│ Session ready to continue from restored state!                               │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

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
