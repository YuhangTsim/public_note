# Task Completion & Agent Run Lifecycle

This document explains how Clawdbot detects task completion, manages agent run states, and handles multi-turn conversations across channel platforms.

## Table of Contents
- [Overview](#overview)
- [Agent Run Lifecycle](#agent-run-lifecycle)
- [Completion Detection](#completion-detection)
- [Session Management](#session-management)
- [Embedded Runner Architecture](#embedded-runner-architecture)
- [Streaming & Events](#streaming--events)
- [Key Files](#key-files)

---

## Overview

Clawdbot's task completion system coordinates between:
1. **Pi agent runtime** - Claude API streaming responses
2. **Tool execution** - Bash, file operations, skills
3. **Channel platforms** - Discord, Telegram, WhatsApp, etc.
4. **Session state** - Multi-turn conversation context

**Core principle:** A task is complete when the agent emits `stop_reason: "end_turn"` and all tool invocations finish executing.

---

## Agent Run Lifecycle

### Run States

Runs progress through distinct states:

```
1. CREATED → Agent run initialized
2. STREAMING → Receiving blocks from Claude API
3. TOOL_EXECUTING → Tool invocations in progress
4. COMPLETED → stop_reason=end_turn received, all tools finished
5. ERROR → Unrecoverable failure
```

### From Pi Coding Agent Runtime

Clawdbot uses `@mariozechner/pi-coding-agent` which provides:

**Stream Events:**
```typescript
// Agent emits these events during execution
type AgentEvent =
  | { type: "message_start"; message: Message }
  | { type: "content_block_start"; index: number; content_block: ContentBlock }
  | { type: "content_block_delta"; index: number; delta: ContentBlockDelta }
  | { type: "content_block_stop"; index: number }
  | { type: "message_delta"; delta: MessageDelta }
  | { type: "message_stop" };
```

**Stop Reasons:**
```typescript
type StopReason = 
  | "end_turn"       // Agent finished naturally
  | "max_tokens"     // Hit token limit
  | "stop_sequence"  // Encountered stop sequence
  | "tool_use";      // Deprecated, should not occur
```

### Completion Criteria

A run is complete when **ALL** conditions met:
1. ✅ Received `message_stop` event
2. ✅ `stop_reason === "end_turn"`
3. ✅ All tool invocations completed or failed
4. ✅ No pending tool approvals

**From `src/agents/pi-embedded-runner/run.ts`:**
```typescript
// Simplified completion check
function isRunComplete(state: RunState): boolean {
  return (
    state.stopReason === "end_turn" &&
    state.toolExecutions.every(tool => tool.status === "completed" || tool.status === "failed") &&
    !state.hasPendingApprovals
  );
}
```

---

## Completion Detection

### Multi-Turn vs Single-Turn

**Single-Turn** (one-shot):
- User sends message
- Agent responds with `end_turn`
- Conversation ends

**Multi-Turn** (dialogue):
- User sends message
- Agent responds with `end_turn`
- User sends follow-up
- Agent continues with context from previous turns

### Context Preservation

**From `src/routing/session-key.ts`:**
```typescript
// Session keys identify conversation contexts
export function buildSessionKey(params: {
  workspaceId: string;
  agentId: string;
  channel: ChannelId;
  peerId?: string;  // For DM scope isolation
}): string {
  const parts = [params.workspaceId, params.agentId, params.channel];
  if (params.peerId) parts.push(params.peerId);
  return parts.join(":");
}
```

**Session Scopes:**
```yaml
# .clawdbot/config.yaml
session:
  dmScope: per-channel-peer  # or: main, per-channel
```

| Scope | Behavior |
|-------|----------|
| `main` | All DMs share one session (⚠️ can leak context between users) |
| `per-channel` | Each channel has isolated session |
| `per-channel-peer` | Each DM sender gets isolated session (recommended) |

---

## Session Management

### Session Lifecycle

**From `src/routing/session.ts`:**
```typescript
export type SessionState = {
  id: string;
  agentId: string;
  workspaceDir: string;
  createdAt: number;
  lastMessageAt: number;
  messageCount: number;
  turns: Turn[];  // Full conversation history
  toolResults: ToolResult[];
};
```

### Turn Structure

```typescript
export type Turn = {
  role: "user" | "assistant";
  content: ContentBlock[];
  timestamp: number;
};

type ContentBlock =
  | { type: "text"; text: string }
  | { type: "tool_use"; id: string; name: string; input: unknown }
  | { type: "tool_result"; tool_use_id: string; content: unknown };
```

### Session Persistence

Sessions are stored in:
```
~/.clawdbot/state/sessions/<session-key>.json
```

**Auto-pruning:** Old sessions are pruned based on:
- `session.maxAge` (default: 7 days)
- `session.maxTurns` (default: 100 turns)

---

## Embedded Runner Architecture

The `pi-embedded-runner` orchestrates agent execution within Clawdbot's event-driven architecture.

### Core Components

**From `src/agents/pi-embedded-runner/run.ts`:**
```typescript
export async function createAgentRun(params: CreateAgentRunParams): Promise<AgentRun> {
  const run = {
    id: crypto.randomUUID(),
    agentId: params.agentId,
    sessionId: params.sessionId,
    state: "created",
    tools: buildToolRegistry(params.config, params.agentId),
    skillsPrompt: resolveSkillsPrompt(params),
    workspacePrompt: buildWorkspacePrompt(params),
  };
  
  // Start streaming
  const stream = await startAgentStream(run);
  
  // Attach event handlers
  stream.on("message_start", (event) => handleMessageStart(run, event));
  stream.on("content_block_delta", (event) => handleContentDelta(run, event));
  stream.on("tool_use", (event) => handleToolUse(run, event));
  stream.on("message_stop", (event) => handleMessageStop(run, event));
  
  return run;
}
```

### Tool Execution Flow

```
1. Agent emits tool_use block
   ├─→ Validate tool exists and is allowed
   ├─→ Check exec-approvals.json (for bash)
   ├─→ If sandbox: check sandbox policy
   └─→ Execute tool or request approval

2. Tool execution
   ├─→ Synchronous: wait for result
   └─→ Async: poll for completion

3. Tool result
   ├─→ Inject tool_result block into context
   └─→ Resume agent execution

4. Agent processes result
   └─→ Either uses result or requests more tools
```

### Run Registry

**From `src/agents/pi-embedded-runner/runs.ts`:**
```typescript
// Active runs are tracked in memory
const ACTIVE_RUNS = new Map<string, AgentRun>();

export function registerRun(run: AgentRun): void {
  ACTIVE_RUNS.set(run.id, run);
}

export function unregisterRun(runId: string): void {
  ACTIVE_RUNS.delete(runId);
}

export function getActiveRun(runId: string): AgentRun | undefined {
  return ACTIVE_RUNS.get(runId);
}
```

**Cleanup:** Runs are unregistered when:
- `message_stop` received AND all tools finished
- Run encounters fatal error
- User cancels run explicitly

---

## Streaming & Events

### Block Streaming

Agent responses stream in real-time:

```typescript
// Simplified streaming handler
async function streamAgentResponse(run: AgentRun, channelAdapter: ChannelAdapter) {
  let currentMessage = "";
  
  run.on("content_block_delta", (event) => {
    if (event.delta.type === "text_delta") {
      currentMessage += event.delta.text;
      // Update channel message incrementally
      channelAdapter.updateMessage(run.channelMessageId, currentMessage);
    }
  });
  
  run.on("content_block_stop", (event) => {
    if (event.index === run.finalBlockIndex) {
      // Finalize message
      channelAdapter.finalizeMessage(run.channelMessageId, currentMessage);
    }
  });
}
```

### Tool Execution Events

```typescript
run.on("tool_use", async (event) => {
  const tool = run.tools.get(event.name);
  if (!tool) {
    injectToolResult(run, {
      tool_use_id: event.id,
      content: `Error: Tool '${event.name}' not found`,
      is_error: true
    });
    return;
  }
  
  // Execute tool asynchronously
  const result = await executeTool(tool, event.input);
  
  // Inject result back into run
  injectToolResult(run, {
    tool_use_id: event.id,
    content: result.output,
    is_error: result.error !== null
  });
});
```

### Heartbeat System

For long-running operations, Clawdbot sends heartbeat tokens:

```typescript
const HEARTBEAT_INTERVAL_MS = 5000;
const HEARTBEAT_TOKEN = "⏳";  // or platform-specific indicator

function startHeartbeat(run: AgentRun, channelAdapter: ChannelAdapter) {
  const interval = setInterval(() => {
    if (run.state !== "tool_executing") {
      clearInterval(interval);
      return;
    }
    channelAdapter.sendTypingIndicator();  // or append "⏳"
  }, HEARTBEAT_INTERVAL_MS);
}
```

---

## Key Files

### Agent Execution Core
- **`src/agents/pi-embedded-runner/run.ts`** (~800 lines) - Main agent run orchestrator
- **`src/agents/pi-embedded-runner/runs.ts`** (~200 lines) - Run registry and lifecycle management
- **`src/agents/agent-scope.ts`** - Agent configuration resolution

### Session Management
- **`src/routing/session.ts`** - Session state and persistence
- **`src/routing/session-key.ts`** - Session key generation
- **`src/routing/session-storage.ts`** - File-based session storage

### Tool Execution
- **`src/agents/tools/bash-tools.exec.ts`** (1496 lines) - Bash tool with approval system
- **`src/agents/tools/clawdbot-tools.ts`** - Core file operations (read, write, edit, grep)
- **`src/agents/tool-registry.ts`** - Tool discovery and registration

### Channel Integration
- **`src/channels/plugins/*.ts`** - Channel-specific adapters (Discord, Telegram, etc.)
- **`src/commands/agent/run-context.ts`** - Context building for agent runs
- **`src/commands/agent/router.ts`** - Message routing to appropriate agent/session

### Node Host (Sandbox)
- **`src/node-host/runner.ts`** - Isolated agent execution in separate process

---

## Completion Scenarios

### Scenario 1: Simple Question

```
User: "What's the current time?"
→ Agent runs `bash` tool: date
→ Tool returns: "Mon Jan 26 10:21:22 EST 2026"
→ Agent responds: "It's 10:21 AM EST on Monday, January 26, 2026."
→ stop_reason: "end_turn"
✅ COMPLETED
```

### Scenario 2: Multi-Step Task

```
User: "Create a new file hello.txt with 'Hello World'"
→ Agent runs `write` tool
→ Tool creates file
→ Agent responds: "Created hello.txt with 'Hello World'"
→ stop_reason: "end_turn"
✅ COMPLETED
```

### Scenario 3: Approval Required

```
User: "Run npm install"
→ Agent runs `bash` tool: npm install
→ Exec-approvals.json security="deny", command not in allowlist
→ Tool status: "pending_approval"
→ Clawdbot prompts: "Approve 'npm install'? (y/n)"
→ User responds: "y"
→ Tool executes, returns result
→ Agent continues with result
→ stop_reason: "end_turn"
✅ COMPLETED
```

### Scenario 4: Max Tokens

```
User: "Explain quantum physics in detail"
→ Agent streams long response...
→ Hits max_tokens limit
→ stop_reason: "max_tokens"
⚠️ INCOMPLETE (but saved to session)
User follow-up: "Continue"
→ Agent resumes from context
→ stop_reason: "end_turn"
✅ COMPLETED
```

### Scenario 5: Tool Error

```
User: "Read file that-does-not-exist.txt"
→ Agent runs `read` tool
→ Tool returns: error="File not found"
→ Agent responds: "The file that-does-not-exist.txt doesn't exist..."
→ stop_reason: "end_turn"
✅ COMPLETED (task failed, but agent finished gracefully)
```

---

## Best Practices

### For Developers

1. **Always handle all stop reasons** - Don't assume `end_turn`
2. **Cleanup on completion** - Unregister runs, close streams
3. **Stream incrementally** - Update UI as blocks arrive
4. **Preserve context** - Save sessions after each turn
5. **Timeout long operations** - Set reasonable limits for tool execution

### For Configuration

```yaml
# Recommended session config
session:
  dmScope: per-channel-peer  # Isolate DM conversations
  maxAge: 604800000           # 7 days in ms
  maxTurns: 100               # Prune old sessions
  
# Recommended agent config
agents:
  list:
    - id: default
      maxTokens: 8192         # Reasonable limit
      tools:
        timeout: 300000       # 5-minute tool timeout
```

---

## Related Documentation

- [Tool System](./03_tool_system.md) - How tools execute and report completion
- [Access Control](./05_access_control.md) - Approval systems that affect completion
- [Gateway Architecture](./08_gateway_architecture.md) - WebSocket event streaming
