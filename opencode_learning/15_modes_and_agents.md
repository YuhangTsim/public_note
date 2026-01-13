# OpenCode Modes and Agent Roles

OpenCode has multiple concepts that use the term "mode", which can be confusing. This document clarifies the different types of modes and how they work.

## 1. Agent Modes (Role Classification)

**Agent modes** define the **role** an agent can play in the system. This is a property set on each agent.

### Types

| Mode | Description | Visibility | Usage |
|------|-------------|------------|-------|
| `primary` | Can be used as the main agent in a session | Shown in agent switcher (Tab key) | User directly interacts with these agents |
| `subagent` | Can only be invoked by other agents or via @ mention | Hidden from agent switcher, shown in @ autocomplete | Used for delegation and specialized tasks |
| `all` | Can function in both primary and subagent roles | Shown in both switcher and @ menu | Default for custom agents |

### Implementation

```typescript
// From: packages/opencode/src/agent/agent.ts
export const Info = z.object({
  name: z.string(),
  mode: z.enum(["subagent", "primary", "all"]),
  // ... other fields
})
```

### Built-in Agent Modes

| Agent | Mode | Purpose |
|-------|------|---------|
| `build` | `primary` | Default development mode with full tool access |
| `plan` | `primary` | Read-only analysis mode with restricted tools |
| `explore` | `subagent` | Fast codebase search specialist |
| `general` | `subagent` | Multi-step task executor |
| `compaction` | `primary` (hidden) | Internal: conversation summarization |
| `title` | `primary` (hidden) | Internal: session title generation |
| `summary` | `primary` (hidden) | Internal: session summary generation |

## 2. Built-in Agents (Previously Called "Modes")

**Important**: The `mode` configuration field is **deprecated**. What used to be called "modes" are now configured as "agents". However, the documentation still uses "mode" terminology for historical reasons.

### Build Mode (Agent)

**Default primary agent** with full capabilities.

**Characteristics:**
- All tools enabled by default
- Full file system access (read, write, edit)
- Can execute shell commands
- Designed for active development work

**Permission configuration:**
```typescript
{
  "*": "allow",
  "question": "allow",
  "doom_loop": "ask",
  "external_directory": { "*": "ask" }
}
```

### Plan Mode (Agent)

**Restricted primary agent** for analysis without modifications.

**Characteristics:**
- Read-only by default
- Cannot write, edit, or execute bash commands
- Can only edit files in `.opencode/plan/*.md`
- Designed for code review and planning

**Permission configuration:**
```typescript
{
  "*": "deny",
  "question": "allow",
  "edit": {
    "*": "deny",
    ".opencode/plan/*.md": "allow"
  }
}
```

**Behavioral enforcement:**
- When active, system injects `prompt/plan.txt` as a critical reminder
- When switching from plan → build, injects `prompt/build-switch.txt` reminder
- Implementation in `packages/opencode/src/session/prompt.ts` (lines 1188-1214)

### Explore Mode (Agent)

**Subagent specialist** for codebase navigation.

**Characteristics:**
- Optimized for search operations
- Only has access to: `grep`, `glob`, `list`, `bash`, `websearch`, `codesearch`, `read`
- Cannot modify files
- Custom prompt: `agent/prompt/explore.txt`

**Usage:**
```
@explore find all authentication-related files
@explore search for API endpoint definitions
```

### General Mode (Agent)

**Subagent worker** for complex multi-step tasks.

**Characteristics:**
- General-purpose task executor
- Full tool access except `todoread` and `todowrite`
- Used for parallel task execution
- No custom prompt (uses default)

**Usage:**
```
@general research this library and find usage examples
@general analyze these three components in parallel
```

## 3. UI Input Modes (Shell vs Normal)

The prompt input UI has two distinct modes that affect how user input is interpreted.

### Normal Mode

Default input mode for conversational interaction.

**Features:**
- Supports @ mentions for agent invocation
- Supports / commands (slash commands)
- File attachments
- Image attachments
- Text formatting

**Entry:** Default state

**Exit:** Press `!` at the start of an empty prompt to switch to shell mode

### Shell Mode

Direct shell command execution mode.

**Features:**
- Input is sent directly to `session.shell()` API
- No @ mention or / command processing
- Appears with monospace font
- Shows "Shell" label instead of agent name

**Entry:** Press `!` at the beginning of an empty prompt

**Exit:** 
- Press `Escape`
- Press `Backspace` when prompt is empty

**Implementation:**
```typescript
// From: packages/app/src/components/prompt-input.tsx
const [store, setStore] = createStore<{
  mode: "normal" | "shell"  // UI input mode
}>({
  mode: "normal"
})

// Switching logic
if (event.key === "!" && store.mode === "normal") {
  if (cursorPosition === 0) {
    setStore("mode", "shell")
  }
}
```

**Shell command execution:**
```typescript
if (mode === "shell") {
  client.session.shell({
    sessionID: session.id,
    agent,
    model,
    command: text,
  })
}
```

## 4. Theme Modes (Dark vs Light)

Simple UI theme selection. Not related to agent behavior.

**Types:**
- `dark` - Dark color scheme
- `light` - Light color scheme
- `system` - Follows OS preference

**Toggle:** Keybind toggles between dark and light

## 5. Configuration

### Configuring Agent Mode (Role)

**In opencode.json:**
```json
{
  "agent": {
    "my-reviewer": {
      "mode": "subagent",  // Role: primary | subagent | all
      "description": "Code review specialist",
      "tools": {
        "write": false,
        "edit": false
      }
    }
  }
}
```

**In markdown (.opencode/agent/my-reviewer.md):**
```markdown
---
mode: subagent
description: Code review specialist
tools:
  write: false
  edit: false
---

You are a code reviewer. Focus on best practices.
```

### Custom Agent with Different Behavior

Create custom "modes" by defining agents with:

1. **Different tool permissions** (what they can do)
2. **Different prompts** (how they behave)
3. **Different models** (which LLM to use)
4. **Different temperature** (creativity level)

**Example: Debug mode**
```markdown
---
mode: primary
temperature: 0.1
model: anthropic/claude-sonnet-4-20250514
tools:
  bash: true
  read: true
  grep: true
  write: false
  edit: false
---

You are in debug mode. Focus on investigation:
- Use bash commands to inspect system state
- Read files and logs carefully
- Search for patterns and anomalies
- Provide clear explanations

DO NOT make changes to files. Only investigate.
```

## 6. Migration: mode → agent

The `mode` config field is deprecated. Old configs are automatically migrated:

**Old style (deprecated):**
```json
{
  "mode": {
    "build": { "model": "..." },
    "plan": { "tools": { "write": false } }
  }
}
```

**New style (current):**
```json
{
  "agent": {
    "build": { "model": "..." },
    "plan": { "tools": { "write": false } }
  }
}
```

**Migration logic:** `packages/opencode/src/config/config.ts` (lines 88, 121)

## 7. Key Differences Summary

### Agent Mode Property
- **What it controls:** Whether agent appears in switcher vs @ menu
- **Values:** `primary`, `subagent`, `all`
- **Configured in:** Agent definition (frontmatter or JSON)

### Built-in Agents (build/plan/etc)
- **What it controls:** Tool permissions, prompts, behavior
- **Values:** `build`, `plan`, `explore`, `general`, etc.
- **Configured in:** `opencode.json` under `agent` key or `.opencode/agent/*.md`
- **Differences:**
  - **Tools:** What operations are allowed (permission rulesets)
  - **Prompts:** Different system prompts for different behaviors
  - **Models:** Can use different LLMs
  - **Temperature:** Different creativity levels

### UI Input Mode
- **What it controls:** How prompt input is interpreted
- **Values:** `normal`, `shell`
- **Toggled by:** `!` key or `Escape`
- **Scope:** UI-only, affects single input

### Theme Mode
- **What it controls:** Visual appearance
- **Values:** `dark`, `light`, `system`
- **Toggled by:** Keybind
- **Scope:** UI-only

## 8. Common Patterns

### Switch Between Primary Agents
```
Press Tab → cycles through build, plan, custom primary agents
```

### Invoke Subagents
```
@explore find authentication code
@general research this library
```

### Use Shell Mode
```
! (at start of prompt) → enters shell mode
ls -la
git status
Escape → back to normal mode
```

### Create Custom Agent "Mode"
```bash
# Create file
mkdir -p .opencode/agent
cat > .opencode/agent/refactor.md << 'EOF'
---
mode: primary
temperature: 0.2
description: Code refactoring specialist
tools:
  edit: true
  read: true
  grep: true
  bash: false
---

You are in refactoring mode. Focus on code quality improvements
without changing functionality.
EOF
```

Then use Tab to switch to `refactor` agent.

## References

- Agent definitions: `packages/opencode/src/agent/agent.ts`
- Config parsing: `packages/opencode/src/config/config.ts`
- Prompt assembly: `packages/opencode/src/session/prompt.ts`
- UI input modes: `packages/app/src/components/prompt-input.tsx`
- Official docs: `packages/web/src/content/docs/modes.mdx`, `agents.mdx`
