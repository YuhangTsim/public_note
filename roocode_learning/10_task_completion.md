# 10: Task Completion & AttemptCompletionTool

## Overview

Tasks in Roo-Code end when the assistant calls `attempt_completion` tool. This triggers validation, user review, and final state transition.

**Key File**: `src/core/tools/handlers/AttemptCompletionTool.ts`

## AttemptCompletionTool

The special tool that signals task completion:

```typescript
// Tool definition
{
  name: "attempt_completion",
  description: "Signal that task is complete and present results",
  input_schema: {
    type: "object",
    properties: {
      result: {
        type: "string",
        description: "Final result summary"
      },
      command: {
        type: "string",
        description: "Optional command to demonstrate completion"
      }
    },
    required: ["result"]
  }
}
```

## Completion Flow

### 1. Assistant Calls Tool

```json
{
  "type": "tool_use",
  "name": "attempt_completion",
  "input": {
    "result": "Created user authentication system with login, logout, and session management",
    "command": "npm test auth.test.ts"
  }
}
```

### 2. Handler Processes Request

```typescript
// src/core/tools/handlers/AttemptCompletionTool.ts
export class AttemptCompletionTool {
  async execute(input: { result: string; command?: string }) {
    // 1. Validate completion state
    await this.validateCompletion()
    
    // 2. Run verification command (if provided)
    if (input.command) {
      const commandResult = await this.runCommand(input.command)
      if (commandResult.exitCode !== 0) {
        throw new Error('Verification command failed')
      }
    }
    
    // 3. Present to user for review
    const userApproval = await this.requestUserReview({
      result: input.result,
      commandOutput: commandResult?.output
    })
    
    // 4. Handle user response
    if (userApproval === 'approved') {
      await this.finalizeCompletion()
    } else if (userApproval === 'rejected') {
      throw new Error('User rejected completion')
    }
  }
}
```

### 3. User Review Interface

User sees completion UI with options:

```
┌─ Task Completion ────────────────┐
│                                   │
│ Result:                           │
│ Created user authentication       │
│ system with login, logout, and    │
│ session management                │
│                                   │
│ Verification:                     │
│ ✓ npm test auth.test.ts passed    │
│                                   │
│ [Approve] [Request Changes] [❌]  │
└───────────────────────────────────┘
```

### 4. State Transition

On approval:
```typescript
// src/core/task/Task.ts
async finalizeCompletion() {
  // 1. Update task state
  this.state = 'completed'
  this.completedAt = new Date()
  
  // 2. Save final history
  await this.saveHistory()
  
  // 3. Notify parent (if subtask)
  if (this.parentTaskId) {
    await this.notifyParent('completed')
  }
  
  // 4. Clean up resources
  await this.cleanup()
}
```

## Validation Before Completion

The tool checks several conditions:

```typescript
// src/core/tools/handlers/AttemptCompletionTool.ts
async validateCompletion(): Promise<void> {
  const issues: string[] = []
  
  // 1. Check for uncommitted changes (if git repo)
  if (await this.hasUncommittedChanges()) {
    issues.push('Warning: Uncommitted changes detected')
  }
  
  // 2. Check for open TODOs
  if (this.task.hasPendingTodos()) {
    issues.push('Warning: Pending TODO items remain')
  }
  
  // 3. Check for failed previous attempts
  if (this.task.attemptCount > 1) {
    issues.push(`Note: This is attempt ${this.task.attemptCount}`)
  }
  
  // Present issues to user if any
  if (issues.length > 0) {
    await this.showValidationIssues(issues)
  }
}
```

## User Response Handling

### Approve
```typescript
case 'approved':
  await task.finalizeCompletion()
  showSuccessNotification('Task completed!')
  break
```

### Request Changes
```typescript
case 'request_changes':
  const feedback = await getUserFeedback()
  await task.addMessage({
    role: 'user',
    content: `Please address this feedback: ${feedback}`
  })
  await task.resumeAgentic() // Continue working
  break
```

### Reject
```typescript
case 'rejected':
  await task.setState('failed')
  showNotification('Task completion rejected')
  break
```

## Optional Verification Command

Assistants can provide a command to prove completion:

```typescript
// Example: Run tests
{
  "result": "Fixed authentication bug",
  "command": "npm test -- auth"
}

// Example: Build project
{
  "result": "Implemented new feature",
  "command": "npm run build"
}

// Example: Lint code
{
  "result": "Refactored components",
  "command": "npm run lint"
}
```

If command fails, completion is blocked:
```typescript
if (commandResult.exitCode !== 0) {
  return {
    error: `Verification failed:\n${commandResult.stderr}`,
    shouldRetry: true
  }
}
```

## Subtask Completion

When a subtask completes, it notifies the parent:

```typescript
// src/core/task/Task.ts
async notifyParent(status: 'completed' | 'failed') {
  const parentTask = await Task.load(this.parentTaskId)
  
  await parentTask.handleSubtaskCompletion({
    subtaskId: this.id,
    status: status,
    result: this.completionResult
  })
  
  // Parent may auto-continue or wait for user
  if (parentTask.shouldAutoContinue()) {
    await parentTask.resumeAgentic()
  }
}
```

## Source Code References

| File | Purpose |
|------|---------|
| `src/core/tools/handlers/AttemptCompletionTool.ts` | Main completion handler |
| `src/core/task/Task.ts` | Task state management |
| `src/core/webview/ClineProvider.ts` | User review UI |
| `src/core/tools/validateToolUse.ts` | Completion validation |

## Key Insights

- **User always reviews** - No automatic completion without approval
- **Verification commands** prove completion (optional but recommended)
- **Validation warnings** alert to potential issues (uncommitted changes, TODOs)
- **Subtask coordination** - Parent tasks notified of child completion

**Version**: Roo-Code v3.39+ (January 2026)
