# Architecture & Agents

Oh My OpenCode replaces the standard OpenCode agent hierarchy with a more structured, role-based system centered around **Sisyphus**.

## The Sisyphus Architecture

Sisyphus is not just a prompt; it's an operating mode. The core principle is **Orchestration over Execution**. Sisyphus prefers to plan and delegate rather than doing everything himself.

### Phase 0: Intent Gate
Every interaction starts with an "Intent Gate" check:
1.  **Check Skills**: Does this match a specific skill (e.g., browser automation)? If so, invoke `playwright` immediately.
2.  **Classify Request**: Is it Trivial, Exploratory, or Open-ended?
3.  **Validate**: Are there ambiguities?

### Delegation System
Sisyphus uses `delegate_task` to spawn sub-agents. This is mandatory for complex tasks.

#### The Team

| Agent | Role | Underlying Model (Typical) |
| :--- | :--- | :--- |
| **Sisyphus** | Orchestrator, Planner, Executor of last resort | Claude 3.5 Sonnet / Opus |
| **Oracle** | "High-IQ" Consultant. Read-only. Used for architectural decisions, hard debugging, and "sanity checks". | GPT-4o / GPT-5 |
| **Librarian** | Researcher. Searches external docs, GitHub code, and web. Answers "How do I use X?". | Claude 3.5 Sonnet |
| **Explore** | Contextual Grep. Searches *internal* codebase. fast and cheap. | Grok Beta / Haiku |
| **Frontend UI/UX** | Visual Specialist. Writes CSS, React components, handles design. | Gemini 1.5 Pro |

### Task Workflow

1.  **User Request**: "Add a dark mode toggle."
2.  **Sisyphus Analysis**: "This involves UI work and state management."
3.  **Delegation 1 (Explore)**: "Find where theme state is currently stored." (Background)
4.  **Delegation 2 (Frontend)**: "Create a Toggle component matching our design system." (Delegate)
5.  **Integration**: Sisyphus integrates the component and wires up the state.
6.  **Verification**: Sisyphus runs tests/lints.

## Background Tasks

OMO heavily utilizes `run_in_background=true` for exploration agents (`explore`, `librarian`). This allows Sisyphus to continue thinking or planning while information is being gathered, parallelizing the workflow.

## Context Management

By aggressively delegating, Sisyphus keeps its own context window clean. Sub-agents return concise summaries or specific code blocks, rather than Sisyphus reading entire files just to find one function. This "Context Injection" strategy is key to handling large codebases.

---

## 160+ Lifecycle Hook Architecture

OMOS is almost entirely **event-driven** through a comprehensive hook system that intercepts agent behavior at every stage.

### Hook Categories

The 160+ hooks are organized into five lifecycle events:

| Event | Hook Point | Purpose |
|-------|-----------|---------|
| `UserPromptSubmit` | Before user prompt is sent | Modify/add to user input |
| `PreToolUse` | Before tool execution | Validate, log, modify tool calls |
| `PostToolUse` | After tool execution | Process results, trigger side effects |
| `Stop` | When agent attempts to finish | Enforce completion criteria |
| `onSummarize` | During context compaction | Preserve critical information |

### Key Hook Implementations

#### 1. Todo Continuation Enforcer
```typescript
// src/hooks/todo-continuation-enforcer/enforcer.ts
plugin.on('session.idle', async (event) => {
  const todos = await loadTodos(event.sessionID)
  const incomplete = todos.filter(t => t.status !== 'completed')
  
  if (incomplete.length > 0) {
    event.preventDefault() // Don't end session!
    await injectContinuationPrompt(event.sessionID, incomplete)
  }
})
```

**Purpose**: Prevents sessions from ending with incomplete tasks.

#### 2. Ralph Loop (Completion Verification)
```typescript
// src/hooks/ralph-loop/ralph-hook.ts
plugin.on('experimental.text.complete', async (input, output) => {
  const boulder = await loadActiveBoulder(input.sessionID)
  
  if (!isBoulderComplete(boulder)) {
    // Append reminder to force continuation
    output.text += buildCompletionReminder(boulder)
    output.finishReason = 'continue'
  }
})
```

**Purpose**: Verifies todos, diagnostics, and tests before allowing completion.

#### 3. Background Task Monitor
```typescript
// src/hooks/background-monitor/monitor.ts
plugin.on('PostToolUse', async (event) => {
  if (event.toolName === 'background_task') {
    // Track spawned tasks
    await trackBackgroundTask(event.sessionID, event.result)
  }
})
```

**Purpose**: Manages lifecycle of background agents.

#### 4. Skill Auto-Loader
```typescript
// src/hooks/skill-loader/loader.ts
plugin.on('UserPromptSubmit', async (event) => {
  const intent = classifyIntent(event.userPrompt)
  
  if (intent.requiresSkill) {
    // Auto-inject skill instructions
    event.systemPrompt += await loadSkillInstructions(intent.skillName)
  }
})
```

**Purpose**: Automatically loads relevant skills based on intent.

### Hook Execution Order

```
User Prompt
     │
     ▼
┌─────────────────┐
│ UserPromptSubmit│ ← Intent classification, skill loading
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   LLM Response  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   PreToolUse    │ ← Tool validation, permission checks
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Tool Execution │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  PostToolUse    │ ← Result processing, side effects
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Stop/Complete │ ← Ralph Loop checks completion
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  onSummarize    │ ← Preserve boulder state during compaction
└─────────────────┘
```

### The "Babysitter" Pattern

Some hooks detect unstable agent behavior and trigger recovery:

```typescript
// src/hooks/babysitter/babysitter.ts
plugin.on('PostToolUse', async (event) => {
  const recentHistory = await getRecentToolCalls(event.sessionID, { limit: 5 })
  
  // Detect error loops
  const consecutiveErrors = recentHistory.filter(h => h.error).length
  if (consecutiveErrors >= 3) {
    // Agent is stuck in error loop
    await triggerRecoveryProtocol(event.sessionID, {
      type: 'error_loop',
      suggestion: 'Consider delegating to Oracle for debugging help'
    })
  }
  
  // Detect empty responses
  const emptyResponses = recentHistory.filter(h => h.output === '').length
  if (emptyResponses >= 2) {
    await triggerRecoveryProtocol(event.sessionID, {
      type: 'empty_response',
      suggestion: 'Try rephrasing the task or breaking it down'
    })
  }
})
```

### Hook Configuration

Hooks can be enabled/disabled via configuration:

```json
{
  "oh-my-opencode": {
    "hooks": {
      "ralph-loop": { "enabled": true, "strictMode": true },
      "todo-continuation-enforcer": { "enabled": true },
      "babysitter": { "enabled": true, "sensitivity": "high" },
      "skill-loader": { "enabled": true, "autoLoad": true }
    }
  }
}
```

### Comparison: OMOS Hooks vs Other Systems

| Feature | OpenCode Base | Roo Code | OMOS |
|---------|--------------|----------|------|
| **Hook System** | Basic plugin API | None (built-in) | 160+ lifecycle hooks |
| **Interception Points** | 3 (pre/post/stop) | N/A | 5 with granular control |
| **Auto-Intervention** | ❌ No | ❌ No | ✅ Yes (continuation enforcers) |
| **Self-Healing** | ❌ No | ❌ No | ✅ Babysitter pattern |
| **Event-Driven** | Partial | No | Fully event-driven |

---

## Key Files

- `src/hooks/` - All hook implementations
- `src/hooks/ralph-loop/` - Completion verification
- `src/hooks/todo-continuation-enforcer/` - Idle monitoring
- `src/hooks/babysitter/` - Error recovery
- `src/hooks/skill-loader/` - Auto skill loading
- `src/features/background-agent/` - Concurrency management
