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
