# Task Completion Mechanisms: Cross-Platform Analysis

**Date:** February 2026  
**Scope:** Roo Code, OpenCode, Oh-My-OpenCode (OMO), Oh-My-OpenCode-Slim (OMOS), OpenHands, Letta AI

---

## Executive Summary

| Platform | Completion Model | Signal | Philosophy | Enforcement |
|----------|-----------------|--------|------------|-------------|
| **Roo Code** | Explicit Tooling | `attempt_completion()` | "I think I'm done. Human, do you agree?" | User review + validation |
| **OpenCode** | LLM Finish Reason | `stop` vs `tool-calls` | "Model stopped → task done" | Streaming event-driven |
| **OMO** | Evidence-Based | Ralph Loop + TODO check | "I verified my work. Exiting." | Hook-injected reminders |
| **OMOS** | Evidence-Based | Ralph Loop + Pantheon verify | "Verified. Orchestrator confirms." | Hook + tmux visibility |
| **OpenHands** | Explicit Action | `AgentFinishAction` | "I formally submit completion." | Controller state change |
| **Letta** | Yield Control | `stop_reason="end_turn"` | "I'm pausing for user input." | Step limit + rules |

---

## 1. Roo Code: Human-in-the-Loop Approval

### Completion Signal
```typescript
// Tool-based completion with user review
{
  "type": "tool_use",
  "name": "attempt_completion",
  "input": {
    "result": "Implemented auth system",
    "command": "npm test -- auth"  // Optional verification
  }
}
```

### Flow
```
Agent calls attempt_completion
         │
         ▼
┌─────────────────────┐
│  Validation Check   │──▶ Pending TODOs? Uncommitted changes?
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Run Verify Command │──▶ If provided, command must pass
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  User Review UI     │──▶ Approve / Request Changes / Reject
└──────────┬──────────┘
           │
     ┌─────┴─────┐
     ▼           ▼
 [Approved]  [Rejected]
     │           │
     ▼           ▼
 Complete    Continue
```

### Key Characteristics
- **Mandatory user review** - No automatic completion
- **Optional verification commands** - Prove completion with tests/build
- **Validation warnings** - Alerts for TODOs, uncommitted changes
- **Subtask coordination** - Parent tasks notified of child completion

---

## 2. OpenCode: Streaming Finish Reasons

### Completion Signal
Based on LLM provider's `finish_reason`:

| Finish Reason | Meaning | Action |
|--------------|---------|--------|
| `stop` | Model naturally completed | **STOP** - Return to user |
| `tool-calls` | Model wants to execute tools | **CONTINUE** - Execute & loop |
| `length` | Hit token limit | **STOP** - May compact |
| `error` | Provider error | **STOP** or retry |

### Flow
```
User Message
     │
     ▼
LLM.stream() ──────────────────────────────┐
     │                                      │
     │    ┌────────────────────────────┐    │
     └───▶│   Vercel AI SDK Stream     │────┘
          └───────────┬────────────────┘
                      │
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
   "text-delta"  "tool-call"   "finish-step"
        │             │             │
        │             │             ▼
        │             │      finishReason = ?
        │             │             │
        │             │    ┌────────┴────────┐
        │             │    ▼                 ▼
        │             │ "tool-calls"      "stop"
        │             │    │                 │
        │             ▼    ▼                 ▼
        │         Execute              SessionStatus
        │         tools                .set("idle")
        │             │                      │
        └─────────────┘                      ▼
            (loop back)              User sees prompt
```

### Key Characteristics
- **Protocol-agnostic** - Works with any LLM provider
- **Streaming real-time** - Events processed as they arrive
- **Plugin extensible** - `experimental.text.complete` hook for enforcement
- **Three-way decision** - `continue`, `stop`, or `compact`

---

## 3. OMO: Evidence-Based with Ralph Loop

### Completion Criteria
A task is NOT complete until **all** are true:
1. ✅ **Todos Empty** - All `todowrite` items marked `completed`
2. ✅ **Diagnostics Clean** - `lsp_diagnostics` returns no errors
3. ✅ **Tests Pass** - No test regressions
4. ✅ **Promise Tag** - `<promise>DONE</promise>` in transcript

### The Ralph Loop
```typescript
// Hook intercepts early completion attempts
async "experimental.text.complete"(input, output) {
  const todos = await getTodos(input.sessionID)
  const incomplete = todos.filter(t => t.status !== "completed")
  
  if (incomplete.length > 0) {
    // Force continuation by appending reminder
    output.text += "\n\n[SYSTEM REMINDER]\n"
    output.text += `You have ${incomplete.length} incomplete TODOs. `
    output.text += "Continue working. Do not stop."
  }
}
```

### Flow
```
Agent generates response
         │
         ▼
┌─────────────────────┐
│  Model sends stop   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Ralph Loop Hook     │──▶ Checks TODOs, errors, tests
│ (text.complete)     │
└──────────┬──────────┘
           │
     ┌─────┴─────┐
     ▼           ▼
 [Complete]  [Incomplete]
     │           │
     ▼           ▼
   Stop      Inject reminder
               │
               ▼
         Continue loop
```

### Key Characteristics
- **Zero-drift workflows** - Multi-step tasks complete without intervention
- **Verification-first** - Tests/diagnostics must pass
- **Hook-based enforcement** - Invisible to agent until triggered
- **Ultrawork mode** - Stricter criteria for `/ulw` commands

### Example: Refactoring a React Component

**Scenario:** Agent is refactoring a Button component with 3 TODOs.

**Initial TODO List:**
```typescript
// Agent creates TODOs via todowrite
todowrite({
  todos: [
    { id: "1", content: "Extract Button props interface", status: "completed" },
    { id: "2", content: "Update Button.test.tsx with new props", status: "in_progress" },
    { id: "3", content: "Run linter and fix any issues", status: "pending" }
  ]
})
```

**Attempt 1: Agent Tries to Finish Early**
```
Agent: "I've refactored the Button component. The props interface is now 
        extracted and the component is cleaner. Task complete!"
        
        [Model sends finishReason: "stop"]
                │
                ▼
        Ralph Loop Hook intercepts:
        - ❌ TODO #2 still "in_progress"
        - ❌ TODO #3 still "pending"
        - ❌ No test results in context
        - ❌ Linter not run
                │
                ▼
        Text Modified:
        "I've refactored the Button component... Task complete!
        
        [SYSTEM REMINDER - RALPH LOOP]
        ⏳ You have 2 incomplete TODO items:
           - [ ] Update Button.test.tsx with new props (in_progress)
           - [ ] Run linter and fix any issues (pending)
           
        🔴 You MUST complete all TODOs before stopping.
        📝 Current diagnostics: NOT CHECKED
        🧪 Current test status: NOT CHECKED
        
        Continue working on the next pending item."
                │
                ▼
        [Loop continues - Agent sees reminder in context]
```

**Attempt 2: Agent Continues Work**
```
Agent: "Let me update the tests and run the linter."

[Agent runs tests - 2 fail, fixes them, tests pass]
[Agent runs linter - 1 error found, fixes it]

Agent marks TODOs complete via todowrite:
- TODO #2 → "completed" ✅
- TODO #3 → "completed" ✅

Agent: "All TODOs are now complete. Tests pass and linter is clean. 
        The refactoring is done."
        
        [Model sends finishReason: "stop"]
                │
                ▼
        Ralph Loop Hook checks:
        - ✅ All TODOs completed
        - ✅ lsp_diagnostics returns []
        - ✅ npm test passed (mentioned in context)
        - ✅ <promise>DONE</promise> tag present
                │
                ▼
        [No text modification - Hook allows completion]
                │
                ▼
        SessionStatus.set("idle")
        User sees final result
```

### Example: Chat vs. Task Mode

**Chat Mode (No TODOs Created):**
```
User: "Hello, how are you?"

Agent: "Hello! I'm ready to help you code. What would you like to work on?"
        
        [No TODOs exist]
                │
                ▼
        Ralph Loop: "No TODOs found - allowing natural conversation end"
                │
                ▼
        [Completion allowed - this is chat, not a task]
```

**Task Mode (TODOs Created):**
```
User: "Refactor the auth module"

Agent: "I'll refactor the auth module. Let me start by creating a plan."

[Agent creates 4 TODOs via todowrite]

Agent: "Alright, I've analyzed the code. Starting the refactoring..."
        
        [TODOs exist]
                │
                ▼
        Ralph Loop: "TODOs detected - enforcement ACTIVE"
                │
                ▼
        [Any attempt to finish before TODOs complete = BLOCKED]
```

---

## 4. OMOS: Pantheon Verification

### Completion Model
OMOS inherits OMO's Ralph Loop but adds **Orchestrator confirmation**:

```
┌─────────────────────────────────────────────────────────┐
│                   TASK COMPLETION FLOW                   │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Fixer/Agent completes work                             │
│         │                                                │
│         ▼                                                │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │
│  │   Tests     │───▶│  Linter     │───▶│   TODOs     │ │
│  │   Pass?     │    │   Clean?    │    │   Done?     │ │
│  └─────────────┘    └─────────────┘    └─────────────┘ │
│         │                  │                  │         │
│         └──────────────────┼──────────────────┘         │
│                            ▼                            │
│                    ┌─────────────┐                       │
│                    │  All Pass?  │                       │
│                    └──────┬──────┘                       │
│                           │                              │
│              ┌────────────┼────────────┐                │
│              ▼            ▼            ▼                │
│           [Yes]        [No]                        │
│              │            │                              │
│              ▼            ▼                              │
│         Orchestrator   Ralph Loop                       │
│         confirms       injects reminder                 │
│              │            │                              │
│              ▼            ▼                              │
│          Complete    Continue                            │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Tmux Visibility
Unlike OMO, OMOS shows completion status in **tmux panes**:

```
┌─────────────────────────────┬─────────────────────────────┐
│                             │                             │
│   Main Session              │   @fixer                    │
│   (Orchestrator)            │   ✅ Task complete          │
│                             │   ✅ Tests passed           │
│   Waiting for results...    │   ✅ 3/3 TODOs done         │
│                             │                             │
└─────────────────────────────┴─────────────────────────────┘
```

### Key Characteristics
- **Pantheon coordination** - Orchestrator verifies specialist work
- **Tmux real-time view** - Visual confirmation of completion
- **Same Ralph enforcement** - Inherited from OMO
- **Streamlined** - Fewer hooks, faster execution

### Example: Multi-Agent Feature Implementation

**Scenario:** Adding a new API endpoint with database migration.

**Orchestrator Creates Plan:**
```typescript
// Orchestrator delegates to Pantheon
todowrite({
  todos: [
    { id: "1", content: "@explorer: Find existing API patterns", status: "pending" },
    { id: "2", content: "@librarian: Research Prisma migration syntax", status: "pending" },
    { id: "3", content: "@fixer: Implement endpoint handler", status: "pending" },
    { id: "4", content: "@fixer: Create database migration", status: "pending" },
    { id: "5", content: "Run tests and verify", status: "pending" }
  ]
})
```

**Tmux Session Layout:**
```
┌─────────────────────────────────────┬─────────────────────────────────────┐
│                                     │                                     │
│  Main Session (@orchestrator)       │  @explorer                          │
│  ─────────────────────────          │  ─────────────                      │
│  Status: DELEGATING                 │  Status: ✅ DONE                    │
│                                     │  Found 3 API pattern files          │
│  Active Tasks:                      │  Pattern: /src/api/*route.ts        │
│  - @explorer: DONE ✅               │                                     │
│  - @librarian: RUNNING ⏳           │                                     │
│  - @fixer: WAITING ⏸️               │                                     │
│                                     │                                     │
├─────────────────────────────────────┼─────────────────────────────────────┤
│                                     │                                     │
│  @librarian                         │  @fixer (STANDBY)                   │
│  ──────────                         │  ────────────────                   │
│  Status: ⏳ FETCHING                │  Status: ⏸️ WAITING                 │
│  Source: Context7                   │  Queue: 2 tasks                     │
│  Query: Prisma migration create     │  - Implement endpoint               │
│                                     │  - Create migration                 │
│                                     │                                     │
└─────────────────────────────────────┴─────────────────────────────────────┘
```

**Fixer Tries to Complete Early (After Task 3 Only):**
```
@fixer completes endpoint implementation:

@fixer: "I've implemented the API endpoint at /src/api/users/route.ts.
          The handler supports GET and POST methods with proper validation."
          
          [Attempts to signal completion]
                  │
                  ▼
          Ralph Loop Hook (runs on orchestrator):
          - ❌ TODO #4 still pending (migration not created)
          - ❌ TODO #5 not started (tests not run)
          - ❌ @fixer doesn't mark work as "completed" - only "in_progress"
                  │
                  ▼
          Tmux @fixer pane updates:
          ┌─────────────────────────────────────┐
          │  @fixer                             │
          │  ───────                            │
          │  Status: ⚠️ REMINDER INJECTED       │
          │                                     │
          │  [SYSTEM] Complete migration task   │
          │  before finishing.                  │
          │                                     │
          │  Pending: TODO #4                   │
          └─────────────────────────────────────┘
                  │
                  ▼
          @fixer continues to migration task...
```

**Final Completion (All Tasks Done):**
```
@fixer: "Database migration created at /prisma/migrations/20240219_add_user_api/.
          Tests pass: 12/12 ✅
          Linter: Clean ✅
          All TODOs marked complete."
          
          [Orchestrator reviews via Ralph Loop]
                  │
                  ▼
          Checks:
          - ✅ All 5 TODOs completed
          - ✅ @explorer, @librarian, @fixer all confirmed
          - ✅ Test output shows 12/12 passed
          - ✅ LSP diagnostics: 0 errors
          - ✅ <promise>DONE</promise> present
                  │
                  ▼
          Orchestrator confirms completion
                  │
                  ▼
          Tmux panes auto-close (except main)
          SessionStatus.set("idle")
```

### Example: Parallel Task with Verification Failure

**Scenario:** One of two parallel tasks fails validation.

```
Orchestrator spawns 2 background tasks:
┌─────────────────────────────┬─────────────────────────────┐
│   @fixer-task-1             │   @fixer-task-2             │
│   Update auth middleware    │   Update user service       │
│                             │                             │
│   ✅ Code written           │   ✅ Code written           │
│   ✅ Tests pass             │   ❌ Tests FAIL (2/5)       │
│   ✅ Linter clean           │   ✅ Linter clean           │
│                             │                             │
│   [Waiting for other]       │   [Trying to complete]      │
└─────────────────────────────┴─────────────────────────────┘
         │                               │
         └───────────────┬───────────────┘
                         ▼
              Ralph Loop on Orchestrator:
              - @fixer-task-1: All checks pass ✅
              - @fixer-task-2: Tests failing ❌
              
              Result: BLOCK completion
              
              Tmux shows:
              @fixer-task-2: "⚠️ Tests failing - fix before completing"
              
              @fixer-task-2 must:
              1. Fix failing tests
              2. Re-run verification
              3. Then completion allowed
```

---

## 5. OpenHands: Explicit AgentFinishAction

### Completion Signal
```python
# Event-based completion
from openhands.events.action.agent import AgentFinishAction

finish_action = AgentFinishAction(
    thought="I have completed the implementation",
    action="finish"
)
```

### Controller Handling
```python
# AgentController listens for finish events
if isinstance(action, AgentFinishAction):
    self.state = AgentState.STOPPED
    await self.notify_frontend("agent_finished")
```

### Flow
```
Agent decides to finish
         │
         ▼
┌─────────────────────┐
│ AgentFinishAction   │
│ event emitted       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ AgentController     │──▶ Sets state = STOPPED
│ catches event       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Frontend notified   │──▶ UI shows completion
└─────────────────────┘
```

### Key Characteristics
- **Event-driven** - Explicit action class
- **Controller-mediated** - State change via controller
- **Sandboxed** - Docker-native execution
- **Memory condensation** - Summarizes history when context overflows

---

## 6. Letta: Control Yielding

### Completion Signal
```python
# Stop reasons (not explicit "done")
class LettaStopReason:
    END_TURN = "end_turn"      # Agent yields control
    MAX_STEPS = "max_steps"    # Safety limit hit
    TOOL_RULE = "tool_rule"    # Security blocked
    REQUIRES_APPROVAL = "requires_approval"  # Human needed
```

### Flow
```
LLM Response
     │
     ▼
┌─────────────────┐
│ Parse response  │──▶ Content + Tool Call?
└───────┬─────────┘
        │
        ▼
┌─────────────────┐
│ Tool execution  │──▶ Update memory if core_memory_replace
│ (if needed)     │
└───────┬─────────┘
        │
        ▼
┌─────────────────┐
│ Yield result    │──▶ Return to user
│ stop_reason =   │    (not "complete" but "end_turn")
│   "end_turn"    │
└─────────────────┘
```

### Key Characteristics
- **Conversation-centric** - Optimized for long-running dialogue
- **Memory-based planning** - No explicit TODO system
- **Self-editing memory** - Agent updates `CoreMemory` blocks
- **Not task-oriented** - Yields control rather than declaring completion

---

## Comparative Analysis

### Philosophical Differences

| Platform | Mental Model | User Relationship |
|----------|-------------|-------------------|
| **Roo Code** | Co-Pilot | "Let me show you, you decide" |
| **OpenCode** | Tool | "Execute until stopped" |
| **OMO** | Autonomous Worker | "I'll verify then finish" |
| **OMOS** | Agent Team | "Orchestrator confirms completion" |
| **OpenHands** | Employee | "I formally submit my work" |
| **Letta** | Companion | "Let's continue talking" |

### Enforcement Mechanisms

| Platform | Enforcement | Strength |
|----------|-------------|----------|
| Roo Code | User review gate | Very Strong (human) |
| OpenCode | Finish reason | Weak (model decides) |
| OMO | Ralph Loop hooks | Strong (forced continue) |
| OMOS | Ralph + Orchestrator | Strong + Coordinated |
| OpenHands | Controller check | Medium (state-based) |
| Letta | Step limits | Weak (safety only) |

### When to Use Each

| Use Case | Best Platform | Why |
|----------|--------------|-----|
| Require human approval | **Roo Code** | Built-in review UI |
| Maximum automation | **OMO/OMOS** | Evidence-based completion |
| Long conversations | **Letta** | Memory-centric design |
| Sandboxed execution | **OpenHands** | Docker-native |
| Simple streaming | **OpenCode** | Minimal overhead |
| Visual monitoring | **OMOS** | Tmux integration |

---

## Implementation Patterns

### Pattern 1: Hook-Based Enforcement (OMO/OMOS)
```typescript
// Force continuation via text modification
async "experimental.text.complete"(input, output) {
  const hasIncomplete = await checkTodos(input.sessionID)
  if (hasIncomplete) {
    output.text += "\n[SYSTEM]: Complete all TODOs before stopping."
  }
}
```

### Pattern 2: Tool-Based Completion (Roo Code)
```typescript
// Explicit completion tool
{
  name: "attempt_completion",
  handler: async (input) => {
    await validateCompletion()  // Check TODOs, tests
    const approved = await requestUserReview()
    return approved ? finalize() : continueTask()
  }
}
```

### Pattern 3: Event-Based (OpenHands)
```python
# Event-driven completion
class AgentController:
    async def handle_action(self, action):
        if isinstance(action, AgentFinishAction):
            self.state = AgentState.STOPPED
            await self.notify_completion()
```

### Pattern 4: Finish Reason (OpenCode)
```typescript
// Stream processing
for await (const event of stream) {
  if (event.type === "finish-step") {
    if (event.finishReason === "tool-calls") {
      return "continue"  // Execute tools, loop back
    } else if (event.finishReason === "stop") {
      return "stop"      // Task complete
    }
  }
}
```

---

## Key Insights

1. **Explicit > Implicit**: Roo Code's `attempt_completion` and OpenHands' `AgentFinishAction` are clearer than relying on `finishReason`

2. **Verification Matters**: OMO/OMOS's evidence-based approach (tests + diagnostics) reduces false positives

3. **Human-in-the-Loop**: Roo Code's mandatory review is safest but adds friction; OMO balances autonomy with verification

4. **Hook Power**: OpenCode's `experimental.text.complete` hook enables sophisticated enforcement without protocol changes

5. **Philosophy Drives Design**: Letta's conversation-centric model doesn't need "completion" - it yields control; OpenHands' employee model requires formal submission

---

## References

- **[Roo Code](../roocode_learning/10_task_completion.md)** - `attempt_completion` tool
- **[OpenCode](./09_task_completion_detection.md)** - Streaming and finish reasons
- **[OMO](../opencode_learning/plugins/oh_my_opencode_learning/06_task_completion.md)** - Ralph Loop and evidence-based completion
- **[OMOS](../opencode_learning/plugins/omos_learning/04_features_and_workflows.md)** - Pantheon orchestration
- **[OpenHands](../openhands_learning/02_task_completion_and_memory.md)** - `AgentFinishAction` and event stream
- **[Letta](../letta_learning/03_agent_loop.md)** - `LettaStopReason` and step loop

---

*Part of [Coding Agent Research](./comparative_analysis_2026.md) horizontal analysis.*
