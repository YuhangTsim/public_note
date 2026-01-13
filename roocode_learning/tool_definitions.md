# Tool Definitions and Passing Mechanism

This document explains how tools are defined and passed along with prompts in Roo, focusing on the transition from XML to native tool calling.

## References
- Native tool definitions: `src/core/prompts/tools/native-tools/`
- Tool building: `src/core/task/build-tools.ts`
- Tool filtering: `src/core/prompts/tools/filter-tools-for-mode.ts`
- XML tools (legacy): `src/core/prompts/tools/`
- Tool protocol resolution: `src/utils/resolveToolProtocol.ts`

---

## Key Change: XML to Native Tool Calling

### Timeline

**December 22, 2025** - Native protocol enforced (commit `d00d9edec`)
- XML tool protocol deprecated
- All new tasks use native tool calling
- Resumed tasks maintain their original protocol (backward compatibility)
- Models without `supportsNativeTools: true` removed

### Current State

From `src/utils/resolveToolProtocol.ts:17-19`:
> "XML tool protocol has been deprecated. All models now use Native tool calling."

The `resolveToolProtocol()` function (lines 31-45) always returns `TOOL_PROTOCOL.NATIVE` for new tasks, unless a `lockedProtocol` exists for resumed tasks.

---

## Native Tool Protocol (Current Standard)

### Tool Definition Format

Native tools use **OpenAI ChatCompletionTool** format with JSON Schema for parameters.

**Example tool structure:**
```typescript
{
  type: "function",
  function: {
    name: "read_file",
    description: "Read the contents of a file at the specified path...",
    parameters: {
      type: "object",
      properties: {
        path: {
          type: "string",
          description: "The path of the file to read..."
        }
      },
      required: ["path"],
      additionalProperties: false
    }
  }
}
```

### Native Tool Locations

All native tools are defined in `src/core/prompts/tools/native-tools/`:

```
native-tools/
├── index.ts                    # Main export, getNativeTools()
├── access_mcp_resource.ts      # MCP resource access
├── apply_diff.ts               # Apply unified diff
├── ask_followup_question.ts    # Ask user questions
├── attempt_completion.ts       # Complete task
├── browser_action.ts           # Browser automation
├── codebase_search.ts          # Semantic code search
├── execute_command.ts          # Run CLI commands
├── list_files.ts               # List directory contents
├── read_file.ts                # Read file contents
├── write_to_file.ts            # Write/overwrite files
├── search_and_replace.ts       # Search and replace in files
├── edit_file.ts                # Edit file with instructions
├── search_files.ts             # Grep search
├── switch_mode.ts              # Switch to different mode
├── update_todo_list.ts         # Manage todo list
├── new_task.ts                 # Create subtask
├── fetch_instructions.ts       # Fetch mode instructions
├── generate_image.ts           # Generate images
├── converters.ts               # OpenAI ↔ Anthropic conversion
└── mcp_server.ts               # MCP server tools
```

Reference: `src/core/prompts/tools/native-tools/index.ts:46-78`

### Main Export Function

```typescript
export function getNativeTools(options: NativeToolsOptions = {}): OpenAI.Chat.ChatCompletionTool[] {
  const { partialReadsEnabled = true, maxConcurrentFileReads = 5, supportsImages = false } = options

  return [
    accessMcpResource,
    apply_diff,
    applyPatch,
    askFollowupQuestion,
    attemptCompletion,
    browserAction,
    codebaseSearch,
    executeCommand,
    fetchInstructions,
    generateImage,
    listFiles,
    newTask,
    createReadFileTool(readFileOptions),  // Dynamic based on options
    runSlashCommand,
    searchAndReplace,
    searchReplace,
    edit_file,
    searchFiles,
    switchMode,
    updateTodoList,
    writeToFile,
  ]
}
```

---

## How Tools Are Passed to API

### Building the Tools Array

From `src/core/task/build-tools.ts:35`, the `buildNativeToolsArray()` function combines:

1. **Native built-in tools** - from `getNativeTools()`
2. **MCP tools** - from `getMcpServerTools(mcpHub)`
3. **Custom tools** - from tool registry (if experiments.customTools enabled)

```typescript
export async function buildNativeToolsArray(options: BuildToolsOptions): Promise<OpenAI.Chat.ChatCompletionTool[]> {
  // 1. Build native tools with dynamic configuration
  const nativeTools = getNativeTools({
    partialReadsEnabled,
    maxConcurrentFileReads,
    supportsImages,
  })

  // 2. Filter based on mode restrictions
  const filteredNativeTools = filterNativeToolsForMode(
    nativeTools,
    mode,
    customModes,
    experiments,
    codeIndexManager,
    filterSettings,
    mcpHub,
  )

  // 3. Get and filter MCP tools
  const mcpTools = getMcpServerTools(mcpHub)
  const filteredMcpTools = filterMcpToolsForMode(mcpTools, mode, customModes, experiments)

  // 4. Load custom tools if enabled
  let nativeCustomTools = []
  if (experiments?.customTools) {
    const toolDirs = getRooDirectoriesForCwd(cwd).map(dir => path.join(dir, "tools"))
    await customToolRegistry.loadFromDirectoriesIfStale(toolDirs)
    const customTools = customToolRegistry.getAllSerialized()
    nativeCustomTools = customTools.map(formatNative)
  }

  // 5. Combine all tools
  return [...filteredNativeTools, ...filteredMcpTools, ...nativeCustomTools]
}
```

Reference: `src/core/task/build-tools.ts:35-106`

### Tool Filtering by Mode

Tools are filtered based on **mode groups** defined in mode configuration.

**Tool groups** (from `src/shared/tools.ts`):
- `read` - read_file, list_files, search_files, codebase_search
- `edit` - write_to_file, search_and_replace, apply_diff, edit_file, search_replace
- `command` - execute_command
- `browser` - browser_action
- `mcp` - MCP server tools
- `modes` - switch_mode, new_task

**Mode group examples:**
- Architect mode: `["read", ["edit", { fileRegex: "\\.md$" }], "browser", "mcp"]`
  - Edit tools restricted to markdown files only
- Code mode: `["read", "edit", "browser", "command", "mcp"]`
  - Full access to all groups, no restrictions

Reference: `packages/types/src/mode.ts:145,157`

### Passing to API

For **native protocol**, tools are passed directly in the API request:

```typescript
// API call structure
{
  model: "claude-sonnet-4-5",
  messages: [...],
  tools: buildNativeToolsArray(options),  // <- Tools passed here as array
  // ... other parameters
}
```

Tools are **NOT** included in the system prompt for native protocol. They're a separate parameter.

---

## XML Tool Protocol (Legacy, Deprecated)

### How XML Tools Worked

For the deprecated XML protocol:

1. **Tool descriptions embedded in system prompt**
   - Generated by `getToolDescriptionsForMode()` in `src/core/prompts/tools/index.ts:53`
   - Appended to system prompt as text (lines 111-127 in `system.ts`)

2. **Agent responds with XML tags**
   ```xml
   <read_file>
   <path>src/file.ts</path>
   </read_file>
   ```

3. **Parameters extracted from XML**
   - Parsed by XML parser in assistant message handler
   - Converted to typed parameters via `parseLegacy()` method

### Legacy Tool Locations

XML tools in `src/core/prompts/tools/`:
- Each tool exports a `description()` function returning XML-formatted documentation
- Example: `read-file.ts`, `write-to-file.ts`, `execute-command.ts`

### System Prompt Inclusion

From `src/core/prompts/system.ts:111-127`:
```typescript
// Build tools catalog section only for XML protocol
const builtInToolsCatalog = isNativeProtocol(effectiveProtocol)
  ? ""  // Empty for native protocol
  : `\n\n${getToolDescriptionsForMode(...)}` // Include in prompt for XML

// Later in prompt assembly:
${getSharedToolUseSection(effectiveProtocol, experiments)}${toolsCatalog}
```

---

## Tool Execution Abstraction

The `BaseTool` class (`src/core/tools/BaseTool.ts`) provides protocol-agnostic execution:

```typescript
class BaseTool<TName extends string> {
  // Handle both protocols
  async handle(block: ToolCallBlock): Promise<ToolResult> {
    if (block.nativeArgs) {
      // Native protocol: use typed args directly
      return this.execute(block.nativeArgs)
    } else {
      // XML protocol: parse legacy XML params
      const parsed = await this.parseLegacy(block.params)
      return this.execute(parsed)
    }
  }

  // Override in subclasses
  abstract parseLegacy(params: Record<string, string>): Promise<TParams>
  abstract execute(params: TParams): Promise<ToolResult>
}
```

Both paths converge on `execute()` with typed parameters, ensuring consistent tool behavior regardless of protocol.

Reference: `src/core/tools/BaseTool.ts:135`

---

## OpenAI ↔ Anthropic Conversion

Tools are converted between formats for different providers.

From `src/core/prompts/tools/native-tools/converters.ts:28`:

```typescript
export function convertOpenAIToolToAnthropic(tool: OpenAI.Chat.ChatCompletionTool): Anthropic.Tool {
  return {
    name: tool.function.name,
    description: tool.function.description,
    input_schema: tool.function.parameters,  // OpenAI: parameters → Anthropic: input_schema
  }
}
```

**Key difference:** Anthropic uses `input_schema` instead of `parameters`.

---

## Backward Compatibility

### Resumed Tasks

Tasks remember their protocol via `lockedProtocol`:

```typescript
function resolveToolProtocol(lockedProtocol?: ToolProtocol, conversationHistory?: Anthropic.MessageParam[]) {
  // If task was created with a specific protocol, keep using it
  if (lockedProtocol) {
    return lockedProtocol
  }

  // For new tasks, always use native
  return TOOL_PROTOCOL.NATIVE
}
```

The `detectToolProtocolFromHistory()` function (line 66) scans conversation history:
- Native tools have an `id` field in tool_calls
- XML tools don't have `id` field

Reference: `src/utils/resolveToolProtocol.ts:31-78`

---

## Summary

### Native Protocol (Current)
- ✅ Tools defined as OpenAI ChatCompletionTool objects with JSON Schema
- ✅ Passed as separate `tools` parameter in API request
- ✅ NOT included in system prompt (reduces token usage)
- ✅ Agent responds with structured `tool_calls` in API response
- ✅ Parameters are typed JSON objects

### XML Protocol (Deprecated)
- ❌ Tools described as XML-formatted text in system prompt
- ❌ Increased token usage (tool docs in every request)
- ❌ Agent responds with XML tags
- ❌ Parameters extracted from XML strings
- ⚠️ Still supported for resumed tasks (backward compatibility)

### Key Benefits of Native Protocol
1. **Reduced token usage** - No tool descriptions in prompt
2. **Better typing** - JSON Schema validation
3. **Provider support** - Native support from Claude, GPT-4, etc.
4. **Cleaner parsing** - Structured tool_calls vs XML parsing
