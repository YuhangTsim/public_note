# 11: ToDo and Subtasks

**Task Delegation and Hierarchy**

---

## Complete Lifecycle

```
Parent Task
  ↓
1. Create ToDo List
  ↓
2. Delegate via new_task
  ↓
3. Child Task Created
  ↓
4. Child Executes
  ↓
5. Child Calls attempt_completion
  ↓
6. Result Returns to Parent
  ↓
7. Parent Continues
```

---

## Step-by-Step

### 1. Parent Creates ToDos

```typescript
{
  name: "update_todo_list",
  input: {
    todos: [
      { id: "1", content: "Design database schema", status: "pending" },
      { id: "2", content: "Implement API", status: "pending" }
    ]
  }
}
```

### 2. Parent Delegates

```typescript
{
  name: "new_task",
  input: {
    mode: "architect",
    message: "Design database schema for user auth system"
  }
}
```

### 3. System Creates Child

```typescript
// src/core/tools/NewTaskTool.ts
async execute(input) {
  const childTask = await provider.createTask({
    task: input.message,
    mode: input.mode,
    parentTask: this.task,
    initialStatus: "active"
  })
  
  this.task.childTaskId = childTask.taskId
  this.task.isPaused = true
  
  return `Subtask created: ${childTask.taskId}`
}
```

### 4. Child Completes

```typescript
// src/core/tools/AttemptCompletionTool.ts
async execute(input) {
  const parent = findTaskById(this.task.parentTaskId)
  
  parent.apiConversationHistory.push({
    role: 'user',
    content: [{
      type: 'tool_result',
      tool_use_id: parent.pendingNewTaskToolCallId,
      content: input.result
    }]
  })
  
  parent.isPaused = false
  parent.recursivelyMakeClineRequests()
}
```

---

## Task Hierarchy

```
Root Task (parent_abc)
  ├─ Child Task (child_123) [completed]
  │   Result: "Schema designed"
  └─ Child Task (child_456) [active]
      └─ Sub-child Task (child_789)
```

---

## Source Code

| File | Purpose |
|------|---------|
| `src/core/tools/NewTaskTool.ts` | Task delegation |
| `src/core/tools/AttemptCompletionTool.ts` | Task completion |
| `src/core/task/Task.ts` | Task orchestration |

---

**Version**: Roo-Code v3.39+ (January 2026)
