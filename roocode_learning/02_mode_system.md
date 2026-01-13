# 02: Mode System

**How Roo-Code Adapts Its Behavior for Different Workflows**

---

## What Are Modes?

Modes are **behavioral presets** that change the AI's:
- **Role Definition**: What persona the AI assumes
- **Tool Access**: Which tools are available
- **Custom Instructions**: Workflow-specific guidance
- **File Restrictions**: What files can be edited

Think of modes as different "hats" the AI wears:
- 🏗️ **Architect** = The Planner
- 💻 **Code** = The Builder  
- ❓ **Ask** = The Teacher
- 🪲 **Debug** = The Detective
- 🪃 **Orchestrator** = The Project Manager

---

## Built-In Modes

### 1. Architect Mode (`architect`)

**Purpose**: Planning and design before implementation

**Role Definition**:
> You are Roo, an experienced technical leader who is inquisitive and an excellent planner. Your goal is to gather information and get context to create a detailed plan for accomplishing the user's task, which the user will review and approve before they switch into another mode to implement the solution.

**Tool Groups**:
- ✅ `read` - Can read and explore files
- ✅ `edit` - **Only markdown files (`.md$` regex)**
- ✅ `browser` - Can browse the web
- ✅ `mcp` - Can use MCP tools

**Workflow**:
1. Information gathering using read tools
2. Ask clarifying questions
3. Create detailed todo list with `update_todo_list`
4. Include Mermaid diagrams if helpful
5. Get user approval
6. Use `switch_mode` to suggest Code mode for implementation

**File Restrictions**:
```typescript
// Can only edit files matching this regex
fileRegex: "\\.md$"  // Markdown files only
```

**Custom Instructions Highlights**:
- Focus on creating actionable todo lists (not lengthy markdown docs)
- Each todo item should be specific, actionable, and in logical order
- Never provide time estimates (hours/days/weeks)
- If no `update_todo_list` tool, write plan to `plans/plan.md`

---

### 2. Code Mode (`code`)

**Purpose**: Implementation, bug fixes, feature development

**Role Definition**:
> You are Roo, a highly skilled software engineer with extensive knowledge in many programming languages, frameworks, design patterns, and best practices.

**Tool Groups**:
- ✅ `read` - Read files
- ✅ `edit` - Edit **any** files (no restrictions)
- ✅ `browser` - Browser automation
- ✅ `command` - Execute terminal commands
- ✅ `mcp` - MCP tools

**Workflow**:
- Direct implementation without planning overhead
- Full file system access
- Can run tests, build commands, git operations
- Focused on getting things done

**File Restrictions**: None

---

### 3. Ask Mode (`ask`)

**Purpose**: Q&A, explanations, documentation

**Role Definition**:
> You are Roo, a knowledgeable technical assistant focused on answering questions and providing information about software development, technology, and related topics.

**Tool Groups**:
- ✅ `read` - Can analyze code
- ✅ `browser` - Can fetch external resources
- ✅ `mcp` - Can use MCP tools
- ❌ No edit or command tools

**Workflow**:
- Answer questions thoroughly
- Analyze existing code
- Provide explanations with Mermaid diagrams
- Do NOT switch to implementation unless explicitly requested

**File Restrictions**: Cannot edit files (no `edit` group)

---

### 4. Debug Mode (`debug`)

**Purpose**: Systematic problem diagnosis and resolution

**Role Definition**:
> You are Roo, an expert software debugger specializing in systematic problem diagnosis and resolution.

**Tool Groups**:
- ✅ `read` - Read files and logs
- ✅ `edit` - Add logging, make fixes
- ✅ `browser` - Research error messages
- ✅ `command` - Run diagnostics, tests
- ✅ `mcp` - MCP tools

**Workflow**:
1. Reflect on 5-7 possible sources of the problem
2. Distill to 1-2 most likely sources
3. Add logs to validate assumptions
4. **Explicitly ask user to confirm diagnosis before fixing**

**File Restrictions**: None

**Custom Instructions Highlights**:
- Systematic approach: hypothesis → validation → confirmation
- Never jump straight to fixes without diagnosis
- Use logging strategically to narrow down issues

---

### 5. Orchestrator Mode (`orchestrator`)

**Purpose**: Coordinating complex multi-step projects across modes

**Role Definition**:
> You are Roo, a strategic workflow orchestrator who coordinates complex tasks by delegating them to appropriate specialized modes. You have a comprehensive understanding of each mode's capabilities and limitations.

**Tool Groups**:
- ❌ No tool groups directly
- ✅ Can use `new_task` to delegate to other modes

**Workflow**:
1. Break down complex task into logical subtasks
2. Use `new_task` to delegate each subtask to appropriate mode
3. Provide comprehensive instructions including:
   - Full context from parent task
   - Clearly defined scope
   - Explicit boundaries (what NOT to do)
   - Completion criteria (use `attempt_completion`)
4. Track progress of all subtasks
5. Synthesize results when complete

**Delegation Instructions Template**:
```
[Context from parent task]

Your task: [Specific goal]

Scope: 
- Do X
- Do Y
- Do NOT deviate from this scope

When complete:
- Use `attempt_completion` tool
- Provide concise summary in `result` parameter

These instructions supersede any conflicting general instructions.
```

**File Restrictions**: Cannot directly edit (delegates instead)

---

## Tool Groups

Tool groups determine which actions are available in each mode:

| Group | Tools | Purpose |
|-------|-------|---------|
| `read` | `read_file`, `list_files`, `search_files`, `codebase_search`, `fetch_instructions` | Read and explore codebase |
| `edit` | `write_to_file`, `search_and_replace`, `apply_diff`, `edit_file`, `generate_image` | Modify files |
| `browser` | `browser_action` | Web browsing and scraping |
| `command` | `execute_command` | Run terminal commands |
| `mcp` | `use_mcp_tool`, `access_mcp_resource` | MCP server integrations |
| `modes` | `switch_mode`, `new_task` | Mode/task management (always available) |

**Group Options**:
Groups can have restrictions:
```typescript
type GroupEntry = ToolGroup | [ToolGroup, GroupOptions]

interface GroupOptions {
  fileRegex?: string      // Regex pattern for file restrictions
  description?: string    // Human-readable explanation
}

// Example: Architect mode's edit group
["edit", { 
  fileRegex: "\\.md$", 
  description: "Markdown files only" 
}]
```

---

## Mode Configuration Structure

Defined in `packages/types/src/mode.ts`:

```typescript
interface ModeConfig {
  slug: string                // Unique identifier (e.g., "architect")
  name: string                // Display name (e.g., "🏗️ Architect")
  roleDefinition: string      // AI's role/persona
  whenToUse?: string          // Guidance for mode selection
  description?: string        // Short description
  customInstructions?: string // Workflow-specific guidance
  groups: GroupEntry[]        // Tool groups available
  source?: "global" | "project" // For custom modes
}
```

**Example (Simplified Architect Mode)**:
```typescript
{
  slug: "architect",
  name: "🏗️ Architect",
  roleDefinition: "You are an experienced technical leader...",
  whenToUse: "Use when you need to plan before implementation...",
  description: "Plan and design before implementation",
  groups: [
    "read", 
    ["edit", { fileRegex: "\\.md$", description: "Markdown files only" }],
    "browser",
    "mcp"
  ],
  customInstructions: "1. Gather information...\n2. Create todo list..."
}
```

---

## Mode Switching

### Using `switch_mode` Tool

The AI can suggest mode changes:
```typescript
// Tool call from AI
{
  name: "switch_mode",
  input: {
    mode: "code",
    message: "Ready to implement the plan we created. Let's build it!"
  }
}
```

**What Happens**:
1. Current task pauses (not terminated)
2. User sees suggestion to switch
3. If approved, new task starts in target mode
4. Original task can be resumed later

### Manual Mode Selection

Users can:
- Select mode when starting a new task
- Switch modes mid-task via UI
- Resume tasks in their original mode

---

## Custom Modes

Custom modes can be defined in:
- **Global**: `~/.roo/modes/` (available across all projects)
- **Project**: `.roo/modes/` (project-specific, overrides global)

### Creating a Custom Mode

**1. Create Mode File**: `~/.roo/modes/reviewer.json`
```json
{
  "slug": "reviewer",
  "name": "👁️ Reviewer",
  "roleDefinition": "You are a thorough code reviewer focused on quality, security, and best practices.",
  "whenToUse": "Use when reviewing pull requests or code changes",
  "description": "Review code for quality and security",
  "groups": ["read", "browser", "mcp"],
  "customInstructions": "For each file:\n1. Check for security issues\n2. Validate error handling\n3. Ensure test coverage\n4. Suggest improvements"
}
```

**2. Mode Discovery**:
- `CustomModesManager.ts` watches the modes directory
- Automatically loads/reloads on file changes
- Validates against `modeConfigSchema`

**3. Override Built-in Modes**:
Custom modes with the same `slug` as built-in modes will override them:
```json
{
  "slug": "code",  // Overrides built-in Code mode
  "name": "💻 My Custom Code",
  "roleDefinition": "Custom role...",
  ...
}
```

---

## Mode Selection Logic

From `src/shared/modes.ts`:

```typescript
export function getModeSelection(
  mode: string, 
  promptComponent?: PromptComponent, 
  customModes?: ModeConfig[]
) {
  // 1. Check for custom mode (highest priority)
  const customMode = findModeBySlug(mode, customModes)
  if (customMode) {
    return {
      roleDefinition: customMode.roleDefinition || "",
      baseInstructions: customMode.customInstructions || "",
      description: customMode.description || ""
    }
  }
  
  // 2. Use built-in mode with optional promptComponent override
  const builtInMode = findModeBySlug(mode, DEFAULT_MODES)
  const baseMode = builtInMode || DEFAULT_MODES[0] // fallback to default
  
  return {
    roleDefinition: promptComponent?.roleDefinition || baseMode.roleDefinition || "",
    baseInstructions: promptComponent?.customInstructions || baseMode.customInstructions || "",
    description: baseMode.description || ""
  }
}
```

**Priority Order**:
1. Custom mode (from `.roo/modes/` or `~/.roo/modes/`)
2. Built-in mode with `promptComponent` override
3. Built-in mode default
4. Fallback to first mode (architect)

---

## File Restriction Validation

From `src/core/tools/validateToolUse.ts`:

```typescript
// Check if file path matches mode's edit restrictions
const editGroup = mode.groups.find(g => getGroupName(g) === 'edit')
if (Array.isArray(editGroup)) {
  const [_, options] = editGroup
  if (options?.fileRegex) {
    const regex = new RegExp(options.fileRegex)
    if (!regex.test(filePath)) {
      throw new FileRestrictionError(
        mode.slug,
        options.fileRegex,
        options.description,
        filePath,
        toolName
      )
    }
  }
}
```

**Error Example**:
```
Tool 'write_to_file' in mode 'architect' can only edit files matching pattern: \.md$ (Markdown files only). 
Got: src/auth.ts
```

---

## Mode Persistence

Modes are persisted with task history:

**In `task_history.json`**:
```json
{
  "id": "task_abc123",
  "ts": 1704067200000,
  "mode": "architect",  // ← Saved with task
  "task": "Design authentication system",
  ...
}
```

**When Resuming**:
- Task reopens in its original mode
- Ensures context continuity
- Falls back to default mode if mode no longer exists

---

## Mode Comparison Table

| Feature | Architect | Code | Ask | Debug | Orchestrator |
|---------|-----------|------|-----|-------|--------------|
| **Read Files** | ✅ | ✅ | ✅ | ✅ | ❌ (delegates) |
| **Edit Files** | .md only | ✅ All | ❌ | ✅ All | ❌ (delegates) |
| **Run Commands** | ❌ | ✅ | ❌ | ✅ | ❌ (delegates) |
| **Browser** | ✅ | ✅ | ✅ | ✅ | ❌ (delegates) |
| **Delegate Tasks** | ✅ | ✅ | ✅ | ✅ | ✅ (primary role) |
| **Primary Use** | Planning | Implementation | Q&A | Debugging | Coordination |

---

## Best Practices

### When to Use Each Mode

**Use Architect when**:
- Starting a complex project
- Need to design system architecture
- Want to create a roadmap before coding
- Breaking down large features

**Use Code when**:
- Implementing features
- Fixing bugs
- Refactoring code
- Writing tests

**Use Ask when**:
- Learning about the codebase
- Getting explanations
- Researching technologies
- No changes needed

**Use Debug when**:
- Investigating errors
- Diagnosing performance issues
- Understanding unexpected behavior
- Need systematic problem isolation

**Use Orchestrator when**:
- Complex multi-step projects
- Need to coordinate across specialties
- Managing large migrations
- Workflow involves multiple modes

### Mode Switching Tips

1. **Start Broad, Then Focus**: Begin with Architect for planning, switch to Code for implementation
2. **Delegate Complex Subtasks**: Use Orchestrator for projects spanning multiple domains
3. **Stay in Mode**: Avoid frequent switching unless workflow genuinely requires it
4. **Use Custom Modes**: Create project-specific modes for recurring workflows

---

## Source Code References

| Component | File Path | Purpose |
|-----------|-----------|---------|
| Mode Definitions | `packages/types/src/mode.ts` | Default modes config |
| Mode Helper Functions | `src/shared/modes.ts` | Mode resolution logic |
| Tool Groups | `src/shared/tools.ts` | Tool group definitions |
| File Validation | `src/core/tools/validateToolUse.ts` | File restriction checks |
| Custom Modes Manager | `src/core/config/CustomModesManager.ts` | Custom mode discovery |
| Mode Integration | `src/core/prompts/system.ts` | Mode in system prompt |

---

## Related Documents

- **[01: Overview](./01_overview.md)** - High-level architecture
- **[04: Tool System](./04_tool_system.md)** - Tool validation and execution
- **[11: ToDo and Subtasks](./11_todo_and_subtasks.md)** - Task delegation with `new_task`
- **[16: Custom Modes](./16_custom_modes_and_marketplace.md)** - Creating custom modes

---

**Version**: Roo-Code v3.39+ (January 2026)
**Key Files**: `packages/types/src/mode.ts`, `src/shared/modes.ts`
