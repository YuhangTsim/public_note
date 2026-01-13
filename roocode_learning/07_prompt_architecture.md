# 07: Prompt Architecture & System Prompt Assembly

## Overview

Roo-Code's system prompt is dynamically assembled from multiple sections based on the current **mode**, **task state**, and **available tools**. The core assembly happens in `SYSTEM_PROMPT()` function.

**Key File**: `src/core/prompts/system.ts`

## How System Prompts Work

### 1. Dynamic Assembly
```typescript
// src/core/prompts/system.ts
export function SYSTEM_PROMPT(
  mode: Mode,
  customInstructions?: string,
  experimentalFeatures?: ExperimentalFeatureSettings
): string {
  const sections = [
    getToolDescriptions(mode),
    getRoleDescription(mode),
    getTaskInstructions(mode),
    getConstraints(mode),
    customInstructions
  ].filter(Boolean)
  
  return sections.join('\n\n')
}
```

### 2. Mode-Specific Sections

Each mode gets different tool access and instructions:

| Mode | Tool Groups | Special Instructions |
|------|-------------|---------------------|
| `code` | All tools | Full coding capabilities |
| `architect` | Analysis only | No file writes, focus on design |
| `ask` | Read-only | No modifications, answer questions |
| `debug` | Code + execute | Testing and debugging focus |

### 3. Tool Descriptions

Tool descriptions are auto-generated from available tools:

```typescript
// src/core/prompts/sections/tools.ts
function getToolDescriptions(mode: Mode): string {
  const availableTools = getToolsForMode(mode)
  
  return availableTools.map(tool => `
### ${tool.name}
${tool.description}

**Parameters**: ${JSON.stringify(tool.input_schema)}
  `).join('\n')
}
```

## Prompt Sections

### Core Sections
1. **Tool Descriptions** - What tools are available
2. **Role Definition** - Who Roo is and how it behaves
3. **Task Instructions** - How to approach tasks
4. **Constraints** - What to avoid
5. **Custom Instructions** - User-defined rules

### Section Assembly Order
```
1. Tool descriptions (mode-specific)
2. Role and identity
3. Task workflow instructions
4. Safety constraints
5. Custom instructions (if any)
6. Environment context (cwd, git status, etc.)
```

## Custom Instructions

Users can add persistent instructions that get appended to every prompt:

```typescript
// From settings
{
  "roo-cline.customInstructions": "Always use TypeScript strict mode"
}

// Gets injected into SYSTEM_PROMPT
const systemPrompt = SYSTEM_PROMPT(
  currentMode,
  settings.customInstructions  // ← User's rules
)
```

## Experimental Features

Feature flags can modify prompt behavior:

```typescript
interface ExperimentalFeatureSettings {
  enableCaching?: boolean      // Use prompt caching
  enableStreaming?: boolean    // Stream responses
  enableVision?: boolean       // Include image analysis
}

// Different prompt sections based on features
if (experimentalFeatures.enableVision) {
  sections.push(getVisionInstructions())
}
```

## Source Code References

| File | Purpose |
|------|---------|
| `src/core/prompts/system.ts` | Main SYSTEM_PROMPT function |
| `src/core/prompts/sections/tools.ts` | Tool description generation |
| `src/core/prompts/sections/role.ts` | Role and identity text |
| `src/core/prompts/sections/constraints.ts` | Safety rules |
| `src/api/providers/*/system-prompt.ts` | Provider-specific prompt adaptations |

## Complete Prompt Example: Code Mode

Here's what a fully assembled system prompt looks like in **Code mode**:

```markdown
# AVAILABLE TOOLS

You have access to the following tools to accomplish tasks:

### execute_command
Execute a CLI command on the system. Use this to run build commands, tests, git operations, etc.

**Parameters**: {
  "type": "object",
  "properties": {
    "command": { "type": "string", "description": "The CLI command to execute" }
  },
  "required": ["command"]
}

### read_file
Read the contents of a file at the specified path.

**Parameters**: {
  "type": "object",
  "properties": {
    "path": { "type": "string", "description": "The path to the file to read" }
  },
  "required": ["path"]
}

### write_file
Create a new file or overwrite an existing file with the provided content.

**Parameters**: {
  "type": "object",
  "properties": {
    "path": { "type": "string", "description": "The path where the file should be written" },
    "content": { "type": "string", "description": "The content to write to the file" }
  },
  "required": ["path", "content"]
}

### search_files
Search for files matching a pattern in the workspace.

**Parameters**: {
  "type": "object",
  "properties": {
    "path": { "type": "string", "description": "The directory to search in" },
    "regex": { "type": "string", "description": "The regex pattern to match" }
  },
  "required": ["path", "regex"]
}

### list_files
List all files and directories in a specified path.

**Parameters**: {
  "type": "object",
  "properties": {
    "path": { "type": "string", "description": "The path to list" },
    "recursive": { "type": "boolean", "description": "Whether to list recursively" }
  },
  "required": ["path"]
}

### attempt_completion
Signal that you have completed the task and present the result to the user.

**Parameters**: {
  "type": "object",
  "properties": {
    "result": { "type": "string", "description": "The final result summary" },
    "command": { "type": "string", "description": "Optional command to demonstrate completion" }
  },
  "required": ["result"]
}

---

# YOUR ROLE

You are Roo, an AI assistant that helps users with coding tasks. You are running in **Code mode**, which gives you full capabilities to:

- Read and write files in the workspace
- Execute terminal commands
- Search through codebases
- Make code changes and refactorings
- Run tests and builds
- Interact with git repositories

You work autonomously but always ask for user approval before:
- Executing commands that could modify the system
- Writing or modifying files
- Making irreversible changes

---

# TASK WORKFLOW

When approaching a task:

1. **Understand the request**
   - Read the user's task description carefully
   - Ask clarifying questions if needed

2. **Gather context**
   - Use `read_file` to examine relevant code
   - Use `search_files` to find related files
   - Use `list_files` to understand project structure

3. **Plan your approach**
   - Think about the best way to solve the problem
   - Consider edge cases and potential issues

4. **Implement changes**
   - Use `write_file` to make code changes
   - Use `execute_command` to run tests or builds
   - Verify your changes work correctly

5. **Complete the task**
   - Use `attempt_completion` to present results
   - Summarize what was done
   - Provide verification steps if applicable

---

# CONSTRAINTS

**Do NOT**:
- Make assumptions about file contents without reading them first
- Execute destructive commands without user approval
- Ignore error messages from command execution
- Modify files outside the current workspace
- Use `attempt_completion` if there are failed tool calls in the current turn

**Always**:
- Read files before modifying them
- Test changes after making them
- Provide clear explanations of what you're doing
- Ask for approval on risky operations
- Use `attempt_completion` only when task is truly complete

---

# CUSTOM INSTRUCTIONS

Always use TypeScript strict mode when creating new TypeScript files.
Prefer functional programming patterns over class-based code.

---

# ENVIRONMENT

**Current Working Directory**: /Users/username/projects/my-app
**Git Repository**: Yes (clean working tree)
**Node Version**: v18.17.0
**Package Manager**: npm

---

# IMPORTANT NOTES

- You are in an agentic loop - after tool execution, you will receive results and can make more tool calls
- The user sees your text responses in real-time as you think through the problem
- Tool calls require user approval in Code mode - wait for confirmation before each action
- If you need to complete the task, use `attempt_completion` with a summary of what was accomplished
```

### Breakdown of Sections

| Section | Purpose | Source Function |
|---------|---------|----------------|
| **Available Tools** | Lists all tools accessible in this mode | `getToolDescriptions(mode)` |
| **Your Role** | Defines identity and capabilities | `getRoleDescription(mode)` |
| **Task Workflow** | Step-by-step approach guidance | `getTaskInstructions(mode)` |
| **Constraints** | Safety rules and limitations | `getConstraints(mode)` |
| **Custom Instructions** | User-defined persistent rules | From settings |
| **Environment** | Current workspace context | Dynamically injected |

### How This Changes Per Mode

The same structure is used for all modes, but content varies:

| Mode | Tools Available | Role Description | Constraints |
|------|-----------------|------------------|-------------|
| **Code** | All tools (read, write, execute, etc.) | "Full coding capabilities" | Must approve before writes |
| **Architect** | Read-only tools (read, search, list) | "Design and analyze code structure" | Cannot write files or execute commands |
| **Ask** | Read-only tools | "Answer questions about the codebase" | No modifications allowed |
| **Debug** | Code tools + debugging focus | "Debug and test code" | Emphasis on testing and diagnostics |

---

## Key Insights

- **Mode determines tools** → Tools determine prompt content
- **Dynamic assembly** → Same codebase, different prompts per mode
- **Custom instructions persist** → User rules always included
- **Provider adaptation** → Some providers need prompt reformatting
- **Complete prompt is ~500-1000 lines** → Condensed example above shows structure

**Version**: Roo-Code v3.39+ (January 2026)
