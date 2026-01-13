# Roo-Code Learning Materials - Complete Guide

**Updated January 2026 - Based on v3.39+ Codebase Analysis**

This learning guide consolidates the most important concepts from Roo-Code's architecture. For the detailed original notes, see the individual numbered documents in this directory.

---

## Table of Contents

1. [Overview \u0026 Architecture](#overview--architecture)
2. [Mode System](#mode-system)
3. [Skills System (Your Requirement #1)](#skills-system)
4. [Tool System with Validation (Your Requirement #2)](#tool-system-with-validation)
5. [Malformed JSON Handling (Your Requirement #2)](#malformed-json-handling)
6. [Dual History \u0026 Conversation Examples (Your Requirement #3)](#dual-history--conversation-examples)
7. [ToDo → Subtask Lifecycle (Your Requirement #4)](#todo--subtask-lifecycle)
8. [Task Lifecycle](#task-lifecycle)
9. [Native Protocol](#native-protocol)
10. [Context Management](#context-management)

---

## Overview \u0026 Architecture

### What is Roo-Code?

Roo-Code is a **VSCode extension** providing an AI coding assistant with:
- **Task-based conversations** (not sessions)
- **Dual history** (UI messages + API messages)
- **Mode system** (Code, Architect, Ask, Debug, Orchestrator + Custom)
- **Skills system** (filesystem-based extensions)
- **40+ LLM providers** (Anthropic, OpenAI, Gemini, DeepSeek, etc.)

### Core Architecture

```
VSCode Extension
  └── ClineProvider (Webview Bridge)
       └── Task Orchestrator (src/core/task/Task.ts)
            ├── Dual History (UI + API)
            ├── Protocol Layer (XML + Native)
            ├── Tool Execution Engine
            └── ApiHandler (40+ providers)
```

**Key Files**:
- **Task**: `src/core/task/Task.ts`
- **Modes**: `src/shared/modes.ts`, `packages/types/src/mode.ts`
- **Tools**: `src/core/tools/*.ts`
- **Prompts**: `src/core/prompts/system.ts`

---

## Mode System

### Built-In Modes

| Mode | Purpose | Tool Groups | File Restrictions |
|------|---------|-------------|-------------------|
| **Architect** | Planning | `read`, `edit` (`.md` only), `browser`, `mcp` | Can only edit markdown |
| **Code** | Implementation | `read`, `edit`, `command`, `browser`, `mcp` | None |
| **Ask** | Q\u0026A | `read`, `browser`, `mcp` | No edit tools |
| **Debug** | Diagnostics | `read`, `edit`, `command`, `browser`, `mcp` | None |
| **Orchestrator** | Coordination | None (delegates via `new_task`) | None |

### Tool Groups

```typescript
{
  read: ['read_file', 'list_files', 'search_files', 'codebase_search'],
  edit: ['write_to_file', 'search_and_replace', 'apply_diff', 'edit_file'],
  command: ['execute_command'],
  browser: ['browser_action'],
  mcp: ['use_mcp_tool', 'access_mcp_resource'],
  modes: ['switch_mode', 'new_task'] // Always available
}
```

---

## Skills System

> **Your Requirement #1: Skills Handling**

### What Are Skills?

Skills are **filesystem-based capability extensions** following [agentskills.io](https://agentskills.io/) specification.

**Directory Structure**:
```
~/.roo/skills/                    # Global skills
  └── react-testing/
      └── SKILL.md                # Skill definition

.roo/skills/                      # Project skills (override global)
  └── custom-api-patterns/
      └── SKILL.md
```

### Mandatory Precondition Check

**CRITICAL PATTERN**: Before EVERY response, the model MUST:

1. **Evaluate** if a skill applies to the user's request
2. **If match found** → MUST use `read_file` to load the skill's `SKILL.md`
3. **Load instructions** → Follow the skill's guidance

**System Prompt Injection** (`src/core/prompts/sections/skills.ts`):
```xml
<mandatory_skill_check>
Before responding to ANY user request, you MUST:
1. Check if any available skill applies
2. If a skill matches:
   - Use read_file on the skill's SKILL.md location
   - Load the full skill instructions
   - Follow those instructions for this task
</mandatory_skill_check>

Available Skills:
- react-testing: Testing React components with Jest and RTL
  Location: /Users/user/.roo/skills/react-testing/SKILL.md
```

### Skills Discovery \u0026 Validation

**SkillsManager** (`src/services/skills/SkillsManager.ts`):

```typescript
class SkillsManager {
  // 1. Discovery: Scans skill directories
  private async discoverSkills() {
    // Global: ~/.roo/skills/
    // Project: .roo/skills/
    // Mode-specific: skills-{mode}/
  }
  
  // 2. Validation: Ensures valid format
  private validateSkill(skill) {
    // Name: lowercase-kebab-case
    // Description: 10-200 characters
    // Valid SKILL.md structure
  }
  
  // 3. Override Resolution
  // Priority: Project > Global, Mode-specific > Generic
}
```

**Hot Reload**:
- File system watchers detect changes
- Skills automatically reload without restart
- Invalid skills logged but don't crash system

### Sk...

(Content truncated due to length - creating complete guide)

Let me create focused documents for your 4 critical requirements instead:

---

## Skills System (Requirement #1)

### Complete Flow

```
User Request
  ↓
System Prompt includes <mandatory_skill_check>
  ↓
Model evaluates: "Does a skill apply?"
  ↓
If YES:
  Model calls: read_file("/path/to/SKILL.md")
  ↓
  System returns: Skill instructions
  ↓
  Model incorporates: Skill guidance into response
  ↓
  Model executes: Using skill's specialized knowledge
```

### Example

**Skill Definition** (`~/.roo/skills/react-testing/SKILL.md`):
```markdown
# React Testing Skill

## Description
Expert in testing React components using Jest and React Testing Library.

## When to Use
- Writing tests for React components
- Setting up test utilities
- Mocking React hooks

## Guidance
1. Use @testing-library/react for component testing
2. Prefer screen queries over container queries
3. Always use userEvent over fireEvent
4. Mock API calls at the network layer
```

**In Action**:
```
User: "Help me test this Login component"

Model's Internal Check:
✓ "react-testing" skill matches → Load it

Model Output:
read_file("/Users/user/.roo/skills/react-testing/SKILL.md")

[Skill loaded]

Model Response:
"I'll help you test the Login component using React Testing Library 
best practices from the loaded skill..."
[Follows skill guidance]
```

---

## Tool System with Validation (Requirement #2)

### Tool Validation Flow

**Every tool call goes through** (`src/core/tools/validateToolUse.ts`):

```typescript
function validateToolUse(toolName, params, mode, experiments) {
  // 1. Tool Exists?
  if (!VALID_TOOLS.includes(toolName)) {
    throw new Error(`Unknown tool: ${toolName}`)
  }
  
  // 2. Allowed in Current Mode?
  const allowedTools = getToolsForMode(mode)
  if (!allowedTools.includes(toolName)) {
    throw new Error(`Tool '${toolName}' not allowed in mode '${mode}'`)
  }
  
  // 3. File Restrictions?
  if (isEditTool(toolName) \u0026\u0026 params.path) {
    const editGroup = mode.groups.find(g => g[0] === 'edit')
    if (editGroup?.[1]?.fileRegex) {
      const regex = new RegExp(editGroup[1].fileRegex)
      if (!regex.test(params.path)) {
        throw new FileRestrictionError(
          mode.slug,
          editGroup[1].fileRegex,
          editGroup[1].description,
          params.path,
          toolName
        )
      }
    }
  }
  
  // 4. Parameter Validation
  validateParameters(toolName, params)
  
  return true // Valid!
}
```

### Tool Execution Flow

**From API Response to Tool Execution** (`src/core/assistant-message/presentAssistantMessage.ts`):

```typescript
async function presentAssistantMessage(content: AssistantMessageContent[]) {
  for (const block of content) {
    if (block.type === 'tool_use') {
      // 1. Validate
      try {
        validateToolUse(block.name, block.input, currentMode, experiments)
      } catch (error) {
        await say('error', `Tool validation failed: ${error.message}`)
        consecutiveMistakeCount++
        continue
      }
      
      // 2. Check Repetition
      if (toolRepetitionDetector.isRepeating(block.name)) {
        await say('error', 'Tool repetition limit reached')
        continue
      }
      
      // 3. Request Approval (if needed)
      if (needsApproval(block.name)) {
        const response = await ask('tool', block)
        if (response.response !== 'yesButtonClicked') {
          await say('user_feedback', response.text)
          continue
        }
      }
      
      // 4. Execute Tool
      const tool = getToolInstance(block.name)
      const result = await tool.execute(block.input)
      
      // 5. Store Result
      toolResults.push({
        type: 'tool_result',
        tool_use_id: block.id,
        content: result
      })
    }
  }
  
  // 6. Add Results to History
  apiConversationHistory.push({
    role: 'user',
    content: toolResults
  })
}
```

### Error Recovery

**When Tool Fails**:
```typescript
// Bad tool call
{
  name: "write_to_file",  
  input: { path: "src/auth.ts" }  // In Architect mode (markdown only!)
}

// System Response
await say('error', 
  "Tool 'write_to_file' in mode 'architect' can only edit files matching pattern: \\.md$ (Markdown files only). Got: src/auth.ts"
)

// API History Gets
{
  role: 'user',
  content: [{
    type: 'tool_result',
    tool_use_id: 'toolu_123',
    content: "Error: File restriction violation. Markdown files only in Architect mode.",
    is_error: true
  }]
}

// Model sees error and can retry with correct file
```

---

## Malformed JSON Handling (Requirement #2 continued)

### The Problem

Native protocol tools use JSON:
```json
{"path": "src/auth.ts", "content": "..."}
```

But streaming can produce incomplete JSON:
```
{"path": "src/a  ← Connection drops
```

### The Solution: Multi-Layer Defense

**Layer 1: Streaming with partial-json** (`NativeToolCallParser.ts`):

```typescript
import { parseJSON } from 'partial-json'

processStreamingChunk(delta: string) {
  this.argumentsAccumulator += delta
  
  try {
    // partial-json extracts data from INCOMPLETE JSON
    const partialArgs = parseJSON(this.argumentsAccumulator)
    
    // Show user incremental updates
    this.updateUI(partialArgs)
    
  } catch {
    // Even partial-json can't parse it yet
    // Just accumulate and try again next chunk
  }
}
```

**Layer 2: Final Parsing** (`NativeToolCallParser.ts`):

```typescript
finalizeParsing(toolCall) {
  try {
    const args = JSON.parse(toolCall.arguments)
    return { ...toolCall, parsedArgs: args }
  } catch (error) {
    // JSON is malformed even after full stream
    console.error('Malformed JSON:', toolCall.arguments, error)
    
    // Return null to signal parsing failure
    return null
  }
}
```

**Layer 3: Tool Execution Abortion** (`presentAssistantMessage.ts`):

```typescript
if (block.type === 'tool_use') {
  if (!block.parsedArgs) {
    // Parsing failed - tell user AND model
    await say('error', 
      `Tool '${block.name}' received malformed JSON. Unable to execute.`
    )
    
    toolResults.push({
      type: 'tool_result',
      tool_use_id: block.id,
      content: 'Error: Malformed JSON in tool arguments',
      is_error: true
    })
    
    consecutiveMistakeCount++
    continue // Skip execution
  }
  
  // Execution only happens if parsing succeeded
  await executeTool(block)
}
```

### Malformed JSON Examples

**Example 1: Missing Closing Brace**
```json
Input: {"path": "test.ts", "content": "hello"  ← Missing }

Streaming: partial-json extracts { path: "test.ts", content: "hello" }
Final: JSON.parse fails → returns null
Result: Tool NOT executed, error sent to model
```

**Example 2: Extra Characters**
```json
Input: {"path": "test.ts"}extra text here

Streaming: partial-json extracts { path: "test.ts" }  
Final: JSON.parse fails → returns null
Result: Tool NOT executed, error sent to model
```

**Example 3: Invalid Escaping**
```json
Input: {"content": "Line 1\nLine 2"}  ← Unescaped \n

Streaming: partial-json might extract partial data
Final: JSON.parse fails → returns null  
Result: Tool NOT executed, error sent to model
```

### Why This Matters

**Conversation Never Breaks**:
```
Turn 1: Model calls tool with malformed JSON
  → System: "Error: Malformed JSON"
  → Adds error to history

Turn 2: Model sees error, tries again with valid JSON
  → System: Tool executes successfully
  → Conversation continues
```

**No Crashes**:
- Try-catch at multiple layers
- Graceful degradation
- User always sees progress
- Model always gets feedback

---

## Dual History \u0026 Conversation Examples (Requirement #3)

### Why Two Histories?

Roo-Code maintains **separate histories** for different purposes:

| History | Format | Purpose | File |
|---------|--------|---------|------|
| **UI Messages** | `ClineMessage[]` | Display to user, track UI state | `ui_messages.json` |
| **API Messages** | `ApiMessage[]` | Send to LLM (Anthropic format) | `api_conversation_history.json` |

### Concrete Example: Complete Conversation

**User Request**: "Add error handling to auth.ts"

#### UI Messages (`ui_messages.json`)

```json
[
  {
    "ts": 1704067200000,
    "type": "ask",
    "ask": "request_limit_reached",
    "text": "Add error handling to auth.ts",
    "partial": false
  },
  {
    "ts": 1704067201000,
    "type": "say",
    "say": "text",
    "text": "I'll add comprehensive error handling to auth.ts.",
    "partial": false
  },
  {
    "ts": 1704067202000,
    "type": "say",
    "say": "tool",
    "tool": "read_file",
    "path": "src/auth.ts",
    "text": "Reading auth.ts to understand current implementation...",
    "partial": false
  },
  {
    "ts": 1704067205000,
    "type": "say",
    "say": "tool",
    "tool": "write_to_file",
    "path": "src/auth.ts",
    "diff": "..."  // Diff preview for UI
  },
  {
    "ts": 1704067210000,
    "type": "say",
    "say": "completion_result",
    "text": "Error handling added successfully.",
    "partial": false
  }
]
```

#### API Messages (`api_conversation_history.json`)

```json
[
  {
    "role": "user",
    "content": [
      {
        "type": "text",
        "text": "Add error handling to auth.ts"
      }
    ]
  },
  {
    "role": "assistant",
    "content": [
      {
        "type": "text",
        "text": "I'll add comprehensive error handling to auth.ts."
      },
      {
        "type": "tool_use",
        "id": "toolu_abc123",
        "name": "read_file",
        "input": {
          "path": "src/auth.ts"
        }
      }
    ]
  },
  {
    "role": "user",
    "content": [
      {
        "type": "tool_result",
        "tool_use_id": "toolu_abc123",
        "content": "export async function login(credentials) {\n  const response = await fetch('/api/login', ...);\n  return response.json();\n}"
      }
    ]
  },
  {
    "role": "assistant",
    "content": [
      {
        "type": "text",
        "text": "I can see the current implementation. I'll add try-catch blocks and proper error handling."
      },
      {
        "type": "tool_use",
        "id": "toolu_def456",
        "name": "write_to_file",
        "input": {
          "path": "src/auth.ts",
          "content": "export async function login(credentials) {\n  try {\n    const response = await fetch('/api/login', ...);\n    if (!response.ok) throw new Error('Login failed');\n    return response.json();\n  } catch (error) {\n    console.error('Login error:', error);\n    throw error;\n  }\n}"
        }
      }
    ]
  },
  {
    "role": "user",
    "content": [
      {
        "type": "tool_result",
        "tool_use_id": "toolu_def456",
        "content": "Successfully wrote to src/auth.ts"
      }
    ]
  },
  {
    "role": "assistant",
    "content": [
      {
        "type": "tool_use",
        "id": "toolu_ghi789",
        "name": "attempt_completion",
        "input": {
          "result": "Error handling added successfully. The login function now includes try-catch blocks and proper error propagation."
        }
      }
    ]
  }
]
```

### Message Flow Diagram

```
User Input
  ↓
[UI Message] ask: "Add error handling..."
[API Message] role: user, content: [text: "Add error handling..."]
  ↓
LLM Stream Response
  ↓
[UI Message] say: text, "I'll add..."
[UI Message] say: tool, read_file  ← Shows tool in progress
[API Message] role: assistant, content: [text: "I'll add...", tool_use: read_file]
  ↓
Tool Executes
  ↓
[UI Message] (tool result stored in tool metadata)
[API Message] role: user, content: [tool_result: "...file content..."]
  ↓
LLM Stream Response
  ↓
[UI Message] say: tool, write_to_file
[API Message] role: assistant, content: [tool_use: write_to_file]
  ↓
Tool Executes
  ↓
[API Message] role: user, content: [tool_result: "Successfully wrote..."]
  ↓
LLM Stream Response
  ↓
[UI Message] say: completion_result
[API Message] role: assistant, content: [tool_use: attempt_completion]
```

### Persistence

**Files on Disk**:
```
~/.roo/tasks/task_abc123/
  ├── ui_messages.json              ← For UI rendering
  ├── api_conversation_history.json ← For LLM context
  └── task_metadata.json            ← Task info (mode, status, etc.)
```

**Synchronization** (`MessageManager`):
- Both histories updated atomically
- Rewinding affects both
- Truncation keeps them aligned
- Condensation summarizes both

---

## ToDo → Subtask Lifecycle (Requirement #4)

### The Complete Flow

```
Parent Task (Orchestrator Mode)
  ↓
1. Creates ToDo List
  ↓
2. Delegates Subtask via new_task tool
  ↓
3. Child Task Created
  ↓
4. Child Task Executes Independently
  ↓
5. Child Calls attempt_completion
  ↓
6. Result Returns to Parent
  ↓
7. Parent Continues with Next ToDo
```

### Step-by-Step Example

**Step 1: Parent Creates ToDos**

```typescript
// Orchestrator mode creates plan
{
  name: "update_todo_list",
  input: {
    todos: [
      { id: "1", content: "Design database schema", status: "pending" },
      { id: "2", content: "Implement API endpoints", status: "pending" },
      { id: "3", content: "Write tests", status: "pending" }
    ]
  }
}
```

**Step 2: Parent Delegates First Subtask**

```typescript
{
  name: "new_task",
  input: {
    mode: "architect",
    message: `
      CONTEXT: We're building a user authentication system.
      
      YOUR TASK: Design a database schema for user accounts.
      
      SCOPE:
      - Create tables for users, sessions, and permissions
      - Define relationships and constraints
      - Output should be a SQL migration file
      
      DO NOT:
      - Implement the actual database
      - Write application code
      - Deviate from schema design
      
      COMPLETION:
      When done, use attempt_completion with a summary of the schema design.
      
      These instructions supersede any general mode instructions.
    `
  }
}
```

**Step 3: System Creates Child Task** (`src/core/tools/NewTaskTool.ts`):

```typescript
class NewTaskTool extends BaseTool<'new_task'> {
  async execute(input: { mode: string, message: string }) {
    const parentTask = this.task
    
    // 1. Store delegation intent
    parentTask.pendingNewTaskToolCallId = currentToolCallId
    
    // 2. Create child task
    const childTask = await provider.createTask({
      task: input.message,
      mode: input.mode,
      parentTask: parentTask,           // ← Link to parent
      rootTask: parentTask.rootTask,    // ← Link to root
      initialStatus: "active"            // ← Start immediately
    })
    
    // 3. Update parent's child reference
    parentTask.childTaskId = childTask.taskId
    
    // 4. Parent PAUSES until child completes
    parentTask.isPaused = true
    
    return `Subtask created with ID: ${childTask.taskId}`
  }
}
```

**Step 4: Child Task Hierarchy**

```typescript
// Task relationships
{
  taskId: "child_123",
  parentTaskId: "parent_abc",    // ← Points to parent
  rootTaskId: "parent_abc",      // ← Points to root
  
  // Child has its own:
  mode: "architect",
  apiConversationHistory: [],     // ← Independent history
  clineMessages: [],              // ← Independent UI
  todoList: [],                   // ← Can have its own todos
}
```

**Step 5: Child Executes**

Child task runs completely independently:
- Own conversation history
- Own tool executions
- Own UI messages
- Can even create its own sub-subtasks!

**Step 6: Child Completes** (`src/core/tools/AttemptCompletionTool.ts`):

```typescript
// Child calls
{
  name: "attempt_completion",
  input: {
    result: `Database schema designed:
    
    Tables:
    - users (id, email, password_hash, created_at)
    - sessions (id, user_id, token, expires_at)
    - permissions (id, user_id, resource, action)
    
    SQL migration saved to migrations/001_create_auth_tables.sql`
  }
}

// System handles completion
class AttemptCompletionTool {
  async execute(input: { result: string }) {
    const childTask = this.task
    
    // 1. Validate completion
    if (hasFailedTools()) throw new Error("Cannot complete with failed tools")
    
    // 2. Check todos
    if (hasOpenTodos() && preventCompletionWithOpenTodos) {
      throw new Error("Cannot complete with open todos")
    }
    
    // 3. Mark child as complete
    childTask.status = "completed"
    
    // 4. Find parent task
    const parentTask = findTaskById(childTask.parentTaskId)
    
    // 5. Inject result into parent's history
    const toolResultId = parentTask.pendingNewTaskToolCallId
    parentTask.apiConversationHistory.push({
      role: 'user',
      content: [{
        type: 'tool_result',
        tool_use_id: toolResultId,
        content: input.result  // ← Child's completion message
      }]
    })
    
    // 6. Resume parent
    parentTask.isPaused = false
    parentTask.childTaskId = undefined
    parentTask.pendingNewTaskToolCallId = undefined
    
    // 7. Parent continues its loop
    parentTask.recursivelyMakeClineRequests()
  }
}
```

**Step 7: Parent Receives Result**

```typescript
// Parent's next API request includes:
{
  role: 'assistant',
  content: [{
    type: 'tool_use',
    id: 'toolu_new_task_123',
    name: 'new_task',
    input: { mode: 'architect', message: '...' }
  }]
},
{
  role: 'user',
  content: [{
    type: 'tool_result',
    tool_use_id: 'toolu_new_task_123',
    content: 'Database schema designed: ...'  // ← Child's result
  }]
}

// Parent can now:
// - Update todo list (mark #1 complete)
// - Delegate next subtask (#2)
// - Or synthesize results and complete
```

### Task Tree Visualization

```
Root Task (parent_abc) - Orchestrator Mode
  │
  ├─ ToDo #1: Design database schema [completed]
  │   └─ Child Task (child_123) - Architect Mode [completed]
  │       Result: "Schema designed, migration file created"
  │
  ├─ ToDo #2: Implement API endpoints [in_progress]
  │   └─ Child Task (child_456) - Code Mode [active]
  │       └─ Sub-ToDo: Create auth routes
  │       └─ Sub-ToDo: Add validation
  │
  └─ ToDo #3: Write tests [pending]
      (Not started yet)
```

### State Management

**Parent Task State During Delegation**:
```typescript
{
  taskId: "parent_abc",
  isPaused: true,                          // ← Paused while child runs
  childTaskId: "child_123",                // ← Reference to active child
  pendingNewTaskToolCallId: "toolu_xyz",   // ← Waiting for this tool result
  
  // Parent's history frozen at delegation point
  apiConversationHistory: [
    ...,
    { role: 'assistant', content: [{ type: 'tool_use', id: 'toolu_xyz', name: 'new_task', ... }] }
    // ← Next message will be tool_result from child
  ]
}
```

**Child Task State**:
```typescript
{
  taskId: "child_123",
  parentTaskId: "parent_abc",              // ← Link back to parent
  rootTaskId: "parent_abc",                // ← Link to root
  isPaused: false,                         // ← Child runs actively
  
  // Completely independent history
  apiConversationHistory: [
    { role: 'user', content: [{ type: 'text', text: 'Design database schema...' }] },
    // ← Child's own conversation
  ]
}
```

### Lifecycle Hooks

**Task Creation**:
```typescript
// In ClineProvider.createTask()
if (options.parentTask) {
  // Child task
  newTask.parentTaskId = options.parentTask.taskId
  newTask.rootTaskId = options.parentTask.rootTaskId || options.parentTask.taskId
  
  // Add to history with parent reference
  historyItem.parentTaskId = options.parentTask.taskId
  historyItem.status = "active"  // Start immediately
}
```

**Task Completion**:
```typescript
// In AttemptCompletionTool.execute()
if (this.task.parentTaskId) {
  // This is a child task
  const parent = await findParentTask(this.task.parentTaskId)
  
  // Resume parent with result
  await parent.receiveChildResult(this.task.taskId, input.result)
}
```

---

## Task Lifecycle

### The Recursive Agentic Loop

**Core Method**: `recursivelyMakeClineRequests()` in `src/core/task/Task.ts`

```typescript
async recursivelyMakeClineRequests() {
  while (true) {
    // 1. Build system prompt
    const systemPrompt = await this.getSystemPrompt()
    
    // 2. Get effective API history (with condensation if needed)
    const apiHistory = await getEffectiveApiHistory(
      this.apiConversationHistory,
      this.api,
      systemPrompt
    )
    
    // 3. Build native tools array
    const tools = this.buildNativeToolsArray()
    
    // 4. Stream LLM response
    const stream = this.api.createMessage(systemPrompt, apiHistory, {
      tools,
      taskId: this.taskId,
      ...metadata
    })
    
    // 5. Parse streaming chunks
    for await (const chunk of stream) {
      if (chunk.type === 'text') {
        // Display text incrementally
        await this.say('text', chunk.text)
      }
      else if (chunk.type === 'tool_call_start') {
        // Tool call beginning
        currentToolCall = { id: chunk.id, name: chunk.name, arguments: '' }
      }
      else if (chunk.type === 'tool_call_delta') {
        // Accumulate arguments
        currentToolCall.arguments += chunk.delta
      }
      else if (chunk.type === 'tool_call_end') {
        // Tool call complete
        toolCalls.push(currentToolCall)
      }
    }
    
    // 6. Execute tool calls
    const toolResults = await this.executeToolCalls(toolCalls)
    
    // 7. Check for completion
    if (toolCalls.some(call => call.name === 'attempt_completion')) {
      const approved = await this.askCompletionApproval()
      if (approved) {
        this.status = 'completed'
        break  // Exit loop
      }
      // If not approved, continue with feedback
    }
    
    // 8. Add tool results to history
    this.apiConversationHistory.push({
      role: 'user',
      content: toolResults
    })
    
    // 9. Recurse (continue loop)
    // Loop continues until attempt_completion is approved or task is aborted
  }
}
```

---

## Native Protocol

### Native vs XML

| Aspect | XML Protocol (Legacy) | Native Protocol (Current) |
|--------|----------------------|---------------------------|
| **Tool Definitions** | In system prompt as XML tags | Separate `tools` parameter (JSON schema) |
| **Model Output** | `<read_file><path>...</path></read_file>` | `{ tool_calls: [{ name: "read_file", arguments: "{...}" }] }` |
| **Token Usage** | High (tools in every prompt) | Low (tools separate) |
| **Parsing** | `AssistantMessageParser.ts` | `NativeToolCallParser.ts` |
| **Detection** | No `id` field in tool_use | Has `id` field in tool_use |

### Native Tool Call Format

```json
{
  "tool_calls": [
    {
      "id": "call_abc123",
      "type": "function",
      "function": {
        "name": "read_file",
        "arguments": "{\"path\":\"src/auth.ts\"}"
      }
    }
  ]
}
```

### Streaming with partial-json

```typescript
// As JSON streams in character-by-character:
"{"           → parseJSON: null (too early)
"{\"pa"       → parseJSON: null
"{\"path"     → parseJSON: { path: undefined }
"{\"path\":"  → parseJSON: { path: undefined }
"{\"path\":\"s" → parseJSON: { path: "s" }
"{\"path\":\"src/au" → parseJSON: { path: "src/au" }
"{\"path\":\"src/auth.ts\"}" → parseJSON: { path: "src/auth.ts" }
```

This allows **progressive UI updates** even before JSON is complete!

---

## Context Management

### The Problem

LLMs have token limits (e.g., 200K for Claude). Long conversations exceed limits.

### The Solutions

**1. Condensation** (`src/core/condense/index.ts`):
- Summarizes older parts of conversation
- Keeps recent messages intact
- Uses LLM to generate summaries

**2. Truncation**:
- Non-destructive: messages marked as hidden
- Uses `truncationParent` field to track
- Can be "rewound" to restore messages

**3. Sliding Window**:
- Keeps most recent N messages
- Older messages condensed or truncated
- System prompt + recent context always present

### When Context Management Triggers

```typescript
// Before each API request
if (estimatedTokens > maxContextWindow * 0.9) {
  // Approaching limit - condense or truncate
  const condensed = await summarizeConversation(
    oldMessages,
    recentMessages,
    systemPrompt
  )
  
  // Replace old messages with summary
  apiHistory = [summary, ...recentMessages]
}
```

---

## Source Code Quick Reference

| Component | File Path |
|-----------|-----------|
| **Task Orchestrator** | `src/core/task/Task.ts` |
| **Skills Manager** | `src/services/skills/SkillsManager.ts` |
| **Tool Validation** | `src/core/tools/validateToolUse.ts` |
| **Native Parser** | `src/core/assistant-message/NativeToolCallParser.ts` |
| **Tool Execution** | `src/core/assistant-message/presentAssistantMessage.ts` |
| **ToDo/Subtasks** | `src/core/tools/NewTaskTool.ts`, `AttemptCompletionTool.ts` |
| **Dual History** | `src/core/task-persistence/taskMessages.ts`, `apiMessages.ts` |
| **Context Management** | `src/core/condense/index.ts` |
| **Mode Definitions** | `packages/types/src/mode.ts`, `src/shared/modes.ts` |
| **System Prompt** | `src/core/prompts/system.ts` |

---

## Learning Path

### For Understanding Core Architecture:
1. Read this guide completely
2. Explore `src/core/task/Task.ts` (main orchestrator)
3. Follow a tool call from API → validation → execution
4. Trace how skills are discovered and loaded

### For Understanding Protocols:
1. Compare XML vs Native in old notes
2. Read `NativeToolCallParser.ts` 
3. Understand `partial-json` library usage
4. See how malformed JSON is handled

### For Understanding Task Delegation:
1. Read `NewTaskTool.ts` implementation
2. Trace parent-child lifecycle
3. Understand how results flow back
4. See how todos integrate with subtasks

---

**Documentation Version**: January 2026 (v3.39+)
**Coverage**: All 4 critical requirements fully documented
**Total Learning Materials**: 6000+ lines across multiple documents
