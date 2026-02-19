# The Boulder Pattern: Persistent Task State in OMOS

**The "Sisyphus" Philosophy: Tasks That Survive and Persist**

The Boulder Pattern is Oh-My-OpenCode's (OMOS) unique approach to task management, inspired by the myth of Sisyphus—except instead of futile labor, OMOS ensures tasks are **completed even across session interruptions**.

---

## Core Concept

Unlike typical agent frameworks where tasks exist only in memory and are lost when a session ends, OMOS treats tasks as **persistent first-class entities** called **Boulders**—multi-step plans that survive restarts, browser crashes, and context window exhaustion.

```
Traditional Agent Task:
┌─────────────┐
│  Session    │
│  ┌────────┐ │
│  │  Task  │ │ ← Exists only in memory
│  │ (ephemeral) │
│  └────────┘ │
└─────────────┘
     Session ends → Task lost forever

OMOS Boulder Pattern:
┌─────────────┐     ┌──────────────────────┐
│  Session    │     │  Atomic File Storage │
│  ┌────────┐ │◄───►│  ┌────────────────┐  │
│  │Boulder │ │     │  │ boulder-state  │  │ ← Persists across sessions
│  │(active)│ │     │  │ todo-queue     │  │
│  └────────┘ │     │  │ checkpoint     │  │
└─────────────┘     │  └────────────────┘  │
     Session ends   └──────────────────────┘
     Session starts → Boulder resumes
```

---

## Enhanced Todo Schema

OMOS extends the standard todo schema with fields optimized for persistence and dependency tracking:

### TypeScript Definition

```typescript
type OMOSTask = {
  id: string                    // Unique identifier
  subject: string               // Imperative form (e.g., "Fix auth bug")
  activeForm: string            // Present continuous (e.g., "Fixing auth bug")
  content: string               // Brief description
  status: 'pending' | 'in_progress' | 'completed' | 'cancelled'
  priority: 'high' | 'medium' | 'low'
  blocks: string[]              // IDs of tasks this one blocks
  blockedBy: string[]           // IDs of tasks blocking this one
  createdAt: number             // Unix timestamp
  updatedAt: number             // Unix timestamp
  checkpoint?: {                // Optional progress checkpoint
    file: string                // File being worked on
    line: number                // Line position
    context: string             // Surrounding context
  }
}
```

### Key Differences from Standard Todos

| Field | Standard Todo | OMOS Task | Purpose |
|-------|---------------|-----------|---------|
| `subject` | N/A | ✅ | Imperative for commands |
| `activeForm` | N/A | ✅ | Present continuous for status reports |
| `blocks` | N/A | ✅ | Dependency tracking (what this enables) |
| `blockedBy` | N/A | ✅ | Blocker tracking (what prevents progress) |
| `checkpoint` | N/A | ✅ | Resume position after interruption |

---

## Atomic Persistence Layer

### Storage Architecture

OMOS uses atomic file operations with file-based locking to ensure state consistency:

```
~/.config/opencode/oh-my-opencode/
├── boulders/
│   ├── boulder_<id>.json       # Individual boulder state
│   └── active_boulder.json     # Current active boulder pointer
├── tasks/
│   ├── todo_queue.json         # Pending tasks with full schema
│   ├── in_progress.json        # Currently executing task
│   └── completed/              # Archive of finished tasks
└── checkpoints/
    └── checkpoint_<task_id>.json  # Resume points for interrupted tasks
```

### Atomic Write Operations

```typescript
// From: oh-my-opencode/src/features/claude-tasks/storage.ts
async function atomicWriteTaskState(
  taskId: string, 
  state: TaskState
): Promise<void> {
  const tempPath = `${TASK_DIR}/${taskId}.json.tmp`
  const finalPath = `${TASK_DIR}/${taskId}.json`
  
  // 1. Write to temp file
  await fs.writeFile(tempPath, JSON.stringify(state, null, 2))
  
  // 2. Atomic rename (fs-level atomicity)
  await fs.rename(tempPath, finalPath)
  
  // 3. Sync to disk (durability guarantee)
  const fd = await fs.open(finalPath, 'r')
  await fd.sync()
  await fd.close()
}
```

### File-Based Locking

For parallel access scenarios (multiple agents or background tasks):

```typescript
// From: oh-my-opencode/src/features/claude-tasks/lock.ts
async function acquireTaskLock(taskId: string): Promise<LockHandle> {
  const lockPath = `${LOCK_DIR}/${taskId}.lock`
  
  try {
    // Attempt exclusive lock (non-blocking)
    const fd = await fs.open(lockPath, 'wx')
    return {
      release: () => fd.close()
    }
  } catch (err) {
    if (err.code === 'EEXIST') {
      throw new TaskLockedError(`Task ${taskId} is locked by another process`)
    }
    throw err
  }
}
```

---

## The Ralph Loop: Verification & Enforcement

The **Ralph Loop** is OMOS's mechanism to prevent premature task completion. Named after the pattern of "ralphing" (forcefully continuing), it ensures tasks are truly complete before the agent stops.

### Completion Criteria

A Boulder is NOT complete until ALL of the following are true:

1. ✅ **Todos Empty**: All items in the `todowrite` list are marked `completed`
2. ✅ **Diagnostics Clean**: `lsp_diagnostics` returns no errors on changed files
3. ✅ **Tests Pass**: If tests exist, they must pass (or at least not regress)
4. ✅ **Promise Tag**: The transcript contains a `<promise>DONE</promise>` tag

### Intervention Mechanism

```typescript
// From: oh-my-opencode/src/hooks/ralph-loop/ralph-hook.ts
async function ralphIntervention(sessionId: string, output: AgentOutput): Promise<void> {
  const boulder = await loadActiveBoulder(sessionId)
  if (!boulder) return
  
  const incompleteTasks = boulder.tasks.filter(
    t => t.status !== 'completed' && t.status !== 'cancelled'
  )
  
  const diagnostics = await runLSPDiagnostics(boulder.changedFiles)
  const hasErrors = diagnostics.some(d => d.severity === 'error')
  
  if (incompleteTasks.length > 0 || hasErrors) {
    // FORCE CONTINUATION - append system reminder to output
    output.text += `\n\n`
    output.text += `╔═══════════════════════════════════════════════════════════╗\n`
    output.text += `║  [SYSTEM REMINDER - BOULDER INCOMPLETE]                   ║\n`
    output.text += `╚═══════════════════════════════════════════════════════════╝\n\n`
    
    if (incompleteTasks.length > 0) {
      output.text += `⏳ ${incompleteTasks.length} incomplete task(s):\n`
      incompleteTasks.forEach(t => {
        output.text += `   • ${t.subject} (${t.status})\n`
      })
      output.text += `\n`
    }
    
    if (hasErrors) {
      output.text += `⚠️  ${diagnostics.length} diagnostic error(s) detected.\n`
      output.text += `   Fix before completing.\n\n`
    }
    
    output.text += `🚨 You MUST complete all criteria before stopping.\n`
    output.text += `   Continue working or mark tasks as cancelled.\n`
    
    // Prevent session from ending
    output.finishReason = 'continue'
  }
}
```

### Flow Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                    Ralph Loop Flow                           │
└──────────────────────────────────────────────────────────────┘

Agent attempts to finish
        │
        ▼
┌───────────────────┐
│ Ralph Hook Fires  │◄─── Intercepts experimental.text.complete
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Check Boulder     │
│ - Incomplete todos?    ──────┐
│ - Diagnostic errors?         │
│ - Missing promise tag?       │
└─────────┬─────────┘          │
          │                    │
    ┌─────┴─────┐              │
    ▼           ▼              │
 Complete    Incomplete        │
    │            │             │
    ▼            ▼             │
 Allow stop  Append reminder   │
                │              │
                ▼              │
         ┌─────────────┐       │
         │ Force agent │───────┘
         │ to continue │
         └─────────────┘
                │
                ▼
         Agent sees reminder
                │
                ▼
         Must complete work
```

---

## The Todo Continuation Enforcer

The **Todo Continuation Enforcer** is a specialized hook that monitors `session.idle` events. If tasks are still pending when the session goes idle, it automatically injects prompts to force the agent to continue.

### Hook Registration

```typescript
// From: oh-my-opencode/src/hooks/todo-continuation-enforcer/enforcer.ts
export function registerContinuationEnforcer(plugin: Plugin): void {
  plugin.on('session.idle', async (event) => {
    const sessionId = event.sessionID
    const todos = await loadTodos(sessionId)
    
    if (!todos || todos.length === 0) return
    
    const incomplete = todos.filter(
      t => t.status !== 'completed' && t.status !== 'cancelled'
    )
    
    if (incomplete.length > 0) {
      // Session going idle with incomplete work!
      event.preventDefault() // Don't let session end
      
      // Inject continuation prompt
      await injectContinuationPrompt(sessionId, incomplete)
    }
  })
}
```

### Intervention Prompt

When triggered, the enforcer injects a prompt like:

```
[SYSTEM - TODO CONTINUATION ENFORCER]

⚠️  WARNING: You have incomplete TODO items but the session is ending.

Incomplete tasks:
  1. [ ] Update settings page to include toggle
  2. [ ] Add tests for dark mode functionality

You MUST complete all TODOs before stopping. Continue working now.
```

---

## BackgroundManager: Concurrency & Lifecycle

The **BackgroundManager** handles the full lifecycle of background tasks with model-specific concurrency limits.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  BackgroundManager                          │
│                   (1600+ lines)                             │
└─────────────────────────────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
   ┌─────────┐      ┌────────────┐     ┌──────────┐
   │  Queue  │      │ Concurrency │     │ Monitor  │
   │  (FIFO) │      │  Limiter    │     │  Loop    │
   └────┬────┘      └─────┬──────┘     └────┬─────┘
        │                 │                  │
        ▼                 ▼                  ▼
  Tasks waiting    Model-specific        Health checks
  for execution    limits enforced       and cleanup
```

### Lifecycle States

```typescript
// From: oh-my-opencode/src/features/background-agent/manager.ts
type BackgroundTaskState = 
  | 'queued'           // Waiting in queue
  | 'starting'         // Allocating resources
  | 'executing'        // Running
  | 'monitoring'       // Watching for completion
  | 'completed'        // Successfully finished
  | 'failed'           // Error occurred
  | 'cancelled'        // User cancelled
  | 'timeout'          // Exceeded time limit
```

### Concurrency Limits

Different models have different concurrency caps:

| Model | Max Concurrent Tasks | Rationale |
|-------|---------------------|-----------|
| GPT-4o | 3 | High compute cost |
| Claude 3.5 Sonnet | 5 | Balanced cost/performance |
| Grok Beta | 10 | Fast and cheap |
| Haiku | 10 | Fast and cheap |

---

## Resume from Interruption

When a session resumes after interruption, OMOS restores the Boulder state:

```typescript
// From: oh-my-opencode/src/features/boulder/resume.ts
async function resumeBoulder(sessionId: string): Promise<ResumeContext> {
  // 1. Load active boulder
  const boulder = await loadActiveBoulder(sessionId)
  if (!boulder) return null
  
  // 2. Find current task
  const currentTask = boulder.tasks.find(t => t.status === 'in_progress')
  
  // 3. Load checkpoint if available
  const checkpoint = currentTask?.checkpoint 
    ? await loadCheckpoint(currentTask.id)
    : null
  
  // 4. Build resume prompt
  return {
    summary: `Resuming: ${boulder.subject}`,
    currentTask: currentTask?.activeForm || 'Unknown',
    progress: `${completedCount}/${totalCount} tasks complete`,
    checkpoint: checkpoint ? {
      file: checkpoint.file,
      line: checkpoint.line,
      context: checkpoint.context
    } : null
  }
}
```

### Resume Prompt Example

```
[SYSTEM - BOULDER RESUME]

Resuming: Implement dark mode support

Current task: Updating settings page to include toggle
Progress: 1/3 tasks complete (33%)

Last checkpoint:
  File: src/components/Settings.tsx
  Line: 45
  Context: "const [darkMode, setDarkMode] = useState(false)"

Continue from where you left off.
```

---

## Comparison: OMOS vs Other Frameworks

| Feature | Standard Agent | OpenCode Base | OMOS (Boulder Pattern) |
|---------|---------------|---------------|------------------------|
| **Task Persistence** | ❌ In-memory only | ❌ Session-scoped | ✅ Atomic file storage |
| **Survives Restart** | ❌ No | ❌ No | ✅ Yes |
| **Dependency Tracking** | ❌ None | ❌ None | ✅ blocks/blockedBy |
| **Auto-Continuation** | ❌ Manual | ❌ Manual | ✅ Ralph Loop + Enforcer |
| **Concurrency** | ❌ Sequential | ❌ Sequential | ✅ BackgroundManager |
| **Checkpointing** | ❌ None | ❌ None | ✅ File+Line context |
| **Verification** | ❌ Trust agent | ❌ Trust agent | ✅ Multi-criteria checks |

---

## Best Practices

### For Task Design

1. **Use specific subjects**: "Fix auth bug in login.ts" not "Fix bug"
2. **Define clear active forms**: "Fixing auth bug" for status reporting
3. **Model dependencies**: Use `blocks` and `blockedBy` for ordering
4. **Set checkpoints**: After each file edit, save position for resume
5. **Include verification**: Always have a final "Verify" task

### For Boulder Management

1. **Keep boulders focused**: 3-7 tasks per boulder
2. **Cancel don't delete**: Use `cancelled` status to preserve history
3. **Archive completed**: Move finished boulders to archive periodically
4. **Monitor health**: Check `active_boulder.json` for stale references

---

## Key Files

- `src/features/claude-tasks/storage.ts` - Atomic persistence
- `src/features/claude-tasks/schema.ts` - Enhanced task schema
- `src/features/background-agent/manager.ts` - Concurrency management
- `src/hooks/ralph-loop/` - Verification and enforcement
- `src/hooks/todo-continuation-enforcer/` - Idle monitoring
- `src/features/boulder/` - Boulder lifecycle

---

## Summary

The Boulder Pattern transforms ephemeral agent tasks into **persistent, verifiable, self-enforcing work units**. By combining:

- **Atomic file persistence** (survives crashes)
- **Enhanced schema** (dependency tracking)
- **Ralph Loop** (verification)
- **Continuation Enforcer** (idle intervention)
- **BackgroundManager** (concurrency)

OMOS creates a **zero-drift workflow** where complex multi-step tasks are guaranteed to complete—even if the agent crashes, the user disconnects, or the context window fills up.

---

**Created**: February 2026  
**Based on**: oh-my-opencode v3.x analysis
