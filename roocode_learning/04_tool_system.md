# 04: Tool System

**Tool Definitions, Validation, Execution, and Error Recovery**

---

## Overview

Tools are **actions the AI can take**. Every tool call goes through a strict validation and execution pipeline.

**Key Files**:
- Tool implementations: `src/core/tools/*.ts`
- Validation: `src/core/tools/validateToolUse.ts`
- Execution: `src/core/assistant-message/presentAssistantMessage.ts`

---

## Tool Categories

### Read Tools
- `read_file` - Read file contents
- `list_files` - List directory contents
- `search_files` - Search by filename pattern
- `codebase_search` - Semantic code search

### Edit Tools
- `write_to_file` - Create or overwrite files
- `search_and_replace` - Find and replace in files
- `apply_diff` - Apply unified diffs
- `edit_file` - Interactive file editing

### Command Tools
- `execute_command` - Run shell commands

### Browser Tools
- `browser_action` - Automated browsing

### MCP Tools
- `use_mcp_tool` - Call MCP server tools
- `access_mcp_resource` - Access MCP resources

### Meta Tools
- `switch_mode` - Change AI mode
- `new_task` - Delegate to subtask
- `attempt_completion` - Complete task

---

## Validation Flow

### Complete Validation Pipeline

```typescript
// src/core/tools/validateToolUse.ts
export function validateToolUse(
  toolName: ToolName,
  params: any,
  mode: ModeConfig,
  experiments?: Record<string, boolean>
): boolean {
  
  // 1. Tool exists?
  if (!isValidToolName(toolName)) {
    throw new Error(`Unknown tool "${toolName}". Available tools: ${VALID_TOOLS.join(', ')}`)
  }
  
  // 2. Tool allowed in current mode?
  const modeTools = getToolsForMode(mode.groups)
  if (!modeTools.includes(toolName)) {
    throw new Error(
      `Tool "${toolName}" is not available in mode "${mode.slug}". ` +
      `Available tools: ${modeTools.join(', ')}`
    )
  }
  
  // 3. File restrictions (if applicable)?
  if (isEditTool(toolName) && params.path) {
    const editGroup = mode.groups.find(g => getGroupName(g) === 'edit')
    
    if (Array.isArray(editGroup)) {
      const [_, options] = editGroup
      
      if (options?.fileRegex) {
        const regex = new RegExp(options.fileRegex)
        
        if (!regex.test(params.path)) {
          throw new FileRestrictionError(
            mode.slug,
            options.fileRegex,
            options.description,
            params.path,
            toolName
          )
        }
      }
    }
  }
  
  // 4. Parameter validation
  validateToolParameters(toolName, params)
  
  return true
}
```

### Example Validation Errors

**Unknown Tool**:
```
Error: Unknown tool "invalid_tool". Available tools: read_file, write_to_file, execute_command, ...
```

**Tool Not Allowed in Mode**:
```
Error: Tool "execute_command" is not available in mode "ask". Available tools: read_file, list_files, search_files, browser_action
```

**File Restriction Violation**:
```
Error: Tool 'write_to_file' in mode 'architect' can only edit files matching pattern: \.md$ (Markdown files only). Got: src/auth.ts
```

---

## Tool Execution Flow

### From API Response to Execution

```typescript
// src/core/assistant-message/presentAssistantMessage.ts
async function presentAssistantMessage(
  content: AssistantMessageContent[],
  task: Task
): Promise<void> {
  
  for (const block of content) {
    if (block.type === 'text') {
      await task.say('text', block.text)
    }
    else if (block.type === 'tool_use') {
      // ==========================================
      // STEP 1: Validation
      // ==========================================
      try {
        validateToolUse(
          block.name,
          block.input,
          task.currentMode,
          task.experiments
        )
      } catch (error) {
        // Validation failed
        await task.say('error', `Tool validation failed: ${error.message}`)
        
        // Add error to API history
        toolResults.push({
          type: 'tool_result',
          tool_use_id: block.id,
          content: `Error: ${error.message}`,
          is_error: true
        })
        
        task.consecutiveMistakeCount++
        continue // Skip execution
      }
      
      // ==========================================
      // STEP 2: Repetition Check
      // ==========================================
      if (task.toolRepetitionDetector.isRepeating(block.name)) {
        await task.say('error', `Tool repetition limit reached for ${block.name}`)
        
        toolResults.push({
          type: 'tool_result',
          tool_use_id: block.id,
          content: 'Error: Tool repetition limit exceeded',
          is_error: true
        })
        
        continue // Skip execution
      }
      
      // ==========================================
      // STEP 3: User Approval (if needed)
      // ==========================================
      if (needsApproval(block.name, block.input)) {
        const response = await task.ask('tool', {
          tool: block.name,
          params: block.input
        })
        
        if (response.response !== 'yesButtonClicked') {
          // User rejected or provided feedback
          await task.say('user_feedback', response.text || 'Tool execution rejected')
          
          toolResults.push({
            type: 'tool_result',
            tool_use_id: block.id,
            content: response.text || 'User rejected tool execution'
          })
          
          continue // Skip execution
        }
      }
      
      // ==========================================
      // STEP 4: Execute Tool
      // ==========================================
      const tool = getToolInstance(block.name)
      
      try {
        const result = await tool.execute(block.input, task)
        
        // Success
        await task.say('tool_result', result)
        
        toolResults.push({
          type: 'tool_result',
          tool_use_id: block.id,
          content: result
        })
        
        task.toolRepetitionDetector.recordToolUse(block.name)
        
      } catch (error) {
        // Execution failed
        await task.say('error', `Tool execution failed: ${error.message}`)
        
        toolResults.push({
          type: 'tool_result',
          tool_use_id: block.id,
          content: `Error: ${error.message}`,
          is_error: true
        })
      }
    }
  }
  
  // ==========================================
  // STEP 5: Add Results to History
  // ==========================================
  if (toolResults.length > 0) {
    task.apiConversationHistory.push({
      role: 'user',
      content: toolResults
    })
  }
}
```

---

## Tool Repetition Detection

### Purpose
Prevent infinite loops where AI repeatedly calls the same tool.

### Implementation

```typescript
// src/core/tools/ToolRepetitionDetector.ts
class ToolRepetitionDetector {
  private toolUsageHistory: Map<string, number[]> = new Map()
  private readonly WINDOW_SIZE = 10
  private readonly MAX_REPETITIONS = 4
  
  recordToolUse(toolName: string): void {
    const now = Date.now()
    const history = this.toolUsageHistory.get(toolName) || []
    
    history.push(now)
    
    // Keep only recent history
    const recentHistory = history.slice(-this.WINDOW_SIZE)
    this.toolUsageHistory.set(toolName, recentHistory)
  }
  
  isRepeating(toolName: string): boolean {
    const history = this.toolUsageHistory.get(toolName) || []
    
    if (history.length < this.MAX_REPETITIONS) {
      return false
    }
    
    // Check if tool was called MAX_REPETITIONS times in WINDOW_SIZE
    const recent = history.slice(-this.MAX_REPETITIONS)
    return recent.length >= this.MAX_REPETITIONS
  }
}
```

### Error Message

```
Tool repetition limit reached for 'read_file'. 
The model has called this tool 4 times in a short period.
This may indicate an infinite loop or confusion.
```

---

## Error Recovery Patterns

### Pattern 1: Validation Error → Model Correction

```
Turn 1: Model calls write_to_file on src/auth.ts (in Architect mode)
  → Validation Error: "Can only edit .md files"
  → Error added to history as tool_result

Turn 2: Model sees error, corrects itself
  → Calls write_to_file on plan.md instead
  → Success!
```

### Pattern 2: Execution Error → Retry with Fix

```
Turn 1: Model calls execute_command("npm test")
  → Execution Error: "Command not found: npm"
  → Error added to history

Turn 2: Model sees error, diagnoses
  → Calls read_file("package.json") to understand project
  → Discovers it's not a Node project
  → Adjusts approach
```

### Pattern 3: User Rejection → Alternative Approach

```
Turn 1: Model calls execute_command("rm -rf node_modules")
  → User rejects: "Too dangerous, let's be more careful"
  → Feedback added to history

Turn 2: Model adjusts
  → Calls list_files to see what's in node_modules
  → Proposes safer alternative
```

---

## Source Code References

| Component | File Path |
|-----------|-----------|
| **Tool Validation** | `src/core/tools/validateToolUse.ts` |
| **Tool Execution** | `src/core/assistant-message/presentAssistantMessage.ts` |
| **Read File Tool** | `src/core/tools/ReadFileTool.ts` |
| **Write File Tool** | `src/core/tools/WriteToFileTool.ts` |
| **Execute Command** | `src/core/tools/ExecuteCommandTool.ts` |
| **New Task Tool** | `src/core/tools/NewTaskTool.ts` |
| **Completion Tool** | `src/core/tools/AttemptCompletionTool.ts` |
| **Repetition Detector** | `src/core/tools/ToolRepetitionDetector.ts` |

---

**Version**: Roo-Code v3.39+ (January 2026)
