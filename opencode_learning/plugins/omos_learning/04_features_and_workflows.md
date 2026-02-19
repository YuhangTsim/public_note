# Features and Workflows

## Tmux Integration

Real-time monitoring of background agents via tmux panes.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TMUX INTEGRATION ARCHITECTURE                            │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  MAIN SESSION                                                               │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │ User: "@explorer search for auth patterns"                            │ │
│  │                                                                       │ │
│  │ Orchestrator spawns background task...                                │ │
│  └────────────────────────┬──────────────────────────────────────────────┘ │
└───────────────────────────┼─────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  BACKGROUND MANAGER                                                         │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │ 1. Create new OpenCode session                                        │ │
│  │ 2. Assign to @explorer agent                                          │ │
│  │ 3. Return task_id immediately                                         │ │
│  └────────────────────────┬──────────────────────────────────────────────┘ │
└───────────────────────────┼─────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  TMUX MANAGER                                                               │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │ 1. Detect current tmux session                                        │ │
│  │ 2. Spawn new pane with layout                                         │ │
│  │ 3. Run: opencode attach <session_id>                                  │ │
│  └────────────────────────┬──────────────────────────────────────────────┘ │
└───────────────────────────┼─────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  TMUX WINDOW                                                                │
│  ┌─────────────────────────┬─────────────────────────┐                     │
│  │                         │                         │                     │
│  │   Main Pane             │   @explorer Pane        │                     │
│  │   (Orchestrator)        │   (Live output)         │                     │
│  │                         │                         │                     │
│  │   Waiting...            │   Searching...          │                     │
│  │                         │   Files: 12/45          │                     │
│  │                         │                         │                     │
│  ├─────────────────────────┼─────────────────────────┤                     │
│  │                         │                         │                     │
│  │   @librarian Pane       │   @fixer Pane           │                     │
│  │   (Live output)         │   (Idle)                │                     │
│  │                         │                         │                     │
│  │   Fetching docs...      │                         │                     │
│  │                         │                         │                     │
│  └─────────────────────────┴─────────────────────────┘                     │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

### Tmux Layouts

```typescript
// Supported layouts (src/utils/tmux.ts)

type TmuxLayout = 
  | 'main-vertical'      // Default - main on left, others stacked right
  | 'main-horizontal'    // Main on top, others bottom
  | 'tiled'              // Grid layout
  | 'even-vertical'      // Equal height panes
  | 'even-horizontal';   // Equal width panes
```

### Layout Visualization

```
main-vertical (default):          main-horizontal:
┌──────────┬──────────┐          ┌───────────────────┐
│          │ Pane 2   │          │                   │
│          ├──────────┤          │      Main         │
│   Main   │ Pane 3   │          │                   │
│          ├──────────┤          ├─────────┬─────────┤
│          │ Pane 4   │          │ Pane 2  │ Pane 3  │
└──────────┴──────────┘          └─────────┴─────────┘

tiled:                            even-vertical:
┌──────────┬──────────┐          ┌──────────┐
│          │          │          │  Pane 1  │
│  Pane 1  │  Pane 2  │          ├──────────┤
├──────────┼──────────┤          │  Pane 2  │
│          │          │          ├──────────┤
│  Pane 3  │  Pane 4  │          │  Pane 3  │
└──────────┴──────────┘          └──────────┘
```

### Tmux Session Lifecycle

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TMUX SESSION LIFECYCLE                                   │
└─────────────────────────────────────────────────────────────────────────────┘

Task Launch:
┌────────────────────────────────────────────────────────────────────────────┐
│ session.create() ──▶ tmux pane spawned ──▶ opencode attach ──▶ task runs  │
└────────────────────────────────────────────────────────────────────────────┘

Task Completes Normally:
┌────────────────────────────────────────────────────────────────────────────┐
│ session.status (idle) ──▶ extract results ──▶ session.abort()              │
│                              │                                             │
│                              ▼                                             │
│                       session.deleted event ──▶ tmux pane closed           │
└────────────────────────────────────────────────────────────────────────────┘

Task Cancelled:
┌────────────────────────────────────────────────────────────────────────────┐
│ cancel() ──▶ session.abort() ──▶ session.deleted event                     │
│                                                   │                        │
│                                                   ▼                        │
│                                            tmux pane closed                │
└────────────────────────────────────────────────────────────────────────────┘

Session Deleted Externally:
┌────────────────────────────────────────────────────────────────────────────┐
│ session.deleted event ──▶ task cleanup ──▶ tmux pane closed                │
└────────────────────────────────────────────────────────────────────────────┘
```

### Graceful Shutdown

```typescript
// src/utils/tmux.ts

async function killPane(paneId: string) {
  // Step 1: Send Ctrl+C to gracefully terminate process
  spawn([tmux, "send-keys", "-t", paneId, "C-c"])
  
  // Step 2: Wait for process to terminate
  await delay(250)
  
  // Step 3: Kill the pane
  spawn([tmux, "kill-pane", "-t", paneId])
}
```

## Background Task System

Fire-and-forget parallel task execution with automatic result collection.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    BACKGROUND TASK FLOW                                     │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐
│  SPAWN TASK     │─── background_task({ agent, prompt })
└────────┬────────┘
         │
         │ Returns immediately:
         │ { task_id: "task_abc123" }
         │
         ▼
┌─────────────────┐
│  CREATE SESSION │─── New isolated session
│                 │    Assign to specified agent
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  EXECUTE        │─── Agent processes task
│                 │    (parallel to main session)
└────────┬────────┘
         │
         │ Options for result retrieval:
         ▼
┌─────────────────┬─────────────────┬─────────────────┐
│  POLL           │  WAIT           │  NOTIFY         │
│                 │                 │                 │
│ background_     │ background_     │ Auto-notify     │
│ output()        │ output()        │ on completion   │
│ with timeout=0  │ with timeout    │                 │
│                 │                 │                 │
│ Non-blocking    │ Blocking wait   │ Event-driven    │
│ check status    │ for result      │ notification    │
└─────────────────┴─────────────────┴─────────────────┘
```

### Background Task API

```typescript
// Spawn a background task
const task_id = await background_task({
  agent: "explorer",
  prompt: "Find all React components in src/",
})

// Check result (non-blocking)
const result = await background_output({
  task_id,
  timeout: 0,  // Don't wait
})

// Wait for result (blocking)
const result = await background_output({
  task_id,
  timeout: 60_000,  // Wait up to 60 seconds
})

// Cancel task
await background_cancel({ task_id })

// Cancel all tasks
await background_cancel({ all: true })
```

### Concurrency Limits

```typescript
// Default: 10 concurrent background tasks
const MAX_CONCURRENT_TASKS = 10

// Task queue when limit reached:
┌─────────────────────────────────────────────────────────┐
│  Active Tasks (10 max)                                  │
│  ┌────────┐ ┌────────┐ ┌────────┐ ... ┌────────┐       │
│  │ Task 1 │ │ Task 2 │ │ Task 3 │     │ Task 10│       │
│  └────────┘ └────────┘ └────────┘     └────────┘       │
│                                                         │
│  Queued Tasks                                           │
│  ┌────────┐ ┌────────┐ ┌────────┐                       │
│  │ Task 11│ │ Task 12│ │ Task 13│  (waiting...)         │
│  └────────┘ └────────┘ └────────┘                       │
└─────────────────────────────────────────────────────────┘
```

## Hook System

Event-driven workflow enforcement that modifies agent behavior at specific lifecycle points.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    HOOK SYSTEM ARCHITECTURE                                 │
└─────────────────────────────────────────────────────────────────────────────┘

OpenCode Lifecycle Events:
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  UserPromptSubmit    PreToolUse    PostToolUse    Stop    onSummarize      │
│        │                │               │           │          │           │
│        ▼                ▼               ▼           ▼          ▼           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    HOOK REGISTRY                                     │   │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                │   │
│  │  │Phase Reminder│ │Post-Read     │ │Auto-Update   │                │   │
│  │  │Hook          │ │Nudge         │ │Checker       │                │   │
│  │  └──────────────┘ └──────────────┘ └──────────────┘                │   │
│  │                                                                     │   │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                │   │
│  │  │(Custom hooks │ │              │ │              │                │   │
│  │  │ can be added)│ │              │ │              │                │   │
│  │  └──────────────┘ └──────────────┘ └──────────────┘                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Phase Reminder Hook

Injects the mandatory workflow reminder before every user message to the Orchestrator.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PHASE REMINDER HOOK                                       │
└─────────────────────────────────────────────────────────────────────────────┘

Trigger: UserPromptSubmit (before Orchestrator processes user message)

Original User Message:
┌─────────────────────────────────────────────────────────────────────────────┐
│ "Add authentication to my API"                                               │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         ▼ (Hook transforms)
┌─────────────────────────────────────────────────────────────────────────────┐
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │ [SYSTEM] Remember your workflow:                                        │ │
│ │                                                                          │ │
│ │ 1. UNDERSTAND - Analyze the request and identify domains                │ │
│ │ 2. DELEGATE - Choose the right specialist for each domain               │ │
│ │ 3. PARALLELIZE - Spawn background tasks when beneficial                 │ │
│ │                                                                          │ │
│ │ Do NOT implement yourself unless it's a trivial change.                 │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                           │
│ "Add authentication to my API"                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Post-Read Nudge Hook

Prevents the "read-then-fix-myself" anti-pattern.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    POST-READ NUDGE HOOK                                      │
└─────────────────────────────────────────────────────────────────────────────┘

Trigger: PostToolUse (after Read tool completes)

Scenario without hook:
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. Orchestrator reads file                                                 │
│ 2. Orchestrator decides to implement fix itself                            │
│ 3. ❌ Violates delegation principle                                         │
└─────────────────────────────────────────────────────────────────────────────┘

Scenario with hook:
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. Orchestrator reads file                                                 │
│ 2. Hook injects: "Consider delegating this to @fixer"                      │
│ 3. Orchestrator delegates to @fixer                                        │
│ 4. ✓ Follows proper workflow                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Auto-Update Checker Hook

Checks for new versions and can auto-install updates.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    AUTO-UPDATE CHECKER                                       │
└─────────────────────────────────────────────────────────────────────────────┘

Trigger: Periodic / on startup

┌─────────────────┐
│ Check NPM       │─── Fetch latest version
│ Registry        │
└────────┬────────┘
         │
         ▼
   ┌───────────┐
   │ Compare   │─── Current vs Latest
   │ Versions  │
   └─────┬─────┘
         │
    ┌────┴────┐
    ▼         ▼
┌────────┐ ┌────────┐
│ Update │ │ Skip   │
│Available│ │(current)│
└───┬────┘ └────────┘
    │
    ▼
┌─────────────────┐
│ Auto-install?   │─── Based on config
│ (configurable)  │
└─────────────────┘
```

### Hook Registration

```typescript
// src/hooks/index.ts

export function registerHooks() {
  return {
    // Workflow enforcement
    phaseReminder: PhaseReminderHook(),
    postReadNudge: PostReadNudgeHook(),
    
    // Maintenance
    autoUpdateChecker: AutoUpdateCheckerHook({
      enabled: config.features.autoUpdate,
      checkInterval: 24 * 60 * 60 * 1000,  // 24 hours
    }),
  }
}
```

## Common Workflows

### Workflow 1: Feature Implementation

```
User: "Add dark mode to my React app"
     │
     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ ORCHESTRATOR                                                                │
│ 1. Understand: UI feature, affects CSS and React components                │
│ 2. Plan: Design first, then implement                                       │
└─────────────────────────────────────────────────────────────────────────────┘
     │
     ├────────────────────────────────────────┐
     │                                        │
     ▼                                        ▼
┌─────────────────────────┐      ┌─────────────────────────┐
│ @explorer               │      │ @librarian              │
│ "Find current CSS      │      │ "Research dark mode    │
│  structure"            │      │  best practices"       │
│                         │      │                         │
│ [Background task]       │      │ [Background task]       │
└───────────┬─────────────┘      └───────────┬─────────────┘
            │                                │
            └──────────────┬─────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ ORCHESTRATOR (receives results)                                             │
│ • Current: Tailwind CSS + CSS variables                                    │
│ • Best practice: Use data-theme attribute + CSS variables                  │
└─────────────────────────────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ @designer                                                                   │
│ • Create color palette (light/dark)                                        │
│ • Design toggle component                                                  │
│ • Specify CSS variable structure                                           │
└─────────────────────────────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ @fixer                                                                      │
│ • Implement CSS variables                                                   │
│ • Create ThemeProvider component                                           │
│ • Add toggle button                                                         │
│ • Test implementation                                                       │
└─────────────────────────────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ ORCHESTRATOR                                                                │
│ "Dark mode implemented:                                                     │
│  - CSS variables in globals.css                                             │
│  - ThemeProvider in _app.tsx                                                │
│  - Toggle in Header component"                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Workflow 2: Debug Complex Issue

```
User: "Fix intermittent test failures in CI"
     │
     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ ORCHESTRATOR                                                                │
│ High-stakes debugging → Delegate to @oracle                                │
└─────────────────────────────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ @oracle                                                                     │
│ 1. Request CI logs, test configuration, recent changes                     │
│ 2. Analyze patterns in failures                                            │
│ 3. Identify root cause: race condition in async setup                     │
│ 4. Recommend fix: Add proper synchronization                               │
└─────────────────────────────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ @fixer                                                                      │
│ Implement recommended fix                                                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Workflow 3: Code Review

```
User: "/review my latest changes"
     │
     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ ORCHESTRATOR                                                                │
│ Code review task → Can handle directly (no delegation needed)              │
└─────────────────────────────────────────────────────────────────────────────┘
     │
     ├────────────────────────────────────────┐
     │                                        │
     ▼                                        ▼
┌─────────────────────────┐      ┌─────────────────────────┐
│ Read modified files     │      │ Run tests, lint         │
│ Check for issues        │      │ Verify no regressions   │
└─────────────────────────┘      └─────────────────────────┘
     │
     ▼
Present review findings
```
