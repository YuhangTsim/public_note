# TODO System in OpenCode

## Overview

The TODO system is OpenCode's **task tracking and coordination mechanism** for multi-step agent workflows. It serves three critical functions:

1. **User Visibility**: Shows real-time progress on complex tasks
2. **Agent Coordination**: Anchors the LLM to a concrete plan, preventing drift
3. **Completion Enforcement**: Ensures agents finish all planned work before stopping

Unlike simple checklists, OpenCode's TODO system is **deeply integrated** into the agent execution model. TODOs are not just documentation—they're **enforced contracts** that govern when an agent can finish its turn.

---

## Why TODOs Matter

### Without TODOs

```
User: "Add dark mode toggle, update settings page, and add tests"

Agent: "I'll add dark mode..."
  [Creates toggle component]
  [Stops with finish reason: "stop"]

❌ Problem: Agent forgot settings page and tests
❌ User has no visibility into what was done
❌ No way to resume automatically
```

### With TODOs

```
User: "Add dark mode toggle, update settings page, and add tests"

Agent: [Creates TODO list]
  1. [ ] Create dark mode toggle component
  2. [ ] Update settings page to include toggle
  3. [ ] Add tests for dark mode functionality

Agent: "Working on dark mode..."
  [in_progress] Create dark mode toggle component
  [✓ completed] Create dark mode toggle component
  [in_progress] Update settings page to include toggle
  [✓ completed] Update settings page to include toggle
  [in_progress] Add tests for dark mode functionality
  [✓ completed] Add tests for dark mode functionality

✅ All TODOs complete → Agent stops
✅ User saw progress in real-time
✅ If interrupted, agent knows exactly where to resume
```

---

## TODO Schema

TODOs are structured objects stored per-session in the OpenCode storage layer.

### TypeScript Definition

```typescript
type Todo = {
  content: string // Brief description (one sentence)
  status: TodoStatus // Current state
  priority: Priority // Importance level
  id: string // Unique identifier
}

type TodoStatus =
  | "pending" // Not yet started
  | "in_progress" // Currently working on
  | "completed" // Finished
  | "cancelled" // No longer needed

type Priority =
  | "high" // Critical path item
  | "medium" // Normal priority
  | "low" // Nice-to-have
```

### Example TODO List

```json
[
  {
    "id": "todo_001",
    "content": "Create dark mode toggle component",
    "status": "completed",
    "priority": "high"
  },
  {
    "id": "todo_002",
    "content": "Update settings page to include toggle",
    "status": "in_progress",
    "priority": "high"
  },
  {
    "id": "todo_003",
    "content": "Add tests for dark mode functionality",
    "status": "pending",
    "priority": "medium"
  }
]
```

---

## Tool Definitions

OpenCode provides two tools for TODO management: `todowrite` and `todoread`.

### TodoWriteTool (from `tool/todo.ts`)

```typescript
Tool.define({
  name: "todowrite",
  description: "Create or update the todo list for the current session",
  parameters: z.object({
    todos: z.array(
      z.object({
        content: z.string().describe("Brief description of the task"),
        status: z.string().describe("Current status: pending, in_progress, completed, cancelled"),
        priority: z.string().describe("Priority level: high, medium, low"),
        id: z.string().describe("Unique identifier for the todo item"),
      }),
    ),
  }),
  execute: async (input, context) => {
    await Storage.write(["todo", context.sessionID], input.todos)
    Bus.publish(Event.TodoUpdated, {
      sessionID: context.sessionID,
      todos: input.todos,
    })
    return { output: "Todo list updated successfully" }
  },
})
```

**Key behaviors**:

- **Replaces entire TODO list** on each write (not incremental updates)
- Publishes event to notify UI of changes
- Stores in session-scoped storage: `["todo", sessionID]`

### TodoReadTool (from `tool/todo.ts`)

```typescript
Tool.define({
  name: "todoread",
  description: "Read the current todo list for the session",
  parameters: z.object({}), // No parameters needed
  execute: async (input, context) => {
    const todos = await Storage.read(["todo", context.sessionID])
    if (!todos) {
      return { output: "No todo list found for this session" }
    }
    return { output: JSON.stringify(todos, null, 2) }
  },
})
```

**Key behaviors**:

- Returns entire TODO list as JSON
- Returns null if no TODOs exist for session
- Agent uses this to check current state before updates

---

## Storage Mechanism

TODOs are persisted using OpenCode's key-value storage abstraction.

### Storage API (from `session/todo.ts`)

```typescript
import { Storage } from "@/storage"
import { Bus } from "@/bus"

// Write TODOs
await Storage.write(
  ["todo", sessionID],  // Key: ["todo", "ses_abc123"]
  todos                  // Value: Todo[]
)

// Read TODOs
const todos = await Storage.read(["todo", sessionID])

// Event published on update
Bus.publish(Event.TodoUpdated, {
  sessionID: "ses_abc123",
  todos: [...]
})
```

### Storage Location

Exact location depends on the storage backend (filesystem, SQLite, etc.), but conceptually:

```
Storage Root
  └─ todo
      └─ ses_abc123
          └─ [Todo, Todo, Todo, ...]
      └─ ses_def456
          └─ [Todo, Todo, ...]
```

Each session has its own isolated TODO list. When a session ends, its TODOs are preserved for historical reference.

---

## Permission System

TODO tools require explicit permissions to execute. This prevents untrusted agents or plugins from modifying TODOs maliciously.

### Permission Definitions

```typescript
// In agent configuration
{
  "name": "build",
  "permissions": [
    "todowrite",  // Can create/update TODOs
    "todoread"    // Can read TODOs
  ]
}
```

### Default Agent Permissions

| Agent       | todowrite | todoread |
| ----------- | --------- | -------- |
| **build**   | ✅ Yes    | ✅ Yes   |
| **plan**    | ❌ No     | ✅ Yes   |
| **general** | ✅ Yes    | ✅ Yes   |

The `plan` agent (read-only exploration agent) can **read** TODOs to understand the task plan but cannot **modify** them.

---

## Event System

TODOs publish events via OpenCode's event bus, enabling UI updates and plugin hooks.

### Event Definition (from `session/todo.ts`)

```typescript
import { BusEvent } from "@/bus/bus-event"

export const Event = {
  TodoUpdated: BusEvent.define(
    "todo.updated",
    z.object({
      sessionID: z.string(),
      todos: z.array(Todo.schema),
    }),
  ),
}
```

### Subscribing to Events

```typescript
import { Bus } from "@/bus"
import { Event } from "@/session/todo"

Bus.subscribe(Event.TodoUpdated, ({ sessionID, todos }) => {
  console.log(`TODOs updated for session ${sessionID}:`)
  todos.forEach((todo) => {
    const icon = todo.status === "completed" ? "✓" : todo.status === "in_progress" ? "▶" : " "
    console.log(`  [${icon}] ${todo.content}`)
  })
})
```

### UI Integration

The OpenCode TUI (Terminal User Interface) subscribes to `todo.updated` events and displays a live TODO sidebar showing:

- Total TODOs
- Completed count
- Current in-progress item
- Pending items

This provides **real-time visibility** without needing to poll or refresh.

---

## How Prompts Instruct LLMs to Use TODOs

OpenCode system prompts include explicit instructions for TODO usage. Different providers have slightly different wording, but the core logic is consistent.

### Anthropic Prompt Instructions (from `prompt/anthropic.txt`)

```
## Todo Management (CRITICAL)

**DEFAULT BEHAVIOR**: Create todos BEFORE starting any non-trivial task.

### When to Create Todos (MANDATORY)

| Trigger | Action |
|---------|--------|
| Multi-step task (2+ steps) | ALWAYS create todos first |
| Uncertain scope | ALWAYS (todos clarify thinking) |
| User request with multiple items | ALWAYS |

### Workflow (NON-NEGOTIABLE)

1. **IMMEDIATELY on receiving request**: `todowrite` to plan atomic steps.
2. **Before starting each step**: Mark `in_progress` (only ONE at a time)
3. **After completing each step**: Mark `completed` IMMEDIATELY (NEVER batch)
4. **If scope changes**: Update todos before proceeding

[Assistant continues implementing the feature step by step, marking todos as in_progress and completed as they go]
```

### Codex Prompt Instructions (from `prompt/codex.txt`)

```
To create a new plan, call `todowrite` with a short list of 1‑sentence steps
(no more than 5-7 words each) with a `status` for each step (`pending`,
`in_progress`, or `completed`).

When steps have been completed, use `todowrite` to mark each finished step as
`completed`. You should only have **one** task as `in_progress` at a time; you
must complete that task before moving on to the next task.

If all steps are complete, ensure you call `todowrite` to mark all steps as `completed`.
```

### Beast Prompt Instructions (from `prompt/beast.txt`)

```
Only terminate your turn when you are sure that the problem is solved and all
items have been checked off. Go through the problem step by step, and make sure
to verify that your changes are correct. NEVER end your turn without having
truly and completely solved the problem.

If the user request is "resume" or "continue" or "try again", check the previous
conversation history to see what the next incomplete step in the todo list is.
Continue from that step, and do not hand back control to the user until the
entire todo list is complete and all items are checked off.
```

### Key Patterns

All prompts emphasize:

1. **Create TODOs immediately** for multi-step tasks
2. **Only ONE in_progress** item at a time
3. **Mark completed IMMEDIATELY** after finishing
4. **Never end turn** with incomplete TODOs

---

## Oh-My-OpenCode TODO Enforcement

The oh-my-opencode plugin takes TODO enforcement to the next level with **mandatory completion checks**. If the agent tries to finish with incomplete TODOs, the plugin **forces continuation** by appending a system reminder.

### Enforcement Mechanism

```typescript
// Pseudo-code based on prompt patterns
async "experimental.text.complete"(input, output) {
  const todos = await Storage.read(["todo", input.sessionID])
  if (!todos) return  // No TODOs to enforce

  const incomplete = todos.filter(t => t.status !== "completed" && t.status !== "cancelled")

  if (incomplete.length > 0) {
    // Agent tried to finish with incomplete work!
    // Append system reminder to force continuation
    output.text += "\n\n"
    output.text += "╔═══════════════════════════════════════════════════════════╗\n"
    output.text += "║  [SYSTEM REMINDER - TODO CONTINUATION]                   ║\n"
    output.text += "╚═══════════════════════════════════════════════════════════╝\n"
    output.text += "\n"
    output.text += `You have ${incomplete.length} incomplete TODO items:\n\n`

    incomplete.forEach(todo => {
      const icon = todo.status === "in_progress" ? "▶" : "○"
      output.text += `  ${icon} ${todo.content} (${todo.status})\n`
    })

    output.text += "\n"
    output.text += "🚨 You MUST complete all TODOs before stopping.\n"
    output.text += "Continue working on the next pending item.\n"
    output.text += "\n"
    output.text += "Use `todowrite` to mark items as 'in_progress' when you start them,\n"
    output.text += "and 'completed' when finished. Never end your turn while TODOs remain.\n"
  }
}
```

### Effect on Agent Behavior

Even if the LLM sends `finishReason: "stop"`, the appended reminder becomes part of the **message context**. On the next loop iteration, the agent sees:

```
[Previous agent text]

╔═══════════════════════════════════════════════════════════╗
║  [SYSTEM REMINDER - TODO CONTINUATION]                   ║
╚═══════════════════════════════════════════════════════════╝

You have 2 incomplete TODO items:

  ○ Update settings page to include toggle (pending)
  ○ Add tests for dark mode functionality (pending)

🚨 You MUST complete all TODOs before stopping.
Continue working on the next pending item.
```

The agent then **resumes work** instead of returning control to the user. This creates a **zero-drift workflow** where complex multi-step tasks are guaranteed to complete.

---

## TODO Lifecycle

A typical TODO goes through several state transitions during task execution.

### State Transition Diagram

```
┌──────────────────────────────────────────────────────────┐
│                  TODO Lifecycle                          │
└──────────────────────────────────────────────────────────┘

    User: "Add feature X, update Y, test Z"
           │
           ▼
    ┌─────────────────────┐
    │   todowrite         │
    │   (create plan)     │
    └─────────────────────┘
           │
           ├─▶ Todo 1: "Add feature X"       [pending]
           ├─▶ Todo 2: "Update Y"            [pending]
           └─▶ Todo 3: "Test Z"              [pending]
           │
           ▼
    ┌─────────────────────┐
    │   todowrite         │
    │   (mark Todo 1      │
    │    in_progress)     │
    └─────────────────────┘
           │
           ├─▶ Todo 1: "Add feature X"       [in_progress] ◀─┐
           ├─▶ Todo 2: "Update Y"            [pending]        │
           └─▶ Todo 3: "Test Z"              [pending]        │
           │                                                  │
           │  [Agent works on Todo 1]                        │
           │  [Makes tool calls, edits files]                │
           │                                                  │
           ▼                                                  │
    ┌─────────────────────┐                                  │
    │   todowrite         │                                  │
    │   (mark Todo 1      │                                  │
    │    completed)       │                                  │
    └─────────────────────┘                                  │
           │                                                  │
           ├─▶ Todo 1: "Add feature X"       [completed]     │
           ├─▶ Todo 2: "Update Y"            [pending]       │
           └─▶ Todo 3: "Test Z"              [pending]       │
           │                                                  │
           ▼                                                  │
    ┌─────────────────────┐                                  │
    │   todowrite         │                                  │
    │   (mark Todo 2      │                                  │
    │    in_progress)     │                                  │
    └─────────────────────┘                                  │
           │                                                  │
           ├─▶ Todo 1: "Add feature X"       [completed]     │
           ├─▶ Todo 2: "Update Y"            [in_progress] ──┘ (Repeat for each TODO)
           └─▶ Todo 3: "Test Z"              [pending]
           │
          ...
           │
           ▼
    ┌─────────────────────┐
    │ All TODOs complete  │
    │ Agent stops         │
    │ Session goes idle   │
    └─────────────────────┘
```

### State Transitions

| From          | To            | Trigger               | Action                        |
| ------------- | ------------- | --------------------- | ----------------------------- |
| (none)        | `pending`     | User request received | Agent creates TODO list       |
| `pending`     | `in_progress` | Agent starts work     | Update via `todowrite`        |
| `in_progress` | `completed`   | Work finished         | Update via `todowrite`        |
| `in_progress` | `cancelled`   | No longer needed      | Update via `todowrite`        |
| `pending`     | `cancelled`   | Scope change          | Update via `todowrite`        |
| `completed`   | `pending`     | Needs rework          | Update via `todowrite` (rare) |

### Rules Enforced by Prompts

1. **Only ONE `in_progress` at a time**: Forces sequential execution
2. **Mark `completed` IMMEDIATELY**: Prevents batching (which hides progress)
3. **Never skip from `pending` to `completed`**: Must go through `in_progress`

---

## Workflow Examples

### Example 1: Simple Multi-Step Task

```
User: "Add logging to user.ts and auth.ts"

──────────────────────────────────────────────────────────────

Agent: [Creates TODOs]

todowrite({
  todos: [
    { id: "todo_1", content: "Add logging to user.ts", status: "pending", priority: "high" },
    { id: "todo_2", content: "Add logging to auth.ts", status: "pending", priority: "high" }
  ]
})

✅ TODO list created

──────────────────────────────────────────────────────────────

Agent: [Starts first TODO]

todowrite({
  todos: [
    { id: "todo_1", content: "Add logging to user.ts", status: "in_progress", priority: "high" },
    { id: "todo_2", content: "Add logging to auth.ts", status: "pending", priority: "high" }
  ]
})

[Edits user.ts to add logging]

✅ Logging added to user.ts

──────────────────────────────────────────────────────────────

Agent: [Completes first TODO]

todowrite({
  todos: [
    { id: "todo_1", content: "Add logging to user.ts", status: "completed", priority: "high" },
    { id: "todo_2", content: "Add logging to auth.ts", status: "pending", priority: "high" }
  ]
})

──────────────────────────────────────────────────────────────

Agent: [Starts second TODO]

todowrite({
  todos: [
    { id: "todo_1", content: "Add logging to user.ts", status: "completed", priority: "high" },
    { id: "todo_2", content: "Add logging to auth.ts", status: "in_progress", priority: "high" }
  ]
})

[Edits auth.ts to add logging]

✅ Logging added to auth.ts

──────────────────────────────────────────────────────────────

Agent: [Completes second TODO]

todowrite({
  todos: [
    { id: "todo_1", content: "Add logging to user.ts", status: "completed", priority: "high" },
    { id: "todo_2", content: "Add logging to auth.ts", status: "completed", priority: "high" }
  ]
})

✅ All TODOs complete → Agent stops
```

### Example 2: Scope Change Mid-Task

```
User: "Add dark mode support to the app"

──────────────────────────────────────────────────────────────

Agent: [Creates TODOs]

todowrite({
  todos: [
    { id: "todo_1", content: "Create theme context", status: "pending", priority: "high" },
    { id: "todo_2", content: "Update components with theme", status: "pending", priority: "medium" },
    { id: "todo_3", content: "Add settings toggle", status: "pending", priority: "high" }
  ]
})

──────────────────────────────────────────────────────────────

Agent: [Starts work, discovers existing theme context]

todoread()
→ Returns current TODO list

Agent: "I found an existing theme context. Updating plan..."

todowrite({
  todos: [
    { id: "todo_1", content: "Create theme context", status: "cancelled", priority: "high" },
    { id: "todo_2", content: "Update components with theme", status: "in_progress", priority: "medium" },
    { id: "todo_3", content: "Add settings toggle", status: "pending", priority: "high" },
    { id: "todo_4", content: "Add dark mode styles", status: "pending", priority: "high" }  // New!
  ]
})

✅ Scope updated dynamically
[Continues with updated plan]
```

### Example 3: Enforcement Triggers Continuation

```
User: "Implement user authentication"

──────────────────────────────────────────────────────────────

Agent: [Creates TODOs]

todowrite({
  todos: [
    { id: "todo_1", content: "Create auth context", status: "pending", priority: "high" },
    { id: "todo_2", content: "Add login/logout handlers", status: "pending", priority: "high" },
    { id: "todo_3", content: "Protect routes", status: "pending", priority: "medium" }
  ]
})

──────────────────────────────────────────────────────────────

Agent: [Completes first TODO]

todowrite({
  todos: [
    { id: "todo_1", content: "Create auth context", status: "completed", priority: "high" },
    { id: "todo_2", content: "Add login/logout handlers", status: "pending", priority: "high" },
    { id: "todo_3", content: "Protect routes", status: "pending", priority: "medium" }
  ]
})

──────────────────────────────────────────────────────────────

Agent: [Tries to stop early - BUG!]

"I've created the auth context. The authentication framework is now in place."

finishReason: "stop"  ← Agent thinks it's done!

──────────────────────────────────────────────────────────────

Oh-My-OpenCode Plugin: [Detects incomplete TODOs]

experimental.text.complete() hook fires:

Output text modified:
"I've created the auth context. The authentication framework is now in place.

╔═══════════════════════════════════════════════════════════╗
║  [SYSTEM REMINDER - TODO CONTINUATION]                   ║
╚═══════════════════════════════════════════════════════════╝

You have 2 incomplete TODO items:

  ○ Add login/logout handlers (pending)
  ○ Protect routes (pending)

🚨 You MUST complete all TODOs before stopping.
Continue working on the next pending item."

──────────────────────────────────────────────────────────────

Agent: [Sees reminder, resumes work]

todowrite({
  todos: [
    { id: "todo_1", content: "Create auth context", status: "completed", priority: "high" },
    { id: "todo_2", content: "Add login/logout handlers", status: "in_progress", priority: "high" },
    { id: "todo_3", content: "Protect routes", status: "pending", priority: "medium" }
  ]
})

[Continues until all TODOs complete]
```

---

## Visual Diagrams

### TODO System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     OpenCode TODO System                            │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────┐
│     Agent       │
│    (via LLM)    │
└────────┬────────┘
         │
         │ Uses tools
         │
         ├──────────▶ todowrite  ──────────┐
         │           (create/update)        │
         │                                  │
         └──────────▶ todoread   ───────┐  │
                     (check state)      │  │
                                        ▼  ▼
                              ┌────────────────────┐
                              │   Storage Layer    │
                              │  ["todo", sesID]   │
                              └──────────┬─────────┘
                                         │
                                         │ Publishes
                                         │
                                         ▼
                              ┌────────────────────┐
                              │     Event Bus      │
                              │  "todo.updated"    │
                              └──────────┬─────────┘
                                         │
                                         │ Notifies
                                         │
                  ┌──────────────────────┼──────────────────────┐
                  │                      │                      │
                  ▼                      ▼                      ▼
         ┌────────────────┐   ┌────────────────┐   ┌────────────────┐
         │      TUI       │   │    Plugin      │   │  Other Hooks   │
         │   (displays    │   │ (enforcement)  │   │   (logging)    │
         │    sidebar)    │   │                │   │                │
         └────────────────┘   └────────────────┘   └────────────────┘
```

### TODO Update Flow

```
┌───────────────────────────────────────────────────────────────────┐
│                    TODO Update Flow                               │
└───────────────────────────────────────────────────────────────────┘

Agent decides to update TODOs
         │
         ▼
┌────────────────────────────────┐
│ Tool call: todowrite           │
│ {                              │
│   todos: [                     │
│     { id: "1", status: "..." } │
│     { id: "2", status: "..." } │
│   ]                            │
│ }                              │
└────────────┬───────────────────┘
             │
             ▼
┌────────────────────────────────┐
│ Permission check               │
│ - Does agent have "todowrite"? │
│ - If no → reject               │
└────────────┬───────────────────┘
             │
             ▼ (allowed)
┌────────────────────────────────┐
│ Storage.write(                 │
│   ["todo", sessionID],         │
│   todos                        │
│ )                              │
└────────────┬───────────────────┘
             │
             ▼
┌────────────────────────────────┐
│ Bus.publish(                   │
│   "todo.updated",              │
│   { sessionID, todos }         │
│ )                              │
└────────────┬───────────────────┘
             │
             ├──────────────────────────────┐
             │                              │
             ▼                              ▼
┌────────────────────────┐   ┌──────────────────────────┐
│  TUI updates display   │   │ Plugin hooks triggered   │
│  - Sidebar refreshed   │   │ - Enforcement checks     │
│  - Progress shown      │   │ - Custom logic           │
└────────────────────────┘   └──────────────────────────┘
```

---

## Code Examples

### Creating TODOs (Agent Perspective)

```typescript
// Agent receives request
User: "Refactor authentication and add tests"

// Agent immediately creates TODO list
await todowrite({
  todos: [
    {
      id: "todo_abc123",
      content: "Extract auth logic into separate module",
      status: "pending",
      priority: "high",
    },
    {
      id: "todo_abc124",
      content: "Update import statements",
      status: "pending",
      priority: "medium",
    },
    {
      id: "todo_abc125",
      content: "Add unit tests for auth module",
      status: "pending",
      priority: "high",
    },
  ],
})

// Returns: "Todo list updated successfully"
```

### Updating TODOs (Sequential Progress)

```typescript
// Mark first TODO as in_progress
await todowrite({
  todos: [
    { id: "todo_abc123", content: "Extract auth logic into separate module", status: "in_progress", priority: "high" },
    { id: "todo_abc124", content: "Update import statements", status: "pending", priority: "medium" },
    { id: "todo_abc125", content: "Add unit tests for auth module", status: "pending", priority: "high" },
  ],
})

// [Work happens: files edited, tools called]

// Mark first TODO as completed
await todowrite({
  todos: [
    { id: "todo_abc123", content: "Extract auth logic into separate module", status: "completed", priority: "high" },
    { id: "todo_abc124", content: "Update import statements", status: "pending", priority: "medium" },
    { id: "todo_abc125", content: "Add unit tests for auth module", status: "pending", priority: "high" },
  ],
})

// Mark second TODO as in_progress
await todowrite({
  todos: [
    { id: "todo_abc123", content: "Extract auth logic into separate module", status: "completed", priority: "high" },
    { id: "todo_abc124", content: "Update import statements", status: "in_progress", priority: "medium" },
    { id: "todo_abc125", content: "Add unit tests for auth module", status: "pending", priority: "high" },
  ],
})

// And so on...
```

### Reading TODOs (Plugin Perspective)

```typescript
import type { Plugin } from "@opencode-ai/plugin"

export default async function myPlugin(input): Promise<Plugin> {
  return {
    async "experimental.text.complete"(hookInput, output) {
      // Read current TODOs
      const todos = await input.client.todo.read({ sessionID: hookInput.sessionID })

      if (!todos) return // No TODOs for this session

      // Check completion status
      const incomplete = todos.filter((t) => t.status !== "completed" && t.status !== "cancelled")

      if (incomplete.length === 0) {
        // All done! Add congratulations
        output.text += "\n\n✅ All TODO items completed!"
      } else {
        // Still work to do - enforce continuation
        output.text += `\n\n⚠️  ${incomplete.length} items remaining.`
      }
    },
  }
}
```

### Subscribing to TODO Events (UI Perspective)

```typescript
import { Bus } from "@/bus"
import { Event } from "@/session/todo"

// Subscribe to TODO updates
Bus.subscribe(Event.TodoUpdated, ({ sessionID, todos }) => {
  // Update sidebar UI
  const completed = todos.filter((t) => t.status === "completed").length
  const total = todos.length

  updateSidebar({
    title: `TODOs: ${completed}/${total}`,
    items: todos.map((t) => ({
      text: t.content,
      status: t.status,
      priority: t.priority,
      icon: t.status === "completed" ? "✓" : t.status === "in_progress" ? "▶" : "○",
    })),
  })
})
```

---

## Best Practices

### For Prompt Engineering

1. **Be explicit about TODO creation**: Use "MANDATORY", "MUST", "ALWAYS"
2. **Enforce single in_progress**: Prevents parallel work that's hard to track
3. **Require immediate completion**: Don't allow batching status updates
4. **Link TODOs to finish logic**: "Never end turn with incomplete TODOs"

### For Plugin Developers

1. **Use `experimental.text.complete` hook**: Best point to enforce completion
2. **Append reminders, don't replace**: Preserve agent's original text
3. **Make reminders visually distinct**: Use box characters, emojis, caps
4. **Check for `cancelled` status**: Not all pending items must complete

### For Agent Designers

1. **Create TODOs for 2+ step tasks**: Single-step tasks don't need tracking
2. **Keep TODO content brief**: 5-7 words max (prompt instruction)
3. **Use priority levels meaningfully**: High = blocking, Medium = normal, Low = nice-to-have
4. **Update scope dynamically**: If plans change, update TODOs immediately

---

## Common Patterns

### Pattern 1: Hierarchical TODOs

```typescript
// Parent TODO
{ id: "todo_1", content: "Implement authentication", status: "in_progress", priority: "high" }

// Sub-TODOs (flat list, but content shows hierarchy)
{ id: "todo_1a", content: "→ Create auth context", status: "completed", priority: "high" }
{ id: "todo_1b", content: "→ Add login handler", status: "in_progress", priority: "high" }
{ id: "todo_1c", content: "→ Add logout handler", status: "pending", priority: "high" }
```

### Pattern 2: Conditional TODOs

```typescript
// Initial plan
{ id: "todo_1", content: "Check if tests exist", status: "pending", priority: "high" }
{ id: "todo_2", content: "Write tests if missing", status: "pending", priority: "high" }

// After checking (tests found)
{ id: "todo_1", content: "Check if tests exist", status: "completed", priority: "high" }
{ id: "todo_2", content: "Write tests if missing", status: "cancelled", priority: "high" }  // Not needed!
```

### Pattern 3: Verification TODOs

```typescript
{ id: "todo_1", content: "Refactor user module", status: "completed", priority: "high" }
{ id: "todo_2", content: "Run lsp_diagnostics", status: "completed", priority: "high" }
{ id: "todo_3", content: "Run tests", status: "completed", priority: "high" }
{ id: "todo_4", content: "Verify no regressions", status: "completed", priority: "medium" }
```

Always include verification steps to ensure quality.

---

## Comparison: OpenCode vs Oh-My-OpenCode

| Feature                  | OpenCode (Base)                             | Oh-My-OpenCode                             |
| ------------------------ | ------------------------------------------- | ------------------------------------------ |
| TODO tools available     | ✅ Yes (`todowrite`, `todoread`)            | ✅ Yes (same tools)                        |
| Prompt instructions      | ✅ Encouraged in prompts                    | ✅ **MANDATORY** in prompts                |
| Enforcement level        | Soft (relies on LLM following instructions) | **Hard** (plugin hook forces continuation) |
| Incomplete TODO behavior | Agent may stop (depends on LLM)             | Agent **cannot** stop (reminder appended)  |
| User experience          | Works well with good models                 | **Guaranteed** completion                  |
| Best for                 | Single-agent workflows                      | Multi-step complex tasks                   |

---

## Key Takeaways

1. **TODOs are contracts, not notes**: They govern when agents can finish
2. **Three-layer system**: Tools → Storage → Events
3. **Permission-based**: Agents need explicit `todowrite`/`todoread` permissions
4. **Prompts are critical**: Instructions must be explicit and mandatory
5. **Oh-my-opencode adds enforcement**: Plugin hook prevents premature completion
6. **Single in_progress rule**: Forces sequential, trackable execution
7. **Immediate completion updates**: Provides real-time progress visibility
8. **Event-driven UI**: Subscribers see updates without polling

---

## Related Documentation

- **[09_task_completion_detection.md](./09_task_completion_detection.md)** - How agents know when to stop
- **[03_session_management.md](./03_session_management.md)** - Session lifecycle and state
- **[04_tool_system.md](./04_tool_system.md)** - Tool definitions and permissions
- **[02_agent_system.md](./02_agent_system.md)** - Agent architecture and configuration
- **[06_prompt_design.md](./06_prompt_design.md)** - How prompts instruct LLMs
