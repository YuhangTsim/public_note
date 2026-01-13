# Task Completion Detection in OpenCode

## Overview

Task completion detection is the mechanism by which OpenCode determines when an AI agent has finished its work and control should return to the user. This is a critical coordination point in the agent lifecycle - the system must know when to keep the agent running (for multi-step tasks) versus when to stop and wait for new user input.

Unlike traditional programs with explicit return statements, LLM-based agents signal completion through **finish reasons** provided by the language model provider (Anthropic, OpenAI, Google, etc.). OpenCode's streaming architecture processes these signals in real-time to make continuation decisions.

---

## LLM Finish Reasons

When a language model completes a response, it provides a **finish reason** indicating why it stopped generating tokens. These reasons come from the underlying provider (via Vercel AI SDK) and directly influence whether OpenCode continues the agent loop or returns control to the user.

### Standard Finish Reasons

| Finish Reason    | Meaning                                | OpenCode Behavior                                     |
| ---------------- | -------------------------------------- | ----------------------------------------------------- |
| `stop`           | Model naturally completed its response | **STOP** - Return to user (task complete)             |
| `tool-calls`     | Model wants to execute tools           | **CONTINUE** - Execute tools, then loop back to model |
| `length`         | Hit maximum token limit                | **STOP** - May trigger compaction if needed           |
| `content-filter` | Response blocked by safety filters     | **STOP** - Treated as error                           |
| `error`          | Provider-level error occurred          | **STOP** or **RETRY** depending on error type         |

### Key Insight

The `stop` vs `tool-calls` distinction is fundamental:

- **`tool-calls`**: Model is mid-task and needs to perform actions → **keep running**
- **`stop`**: Model is done and waiting for next user input → **go idle**

This allows multi-step workflows where the agent can:

1. Generate text (thinking)
2. Call tools (acting)
3. Receive tool results
4. Generate more text
5. Call more tools
6. Eventually finish with `stop`

---

## Streaming Architecture

OpenCode uses **streaming responses** from language models, processing events in real-time as they arrive. This enables live UI updates and immediate tool execution without waiting for the complete response.

### Stream Event Types

The Vercel AI SDK (used by OpenCode) provides a `fullStream` iterator that emits these event types:

```
┌─────────────────────────────────────────────────────────────┐
│                    LLM Stream Events                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  start                    → Session becomes "busy"          │
│  reasoning-start          → Create reasoning part           │
│  reasoning-delta          → Stream reasoning tokens         │
│  reasoning-end            → Finalize reasoning part         │
│  start-step               → Begin new inference step        │
│  text-start               → Create text part                │
│  text-delta               → Stream text tokens              │
│  text-end                 → Finalize text part              │
│  tool-call-start          → Begin tool execution            │
│  tool-call                → Enqueue tool for execution      │
│  tool-result              → Tool completed successfully     │
│  tool-error               → Tool failed                     │
│  finish-step              → Step complete (has finishReason)│
│  finish                   → Stream ended                    │
│  error                    → Stream failed                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Event Processing Flow

```
User Message
    │
    ├──▶ LLM.stream(input)  ───────────────────────┐
    │                                              │
    │                          ┌───────────────────▼──────────────┐
    │                          │   Vercel AI SDK Stream           │
    │                          │   (fullStream iterator)          │
    │                          └───────────────────┬──────────────┘
    │                                              │
    ├──▶ SessionProcessor.process()  ◀─────────────┘
    │         │
    │         ├──▶ "start"              → SessionStatus.set("busy")
    │         ├──▶ "text-delta"         → Session.updatePart(text)
    │         ├──▶ "tool-call"          → Queue tool execution
    │         ├──▶ "tool-result"        → Update tool part
    │         ├──▶ "finish-step"        → Capture finishReason
    │         └──▶ "finish"             → Exit stream loop
    │
    ├──▶ Decide: continue or stop?
    │         │
    │         ├──▶ needsCompaction?    → return "compact"
    │         ├──▶ blocked?             → return "stop"
    │         ├──▶ error?               → return "stop"
    │         └──▶ otherwise            → return "continue"
    │
    └──▶ If "continue":  Loop back to LLM.stream()
         If "stop":      SessionStatus.set("idle")
         If "compact":   Trigger compaction, then continue
```

---

## Message Lifecycle

A complete agent turn involves multiple phases:

### 1. **Start Phase**

```typescript
// User sends message
const userMessage = await Session.createUserMessage(input)

// Assistant message created
const assistantMessage = await Session.createAssistantMessage({
  sessionID,
  parentID: userMessage.id,
})

// Session status becomes "busy"
SessionStatus.set(sessionID, { type: "busy" })
```

### 2. **Streaming Phase**

```typescript
// Stream starts
for await (const event of stream.fullStream) {
  switch (event.type) {
    case "text-delta":
      // Real-time text streaming to UI
      await Session.updatePart({ part: currentText, delta: event.text })
      break

    case "tool-call":
      // Queue tool for execution
      toolcalls[event.toolCallId] = { ...event }
      break

    case "tool-result":
      // Tool completed, store result
      await Session.updatePart({ ...toolcalls[event.toolCallId], result: event.result })
      delete toolcalls[event.toolCallId]
      break

    case "finish-step":
      // Capture finish reason
      assistantMessage.finish = event.finishReason
      await Session.updateMessage(assistantMessage)
      break
  }
}
```

### 3. **Decision Phase**

```typescript
// After stream completes, decide next action
if (needsCompaction) return "compact"
if (blocked) return "stop" // Permission denied / question rejected
if (assistantMessage.error) return "stop"
return "continue" // Default: keep agent running
```

### 4. **Completion Phase**

```typescript
// If decision is "stop"
assistantMessage.time.completed = Date.now()
await Session.updateMessage(assistantMessage)
SessionStatus.set(sessionID, { type: "idle" })
Bus.publish(Session.Event.Idle, { sessionID })

// UI receives "idle" event and shows prompt again
```

---

## Decision Logic: Continue vs Stop

The `SessionProcessor.process()` function returns one of three values after each stream completes:

### Return Values

| Return Value | Trigger Condition                                    | Next Action                                     |
| ------------ | ---------------------------------------------------- | ----------------------------------------------- |
| `"continue"` | Model has more work (tool-calls finish reason)       | Loop: Call LLM.stream() again with tool results |
| `"stop"`     | Model finished, error occurred, or permission denied | Exit: Set status to "idle", notify user         |
| `"compact"`  | Token overflow detected                              | Trigger compaction, then continue               |

### Implementation (from `processor.ts:395-400`)

```typescript
input.assistantMessage.time.completed = Date.now()
await Session.updateMessage(input.assistantMessage)

if (needsCompaction) return "compact"
if (blocked) return "stop"
if (input.assistantMessage.error) return "stop"
return "continue"
```

### Special Cases

#### Blocked State

```typescript
// Set when permission is rejected or question is rejected
if (value.error instanceof PermissionNext.RejectedError || value.error instanceof Question.RejectedError) {
  blocked = shouldBreak // Controlled by config.experimental.continue_loop_on_deny
}
```

If `continue_loop_on_deny` is `false` (default), the agent stops immediately when user denies permission. If `true`, the agent can continue working on other tasks.

#### Compaction State

```typescript
// Check after each step completes
if (await SessionCompaction.isOverflow({ tokens: usage.tokens, model: input.model })) {
  needsCompaction = true
}
```

When the conversation becomes too long (exceeds model context window), OpenCode triggers **compaction** - a summarization process that condenses old messages while preserving important context.

#### Error State with Retry

```typescript
// Retryable errors (rate limits, temporary outages)
const retry = SessionRetry.retryable(error)
if (retry !== undefined) {
  attempt++
  const delay = SessionRetry.delay(attempt, error)
  SessionStatus.set(input.sessionID, {
    type: "retry",
    attempt,
    message: retry,
    next: Date.now() + delay,
  })
  await SessionRetry.sleep(delay, input.abort)
  continue // Try again
}
```

Transient errors (rate limits, network issues) trigger exponential backoff retry logic. Only after max retries does the session actually stop with error.

---

## Session Status Management

OpenCode maintains real-time session status to coordinate UI display and prevent race conditions.

### Status Types (from `status.ts`)

```typescript
type SessionStatus =
  | { type: "idle" } // Waiting for user input
  | { type: "busy" } // Agent actively working
  | {
      type: "retry" // Waiting to retry after error
      attempt: number
      message: string
      next: number
    } // Timestamp of next retry
```

### Status Transitions

```
┌──────────────────────────────────────────────────────────┐
│                  Session Status Flow                     │
└──────────────────────────────────────────────────────────┘

    User sends message
           │
           ▼
       [  BUSY  ]  ────────────────────────┐
           │                               │
           │ (LLM streaming)               │ (Error + retryable)
           │                               │
           ├─▶ tool-calls                  ▼
           │   (execute tools)        [  RETRY  ]
           │   (loop back to LLM)           │
           │                                │ (wait delay)
           ├─▶ finish-step                  │
           │   (finish reason = "stop")     │
           │                                ▼
           ▼                          [  BUSY  ] (try again)
       [  IDLE  ]  ◀───────────────────────┘
                                      (max retries)
```

### Status Events

```typescript
// Published on every status change
Bus.publish(SessionStatus.Event.Status, {
  sessionID: "ses_abc123",
  status: { type: "busy" },
})

// Also publishes deprecated "idle" event for backward compatibility
Bus.publish(SessionStatus.Event.Idle, {
  sessionID: "ses_abc123",
})
```

UI components subscribe to these events to show loading spinners, retry counters, or re-enable the input prompt.

---

## Oh-My-OpenCode Enhancements

The oh-my-opencode plugin adds advanced completion enforcement through the **`experimental.text.complete`** hook. This hook fires **after each text part is finalized** and allows plugins to inspect/modify the agent's text before the system decides whether to continue or stop.

### Hook Definition (from `plugin/src/index.ts:214-217`)

```typescript
"experimental.text.complete"?: (
  input: { sessionID: string; messageID: string; partID: string },
  output: { text: string },
) => Promise<void>
```

### Hook Invocation (from `processor.ts:308-317`)

```typescript
case "text-end":
  if (currentText) {
    currentText.text = currentText.text.trimEnd()
    const textOutput = await Plugin.trigger(
      "experimental.text.complete",
      {
        sessionID: input.sessionID,
        messageID: input.assistantMessage.id,
        partID: currentText.id,
      },
      { text: currentText.text },
    )
    currentText.text = textOutput.text  // Hook can modify text
    await Session.updatePart(currentText)
  }
```

### TODO Continuation Enforcer

Oh-my-opencode uses this hook to implement **mandatory TODO completion**. If the agent tries to finish with incomplete TODOs, the hook **appends a system reminder** to force continuation:

**Pseudo-code** (based on prompt patterns found):

```typescript
// In oh-my-opencode plugin
async "experimental.text.complete"(input, output) {
  const todos = await getTodos(input.sessionID)
  const incomplete = todos.filter(t => t.status !== "completed")

  if (incomplete.length > 0) {
    // Append reminder to force agent to continue
    output.text += "\n\n[SYSTEM REMINDER - TODO CONTINUATION]\n"
    output.text += `You have ${incomplete.length} incomplete TODO items:\n`
    incomplete.forEach(todo => {
      output.text += `- [ ] ${todo.content} (${todo.status})\n`
    })
    output.text += "\nYou MUST complete all TODOs before stopping. "
    output.text += "Continue working on the next pending item."
  }
}
```

### Effect on Continuation

Even if the model sends `finishReason: "stop"`, the appended system reminder acts as an **implicit continuation signal**. The agent sees the reminder in context and generates another response to address the incomplete TODOs, effectively converting `stop` into `tool-calls` behavior.

This ensures **zero-drift workflows** where multi-step tasks are guaranteed to complete without user intervention.

---

## Complete Flow Diagram

```
┌───────────────────────────────────────────────────────────────────────┐
│                  OpenCode Task Completion Flow                        │
└───────────────────────────────────────────────────────────────────────┘

USER SENDS MESSAGE
      │
      ▼
┌──────────────────────────────────────────────────────┐
│ Session.createUserMessage()                          │
│ Session.createAssistantMessage()                     │
│ SessionStatus.set("busy")                            │
└──────────────────┬───────────────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────────────┐
│ LLM.stream(input)  ──────────────────┐               │
│   └─▶ Vercel AI SDK                  │               │
│       └─▶ Provider (Anthropic/etc.)  │               │
└──────────────────┬───────────────────┘               │
                   │                                   │
                   │ Stream events                     │
                   │                                   │
                   ▼                                   │
┌──────────────────────────────────────────────────────┤
│ SessionProcessor.process()                           │
│   │                                                  │
│   ├─▶ "start"            → Set status "busy"         │
│   ├─▶ "text-delta"       → Stream to UI              │
│   ├─▶ "tool-call"        → Queue tool                │
│   ├─▶ "tool-result"      → Store result              │
│   ├─▶ "finish-step"      → Capture finishReason      │
│   │                                                  │
│   │   finishReason = ?                               │
│   │         │                                        │
│   │         ├─▶ "tool-calls"  ──────────────┐        │
│   │         ├─▶ "stop"        ──────────────┼──┐     │
│   │         ├─▶ "length"      ──────────────┼──┤     │
│   │         └─▶ "error"       ──────────────┼──┤     │
│   │                                         │  │     │
│   └─▶ "text-end"  ──────────────────────────┼──┤     │
│         │                                   │  │     │
│         ▼                                   │  │     │
│   Plugin.trigger("experimental.text.complete") │     │
│         │                                   │  │     │
│         ├─▶ Oh-my-opencode checks TODOs     │  │     │
│         │   Incomplete? → Append reminder   │  │     │
│         │   Complete? → No change           │  │     │
│         │                                   │  │     │
│         └─▶ Text potentially modified       │  │     │
│                                             │  │     │
│   ◀─────────────────────────────────────────┘  │     │
│   Stream ends                                  │     │
│                                                │     │
└──────────────────┬─────────────────────────────┘     │
                   │                                   │
                   ▼                                   │
┌──────────────────────────────────────────────────────┤
│ Decision Logic:                                      │
│   if (needsCompaction)    return "compact"           │
│   if (blocked)            return "stop"              │
│   if (error)              return "stop"   ───────────┤
│   else                    return "continue"  ────┐   │
└──────────────────┬────────────────────────────┐  │   │
                   │                            │  │   │
          "continue" or "compact"            "stop"│   │
                   │                            │  │   │
                   ▼                            ▼  ▼   │
     ┌─────────────────────────┐    ┌──────────────────┴───┐
     │ Loop back to LLM.stream │    │ SessionStatus.set(   │
     │ with tool results       │    │   "idle"             │
     └─────────────────────────┘    │ )                    │
                   │                │ Bus.publish(         │
                   │                │   Event.Idle         │
                   └────────────────│ )                    │
                                    └──────────────────────┘
                                              │
                                              ▼
                                    USER SEES PROMPT AGAIN
```

---

## Code Examples

### Reading Session Status

```typescript
import { SessionStatus } from "@/session/status"

// Get current status
const status = SessionStatus.get("ses_abc123")

if (status.type === "idle") {
  console.log("Session is ready for input")
} else if (status.type === "busy") {
  console.log("Agent is working...")
} else if (status.type === "retry") {
  console.log(`Retrying (attempt ${status.attempt}) in ${status.next - Date.now()}ms`)
}

// List all active sessions
const allStatuses = SessionStatus.list()
for (const [sessionID, status] of Object.entries(allStatuses)) {
  console.log(`${sessionID}: ${status.type}`)
}
```

### Subscribing to Status Changes

```typescript
import { Bus } from "@/bus"
import { SessionStatus } from "@/session/status"

// Subscribe to status changes
Bus.subscribe(SessionStatus.Event.Status, ({ sessionID, status }) => {
  if (status.type === "idle") {
    // Show input prompt
    showPrompt()
  } else if (status.type === "busy") {
    // Show loading spinner
    showSpinner()
  }
})

// Also available: deprecated "idle" event
Bus.subscribe(SessionStatus.Event.Idle, ({ sessionID }) => {
  console.log(`Session ${sessionID} is now idle`)
})
```

### Implementing a Plugin Hook

```typescript
import type { Plugin } from "@opencode-ai/plugin"

export default async function myPlugin(input): Promise<Plugin> {
  return {
    async "experimental.text.complete"(hookInput, output) {
      // Called after each text part completes
      console.log(`Text completed: ${output.text}`)

      // You can modify the text
      if (output.text.includes("TODO")) {
        output.text += "\n\n[Note: Remember to track your TODOs!]"
      }

      // Or enforce custom rules
      const hasIncompleteWork = checkForIncompleteWork(hookInput.sessionID)
      if (hasIncompleteWork) {
        output.text += "\n\n[SYSTEM]: You have incomplete work. Continue!"
      }
    },
  }
}
```

---

## Key Takeaways

1. **Finish reasons drive continuation**: `tool-calls` means continue, `stop` means done
2. **Streaming enables real-time updates**: Events processed as they arrive, not after completion
3. **Three-way decision**: `continue`, `stop`, or `compact` after each stream
4. **Status management prevents races**: UI always knows if session is `idle`, `busy`, or `retry`
5. **Plugins can enforce completion**: `experimental.text.complete` hook allows modification before decision
6. **Oh-my-opencode enforces TODOs**: Appends reminders to force continuation until all items complete
7. **Retries handle transient errors**: Network issues and rate limits trigger exponential backoff
8. **Compaction prevents overflow**: Long conversations automatically summarized to stay within context limits

---

## Related Documentation

- **[03_session_management.md](./03_session_management.md)** - Session lifecycle and state management
- **[02_agent_system.md](./02_agent_system.md)** - Agent architecture and permissions
- **[10_todo_system.md](./10_todo_system.md)** - TODO tracking and completion enforcement
- **[05_mcp_integration.md](./05_mcp_integration.md)** - Plugin hooks and extensions
