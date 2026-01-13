# Native Protocol (JSON Mode) and Task Completion Detection

This document explains how Roo Code implements the Native Protocol (commonly referred to as "JSON mode") and how task completion is detected in this protocol.

## References
- Protocol resolution: `src/utils/resolveToolProtocol.ts`
- Native tool parser: `src/core/assistant-message/NativeToolCallParser.ts`
- XML parser: `src/core/assistant-message/AssistantMessageParser.ts`
- Tool execution: `src/core/assistant-message/presentAssistantMessage.ts`
- Task completion: `src/core/tools/AttemptCompletionTool.ts`
- Task loop: `src/core/task/Task.ts:2239-3456`

---

## Table of Contents
1. [Protocol Overview](#protocol-overview)
2. [Native Protocol Architecture](#native-protocol-architecture)
3. [Task Completion Detection](#task-completion-detection)
4. [Complete Flow Diagram](#complete-flow-diagram)
5. [Key Differences: XML vs Native](#key-differences-xml-vs-native)
6. [Code Deep Dive](#code-deep-dive)

---

## Protocol Overview

### What Are the Two Protocols?

Roo Code supports two different protocols for tool communication between the model and the application:

#### 1. XML Protocol (Legacy)
**How it works:**
- Tools are described in the system prompt as text instructions
- Model outputs tool calls as XML-formatted text embedded in its response
- Response is parsed character-by-character to extract XML tags
- Tool parameters are string key-value pairs extracted from XML

**Example model response:**
```xml
I'll create a file for you.

<write_to_file>
<path>hello.txt</path>
<file_text>Hello World</file_text>
</write_to_file>
```

#### 2. Native Protocol (Current Standard)
**How it works:**
- Tools are passed to the API as structured function definitions (separate from system prompt)
- Model returns structured `tool_use` blocks with typed JSON arguments
- API streams tool calls as typed chunks with incremental JSON parsing
- Tool arguments are proper JSON objects, not strings

**Example API response:**
```json
{
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "I'll create a file for you."
    },
    {
      "type": "tool_use",
      "id": "toolu_01A7BcD3eFgH4iJkL5mNo6pQ",
      "name": "write_to_file",
      "input": {
        "path": "hello.txt",
        "file_text": "Hello World"
      }
    }
  ]
}
```

### Why "JSON Mode" is Actually "Native Protocol"

The term "JSON mode" is somewhat misleading. What users refer to as "JSON mode" is actually:

- **Native function calling** using the API provider's built-in tool calling mechanism
- **Structured responses** where tool calls are first-class objects, not text
- **JSON Schema validation** where tool parameters are validated against schemas
- **Incremental JSON parsing** during streaming for progressive rendering

The key distinction is that tools are **native API constructs**, not text instructions to be parsed.

---

## Native Protocol Architecture

### 1. Protocol Selection

**File:** `src/utils/resolveToolProtocol.ts:31-78`

```typescript
export function resolveToolProtocol(
  apiConfiguration?: ApiConfiguration,
  modelInfo?: ModelInfo,
  lockedProtocol?: ToolProtocol,
  conversationHistory?: Anthropic.MessageParam[]
): ToolProtocol {
  // If protocol is locked (for resumed tasks), use that
  if (lockedProtocol) {
    return lockedProtocol
  }

  // For new tasks, always use native protocol
  return TOOL_PROTOCOL.NATIVE
}
```

**Key Points:**
- New tasks **always use native protocol** (as of December 2025)
- Protocol is **locked at task creation** to maintain consistency
- Resumed tasks preserve their original protocol via `lockedProtocol`
- XML protocol is **deprecated** but still supported for backward compatibility

### 2. API Stream Chunks

**File:** `src/api/transform/stream.ts:1-115`

When using native protocol, the API stream yields these chunk types:

```typescript
export type ApiStreamChunk =
  | ApiStreamTextChunk              // Plain text content
  | ApiStreamUsageChunk             // Token usage statistics
  | ApiStreamReasoningChunk         // Extended thinking content
  | ApiStreamToolCallPartialChunk   // Streaming tool call (primary)
  | ApiStreamToolCallStartChunk     // Tool call initiated
  | ApiStreamToolCallDeltaChunk     // Incremental JSON arguments
  | ApiStreamToolCallEndChunk       // Tool call completed
  // ... other chunk types
```

**Tool Call Streaming Example:**

```typescript
// Chunk 1: Tool call starts
{
  type: "tool_call_partial",
  index: 0,
  id: "toolu_01ABC",
  name: "write_to_file",
  arguments: ""  // Empty at start
}

// Chunk 2: Arguments begin streaming
{
  type: "tool_call_partial",
  index: 0,
  id: "toolu_01ABC",
  name: "write_to_file",
  arguments: "{\"path\": \"he"  // Partial JSON!
}

// Chunk 3: More arguments
{
  type: "tool_call_partial",
  index: 0,
  id: "toolu_01ABC",
  name: "write_to_file",
  arguments: "{\"path\": \"hello.txt\", \"file_text\": \"Hello Wo"
}

// Chunk 4: Complete arguments
{
  type: "tool_call_partial",
  index: 0,
  id: "toolu_01ABC",
  name: "write_to_file",
  arguments: "{\"path\": \"hello.txt\", \"file_text\": \"Hello World\"}"
}
```

### 3. Incremental JSON Parsing

**File:** `src/core/assistant-message/NativeToolCallParser.ts`

The `NativeToolCallParser` handles streaming tool calls with **incremental JSON parsing**:

```typescript
export class NativeToolCallParser {
  // Track streaming state for each tool call
  private static streamingToolCalls = new Map<string, StreamingToolCallState>()

  // Process raw stream chunks
  static processRawChunk(chunk: {
    index: number
    id?: string
    name?: string
    arguments?: string
  }): ToolCallStreamEvent[] {
    const events: ToolCallStreamEvent[] = []

    // Emit start event when tool name is known
    if (chunk.name && !this.streamingToolCalls.has(chunk.id)) {
      events.push({
        type: "tool_call_start",
        toolCallId: chunk.id,
        toolName: chunk.name
      })

      this.streamingToolCalls.set(chunk.id, {
        id: chunk.id,
        name: chunk.name,
        arguments: ""
      })
    }

    // Emit delta event for argument chunks
    if (chunk.arguments) {
      const state = this.streamingToolCalls.get(chunk.id)
      state.arguments += chunk.arguments

      events.push({
        type: "tool_call_delta",
        toolCallId: chunk.id,
        argumentsDelta: chunk.arguments
      })
    }

    return events
  }

  // Parse incremental JSON during streaming
  static processStreamingChunk(id: string, argumentsChunk: string): ToolUse | null {
    const state = this.streamingToolCalls.get(id)
    if (!state) return null

    // Accumulate arguments
    state.arguments += argumentsChunk

    try {
      // Use partial-json library to parse incomplete JSON!
      const partialArgs = parseJSON(state.arguments)

      return {
        type: "tool_use",
        id: id,
        name: state.name,
        nativeArgs: partialArgs,
        partial: true  // Mark as incomplete
      }
    } catch (e) {
      // Not parseable yet, wait for more chunks
      return null
    }
  }

  // Finalize when stream ends
  static finalizeStreamingToolCall(id: string): ToolUse | McpToolUse | null {
    const state = this.streamingToolCalls.get(id)
    if (!state) return null

    // Parse complete JSON
    const args = JSON.parse(state.arguments)

    // Create final ToolUse object
    const toolUse: ToolUse = {
      type: "tool_use",
      id: id,
      name: state.name as ToolName,
      nativeArgs: args,
      partial: false  // Mark as complete
    }

    // Cleanup
    this.streamingToolCalls.delete(id)

    return toolUse
  }
}
```

**Why Incremental Parsing Matters:**

The `partial-json` library allows parsing incomplete JSON, enabling:
- **Progressive rendering**: UI can display partial tool arguments as they arrive
- **Better UX**: Users see tool parameters filling in real-time
- **Error detection**: Malformed JSON can be detected early

**Parsing example:**
```typescript
// Stream chunk 1
parseJSON("{\"path\":")  // → { path: undefined }

// Stream chunk 2
parseJSON("{\"path\": \"hel")  // → { path: "hel" }

// Stream chunk 3
parseJSON("{\"path\": \"hello.txt\"}")  // → { path: "hello.txt" }
```

### 4. ToolUse Data Structure

**File:** `src/shared/ExtensionMessage.ts`

```typescript
export interface ToolUse<TName extends ToolName = ToolName> {
  type: "tool_use"

  // Native protocol fields
  id?: string                          // Tool call ID (only in native protocol)
  nativeArgs?: ToolParamsV2<TName>     // Typed JSON arguments (native)

  // XML protocol fields
  params: Record<string, string>       // String key-value pairs (XML)

  // Common fields
  name: TName                          // Tool name
  partial?: boolean                    // True during streaming
  originalName?: string                // For aliased tools in history
}
```

**Protocol Detection Logic:**

```typescript
// How Roo determines which protocol a tool call uses:
const toolProtocol = toolUse.id ? "native" : "xml"

if (toolProtocol === "native") {
  // Use nativeArgs (already parsed JSON)
  const args = toolUse.nativeArgs
} else {
  // Parse params (string key-value pairs)
  const args = await tool.parseLegacy(toolUse.params)
}
```

**Key insight:** The presence of an `id` field indicates native protocol!

---

## Task Completion Detection

### Overview

**Task completion is protocol-agnostic** - both XML and Native protocols signal completion the same way:

> The model calls the `attempt_completion` tool with a `result` parameter.

The difference is **how the tool call is communicated**, not **what it means**.

### 1. Model Signals Completion

**Native Protocol:**
```json
{
  "type": "tool_use",
  "id": "toolu_04ABC",
  "name": "attempt_completion",
  "input": {
    "result": "Successfully created an Express.js server with /hello endpoint."
  }
}
```

**XML Protocol:**
```xml
<attempt_completion>
<result>Successfully created an Express.js server with /hello endpoint.</result>
</attempt_completion>
```

### 2. Tool Use Block Created

**File:** `src/core/task/Task.ts:2700-2772`

During stream processing, when a `tool_call_partial` chunk arrives:

```typescript
case "tool_call_partial": {
  // Process chunk through NativeToolCallParser
  const events = NativeToolCallParser.processRawChunk({
    index: chunk.index,
    id: chunk.id,
    name: chunk.name,
    arguments: chunk.arguments,
  })

  for (const event of events) {
    if (event.type === "tool_call_start") {
      // Initialize streaming state
      NativeToolCallParser.initializeStreamingToolCall(event.toolCallId, event.toolName)
    }
    else if (event.type === "tool_call_delta") {
      // Process incremental arguments
      const partialToolUse = NativeToolCallParser.processStreamingChunk(
        event.toolCallId,
        event.argumentsDelta
      )

      // Update assistantMessageContent with partial tool use
      if (partialToolUse) {
        this.assistantMessageContent[index] = partialToolUse
        await presentAssistantMessage(this)
      }
    }
    else if (event.type === "tool_call_end") {
      // Finalize tool call
      const finalToolUse = NativeToolCallParser.finalizeStreamingToolCall(event.toolCallId)

      if (finalToolUse) {
        this.assistantMessageContent[index] = finalToolUse
        await presentAssistantMessage(this)
      }
    }
  }
  break
}
```

**Result:** A `ToolUse` object is added to `assistantMessageContent`:

```typescript
{
  type: "tool_use",
  id: "toolu_04ABC",
  name: "attempt_completion",
  nativeArgs: {
    result: "Successfully created an Express.js server..."
  },
  partial: false
}
```

### 3. Tool Execution Triggered

**File:** `src/core/assistant-message/presentAssistantMessage.ts:45-350`

```typescript
export async function presentAssistantMessage(cline: Task): Promise<void> {
  // Lock to prevent concurrent execution
  if (cline.presentAssistantMessageLocked) return
  cline.presentAssistantMessageLocked = true

  try {
    // Process each content block in assistantMessageContent
    while (cline.currentStreamingContentIndex < cline.assistantMessageContent.length) {
      const block = cline.assistantMessageContent[cline.currentStreamingContentIndex]

      // Handle tool_use blocks
      if (block.type === "tool_use") {
        // Determine protocol by checking for id field
        const toolProtocol = block.id ? "native" : "xml"

        // Check if it's attempt_completion
        if (block.name === "attempt_completion") {
          // Execute completion tool!
          await handleAttemptCompletion(block, cline, toolProtocol)
          break  // Task may end here
        } else {
          // Execute other tools
          await executeTool(block, cline, toolProtocol)
        }
      }

      cline.currentStreamingContentIndex++
    }
  } finally {
    cline.presentAssistantMessageLocked = false
  }
}
```

### 4. Attempt Completion Tool Execution

**File:** `src/core/tools/AttemptCompletionTool.ts:32-152`

```typescript
export class AttemptCompletionTool extends BaseTool<"attempt_completion"> {
  async execute(
    params: AttemptCompletionParams,
    task: Task,
    callbacks: AttemptCompletionCallbacks
  ): Promise<void> {
    const { result } = params
    const { handleError, pushToolResult, askFinishSubTaskApproval } = callbacks

    // VALIDATION: Prevent completion if tools failed in this turn
    if (task.didToolFailInCurrentTurn) {
      const errorMsg = t("common:errors.attempt_completion_tool_failed")
      await task.say("error", errorMsg)
      pushToolResult(formatResponse.toolError(errorMsg))
      return  // Don't complete, continue loop
    }

    // VALIDATION: Check for incomplete todos (if setting enabled)
    const preventCompletionWithOpenTodos = vscode.workspace
      .getConfiguration(Package.name)
      .get<boolean>("preventCompletionWithOpenTodos", false)

    const hasIncompleteTodos = task.todoList &&
      task.todoList.some((todo) => todo.status !== "completed")

    if (preventCompletionWithOpenTodos && hasIncompleteTodos) {
      task.consecutiveMistakeCount++
      task.recordToolError("attempt_completion")

      const errorMsg = "Cannot complete task while there are incomplete todos."
      pushToolResult(formatResponse.toolError(errorMsg))
      return  // Don't complete, continue loop
    }

    // Reset mistake counter
    task.consecutiveMistakeCount = 0

    // Display completion result to user
    await task.say("completion_result", result, undefined, false)

    // Emit final token usage before completion
    task.emitFinalTokenUsageUpdate()

    // Track completion in telemetry
    TelemetryService.instance.captureTaskCompleted(task.taskId)

    // EMIT TASK COMPLETED EVENT
    task.emit(
      RooCodeEventName.TaskCompleted,
      task.taskId,
      task.getTokenUsage(),
      task.toolUsage
    )

    // Handle subtask delegation (if this is a subtask)
    if (task.parentTaskId) {
      await askFinishSubTaskApproval?.(result)
      return
    }

    // ASK USER FOR APPROVAL
    const { response, text, images } = await task.ask("completion_result", "", false)

    if (response === "yesButtonClicked") {
      // User approved - task completes successfully
      return  // ← TASK ENDS HERE
    }

    // User provided feedback - continue the task
    if (text || images) {
      await task.say("user_feedback", text ?? "", images)

      const feedbackText = `The user has provided feedback on the results. Consider their input to continue the task:\n<feedback>\n${text}\n</feedback>`

      // Push feedback as tool result - loop continues
      pushToolResult(formatResponse.toolResult(feedbackText, images))
    }
  }
}
```

**What happens:**

1. **Validation checks** ensure task can complete:
   - No tools failed in current turn
   - No incomplete todos (if setting enabled)

2. **Display result** to user via UI

3. **Emit TaskCompleted event** with final token usage

4. **Ask user for approval**:
   - **User clicks "Yes"**: Task ends, loop breaks
   - **User provides feedback**: Feedback becomes tool result, loop continues

### 5. Task Loop Breaks

**File:** `src/core/task/Task.ts:2239-2271`

```typescript
private async initiateTaskLoop(userContent: Anthropic.Messages.ContentBlockParam[]): Promise<void> {
  let nextUserContent = userContent
  let includeFileDetails = true

  this.emit(RooCodeEventName.TaskStarted)

  while (!this.abort) {
    // Main conversation loop
    const didEndLoop = await this.recursivelyMakeClineRequests(
      nextUserContent,
      includeFileDetails
    )

    includeFileDetails = false

    if (didEndLoop) {
      break  // ← EXITS HERE when attempt_completion is approved
    } else {
      // No tools were used - prompt model to use a tool
      nextUserContent = [{
        type: "text",
        text: formatResponse.noToolsUsed(this._taskToolProtocol ?? "xml")
      }]
    }
  }

  // Task completed
  this.emit(RooCodeEventName.TaskFinished)
}
```

**Loop exit conditions:**
- `didEndLoop = true` when `attempt_completion` is approved
- `this.abort = true` if user manually aborts task
- Task rejection or critical error

---

## Complete Flow Diagram

### High-Level Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ USER SUBMITS REQUEST                                            │
│ "Create a simple Express.js server"                            │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ TASK INITIALIZATION                                             │
│ - Resolve tool protocol → NATIVE                                │
│ - Initialize NativeToolCallParser (no XML parser)               │
│ - Build system prompt and tools array                           │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ TASK LOOP: initiateTaskLoop()                                   │
│ while (!this.abort) { ... }                                     │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ API REQUEST: recursivelyMakeClineRequests()                     │
│ - Build user message with environment details                   │
│ - Add tool results from previous turn                           │
│ - Call attemptApiRequest() → API streaming starts               │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ STREAM PROCESSING                                               │
│ for await (chunk of stream) {                                   │
│   switch (chunk.type) {                                         │
│     case "text": → Build text content                           │
│     case "tool_call_partial": → Process tool call               │
│     case "usage": → Track tokens                                │
│   }                                                              │
│ }                                                                │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ TOOL CALL CHUNK ARRIVES                                         │
│ {                                                               │
│   type: "tool_call_partial",                                    │
│   id: "toolu_01ABC",                                            │
│   name: "write_to_file",                                        │
│   arguments: "{\"path\": \"server.js\", ...}"                   │
│ }                                                               │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ NATIVE TOOL CALL PARSER: processRawChunk()                      │
│ - Emit start event (tool_call_start)                           │
│ - Emit delta events (tool_call_delta) for argument chunks      │
│ - Parse incremental JSON with partial-json library              │
│ - Emit end event (tool_call_end)                               │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ FINALIZE TOOL CALL: finalizeStreamingToolCall()                 │
│ Create ToolUse object:                                          │
│ {                                                               │
│   type: "tool_use",                                            │
│   id: "toolu_01ABC",                                           │
│   name: "write_to_file",                                       │
│   nativeArgs: { path: "server.js", file_text: "..." },        │
│   partial: false                                               │
│ }                                                               │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ ADD TO assistantMessageContent[]                                │
│ - Append ToolUse object to array                               │
│ - Call presentAssistantMessage(task)                           │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ PRESENT ASSISTANT MESSAGE: presentAssistantMessage()            │
│ - Iterate through assistantMessageContent blocks               │
│ - Detect protocol: block.id ? "native" : "xml"                 │
│ - Execute tool based on name                                   │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ EXECUTE TOOL                                                    │
│ - WriteToFileTool.execute(block.nativeArgs)                    │
│ - Tool writes file to disk                                     │
│ - pushToolResult() → adds to userMessageContent[]              │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ BUILD NEXT USER MESSAGE                                         │
│ - Convert userMessageContent to tool_result blocks             │
│ - Format: { type: "tool_result", tool_use_id, content }        │
│ - Add to apiConversationHistory                                │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ LOOP BACK                                                       │
│ - Push stack item with tool results                            │
│ - Continue to next iteration                                   │
│ - Repeat API request with updated conversation history         │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
        ... (multiple turns with tool executions) ...
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ COMPLETION TOOL CALL ARRIVES                                    │
│ {                                                               │
│   type: "tool_call_partial",                                    │
│   id: "toolu_04XYZ",                                           │
│   name: "attempt_completion",                                  │
│   arguments: "{\"result\": \"Server created!\"}"               │
│ }                                                               │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ PARSE COMPLETION CALL                                           │
│ - NativeToolCallParser.finalizeStreamingToolCall()             │
│ - Create ToolUse with name="attempt_completion"                │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ EXECUTE ATTEMPT COMPLETION                                      │
│ AttemptCompletionTool.execute(params, task, callbacks)         │
│ - Validate: No failed tools, no incomplete todos               │
│ - Display result to user                                       │
│ - Emit TaskCompleted event                                     │
│ - Ask user for approval                                        │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
                ┌────────┴────────┐
                │                 │
                ▼                 ▼
    ┌──────────────────┐  ┌──────────────────┐
    │ USER CLICKS "YES"│  │ USER GIVES       │
    │                  │  │ FEEDBACK         │
    └─────────┬────────┘  └────────┬─────────┘
              │                    │
              │                    ▼
              │         ┌──────────────────────┐
              │         │ Push feedback as     │
              │         │ tool_result          │
              │         │ Loop continues       │
              │         └──────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────────┐
│ TASK COMPLETION                                                 │
│ - recursivelyMakeClineRequests() returns didEndLoop=true       │
│ - initiateTaskLoop() breaks from while loop                    │
│ - Emit TaskFinished event                                      │
│ - Task execution ends                                          │
└─────────────────────────────────────────────────────────────────┘
```

### Detailed Native Protocol Tool Call Flow

```
API STREAM CHUNK
    ↓
┌───────────────────────────────────────────────────┐
│ chunk = {                                         │
│   type: "tool_call_partial",                      │
│   index: 0,                                       │
│   id: "toolu_01ABC",                              │
│   name: "write_to_file",                          │
│   arguments: "{\"path\": \"server.js\", ..."      │
│ }                                                 │
└───────────────┬───────────────────────────────────┘
                │
                ▼
┌───────────────────────────────────────────────────┐
│ NativeToolCallParser.processRawChunk(chunk)      │
│ - Detect new tool call (id not in streamingMap)  │
│ - Initialize streaming state                     │
│ - Emit: tool_call_start event                   │
└───────────────┬───────────────────────────────────┘
                │
                ▼
┌───────────────────────────────────────────────────┐
│ Task.ts handles tool_call_start event            │
│ - Initialize NativeToolCallParser state          │
│ - Create placeholder in assistantMessageContent  │
└───────────────┬───────────────────────────────────┘
                │
                ▼
       (More chunks arrive...)
                │
                ▼
┌───────────────────────────────────────────────────┐
│ NativeToolCallParser.processRawChunk(chunk)      │
│ - Accumulate arguments: state.arguments += chunk │
│ - Emit: tool_call_delta event                   │
└───────────────┬───────────────────────────────────┘
                │
                ▼
┌───────────────────────────────────────────────────┐
│ Task.ts handles tool_call_delta event            │
│ - processStreamingChunk(id, argumentsDelta)      │
│ - Parse partial JSON with parseJSON()            │
│ - Update assistantMessageContent with partial    │
│ - Call presentAssistantMessage() for UI update   │
└───────────────┬───────────────────────────────────┘
                │
                ▼
       (Final chunk arrives)
                │
                ▼
┌───────────────────────────────────────────────────┐
│ Stream ends (finish_reason = "tool_calls")       │
│ - Emit: tool_call_end event                     │
└───────────────┬───────────────────────────────────┘
                │
                ▼
┌───────────────────────────────────────────────────┐
│ Task.ts handles tool_call_end event              │
│ - finalizeStreamingToolCall(id)                  │
│ - Parse complete JSON                            │
│ - Create final ToolUse object:                   │
│   {                                              │
│     type: "tool_use",                           │
│     id: "toolu_01ABC",                          │
│     name: "write_to_file",                      │
│     nativeArgs: { path: "...", file_text: ... },│
│     partial: false                              │
│   }                                              │
└───────────────┬───────────────────────────────────┘
                │
                ▼
┌───────────────────────────────────────────────────┐
│ presentAssistantMessage(task)                    │
│ - Iterate assistantMessageContent                │
│ - Find ToolUse block                             │
│ - Detect protocol: block.id → "native"          │
│ - Route to appropriate tool handler              │
└───────────────┬───────────────────────────────────┘
                │
                ▼
┌───────────────────────────────────────────────────┐
│ ExecuteTool(toolUse, task, "native")             │
│ - Get tool by name: tools.get("write_to_file")  │
│ - Call tool.execute(toolUse.nativeArgs)          │
│ - Tool performs action (write file)              │
│ - Return result                                  │
└───────────────┬───────────────────────────────────┘
                │
                ▼
┌───────────────────────────────────────────────────┐
│ pushToolResult(result)                           │
│ - Add to task.userMessageContent:               │
│   {                                              │
│     type: "tool_result",                        │
│     tool_use_id: "toolu_01ABC",                 │
│     content: "File written successfully"        │
│   }                                              │
└───────────────┬───────────────────────────────────┘
                │
                ▼
┌───────────────────────────────────────────────────┐
│ Add to API Conversation History                  │
│ - Build user message with tool_result blocks    │
│ - Push to stack for next iteration              │
│ - Loop continues...                              │
└───────────────────────────────────────────────────┘
```

---

## Key Differences: XML vs Native

### Comparison Table

| Aspect | XML Protocol | Native Protocol |
|--------|--------------|-----------------|
| **Tool Definition** | Text in system prompt | Structured API parameter |
| **Model Output** | XML tags in text | Structured `tool_use` blocks |
| **Tool ID** | None | Unique ID (e.g., `toolu_01ABC`) |
| **Arguments Format** | String key-value pairs | Typed JSON objects |
| **Parsing** | Character-by-character XML | Incremental JSON parsing |
| **Parser Class** | `AssistantMessageParser` | `NativeToolCallParser` |
| **Streaming** | Text accumulation | Partial JSON parsing |
| **Protocol Detection** | `!block.id` | `block.id !== undefined` |
| **Argument Access** | `block.params` (strings) | `block.nativeArgs` (typed) |
| **Token Usage** | Higher (tools in prompt) | Lower (tools separate) |
| **Validation** | Runtime parsing errors | JSON Schema validation |

### Example Comparison

**Task:** Write a file

#### XML Protocol

**System Prompt:**
```
...
<write_to_file>
Description: Write content to a file at the specified path.

Parameters:
- path: (required) The path where the file should be written
- file_text: (required) The content to write to the file

Usage:
<write_to_file>
<path>path/to/file</path>
<file_text>content here</file_text>
</write_to_file>
...
```

**Model Response:**
```
I'll create the file for you.

<write_to_file>
<path>server.js</path>
<file_text>const express = require('express');</file_text>
</write_to_file>
```

**Parsed ToolUse:**
```typescript
{
  type: "tool_use",
  name: "write_to_file",
  params: {
    path: "server.js",
    file_text: "const express = require('express');"
  },
  // NO id field
}
```

#### Native Protocol

**API Request:**
```typescript
{
  tools: [
    {
      type: "function",
      function: {
        name: "write_to_file",
        description: "Write content to a file at the specified path.",
        parameters: {
          type: "object",
          properties: {
            path: { type: "string", description: "..." },
            file_text: { type: "string", description: "..." }
          },
          required: ["path", "file_text"],
          additionalProperties: false
        }
      }
    }
  ]
}
```

**API Response:**
```json
{
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "I'll create the file for you."
    },
    {
      "type": "tool_use",
      "id": "toolu_01ABC",
      "name": "write_to_file",
      "input": {
        "path": "server.js",
        "file_text": "const express = require('express');"
      }
    }
  ]
}
```

**Parsed ToolUse:**
```typescript
{
  type: "tool_use",
  id: "toolu_01ABC",  // ← Has ID
  name: "write_to_file",
  nativeArgs: {
    path: "server.js",
    file_text: "const express = require('express');"
  },
  params: {},  // Empty for native protocol
  partial: false
}
```

---

## Code Deep Dive

### 1. Protocol Resolution

**File:** `src/utils/resolveToolProtocol.ts`

```typescript
export const TOOL_PROTOCOL = {
  XML: "xml",
  NATIVE: "native",
} as const

export type ToolProtocol = (typeof TOOL_PROTOCOL)[keyof typeof TOOL_PROTOCOL]

export function resolveToolProtocol(
  apiConfiguration?: ApiConfiguration,
  modelInfo?: ModelInfo,
  lockedProtocol?: ToolProtocol,
  conversationHistory?: Anthropic.MessageParam[]
): ToolProtocol {
  // Priority 1: Use locked protocol (for resumed tasks)
  if (lockedProtocol) {
    return lockedProtocol
  }

  // Priority 2: Detect from conversation history
  if (conversationHistory && conversationHistory.length > 0) {
    const detectedProtocol = detectToolProtocolFromHistory(conversationHistory)
    if (detectedProtocol) {
      return detectedProtocol
    }
  }

  // Priority 3: Check model capabilities
  if (!modelInfo?.supportsNativeTools) {
    return TOOL_PROTOCOL.XML
  }

  // Default: Use native protocol
  return TOOL_PROTOCOL.NATIVE
}

function detectToolProtocolFromHistory(
  history: Anthropic.MessageParam[]
): ToolProtocol | null {
  for (const msg of history) {
    if (msg.role === "assistant" && Array.isArray(msg.content)) {
      for (const block of msg.content) {
        if (block.type === "tool_use") {
          // Native protocol tool calls have an 'id' field
          return block.id ? TOOL_PROTOCOL.NATIVE : TOOL_PROTOCOL.XML
        }
      }
    }
  }
  return null
}
```

### 2. Native Tool Call Parser

**File:** `src/core/assistant-message/NativeToolCallParser.ts`

```typescript
interface StreamingToolCallState {
  id: string
  name: string
  arguments: string  // Accumulated JSON string
}

export class NativeToolCallParser {
  private static streamingToolCalls = new Map<string, StreamingToolCallState>()

  /**
   * Process raw API stream chunk and emit typed events
   */
  static processRawChunk(chunk: {
    index: number
    id?: string
    name?: string
    arguments?: string
  }): ToolCallStreamEvent[] {
    const events: ToolCallStreamEvent[] = []
    const { id, name, arguments: args } = chunk

    if (!id) return events

    // Check if this is a new tool call
    const isNewCall = !this.streamingToolCalls.has(id)

    if (isNewCall && name) {
      // START EVENT: New tool call detected
      this.streamingToolCalls.set(id, {
        id,
        name,
        arguments: args || ""
      })

      events.push({
        type: "tool_call_start",
        toolCallId: id,
        toolName: name
      })
    } else {
      // Get existing state
      const state = this.streamingToolCalls.get(id)
      if (!state) return events

      // Update name if it just arrived
      if (name && !state.name) {
        state.name = name
        events.push({
          type: "tool_call_start",
          toolCallId: id,
          toolName: name
        })
      }
    }

    // DELTA EVENT: Arguments chunk arrived
    if (args) {
      const state = this.streamingToolCalls.get(id)!
      state.arguments += args

      events.push({
        type: "tool_call_delta",
        toolCallId: id,
        argumentsDelta: args
      })
    }

    return events
  }

  /**
   * Parse incremental JSON during streaming
   * Returns partial ToolUse for progressive rendering
   */
  static processStreamingChunk(id: string, argumentsChunk: string): ToolUse | null {
    const state = this.streamingToolCalls.get(id)
    if (!state) return null

    try {
      // Use partial-json to parse incomplete JSON
      const partialArgs = parseJSON(state.arguments)

      return {
        type: "tool_use",
        id,
        name: state.name as ToolName,
        nativeArgs: partialArgs,
        params: {},
        partial: true  // Mark as incomplete
      }
    } catch (e) {
      // JSON not parseable yet
      return null
    }
  }

  /**
   * Finalize tool call when stream ends
   * Parses complete JSON and creates final ToolUse
   */
  static finalizeStreamingToolCall(id: string): ToolUse | McpToolUse | null {
    const state = this.streamingToolCalls.get(id)
    if (!state) return null

    try {
      // Parse complete JSON arguments
      const args = JSON.parse(state.arguments)

      // Check if this is an MCP tool (dynamic tool from MCP server)
      const isMcpTool = state.name.includes("__")

      if (isMcpTool) {
        // Parse MCP tool format: "servername__toolname"
        const [serverName, toolName] = state.name.split("__")

        return {
          type: "mcp_tool_use",
          id,
          serverName,
          toolName,
          arguments: args,
          partial: false
        }
      }

      // Standard tool
      return {
        type: "tool_use",
        id,
        name: state.name as ToolName,
        nativeArgs: args,
        params: {},  // Empty for native protocol
        partial: false
      }
    } catch (e) {
      console.error(`Failed to parse tool call arguments for ${state.name}:`, e)
      return null
    } finally {
      // Cleanup streaming state
      this.streamingToolCalls.delete(id)
    }
  }

  /**
   * Reset all streaming state
   */
  static reset(): void {
    this.streamingToolCalls.clear()
  }
}
```

### 3. Stream Processing in Task

**File:** `src/core/task/Task.ts:2700-2772`

```typescript
// Inside recursivelyMakeClineRequests(), stream processing loop:

while (!item.done) {
  const chunk = item.value
  item = await nextChunkWithAbort()

  switch (chunk.type) {
    case "tool_call_partial": {
      // Process native protocol tool call chunk
      const events = NativeToolCallParser.processRawChunk({
        index: chunk.index,
        id: chunk.id,
        name: chunk.name,
        arguments: chunk.arguments,
      })

      // Handle each event type
      for (const event of events) {
        if (event.type === "tool_call_start") {
          // Initialize streaming for this tool call
          const index = this.assistantMessageContent.length

          // Create placeholder
          this.assistantMessageContent.push({
            type: "tool_use",
            id: event.toolCallId,
            name: event.toolName as ToolName,
            nativeArgs: {},
            params: {},
            partial: true
          })

          // Trigger UI update
          await presentAssistantMessage(this)
        }
        else if (event.type === "tool_call_delta") {
          // Update with incremental JSON parsing
          const partialToolUse = NativeToolCallParser.processStreamingChunk(
            event.toolCallId,
            event.argumentsDelta
          )

          if (partialToolUse) {
            // Find and update the tool use block
            const index = this.assistantMessageContent.findIndex(
              (block) => block.type === "tool_use" && block.id === event.toolCallId
            )

            if (index !== -1) {
              this.assistantMessageContent[index] = partialToolUse
              await presentAssistantMessage(this)
            }
          }
        }
        else if (event.type === "tool_call_end") {
          // Finalize the tool call
          const finalToolUse = NativeToolCallParser.finalizeStreamingToolCall(
            event.toolCallId
          )

          if (finalToolUse) {
            const index = this.assistantMessageContent.findIndex(
              (block) =>
                (block.type === "tool_use" || block.type === "mcp_tool_use") &&
                block.id === event.toolCallId
            )

            if (index !== -1) {
              this.assistantMessageContent[index] = finalToolUse
              await presentAssistantMessage(this)
            }
          }
        }
      }
      break
    }

    case "text": {
      // Handle text chunks
      // For native protocol, no XML parsing needed
      this.assistantMessageContent.push({
        type: "text",
        content: chunk.text,
        partial: false
      })

      await presentAssistantMessage(this)
      break
    }

    // ... other chunk types ...
  }
}
```

### 4. Tool Execution

**File:** `src/core/assistant-message/presentAssistantMessage.ts`

```typescript
export async function presentAssistantMessage(cline: Task): Promise<void> {
  if (cline.presentAssistantMessageLocked) return
  cline.presentAssistantMessageLocked = true

  try {
    // Process each content block
    while (cline.currentStreamingContentIndex < cline.assistantMessageContent.length) {
      const block = cline.assistantMessageContent[cline.currentStreamingContentIndex]

      // Skip partial blocks (still streaming)
      if (block.partial) {
        break
      }

      if (block.type === "text") {
        // Display text to user
        await cline.say("text", block.content)
      }
      else if (block.type === "tool_use") {
        // Determine protocol by checking for id field
        const toolProtocol: ToolProtocol = block.id ? "native" : "xml"

        // Create callbacks for tool execution
        const callbacks = {
          pushToolResult: (result: ToolResponse) => {
            // Add tool result to userMessageContent
            if (block.id) {
              cline.userMessageContent.push({
                type: "tool_result",
                tool_use_id: block.id,
                content: typeof result === "string" ? result : JSON.stringify(result)
              })
            }
          },
          handleError: async (error: string) => {
            cline.didToolFailInCurrentTurn = true
            await cline.say("error", error)
          },
          // ... other callbacks ...
        }

        // Execute the tool
        await executeToolByName(block.name, block, cline, toolProtocol, callbacks)

        cline.didAlreadyUseTool = true
      }
      else if (block.type === "mcp_tool_use") {
        // Handle MCP tool execution
        await executeMcpTool(block, cline, callbacks)
      }

      cline.currentStreamingContentIndex++
    }
  } finally {
    cline.presentAssistantMessageLocked = false
  }

  // Signal that we're ready to continue
  if (!cline.didAlreadyUseTool) {
    cline.userMessageContentReady = true
  }
}

async function executeToolByName(
  name: ToolName,
  toolUse: ToolUse,
  task: Task,
  protocol: ToolProtocol,
  callbacks: ToolCallbacks
): Promise<void> {
  // Get tool handler
  const tool = getToolByName(name)

  if (!tool) {
    throw new Error(`Unknown tool: ${name}`)
  }

  // Extract arguments based on protocol
  let args: any
  if (protocol === "native") {
    args = toolUse.nativeArgs  // Already parsed JSON
  } else {
    args = await tool.parseLegacy(toolUse.params)  // Parse XML params
  }

  // Execute the tool
  await tool.execute(args, task, callbacks)
}
```

---

## Summary

### Key Takeaways

1. **Native Protocol = Structured Tool Calling**
   - Tools are API-native constructs, not text instructions
   - JSON arguments are typed and validated
   - Incremental parsing enables progressive rendering

2. **Task Completion is Protocol-Agnostic**
   - Both protocols signal completion via `attempt_completion` tool
   - Detection is based on tool name, not protocol
   - User approval required before task ends

3. **Protocol Detection via ID Field**
   - Native protocol: `block.id !== undefined`
   - XML protocol: `!block.id`
   - This determines argument extraction method

4. **Streaming Flow**
   - Chunks arrive incrementally
   - Partial JSON parsed with `partial-json` library
   - UI updates in real-time as arguments stream in
   - Finalized when stream ends or `tool_calls` finish reason

5. **Completion Flow**
   ```
   attempt_completion tool call
   → NativeToolCallParser parses it
   → presentAssistantMessage detects it
   → AttemptCompletionTool.execute()
   → Emit TaskCompleted event
   → Ask user for approval
   → Break task loop if approved
   ```

### Migration Timeline

- **December 22, 2025**: Native protocol enforced as default
- **Current**: XML protocol deprecated but supported for resumed tasks
- **Future**: XML protocol will be removed once all tasks are migrated

### Benefits of Native Protocol

| Benefit | Description |
|---------|-------------|
| **Reduced Tokens** | Tools not in system prompt, saving ~2000-5000 tokens per request |
| **Better Typing** | JSON Schema validation ensures correct argument types |
| **Streaming UX** | Progressive JSON parsing enables real-time parameter display |
| **Standardization** | Follows industry-standard tool calling (OpenAI/Anthropic) |
| **Reliability** | Less prone to parsing errors vs character-by-character XML |

---

**Document Created:** January 7, 2026
**Based on:** Roo Code repository commit 861139ca2
**Covers:** Native protocol architecture, task completion detection, and complete flow analysis
