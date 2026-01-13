# 03: Task Lifecycle

**How Roo-Code Tasks Are Created, Executed, and Completed**

---

## Overview

In Roo-Code, a **Task** is the fundamental unit of an AI conversation. Unlike "sessions" in other tools, tasks are:
- **Self-contained**: Each task has its own history, state, and mode
- **Persistent**: Tasks save to disk and can be resumed later
- **Hierarchical**: Tasks can create child tasks via delegation
- **Mode-locked**: Each task runs in a specific mode

**Key File**: `src/core/task/Task.ts` (~4000 lines)

---

## Task Creation

### Three Ways to Create a Task

#### 1. New Task (User-Initiated)

```typescript
// In ClineProvider.ts
async createTask(options: CreateTaskOptions) {
  const task = new Task({
    provider: this,
    apiConfiguration: currentProviderSettings,
    task: options.task,              // User's request
    images: options.images,          // Optional image attachments
    mode: options.mode || 'code',    // Default to Code mode
    startTask: true                  // Start immediately
  })
  
  // Initialize async properties
  await task.waitForModeInitialization()
  
  // Start the agentic loop
  if (options.startTask) {
    await task.initiateTaskLoop()
  }
  
  return task
}
```

#### 2. Resume from History

```typescript
// Loading from task_history.json
async createTaskWithHistoryItem(historyItem: HistoryItem) {
  const task = new Task({
    provider: this,
    apiConfiguration: getProviderSettings(),
    historyItem: historyItem,        // ← Load from history
    startTask: false                 // Don't auto-start
  })
  
  // Task restores:
  // - Mode from historyItem.mode
  // - Messages from ui_messages.json
  // - API history from api_conversation_history.json
  // - Tool protocol from historyItem.toolProtocol
  
  return task
}
```

#### 3. Child Task (Delegation)

```typescript
// Via new_task tool
async createTask(options: CreateTaskOptions) {
  const task = new Task({
    provider: this,
    apiConfiguration: currentProviderSettings,
    task: options.task,
    mode: options.mode,
    parentTask: options.parentTask,     // ← Link to parent
    rootTask: options.rootTask,         // ← Link to root
    initialStatus: 'active'             // ← Start immediately
  })
  
  return task
}
```

---

## Task Initialization

### Constructor Phase

```typescript
constructor(options: TaskOptions) {
  // 1. Basic identifiers
  this.taskId = crypto.randomUUID()
  this.instanceId = crypto.randomUUID()
  this.rootTaskId = options.rootTask?.taskId
  this.parentTaskId = options.parentTask?.taskId
  
  // 2. Initialize mode (async)
  if (options.historyItem) {
    // Resume: mode from history
    this._taskMode = options.historyItem.mode || defaultModeSlug
    this.taskModeReady = Promise.resolve()
  } else {
    // New task: fetch mode from provider state
    this.taskModeReady = this.initializeTaskMode()
  }
  
  // 3. Resolve tool protocol
  if (options.historyItem) {
    // Detect from history or use stored protocol
    this._taskToolProtocol = 
      options.historyItem.toolProtocol ||
      detectToolProtocolFromHistory(apiHistory)
  } else {
    // New task: use current settings
    this._taskToolProtocol = resolveToolProtocol(settings)
  }
  
  // 4. Load or initialize histories
  if (options.historyItem) {
    this.loadHistoriesFromDisk()
  } else {
    this.apiConversationHistory = []
    this.clineMessages = []
  }
  
  // 5. Initialize services
  this.fileContextTracker = new FileContextTracker()
  this.toolRepetitionDetector = new ToolRepetitionDetector()
  this.messageQueueService = new MessageQueueService()
  this.browserSession = new BrowserSession()
  
  // 6. Create history entry
  this.addToHistory()
}
```

### Async Initialization

```typescript
private async initializeTaskMode(): Promise<void> {
  const providerState = await this.providerRef.deref()?.getState()
  this._taskMode = providerState?.currentMode || defaultModeSlug
}

// Wait for initialization before starting
await task.waitForModeInitialization()
```

---

## The Agentic Loop

### Core Method: `recursivelyMakeClineRequests()`

This is the **heart** of Roo-Code's AI execution:

```typescript
async recursivelyMakeClineRequests(): Promise<void> {
  while (true) {
    // ========================================
    // PHASE 1: Preparation
    // ========================================
    
    // Check for abort/pause
    if (this.abort) return
    if (this.isPaused) return
    
    // Handle pending asks (user approval needed)
    if (this.idleAsk || this.interactiveAsk) {
      await this.waitForAskResponse()
      continue
    }
    
    // ========================================
    // PHASE 2: Build API Request
    // ========================================
    
    // Get system prompt
    const systemPrompt = await this.getSystemPrompt()
    
    // Get effective API history (with context management)
    const apiHistory = await getEffectiveApiHistory(
      this.apiConversationHistory,
      this.api,
      systemPrompt,
      {
        maxTokens: this.api.getModel().info.maxTokens,
        condensationEnabled: true
      }
    )
    
    // Build native tools array
    const tools = this.buildNativeToolsArray()
    
    // ========================================
    // PHASE 3: Stream LLM Response
    // ========================================
    
    const stream = this.api.createMessage(systemPrompt, apiHistory, {
      tools,
      taskId: this.taskId,
      abortSignal: this.currentRequestAbortController?.signal
    })
    
    // Track streaming state
    let textAccumulator = ''
    let toolCalls: ToolUse[] = []
    let currentToolCall: Partial<ToolUse> | null = null
    
    // ========================================
    // PHASE 4: Parse Streaming Chunks
    // ========================================
    
    for await (const chunk of stream) {
      if (chunk.type === 'text') {
        textAccumulator += chunk.text
        await this.say('text', chunk.text, true) // partial=true
      }
      else if (chunk.type === 'tool_call_start') {
        currentToolCall = {
          id: chunk.id,
          name: chunk.name,
          input: {}
        }
        await this.say('tool', currentToolCall.name, true)
      }
      else if (chunk.type === 'tool_call_delta') {
        // Accumulate tool arguments
        currentToolCall.arguments += chunk.delta
        
        // Try partial parsing for UI updates
        try {
          const partial = parseJSON(currentToolCall.arguments)
          await this.updateToolUI(partial)
        } catch {
          // Not parseable yet
        }
      }
      else if (chunk.type === 'tool_call_end') {
        // Finalize tool call
        const parsedArgs = JSON.parse(currentToolCall.arguments)
        toolCalls.push({
          ...currentToolCall,
          input: parsedArgs
        })
        currentToolCall = null
      }
      else if (chunk.type === 'usage') {
        this.updateUsageMetrics(chunk.usage)
      }
    }
    
    // ========================================
    // PHASE 5: Execute Tool Calls
    // ========================================
    
    const toolResults: ToolResult[] = []
    
    for (const toolCall of toolCalls) {
      // Validate tool
      try {
        validateToolUse(
          toolCall.name,
          toolCall.input,
          this.currentMode,
          this.experiments
        )
      } catch (error) {
        await this.say('error', error.message)
        toolResults.push({
          type: 'tool_result',
          tool_use_id: toolCall.id,
          content: `Error: ${error.message}`,
          is_error: true
        })
        continue
      }
      
      // Check repetition
      if (this.toolRepetitionDetector.isRepeating(toolCall.name)) {
        await this.say('error', 'Tool repetition limit reached')
        toolResults.push({
          type: 'tool_result',
          tool_use_id: toolCall.id,
          content: 'Error: Tool repetition limit exceeded',
          is_error: true
        })
        continue
      }
      
      // Request approval if needed
      if (this.needsApproval(toolCall)) {
        const response = await this.ask('tool', toolCall)
        if (response.response !== 'yesButtonClicked') {
          // User rejected or provided feedback
          toolResults.push({
            type: 'tool_result',
            tool_use_id: toolCall.id,
            content: response.text || 'User rejected tool execution'
          })
          continue
        }
      }
      
      // Execute tool
      const tool = this.getToolInstance(toolCall.name)
      const result = await tool.execute(toolCall.input, this)
      
      toolResults.push({
        type: 'tool_result',
        tool_use_id: toolCall.id,
        content: result
      })
    }
    
    // ========================================
    // PHASE 6: Handle Completion
    // ========================================
    
    const completionTool = toolCalls.find(t => t.name === 'attempt_completion')
    if (completionTool) {
      const approved = await this.handleCompletion(completionTool)
      if (approved) {
        this.status = 'completed'
        this.emit(RooCodeEventName.TaskCompleted)
        return // Exit loop
      }
      // If not approved, feedback is in toolResults, continue loop
    }
    
    // ========================================
    // PHASE 7: Add to History & Recurse
    // ========================================
    
    // Add assistant message to history
    this.apiConversationHistory.push({
      role: 'assistant',
      content: [
        { type: 'text', text: textAccumulator },
        ...toolCalls.map(tc => ({
          type: 'tool_use',
          id: tc.id,
          name: tc.name,
          input: tc.input
        }))
      ]
    })
    
    // Add tool results to history
    if (toolResults.length > 0) {
      this.apiConversationHistory.push({
        role: 'user',
        content: toolResults
      })
    }
    
    // Save histories to disk
    await this.saveApiMessages()
    await this.saveClineMessages()
    
    // Loop continues (recurse)
  }
}
```

---

## State Management

### Task State Properties

```typescript
class Task {
  // Lifecycle state
  abort: boolean = false
  isPaused: boolean = false
  isInitialized: boolean = false
  abandoned: boolean = false
  
  // Ask state (waiting for user)
  idleAsk?: ClineMessage        // Informational ask
  resumableAsk?: ClineMessage   // Can continue without response
  interactiveAsk?: ClineMessage // Blocking ask
  
  // Child task state
  childTaskId?: string
  pendingNewTaskToolCallId?: string
  
  // Streaming state
  didFinishAbortingStream: boolean = false
  currentRequestAbortController?: AbortController
  
  // Histories
  apiConversationHistory: ApiMessage[] = []
  clineMessages: ClineMessage[] = []
  
  // Mode \u0026 Protocol (locked for task lifetime)
  private _taskMode: string
  private _taskToolProtocol: ToolProtocol
}
```

### State Transitions

```
Created → Initialized → Active → [Paused] → Completed
                  ↓                    ↓
                Aborted            Abandoned
```

**States**:
- **Created**: Constructor finished
- **Initialized**: `isInitialized = true` after first API call setup
- **Active**: Loop running, making API requests
- **Paused**: `isPaused = true` (child task running, or user pause)
- **Completed**: `status = 'completed'`, `attempt_completion` approved
- **Aborted**: `abort = true`, user cancelled
- **Abandoned**: Task closed without completion

---

## Task Completion

### Attempt Completion Flow

```typescript
private async handleCompletion(toolCall: ToolUse): Promise<boolean> {
  // 1. Check for failed tools in current turn
  if (this.hasFailedToolsInTurn()) {
    await this.say('error', 'Cannot complete with failed tools')
    return false
  }
  
  // 2. Check for open todos
  if (this.hasOpenTodos() && this.preventCompletionWithOpenTodos) {
    await this.say('error', 'Cannot complete with open todos')
    return false
  }
  
  // 3. Ask user for approval
  const response = await this.ask('completion_result', {
    result: toolCall.input.result
  })
  
  if (response.response === 'yesButtonClicked') {
    // Approved
    this.status = 'completed'
    this.emit(RooCodeEventName.TaskCompleted)
    
    // If child task, notify parent
    if (this.parentTaskId) {
      await this.notifyParentOfCompletion(toolCall.input.result)
    }
    
    return true
  } else {
    // User provided feedback
    await this.say('user_feedback', response.text)
    
    // Add feedback to history, loop continues
    return false
  }
}
```

---

## Task Disposal

### Cleanup on Task End

```typescript
public dispose(): void {
  // 1. Cancel in-progress HTTP request
  this.cancelCurrentRequest()
  
  // 2. Remove event listeners
  this.removeAllListeners()
  
  // 3. Dispose services
  this.messageQueueService.dispose()
  
  // 4. Release terminals
  TerminalRegistry.releaseTerminalsForTask(this.taskId)
  
  // 5. Close browser sessions
  this.urlContentFetcher.closeBrowser()
  this.browserSession.closeBrowser()
  
  // 6. Unsubscribe from bridge (if enabled)
  if (this.enableBridge) {
    BridgeOrchestrator.getInstance()
      ?.unsubscribeFromTask(this.taskId)
  }
}
```

---

## Task Persistence

### Files on Disk

```
~/.roo/tasks/task_{taskId}/
├── api_conversation_history.json  # LLM context
├── ui_messages.json                # UI display
└── task_metadata.json              # Mode, status, etc.
```

### Saving

```typescript
private async saveApiMessages(): Promise<void> {
  await saveApiMessages(
    this.globalStoragePath,
    this.taskId,
    this.apiConversationHistory
  )
}

private async saveClineMessages(): Promise<void> {
  await saveTaskMessages(
    this.globalStoragePath,
    this.taskId,
    this.clineMessages
  )
}
```

### Loading

```typescript
private async loadHistoriesFromDisk(): Promise<void> {
  this.apiConversationHistory = await readApiMessages(
    this.globalStoragePath,
    this.taskId
  )
  
  this.clineMessages = await readTaskMessages(
    this.globalStoragePath,
    this.taskId
  )
}
```

---

## Key Concepts

### Task vs Session

| Task (Roo-Code) | Session (Other Tools) |
|-----------------|----------------------|
| Self-contained unit | Continuous conversation |
| Can be paused/resumed | Usually continuous |
| Mode-locked | May not have modes |
| Hierarchical (parent/child) | Flat structure |
| Persistent to disk | May be in-memory |

### Mode Locking

```typescript
// Mode is set at task creation and NEVER changes
constructor(options: TaskOptions) {
  this._taskMode = options.mode || 'code'
  // This mode is locked for the task's lifetime
}

// To change mode, use switch_mode tool
// → Creates NEW task in different mode
// → Original task remains in original mode
```

### Protocol Locking

```typescript
// Protocol is locked to prevent incompatibility
constructor(options: TaskOptions) {
  if (options.historyItem) {
    // Resume with same protocol as before
    this._taskToolProtocol = 
      options.historyItem.toolProtocol ||
      detectToolProtocolFromHistory(apiHistory)
  } else {
    // New task: current protocol
    this._taskToolProtocol = resolveToolProtocol(settings)
  }
  
  // This protocol is LOCKED for task lifetime
  // Even if user changes settings, this task keeps its protocol
}
```

---

## Related Documents

- **[04: Tool System](./04_tool_system.md)** - Tool validation and execution
- **[05: Dual History](./05_dual_history.md)** - UI vs API messages
- **[10: Task Completion](./10_task_completion.md)** - Completion handling
- **[11: ToDo and Subtasks](./11_todo_and_subtasks.md)** - Task delegation

---

## Source Code References

| Component | File Path | Key Methods |
|-----------|-----------|-------------|
| **Task Class** | `src/core/task/Task.ts` | `recursivelyMakeClineRequests()`, `handleCompletion()` |
| **Task Creation** | `src/core/webview/ClineProvider.ts` | `createTask()`, `createTaskWithHistoryItem()` |
| **Persistence** | `src/core/task-persistence/` | `saveApiMessages()`, `saveTaskMessages()` |
| **Tool Execution** | `src/core/assistant-message/presentAssistantMessage.ts` | Tool execution loop |

---

**Version**: Roo-Code v3.39+ (January 2026)
