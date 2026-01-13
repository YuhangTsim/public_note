# Tool Validation System in Roo-Code

## Overview

The tool validation system ensures that Claude/AI models only use tools that are appropriate for the current mode and configuration. It provides two-level validation:
1. **Valid tool check**: Is this a known tool that exists?
2. **Permission check**: Is this tool allowed in the current mode/configuration?

## Core File: `src/core/tools/validateToolUse.ts`

### Key Functions

#### 1. `isValidToolName(toolName: string, experiments?: Record<string, boolean>): boolean`

**Purpose**: Checks if a tool name is a valid, known tool (NOT whether it's allowed).

**Validation Logic**:
```typescript
// Check 1: Is it a static tool defined in validToolNames?
if (validToolNames.includes(toolName)) return true

// Check 2: Is it a custom tool (if customTools experiment is enabled)?
if (experiments?.customTools && customToolRegistry.has(toolName)) return true

// Check 3: Is it a dynamic MCP tool (starts with "mcp_")?
if (toolName.startsWith("mcp_")) return true

return false
```

**Examples**:
- `isValidToolName("read_file")` → `true` (built-in tool)
- `isValidToolName("edit_file")` → `false` (doesn't exist, "apply_diff" is the canonical name)
- `isValidToolName("mcp_github_searchCode")` → `true` (dynamic MCP tool)
- `isValidToolName("totally_fake_tool")` → `false` (unknown)

---

#### 2. `validateToolUse(...)`

**Purpose**: Full validation that a tool can be used in the current context.

**Parameters**:
- `toolName: ToolName` - The tool to validate
- `mode: Mode` - Current mode (e.g., "code", "architect", "ask")
- `customModes?: ModeConfig[]` - User-defined custom modes
- `toolRequirements?: Record<string, boolean>` - Special requirements (e.g., `{apply_diff: false}` disables diffs)
- `toolParams?: Record<string, unknown>` - Tool parameters (used for file restriction checks)
- `experiments?: Record<string, boolean>` - Feature flags
- `includedTools?: string[]` - Opt-in tools explicitly included

**Validation Steps**:
```typescript
// Step 1: Check if tool exists
if (!isValidToolName(toolName, experiments)) {
    throw new Error(`Unknown tool "${toolName}". This tool does not exist...`)
}

// Step 2: Check if tool is allowed for mode
if (!isToolAllowedForMode(...)) {
    throw new Error(`Tool "${toolName}" is not allowed in ${mode} mode.`)
}
```

---

#### 3. `isToolAllowedForMode(...)`

**Purpose**: The main permission check - determines if a tool is allowed in a specific mode.

**Permission Hierarchy** (checked in order):

```typescript
// 1. ALWAYS ALLOWED: Tools that are always available
if (ALWAYS_AVAILABLE_TOOLS.includes(tool)) return true
// Examples: ask_followup_question, attempt_completion, switch_mode, new_task, update_todo_list

// 2. CUSTOM TOOLS: Custom tools are allowed in any mode (for now)
if (experiments?.customTools && customToolRegistry.has(tool)) return true

// 3. EXPERIMENT FLAGS: Some tools require experiments to be enabled
if (experiments && Object.values(EXPERIMENT_IDS).includes(tool as ExperimentId)) {
    if (!experiments[tool]) return false
}

// 4. TOOL REQUIREMENTS: Explicit disabling of tools
if (toolRequirements) {
    if (tool in toolRequirements && !toolRequirements[tool]) return false
}
// Example: {apply_diff: false} disables the apply_diff tool

// 5. MODE GROUPS: Check if tool is in mode's allowed groups
const mode = getModeBySlug(modeSlug, customModes)
for (const group of mode.groups) {
    const groupName = getGroupName(group)
    const groupConfig = TOOL_GROUPS[groupName]

    // Check if tool is in this group
    const isRegularTool = groupConfig.tools.includes(tool)
    const isCustomTool = groupConfig.customTools?.includes(tool) && includedTools?.includes(tool)

    if (isRegularTool || isCustomTool) {
        // Additional checks for specific groups...
        return true
    }
}

return false
```

**Special Case: File Restrictions**

For edit tools in modes with file restrictions:

```typescript
if (groupName === "edit" && options.fileRegex) {
    const filePath = toolParams?.path
    const isEditOperation = EDIT_OPERATION_PARAMS.some(param => toolParams?.[param])

    // Validate single file path
    if (filePath && isEditOperation && !doesFileMatchRegex(filePath, options.fileRegex)) {
        throw new FileRestrictionError(mode.name, options.fileRegex, options.description, filePath, tool)
    }

    // Validate multi-file operations (XML args)
    if (toolParams?.args && typeof toolParams.args === "string") {
        // Extract and validate all <path>...</path> entries
        const filePathMatches = toolParams.args.match(/<path>([^<]+)<\/path>/g)
        // ... validate each path against fileRegex
    }
}
```

---

## Integration into Task Execution Flow

### Location: `src/core/assistant-message/presentAssistantMessage.ts`

This is where tool validation happens during task execution:

```typescript
export async function presentAssistantMessage(cline: Task) {
    // ... process streaming content blocks ...

    switch (block.type) {
        case "tool_use": {
            // Fetch current state for validation
            const state = await cline.providerRef.deref()?.getState()
            const { mode, customModes, experiments } = state ?? {}

            // ... handle partial blocks ...

            // VALIDATION HAPPENS HERE (only for complete blocks, not partial)
            if (!block.partial) {
                const modelInfo = cline.api.getModel()
                const includedTools = modelInfo?.info?.includedTools?.map(resolveToolAlias)

                try {
                    validateToolUse(
                        block.name as ToolName,
                        mode ?? defaultModeSlug,
                        customModes ?? [],
                        { apply_diff: cline.diffEnabled },  // Tool requirements
                        block.params,                       // Tool params (for file restrictions)
                        experiments,
                        includedTools,
                    )
                } catch (error) {
                    cline.consecutiveMistakeCount++

                    // Push error as tool_result (native protocol)
                    if (toolProtocol === TOOL_PROTOCOL.NATIVE && toolCallId) {
                        cline.pushToolResultToUserContent({
                            type: "tool_result",
                            tool_use_id: toolCallId,
                            content: formatResponse.toolError(error.message, toolProtocol),
                            is_error: true,
                        })
                    }

                    break  // Don't execute the tool
                }
            }

            // ... execute the validated tool ...
        }
    }
}
```

---

## Tool Filtering for Model API

### Location: `src/core/prompts/tools/filter-tools-for-mode.ts`

Before sending tools to the model API, they are filtered based on mode:

```typescript
export function filterNativeToolsForMode(
    nativeTools: OpenAI.Chat.ChatCompletionTool[],
    mode: string | undefined,
    customModes: ModeConfig[] | undefined,
    experiments: Record<string, boolean> | undefined,
    codeIndexManager?: CodeIndexManager,
    settings?: Record<string, any>,
    mcpHub?: McpHub,
): OpenAI.Chat.ChatCompletionTool[] {
    // Get all tools for this mode
    const allToolsForMode = getToolsForMode(modeConfig.groups)

    // Filter to only allowed tools using isToolAllowedForMode
    let allowedToolNames = new Set(
        allToolsForMode.filter(tool =>
            isToolAllowedForMode(tool, modeSlug, customModes ?? [], ...)
        )
    )

    // Apply model-specific customization
    const { allowedTools, aliasRenames } = applyModelToolCustomization(...)

    // Apply conditional exclusions based on settings
    if (!codeIndexManager?.isFeatureEnabled) {
        allowedToolNames.delete("codebase_search")
    }
    if (settings?.todoListEnabled === false) {
        allowedToolNames.delete("update_todo_list")
    }
    // ... more conditional checks ...

    // Return filtered tools
    return nativeTools.filter(tool => allowedToolNames.has(tool.function.name))
}
```

---

## Complete Flow: From API to Execution

```
1. User sends message
   ↓
2. System builds prompt with filtered tools
   - filterNativeToolsForMode() removes disallowed tools
   - Only allowed tools are sent to model API
   ↓
3. Model responds with tool calls
   ↓
4. presentAssistantMessage() processes response
   ↓
5. For each tool_use block:
   a. Wait for complete block (not partial)
   b. validateToolUse() checks permission
      - isValidToolName(): Does tool exist?
      - isToolAllowedForMode(): Is tool allowed in mode?
      - File restriction checks (if applicable)
   c. If validation fails:
      - Increment mistake counter
      - Push error as tool_result
      - Skip execution
   d. If validation succeeds:
      - Execute tool
      - Return result
```

---

## Mode Configuration Example

Modes define which tool groups are available:

```typescript
// Built-in modes (from @roo-code/types)
{
    slug: "code",
    name: "Code",
    groups: ["edit", "read", "command", "browser", "mcp", "ask"],
    roleDefinition: "You are Roo Code..."
}

{
    slug: "architect",
    name: "Architect",
    groups: ["read", "browser", "mcp"],
    roleDefinition: "You are an expert software architect..."
}

// Custom mode with file restrictions
{
    slug: "docs-only",
    name: "Documentation Mode",
    groups: [
        "read",
        ["edit", {
            fileRegex: ".*\\.(md|txt)$",
            description: "Only Markdown and text files"
        }]
    ],
    roleDefinition: "You can only edit documentation files"
}
```

**Tool Group Definitions** (from `src/shared/tools.ts`):

```typescript
export const TOOL_GROUPS = {
    edit: {
        tools: ["write_to_file", "apply_diff", "search_and_replace", "search_replace", "edit_file", "apply_patch"]
    },
    read: {
        tools: ["read_file", "list_files", "fetch_instructions", "search_files"]
    },
    command: {
        tools: ["execute_command"]
    },
    browser: {
        tools: ["browser_action"]
    },
    mcp: {
        tools: ["use_mcp_tool", "access_mcp_resource"]
    },
    ask: {
        tools: ["ask_followup_question"]
    }
}

export const ALWAYS_AVAILABLE_TOOLS = [
    "ask_followup_question",
    "attempt_completion",
    "switch_mode",
    "new_task",
    "update_todo_list",
    "codebase_search"
]
```

---

## Example Scenarios

### Scenario 1: Code Mode - All Tools Available

```typescript
Mode: "code"
Tool Call: read_file({ path: "src/index.ts" })

Validation Flow:
1. isValidToolName("read_file") → true (built-in tool)
2. isToolAllowedForMode("read_file", "code", ...) → true
   - Code mode includes "read" group
   - read_file is in TOOL_GROUPS.read.tools
Result: ✅ Tool executes
```

### Scenario 2: Architect Mode - Edit Tool Blocked

```typescript
Mode: "architect"
Tool Call: write_to_file({ path: "src/index.ts", content: "..." })

Validation Flow:
1. isValidToolName("write_to_file") → true
2. isToolAllowedForMode("write_to_file", "architect", ...) → false
   - Architect mode only includes ["read", "browser", "mcp"]
   - write_to_file is in TOOL_GROUPS.edit
   - "edit" group is NOT in architect mode
Result: ❌ Error: "Tool 'write_to_file' is not allowed in architect mode."
```

### Scenario 3: Custom Mode with File Restrictions

```typescript
Mode: "docs-only"
Mode Config: {
    groups: [
        "read",
        ["edit", { fileRegex: ".*\\.(md|txt)$" }]
    ]
}

Tool Call 1: write_to_file({ path: "README.md", content: "..." })
Validation:
1. isValidToolName("write_to_file") → true
2. isToolAllowedForMode(...) → true (edit group is allowed)
3. File restriction check:
   - "README.md" matches ".*\\.(md|txt)$" → true
Result: ✅ Tool executes

Tool Call 2: write_to_file({ path: "src/index.ts", content: "..." })
Validation:
1. isValidToolName("write_to_file") → true
2. isToolAllowedForMode(...) → throws FileRestrictionError
   - "src/index.ts" does NOT match ".*\\.(md|txt)$"
Result: ❌ Error: "Tool 'write_to_file' in mode 'docs-only' can only edit files matching pattern: .*\.(md|txt)$ (Only Markdown and text files). Got: src/index.ts"
```

### Scenario 4: Unknown Tool

```typescript
Mode: "code"
Tool Call: edit_file_legacy({ ... })  // Doesn't exist

Validation Flow:
1. isValidToolName("edit_file_legacy") → false
   - Not in validToolNames
   - Not a custom tool
   - Doesn't start with "mcp_"
Result: ❌ Error: "Unknown tool 'edit_file_legacy'. This tool does not exist. Please use one of the available tools: ..."
```

### Scenario 5: Disabled Tool via Requirements

```typescript
Mode: "code"
Tool Requirements: { apply_diff: false }  // User disabled diffs
Tool Call: apply_diff({ path: "src/index.ts", diff: "..." })

Validation Flow:
1. isValidToolName("apply_diff") → true
2. isToolAllowedForMode("apply_diff", "code", [], { apply_diff: false }, ...) → false
   - Tool requirements check fails
Result: ❌ Error: "Tool 'apply_diff' is not allowed in code mode."
```

---

## Key Takeaways

1. **Two-stage validation**: Existence check + Permission check
2. **Mode-based restrictions**: Tools are grouped, modes declare which groups they allow
3. **File-level restrictions**: Modes can restrict edit tools to specific file patterns
4. **Runtime enforcement**: Validation happens right before tool execution in `presentAssistantMessage`
5. **Proactive filtering**: Tools are filtered before being sent to the model API
6. **Always-available tools**: Some tools (like `attempt_completion`) are always available regardless of mode
7. **Custom modes**: Users can create modes with custom tool restrictions
8. **Error handling**: Validation errors increment mistake counter and return error tool_result

This system ensures that AI models:
- Only see tools they're allowed to use (via filtering)
- Can't bypass restrictions even if they try (via runtime validation)
- Get clear error messages when attempting to use disallowed tools
- Respect file-level restrictions in custom modes
