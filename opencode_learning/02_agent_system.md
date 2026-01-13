# Agent System Architecture

## Overview

The agent system is the core orchestration mechanism in OpenCode. Agents are configurable AI entities with specific permissions, prompts, and capabilities.

**Location**: `packages/opencode/src/agent/agent.ts`

## Agent Types

### 1. Primary Agents (`mode: "primary"`)

User-facing agents that can be selected directly:

- **build** - Default full-access agent for development work
- **plan** - Read-only agent for analysis and code exploration
- **compaction** - Internal agent for message history compression
- **title** - Generates session titles
- **summary** - Creates session summaries

### 2. Subagents (`mode: "subagent"`)

Specialized agents invoked by other agents:

- **general** - General-purpose research and multi-step tasks
- **explore** - Fast codebase exploration (grep, glob, read only)
- **oracle** - Deep reasoning for architecture decisions (expensive)
- **librarian** - External documentation and GitHub searches

### 3. Mode: "all"

Custom user-defined agents that can be both primary and subagent.

## Agent Definition Schema

```typescript
export const Info = z.object({
  name: z.string(), // Unique identifier
  description: z.string().optional(), // When to use this agent
  mode: z.enum(["subagent", "primary", "all"]),
  native: z.boolean().optional(), // Built-in vs custom
  hidden: z.boolean().optional(), // Hide from UI
  topP: z.number().optional(), // Sampling parameter
  temperature: z.number().optional(), // Randomness control
  color: z.string().optional(), // UI color coding
  permission: PermissionNext.Ruleset, // Access control rules
  model: z
    .object({
      modelID: z.string(),
      providerID: z.string(),
    })
    .optional(),
  prompt: z.string().optional(), // Custom system prompt
  options: z.record(z.string(), z.any()),
  steps: z.number().int().positive().optional(),
})
```

## Built-in Agents Deep Dive

### Build Agent

```typescript
{
  name: "build",
  mode: "primary",
  native: true,
  permission: {
    "*": "allow",           // All tools allowed
    question: "allow",      // Can ask user questions
    doom_loop: "ask",       // Warn on infinite loops
    read: {
      "*.env": "deny",      // Block .env files
      "*.env.*": "deny",
    }
  }
}
```

**Purpose**: Full-featured development agent
**Use Case**: Code changes, refactoring, feature implementation
**Restrictions**: Cannot read .env files by default

### Plan Agent

```typescript
{
  name: "plan",
  mode: "primary",
  native: true,
  permission: {
    edit: {
      "*": "deny",                    // No file edits
      ".opencode/plan/*.md": "allow", // Except planning docs
    },
    question: "allow",
  }
}
```

**Purpose**: Safe exploration and analysis
**Use Case**: Understanding unfamiliar codebases, planning changes
**Restrictions**: Cannot modify files (except planning docs)

### Explore Agent

```typescript
{
  name: "explore",
  mode: "subagent",
  native: true,
  permission: {
    "*": "deny",           // Deny all by default
    grep: "allow",         // Allow search tools
    glob: "allow",
    list: "allow",
    bash: "allow",
    read: "allow",
    webfetch: "allow",
    websearch: "allow",
    codesearch: "allow",
  },
  prompt: PROMPT_EXPLORE,
  description: "Fast agent specialized for exploring codebases..."
}
```

**Purpose**: Contextual grep - find code patterns quickly
**Use Case**: "Find auth implementations", "Locate API endpoints"
**Restrictions**: Read-only, no file modifications
**Thoroughness Levels**: "quick", "medium", "very thorough"

### General Agent

```typescript
{
  name: "general",
  mode: "subagent",
  native: true,
  permission: {
    todoread: "deny",      // No access to parent's todos
    todowrite: "deny",
  },
  description: "General-purpose agent for researching complex questions..."
}
```

**Purpose**: Multi-step research and parallel task execution
**Use Case**: Complex questions requiring multiple search angles
**Restrictions**: Cannot access parent session's todos

## Permission System

### Permission Structure

```typescript
type Ruleset = Array<{
  permission: string // Tool name or special pattern
  pattern: string // File/path pattern (glob)
  action: "allow" | "deny" | "ask"
}>
```

### Permission Resolution

```typescript
// Merge order (later overrides earlier):
1. System defaults
2. Agent-specific defaults
3. User config overrides

// Example:
const defaults = {
  "*": "allow",
  "read": { "*.env": "deny" }
}

const agentDefaults = {
  "question": "allow"
}

const userOverrides = {
  "bash": "ask"
}

// Result: All allowed except .env files, bash requires approval
```

### Special Permissions

- `doom_loop`: Detect infinite tool call loops
- `external_directory`: Access files outside project directory
- `question`: Ask user for input
- Tool-specific: `bash`, `edit`, `read`, etc.

## Agent Lifecycle

### 1. Initialization

```typescript
const state = Instance.state(async () => {
  const cfg = await Config.get()

  // Load built-in agents
  const result: Record<string, Info> = {
    /* ... */
  }

  // Load custom agents from config
  for (const [key, value] of Object.entries(cfg.agent ?? {})) {
    if (value.disable) {
      delete result[key]
      continue
    }
    // Merge custom config with defaults
  }

  return result
})
```

### 2. Selection

```typescript
// Get specific agent
const agent = await Agent.get("build")

// List all agents (sorted by default)
const agents = await Agent.list()

// Get default agent
const defaultAgent = await Agent.defaultAgent()
```

### 3. Execution Context

When an agent executes:

1. Load agent definition
2. Resolve permissions
3. Load custom prompt (if any)
4. Apply temperature/topP settings
5. Select model (agent-specific or default)
6. Execute with constrained tool access

## Custom Agent Creation

### Via Config File (`.opencode/config.toml`)

```toml
[agent.reviewer]
mode = "subagent"
description = "Code review specialist"
prompt = """
You are a code review expert. Focus on:
- Security vulnerabilities
- Performance issues
- Code style violations
"""
temperature = 0.3

[agent.reviewer.model]
provider_id = "anthropic"
model_id = "claude-3-5-sonnet-latest"

[agent.reviewer.permission]
"*" = "deny"
read = "allow"
grep = "allow"
glob = "allow"
```

### Via Agent.generate() API

```typescript
const agentDef = await Agent.generate({
  description: "A Rust specialist agent that helps with Rust code",
  model: { providerID: "anthropic", modelID: "claude-3-5-sonnet" }
})

// Returns:
{
  identifier: "rust_specialist",
  whenToUse: "Use when working with Rust code, cargo, or Rust-specific questions",
  systemPrompt: "You are a Rust programming expert..."
}
```

## Agent Invocation Patterns

### Direct Invocation (Primary Agents)

```typescript
// User switches agent in TUI with Tab key
// Or specifies via CLI:
opencode --agent plan
```

### Subagent Delegation

```typescript
// In agent prompts, subagents are invoked via Task tool:
Task(
  (agent = "explore"),
  (prompt = "Find all authentication implementations in the codebase"),
  (description = "Search for auth patterns"),
)
```

### Background Execution

```typescript
// Launch async subagent for parallel work:
background_task((agent = "explore"), (prompt = "Find error handling patterns"), (description = "Search error patterns"))

// Later retrieve results:
const result = await background_output(task_id)
```

## Agent Communication

### Subagent → Parent

- Returns single message with findings
- No access to parent's todo list
- Cannot modify parent session state
- Stateless unless session_id provided

### Parent → Subagent

- Passes detailed task description
- Specifies expected output format
- Provides context (file paths, constraints)
- Defines allowed tools via permissions

## Agent Specialization Strategy

### When to Create Custom Agents

**Good Candidates**:

- Domain-specific expertise (Rust, React, Security)
- Workflow automation (PR review, documentation)
- Constrained environments (production debugging)
- Specialized tool sets (only read + search)

**Bad Candidates**:

- One-off tasks (use general agent)
- Tasks requiring full tool access (use build agent)
- Too similar to existing agents (customize existing)

## Agent Prompt Engineering

### Effective Agent Prompts

```
1. Identity: "You are a [role] specialized in [domain]"
2. Constraints: "You have access to [tools] but cannot [restrictions]"
3. Workflow: "When given a task, you should [steps]"
4. Output Format: "Return your findings as [format]"
5. Thoroughness: "Be [concise/detailed/exhaustive]"
```

### Example: Explore Agent Prompt

```
You are a codebase exploration specialist.

Your job: Find relevant code patterns quickly.
Your tools: grep, glob, read, bash (for git operations)
Your constraints: Read-only, no modifications

Workflow:
1. Understand search intent
2. Try multiple search patterns
3. Check common locations
4. Return file paths + relevant snippets

Thoroughness levels:
- quick: 1-2 search patterns, common locations only
- medium: 3-5 patterns, include edge cases
- very thorough: Exhaustive search, all naming conventions
```

## Agent Composition Patterns

### Sequential Delegation

```typescript
1. Parent calls explore → gets file list
2. Parent calls general → analyzes patterns
3. Parent calls oracle → validates approach
4. Parent executes implementation
```

### Parallel Delegation

```typescript
// Launch multiple explore agents simultaneously:
const tasks = [
  background_task((agent = "explore"), (prompt = "Find auth code")),
  background_task((agent = "explore"), (prompt = "Find error handling")),
  background_task((agent = "librarian"), (prompt = "Find JWT best practices")),
]

// Collect results when needed
const results = await Promise.all(tasks.map((t) => background_output(t.id)))
```

### Recursive Delegation

```typescript
general agent
  └─> spawns explore agents
       └─> explore spawns grep/glob tools
            └─> returns to general
                 └─> returns to parent
```

## Agent Performance Characteristics

| Agent     | Speed  | Cost      | Thoroughness | Best For               |
| --------- | ------ | --------- | ------------ | ---------------------- |
| build     | Medium | High      | Varies       | Development work       |
| plan      | Medium | Medium    | High         | Codebase analysis      |
| explore   | Fast   | Low       | Medium       | Quick searches         |
| general   | Medium | Medium    | High         | Complex research       |
| oracle    | Slow   | Very High | Very High    | Architecture decisions |
| librarian | Medium | Medium    | High         | External docs          |

## Testing Custom Agents

```bash
# Run with custom agent
opencode --agent my_agent

# Test in config directory
bun dev --agent my_agent

# Check agent permissions
opencode agent list
opencode agent inspect my_agent
```

## Best Practices

1. **Start Simple**: Begin with permission overrides on existing agents
2. **Clear Purpose**: Each agent should have one clear specialty
3. **Permission Principle of Least Privilege**: Only grant needed tools
4. **Prompt Specificity**: Be explicit about behavior and output format
5. **Test Thoroughly**: Verify permission boundaries work as expected
6. **Document Usage**: Add clear `description` for when to use
7. **Monitor Cost**: Expensive agents (oracle) should be used sparingly

## Next Steps

- [03_session_management.md](./03_session_management.md) - How agents interact with sessions
- [04_tool_system.md](./04_tool_system.md) - Tools available to agents
- [06_provider_layer.md](./06_provider_layer.md) - How agents connect to LLMs
