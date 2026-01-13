# Error Handling: Malformed JSON in Native Protocol

This document explains how Roo Code handles malformed or invalid JSON when using the Native Protocol, including error detection, recovery mechanisms, and user feedback.

## References
- JSON Parser: `src/core/assistant-message/NativeToolCallParser.ts`
- Tool Execution: `src/core/tools/BaseTool.ts`
- Error Handling: `src/core/assistant-message/presentAssistantMessage.ts`
- Stream Processing: `src/core/task/Task.ts:2670-2898`
- Test Cases: `src/core/assistant-message/__tests__/NativeToolCallParser.spec.ts`

---

## Table of Contents
1. [Overview](#overview)
2. [Error Detection Stages](#error-detection-stages)
3. [Error Handling Flow](#error-handling-flow)
4. [Resilience Features](#resilience-features)
5. [User Experience](#user-experience)
6. [Code Deep Dive](#code-deep-dive)
7. [Example Scenarios](#example-scenarios)

---

## Overview

### Key Question: What Happens When JSON is Malformed?

**Short Answer:** The system handles it gracefully - errors are caught, logged, communicated back to the model, and the conversation continues.

**Key Principles:**
1. **Fail gracefully** - Never crash, always return null or error
2. **Communicate errors** - Send clear error messages to both user and model
3. **Continue conversation** - Task loop never breaks on JSON errors
4. **Enable recovery** - Model can see the error and try again

### Why This Matters

LLMs can produce malformed JSON for various reasons:
- Streaming interruptions
- Token limits cutting off mid-JSON
- Model hallucinations
- Escape sequence errors
- Missing closing braces/brackets

Roo Code is designed to handle these gracefully without breaking the conversation flow.

---

## Error Detection Stages

JSON errors can be detected at three different stages:

### Stage 1: Incremental Parsing (During Streaming)
**Location:** `NativeToolCallParser.processStreamingChunk()`

- Uses `partial-json` library for lenient parsing
- Handles incomplete JSON like `{"path": "hel`
- Returns `null` if JSON is too malformed even for partial parsing
- **No errors thrown** - silently waits for more data

### Stage 2: Final Parsing (Stream End)
**Location:** `NativeToolCallParser.finalizeStreamingToolCall()`

- Attempts full `JSON.parse()` on accumulated arguments
- Catches `SyntaxError` if JSON is invalid
- Logs error details to console
- Returns `null` instead of throwing

### Stage 3: Tool Execution (Parameter Validation)
**Location:** `BaseTool.handle()`

- Checks if `nativeArgs` is defined
- Validates required parameters exist
- Catches type errors and missing fields
- Sends error back to model via `tool_result`

---

## Error Handling Flow

### Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ MODEL OUTPUTS TOOL CALL WITH MALFORMED JSON                 │
│ {                                                           │
│   type: "tool_use",                                        │
│   id: "toolu_01ABC",                                       │
│   name: "write_to_file",                                   │
│   input: { "path": "file.txt", "content": "hello}  ← BAD  │
│ }                                                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ STAGE 1: INCREMENTAL PARSING                                │
│ NativeToolCallParser.processStreamingChunk()               │
│                                                             │
│ Chunk 1: {"path": "file.txt", "content": "hel             │
│   → parseJSON() returns { path: "file.txt", content: "hel" }│
│   → Partial ToolUse created, UI updates                    │
│                                                             │
│ Chunk 2: {"path": "file.txt", "content": "hello}          │
│   → parseJSON() fails (extra })                            │
│   → Returns null, waits for more data                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ STREAM ENDS (finish_reason = "tool_calls")                 │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ STAGE 2: FINAL PARSING                                      │
│ NativeToolCallParser.finalizeStreamingToolCall()           │
│                                                             │
│ try {                                                       │
│   args = JSON.parse('{"path":"file.txt","content":"hello}')│
│   // FAILS: Unexpected token } in JSON at position 45      │
│ } catch (error) {                                           │
│   console.error("Failed to parse tool call arguments")     │
│   console.error("Tool call: ...")                          │
│   return null  ← GRACEFUL FAILURE                          │
│ }                                                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ TASK.TS HANDLES NULL RETURN                                 │
│ - Tool is still marked as non-partial (ready to execute)   │
│ - assistantMessageContent updated                          │
│ - presentAssistantMessage(task) called                     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ STAGE 3: TOOL EXECUTION                                     │
│ presentAssistantMessage() → BaseTool.handle()              │
│                                                             │
│ const toolUse = {                                           │
│   type: "tool_use",                                        │
│   id: "toolu_01ABC",                                       │
│   name: "write_to_file",                                   │
│   nativeArgs: undefined,  ← NULL FROM PARSING              │
│   params: {}                                               │
│ }                                                           │
│                                                             │
│ try {                                                       │
│   if (block.nativeArgs !== undefined) {                    │
│     params = block.nativeArgs                              │
│   } else {                                                  │
│     // Try XML fallback (usually fails)                    │
│     params = this.parseLegacy(block.params)                │
│   }                                                         │
│ } catch (error) {                                           │
│   console.error("Error parsing parameters:", error)        │
│   handleError("parsing write_to_file args", error)         │
│   pushToolResult("<error>Failed to parse...</error>")      │
│   return  ← TOOL EXECUTION ABORTED                         │
│ }                                                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ ERROR COMMUNICATION                                          │
│ handleError() in presentAssistantMessage.ts                │
│                                                             │
│ 1. Log to user via cline.say("error", errorMessage)       │
│ 2. Format error for model:                                 │
│    const errorString = `Error parsing write_to_file args:  │
│      Unexpected token } in JSON at position 45`            │
│                                                             │
│ 3. Push tool_result to userMessageContent:                 │
│    {                                                        │
│      type: "tool_result",                                  │
│      tool_use_id: "toolu_01ABC",                          │
│      content: errorString,                                 │
│      is_error: true                                        │
│    }                                                        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ BUILD NEXT API REQUEST                                       │
│ userMessageContent → tool_result block                     │
│                                                             │
│ {                                                           │
│   role: "user",                                            │
│   content: [                                               │
│     {                                                       │
│       type: "tool_result",                                │
│       tool_use_id: "toolu_01ABC",                         │
│       content: "Error parsing write_to_file args: ...",   │
│       is_error: true                                       │
│     }                                                       │
│   ]                                                         │
│ }                                                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ CONVERSATION CONTINUES                                       │
│ Model receives error in next turn                          │
│ Model can:                                                  │
│ - Try again with corrected JSON                            │
│ - Ask for clarification                                    │
│ - Attempt completion with explanation                      │
│                                                             │
│ Task loop does NOT break - conversation resilient ✓        │
└─────────────────────────────────────────────────────────────┘
```

---

## Resilience Features

### 1. Lenient Incremental Parsing

**Feature:** Uses `partial-json` library for progressive parsing

**Benefit:** Can extract partial data from incomplete JSON during streaming

**Example:**
```typescript
// Stream chunk arrives
const partialJSON = '{"path": "file.txt", "content": "hel'

// Standard JSON.parse() would fail
JSON.parse(partialJSON)  // ✗ SyntaxError: Unexpected end of JSON input

// partial-json succeeds
parseJSON(partialJSON)  // ✓ { path: "file.txt", content: "hel" }
```

**Implementation:**
```typescript
import { parseJSON } from "partial-json"

try {
  const partialArgs = parseJSON(toolCall.argumentsAccumulator)
  return createPartialToolUse(id, name, partialArgs, true)
} catch {
  // Even partial-json can't parse - wait for more data
  return null
}
```

**Location:** `src/core/assistant-message/NativeToolCallParser.ts:246-256`

### 2. Graceful Null Returns

**Feature:** Parsing failures return `null` instead of throwing exceptions

**Benefit:** Prevents crashes and allows fallback handling

**Implementation:**
```typescript
try {
  const args = JSON.parse(toolCall.arguments)
  return createFinalToolUse(id, name, args)
} catch (error) {
  console.error(`Failed to parse tool call arguments: ${error.message}`)
  console.error(`Tool call: ${JSON.stringify(toolCall, null, 2)}`)
  return null  // ← Graceful degradation
}
```

**What happens with null:**
- Tool still marked as complete (not partial)
- Execution attempted with undefined nativeArgs
- Validation catches missing parameters
- Error communicated to model

**Location:** `src/core/assistant-message/NativeToolCallParser.ts:594-610`

### 3. XML Fallback Parsing

**Feature:** If native args are undefined, attempts XML parsing fallback

**Benefit:** Handles edge cases where protocol detection is ambiguous

**Implementation:**
```typescript
let params: ToolParams<TName>
try {
  if (block.nativeArgs !== undefined) {
    // Native protocol - use parsed JSON args
    params = block.nativeArgs as ToolParams<TName>
  } else {
    // Fallback to XML protocol parsing
    params = this.parseLegacy(block.params)
  }
} catch (error) {
  // Both parsing methods failed
  await callbacks.handleError(`parsing ${this.name} args`, error)
  callbacks.pushToolResult(`<error>Failed to parse parameters</error>`)
  return
}
```

**Note:** For native protocol tools, XML fallback usually fails too, resulting in error communication

**Location:** `src/core/tools/BaseTool.ts:143-156`

### 4. Tool Execution Abortion

**Feature:** Tools don't execute if parameters are invalid

**Benefit:** Prevents cascading errors and undefined behavior

**Flow:**
```typescript
if (parsing_failed) {
  handleError()
  pushToolResult(error_message)
  return  // ← Tool.execute() never called
}
```

**Safety guarantee:** Invalid parameters never reach tool implementation code

### 5. Error Result Communication

**Feature:** Errors are sent back to model as `tool_result` blocks with `is_error: true`

**Benefit:** Model can see what went wrong and adjust

**Implementation:**
```typescript
cline.userMessageContent.push({
  type: "tool_result",
  tool_use_id: toolCallId,
  content: errorString,
  is_error: true,  // ← Anthropic API recognizes this as error
} as Anthropic.ToolResultBlockParam)
```

**Model receives:**
```json
{
  "role": "user",
  "content": [
    {
      "type": "tool_result",
      "tool_use_id": "toolu_01ABC",
      "content": "Error parsing write_to_file args: Unexpected token } in JSON at position 45",
      "is_error": true
    }
  ]
}
```

**Location:** `src/core/assistant-message/presentAssistantMessage.ts:727-750`

### 6. Conversation Continuity

**Feature:** Task loop never breaks on JSON errors

**Benefit:** Conversation can recover and task can still complete

**Implementation:**
```typescript
// In initiateTaskLoop()
while (!this.abort) {
  const didEndLoop = await this.recursivelyMakeClineRequests(...)

  if (didEndLoop) {
    break  // Only breaks on attempt_completion approval
  } else {
    // Continue loop even if errors occurred
    nextUserContent = [formatResponse.noToolsUsed()]
  }
}
```

**Guarantees:**
- Errors don't break the loop
- Model always gets error feedback
- Can try again or attempt completion
- User can intervene if needed

**Location:** `src/core/task/Task.ts:2239-2271`

---

## User Experience

### What the User Sees

#### 1. Chat Window Error Message

```
❌ Error parsing write_to_file args:
   Unexpected token } in JSON at position 45

Tool: write_to_file
Status: Failed - Invalid arguments
```

#### 2. Tool Call Display

The UI shows the tool call with whatever data was successfully extracted:

```
🔧 write_to_file

Arguments (partial):
  path: "file.txt"
  content: "hello  ← Incomplete

Status: ❌ Parse Error
```

#### 3. Console Logs (Developer View)

```
[NativeToolCallParser] Failed to parse tool call arguments: Unexpected token } in JSON at position 45
Tool call: {
  "id": "toolu_01ABC",
  "name": "write_to_file",
  "arguments": "{\"path\": \"file.txt\", \"content\": \"hello}"
}
```

#### 4. Model's Next Response

The model typically acknowledges the error:

```
I apologize for the JSON formatting error. Let me try again with correct syntax.
```

Then it calls the tool again with fixed JSON.

### User Actions

Users can:
1. **Wait** - Let the model retry automatically
2. **Intervene** - Provide feedback or correction
3. **Abort** - Stop the task if errors persist
4. **Inspect** - Check console logs for debugging

---

## Code Deep Dive

### 1. NativeToolCallParser - Incremental Parsing

**File:** `src/core/assistant-message/NativeToolCallParser.ts:234-273`

```typescript
/**
 * Process streaming chunks and extract partial arguments
 *
 * @param id - Tool call ID
 * @param chunk - Incremental JSON string
 * @returns Partial ToolUse or null if unparseable
 */
public static processStreamingChunk(id: string, chunk: string): ToolUse | null {
  const toolCall = this.streamingToolCalls.get(id)
  if (!toolCall) {
    console.warn(`[NativeToolCallParser] Received chunk for unknown tool call: ${id}`)
    return null
  }

  // Accumulate the JSON string incrementally
  toolCall.argumentsAccumulator += chunk

  try {
    // Use partial-json-parser to extract values from incomplete JSON
    // This library can handle missing closing braces, incomplete strings, etc.
    const partialArgs = parseJSON(toolCall.argumentsAccumulator)

    // Extract the resolved tool name (handles MCP tools, tool aliases)
    const { resolvedName, originalName } = this.resolveToolName(toolCall.name)

    // Create partial ToolUse with whatever we've successfully parsed
    return this.createPartialToolUse(
      toolCall.id,
      resolvedName,
      partialArgs || {},  // Use empty object if parsing returned null
      true,  // Mark as partial
      originalName,
    )
  } catch {
    // Even partial-json-parser can fail on severely malformed JSON
    // Examples: random characters, mismatched quotes, etc.
    // Don't throw - just return null and wait for next chunk
    return null
  }
}
```

**Key behaviors:**
- **Accumulation:** Builds up JSON string incrementally as chunks arrive
- **Lenient parsing:** Uses `partial-json` which tolerates incomplete JSON
- **Silent failure:** Returns `null` instead of throwing on unparseable data
- **Progressive updates:** Returns partial data for UI rendering

### 2. NativeToolCallParser - Final Parsing

**File:** `src/core/assistant-message/NativeToolCallParser.ts:594-610`

```typescript
/**
 * Parse a complete tool call from the API
 * Called when stream ends or for non-streaming responses
 *
 * @param toolCall - Complete tool call object from API
 * @returns Fully parsed ToolUse or McpToolUse, or null if parsing fails
 */
private static parseToolCall(
  toolCall: { id: string; name: string; arguments: string }
): ToolUse | McpToolUse | null {
  try {
    // Attempt full JSON parse
    // Empty string arguments default to empty object
    const args = toolCall.arguments === "" ? {} : JSON.parse(toolCall.arguments)

    // Check if this is an MCP tool (contains "__" separator)
    const isMcpTool = toolCall.name.includes("__")

    if (isMcpTool) {
      // Parse MCP tool: "servername__toolname" format
      const [serverName, toolName] = toolCall.name.split("__")
      return {
        type: "mcp_tool_use",
        id: toolCall.id,
        serverName,
        toolName,
        arguments: args,
        partial: false,
      }
    }

    // Standard tool - validate name and build nativeArgs
    if (!isToolName(toolCall.name)) {
      console.warn(`Unknown tool name: ${toolCall.name}`)
      return null
    }

    // Build typed nativeArgs from parsed JSON
    const nativeArgs = this.buildNativeArgs(toolCall.name, args)

    return {
      type: "tool_use",
      id: toolCall.id,
      name: toolCall.name as ToolName,
      nativeArgs,
      params: {},  // Empty for native protocol
      partial: false,
    }
  } catch (error) {
    // JSON.parse() failed - log details for debugging
    console.error(
      `Failed to parse tool call arguments: ${error instanceof Error ? error.message : String(error)}`
    )
    console.error(`Tool call: ${JSON.stringify(toolCall, null, 2)}`)

    // Return null to allow graceful degradation
    // Tool execution will handle undefined nativeArgs
    return null
  }
}
```

**Key behaviors:**
- **Standard JSON.parse():** Uses strict parsing for complete JSON
- **Empty string handling:** Treats `""` as `{}` (valid empty args)
- **MCP tool detection:** Checks for `__` separator in tool name
- **Error logging:** Logs full error details and tool call JSON
- **Graceful return:** Returns `null` instead of throwing exception

### 3. BaseTool - Parameter Handling

**File:** `src/core/tools/BaseTool.ts:135-171`

```typescript
/**
 * Handle tool execution with protocol-agnostic parameter parsing
 *
 * @param task - Current task instance
 * @param block - ToolUse block from assistant message
 * @param callbacks - Callbacks for error handling and result pushing
 */
async handle(task: Task, block: ToolUse<TName>, callbacks: ToolCallbacks): Promise<void> {
  // Don't execute partial tool calls (still streaming)
  if (block.partial) {
    try {
      await this.handlePartial(task, block)
    } catch (error) {
      console.error(`Error in handlePartial:`, error)
      await callbacks.handleError(
        `handling partial ${this.name}`,
        error instanceof Error ? error : new Error(String(error)),
      )
    }
    return
  }

  // Determine protocol and parse parameters accordingly
  let params: ToolParams<TName>
  try {
    if (block.nativeArgs !== undefined) {
      // Native protocol: nativeArgs provided by NativeToolCallParser
      // Already typed and validated
      params = block.nativeArgs as ToolParams<TName>
    } else {
      // XML/legacy protocol: parse string params into typed params
      // Or fallback if native parsing failed (nativeArgs is undefined)
      params = await this.parseLegacy(block.params)
    }
  } catch (error) {
    // Parameter parsing failed - abort execution
    console.error(`Error parsing parameters for ${this.name}:`, error)

    const errorMessage = `Failed to parse ${this.name} parameters: ${
      error instanceof Error ? error.message : String(error)
    }`

    // Notify error handler (logs to user)
    await callbacks.handleError(`parsing ${this.name} args`, new Error(errorMessage))

    // Send error as tool result (goes to model)
    callbacks.pushToolResult(`<error>${errorMessage}</error>`)

    // Abort - don't call execute()
    return
  }

  // Parameters successfully parsed - execute the tool
  try {
    await this.execute(params, task, callbacks)
  } catch (error) {
    // Tool execution error (different from parsing error)
    console.error(`Error executing ${this.name}:`, error)
    await callbacks.handleError(
      `executing ${this.name}`,
      error instanceof Error ? error : new Error(String(error)),
    )
  }
}
```

**Key behaviors:**
- **Protocol detection:** Checks `nativeArgs !== undefined` to determine protocol
- **Fallback parsing:** Attempts XML parsing if native args unavailable
- **Error isolation:** Catches parsing errors separately from execution errors
- **Execution abortion:** Returns early if parsing fails
- **Dual error communication:** Logs to user AND sends to model

### 4. presentAssistantMessage - Error Communication

**File:** `src/core/assistant-message/presentAssistantMessage.ts:626-640, 727-750`

```typescript
/**
 * Handle tool execution errors and communicate to user and model
 */
const handleError = async (action: string, error: Error) => {
  // Silently ignore AskIgnoredError - internal control flow signal
  if (error instanceof AskIgnoredError) {
    return
  }

  // Format error message with full details
  const errorString = `Error ${action}: ${JSON.stringify(serializeError(error))}`

  // Display error to user in chat
  await cline.say(
    "error",
    `Error ${action}:\n${error.message ?? JSON.stringify(serializeError(error), null, 2)}`,
  )

  // Send error back to model as tool result
  pushToolResult(formatResponse.toolError(errorString, toolProtocol))
}

/**
 * Push tool result to userMessageContent for next API request
 */
const pushToolResult = (content: ToolResponse) => {
  if (hasToolResult) return  // Prevent duplicate results

  let resultContent: string
  let imageBlocks: Anthropic.ImageBlockParam[] = []

  // Handle string or multi-part content
  if (typeof content === "string") {
    resultContent = content || "(tool did not return anything)"
  } else {
    const textBlocks = content.filter((item) => item.type === "text")
    imageBlocks = content.filter((item) => item.type === "image") as Anthropic.ImageBlockParam[]
    resultContent = textBlocks.map((item) => item.text).join("\n") || ""
  }

  // Add tool_result block to userMessageContent
  // This will be sent in the next API request
  if (toolCallId) {
    cline.userMessageContent.push({
      type: "tool_result",
      tool_use_id: toolCallId,
      content: resultContent,
      is_error: resultContent.includes("<error>"),  // Mark as error if contains error tags
    } as Anthropic.ToolResultBlockParam)

    // Add any image blocks separately
    if (imageBlocks.length > 0) {
      cline.userMessageContent.push(...imageBlocks)
    }
  }

  hasToolResult = true
  cline.didAlreadyUseTool = true
}
```

**Key behaviors:**
- **Dual notification:** Errors displayed to user AND sent to model
- **Serialization:** Errors converted to JSON for structured logging
- **Error marking:** `is_error: true` flag set for Anthropic API
- **Deduplication:** Prevents multiple results for same tool call
- **Multi-part support:** Handles text and images in results

---

## Example Scenarios

### Scenario 1: Missing Closing Brace

**Model Output:**
```json
{
  "type": "tool_use",
  "id": "toolu_01ABC",
  "name": "write_to_file",
  "input": {
    "path": "hello.txt",
    "file_text": "Hello World"
  // Missing closing }
}
```

**What Happens:**

1. **Streaming:**
   - Chunks: `{"path": "hello.txt", "file_text": "Hello World"`
   - `parseJSON()` extracts: `{ path: "hello.txt", file_text: "Hello World" }`
   - UI shows partial data ✓

2. **Final Parsing:**
   - `JSON.parse()` fails: "Unexpected end of JSON input"
   - Returns `null`
   - Logs error to console

3. **Tool Execution:**
   - `nativeArgs` is `undefined`
   - Falls back to `parseLegacy({})`
   - Parsing fails (empty params)
   - Error pushed: "Failed to parse write_to_file parameters"

4. **Model Response:**
   - Receives error in next turn
   - Can retry with corrected JSON

**Outcome:** ✓ Error handled, conversation continues

### Scenario 2: Extra Closing Brace

**Model Output:**
```json
{
  "type": "tool_use",
  "id": "toolu_01ABC",
  "name": "read_file",
  "input": {
    "path": "package.json"
  }}  // Extra }
}
```

**What Happens:**

1. **Streaming:**
   - Chunks arrive progressively
   - `parseJSON()` may extract partial data
   - Extra `}` causes parsing error in later chunks

2. **Final Parsing:**
   - `JSON.parse('{"path":"package.json"}}')` fails
   - Error: "Unexpected token } in JSON at position 27"
   - Returns `null`

3. **Tool Execution:**
   - Same error flow as Scenario 1
   - Error message sent to model

4. **Model Response:**
   - Sees: "Error parsing read_file args: Unexpected token }"
   - Retries with correct JSON

**Outcome:** ✓ Error handled, conversation continues

### Scenario 3: Escape Sequence Error

**Model Output:**
```json
{
  "type": "tool_use",
  "id": "toolu_01ABC",
  "name": "write_to_file",
  "input": {
    "path": "test.txt",
    "file_text": "Line 1\nLine 2"  // Unescaped \n in JSON
  }
}
```

**What Happens:**

1. **Streaming:**
   - `parseJSON()` handles escaped sequences
   - May successfully parse if library is tolerant

2. **Final Parsing:**
   - Depends on JSON validity
   - If invalid: Returns `null` with error
   - If valid (properly escaped): Succeeds ✓

3. **Best Case:**
   - Tool executes successfully
   - File written with newline

4. **Worst Case:**
   - Parsing fails
   - Error communicated to model
   - Model retries with `\\n` (properly escaped)

**Outcome:** Depends on actual JSON validity, errors handled if needed

### Scenario 4: Completely Random String

**Model Output:**
```json
{
  "type": "tool_use",
  "id": "toolu_01ABC",
  "name": "execute_command",
  "input": asdfghjkl12345!@#$%
}
```

**What Happens:**

1. **Streaming:**
   - `parseJSON()` completely fails
   - Returns `null` immediately
   - No partial data extracted

2. **Final Parsing:**
   - `JSON.parse('asdfghjkl12345!@#$%')` throws
   - Error: "Unexpected token a in JSON at position 0"
   - Returns `null`

3. **Tool Execution:**
   - `nativeArgs` is `undefined`
   - Parsing fails
   - Error: "Failed to parse execute_command parameters"

4. **User View:**
   - Error displayed prominently
   - Console shows malformed input
   - Model receives detailed error

**Outcome:** ✓ Error handled, no crash, conversation continues

### Scenario 5: Type Mismatch (Valid JSON, Wrong Type)

**Model Output:**
```json
{
  "type": "tool_use",
  "id": "toolu_01ABC",
  "name": "write_to_file",
  "input": {
    "path": ["array", "instead", "of", "string"],
    "file_text": 12345
  }
}
```

**What Happens:**

1. **Streaming:**
   - JSON is syntactically valid
   - `parseJSON()` succeeds ✓

2. **Final Parsing:**
   - `JSON.parse()` succeeds ✓
   - `nativeArgs = { path: [...], file_text: 12345 }`

3. **Tool Execution:**
   - Tool receives mistyped arguments
   - Runtime validation in tool code detects type error
   - OR TypeScript catches at compile time
   - Error: "Expected string for path, got array"

4. **Error Communication:**
   - Tool-specific error message
   - Sent back to model
   - Model can correct types

**Outcome:** ✓ Type error caught at runtime, handled gracefully

---

## Summary

### Error Handling Guarantees

| Guarantee | Status |
|-----------|--------|
| **No crashes on malformed JSON** | ✓ Guaranteed |
| **Errors logged to console** | ✓ Guaranteed |
| **Errors displayed to user** | ✓ Guaranteed |
| **Errors sent to model** | ✓ Guaranteed |
| **Conversation continues** | ✓ Guaranteed |
| **Tool execution aborted if invalid** | ✓ Guaranteed |
| **Partial data extracted when possible** | ✓ Best effort |
| **Automatic retry** | ✗ Not automatic (model decides) |

### Error Recovery Path

```
Malformed JSON → Parse Error → Null Return → Tool Validation Error
    → Error Message to Model → Model Adjusts → Retry → Success
```

### Key Takeaways

1. **Resilience is built-in** - Multiple layers of error detection and recovery
2. **Partial parsing helps** - `partial-json` extracts what it can during streaming
3. **Graceful degradation** - Returns `null` instead of crashing
4. **Clear communication** - Errors visible to user, model, and developers
5. **Conversation continuity** - Task loop never breaks on JSON errors
6. **Model agency** - Model receives errors and can self-correct

### When to Worry

Malformed JSON errors are **normal and expected** in these cases:
- Streaming interruptions
- Token limits
- Model experimentation

Only worry if:
- Errors persist across multiple retries
- Same tool always fails
- Model can't recover after seeing error
- User workflow is blocked

In these cases, check:
- Console logs for detailed error messages
- Tool implementation for bugs
- System prompt for clarity
- Model configuration (temperature, etc.)

---

## Testing

### Test Cases

**Location:** `src/core/assistant-message/__tests__/NativeToolCallParser.spec.ts`

The test suite includes:
- Valid JSON parsing
- Incomplete JSON handling
- Malformed JSON detection
- Empty argument handling
- MCP tool format parsing
- Edge cases and boundary conditions

**Run tests:**
```bash
npm test -- NativeToolCallParser.spec.ts
```

---

**Document Created:** January 7, 2026
**Based on:** Roo Code repository commit 861139ca2
**Covers:** Complete error handling for malformed JSON in Native Protocol
