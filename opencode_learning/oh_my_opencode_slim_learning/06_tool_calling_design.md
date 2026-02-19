# oh-my-opencode-slim: Tool Calling Design

## Overview

**oh-my-opencode-slim (OMOS)** uses **OpenCode's native tool calling system**, not XML-based tool calling. The XML-like tags in prompts (`<Role>`, `<Workflow>`, `<results>`) are for **structuring system instructions and output formats**, not for actual tool invocation.

---

## Tool Calling Architecture

### 1. **OpenCode Plugin SDK**

Tools are defined using the `@opencode-ai/plugin/tool` SDK:

```typescript
import { type ToolDefinition, tool } from '@opencode-ai/plugin/tool';

export const grep: ToolDefinition = tool({
  description: 'Fast content search tool with safety limits...',
  args: {
    pattern: tool.schema.string().describe('The regex pattern...'),
    include: tool.schema.string().optional().describe('File pattern...'),
    // ... more args
  },
  execute: async (args) => {
    // Tool implementation
    const result = await runRg({ pattern: args.pattern, ... });
    return formatGrepResult(result);
  },
});
```

### 2. **Tool Definition Pattern**

All tools follow this structure:

| Property | Type | Description |
|----------|------|-------------|
| `description` | `string` | Human-readable description of what the tool does |
| `args` | Zod Schema | Validated arguments using Zod schemas |
| `execute` | `function` | Async function that implements the tool logic |

### 3. **Tool Categories**

OMOS provides 3 categories of tools:

#### **A. Built-in Tools** (`src/tools/`)
- `grep` - Ripgrep-based content search
- `ast_grep_search` / `ast_grep_replace` - AST-aware pattern matching
- `lsp_goto_definition` / `lsp_find_references` / `lsp_diagnostics` / `lsp_rename` - LSP integration

#### **B. Background Task Tools** (`src/tools/background.ts`)
- `background_task` - Launch fire-and-forget agent tasks
- `background_output` - Retrieve results from background tasks
- `background_cancel` - Cancel running background tasks

#### **C. MCP Tools** (Model Context Protocol)
- `websearch` - Web search via Exa AI
- `context7` - Official library documentation
- `grep_app` - GitHub code search via grep.app

---

## How Tool Calling Works

### **Step 1: Tool Registration**

Tools are registered with OpenCode in `src/index.ts`:

```typescript
const OhMyOpenCodeLite: Plugin = async (ctx) => {
  // ... initialization ...
  
  return {
    name: 'oh-my-opencode-slim',
    agents: getAgentConfigs(agents, config),
    tools: {
      grep,
      ast_grep_search,
      ast_grep_replace,
      lsp_goto_definition,
      lsp_find_references,
      lsp_diagnostics,
      lsp_rename,
      ...createBackgroundTools(ctx, backgroundManager, config.tmux, config),
    },
    mcp: mcps,
    // ...
  };
};
```

### **Step 2: Agent Tool Permissions**

Each agent is configured with specific tool permissions via `config/agent-mcps.ts`:

```typescript
export const DEFAULT_AGENT_MCPS: Record<AgentName, string[]> = {
  orchestrator: ['websearch'],  // Can use websearch MCP
  explorer: [],                  // No MCPs (uses built-in tools only)
  oracle: [],                    // No MCPs
  librarian: ['websearch', 'context7', 'grep_app'],  // Full research suite
  designer: [],                  // No MCPs
  fixer: [],                     // No MCPs
};
```

### **Step 3: OpenCode Handles Tool Invocation**

OpenCode itself manages the actual tool calling:
- **Format**: JSON-based (OpenAI-compatible function calling format)
- **Detection**: OpenCode parses LLM responses for tool call requests
- **Execution**: OpenCode routes tool calls to the appropriate `execute` function
- **Response**: Results are returned to the LLM as JSON

---

## XML Tags in Prompts vs Tool Calling

### **XML Tags Are For Prompt Structure**

The XML-like tags in agent prompts serve different purposes:

```markdown
<Role>
You are an AI coding orchestrator...
</Role>

<Agents>
@explorer
- Role: Parallel search specialist...
</Agents>

<Workflow>
## 1. Understand
Parse request: explicit requirements + implicit needs.
</Workflow>
```

**Purpose**: Help the LLM parse different sections of its system instructions.

### **Output Format Tags**

Some agents use XML for structured outputs:

```markdown
**Output Format**:
<results>
<files>
- /path/to/file.ts:42 - Brief description
</files>
<answer>
Concise answer to the question
</answer>
</results>
```

**Purpose**: Ensure consistent, parseable responses from agents.

---

## Tool Calling Format (Under the Hood)

While OMOS doesn't define the wire format (OpenCode handles that), the flow is:

```
1. LLM generates tool call request:
   {
     "tool": "grep",
     "args": {
       "pattern": "function handleClick",
       "include": "*.ts"
     }
   }

2. OpenCode validates args against Zod schema

3. OpenCode calls the tool's execute() function

4. Tool returns result (string or JSON)

5. OpenCode sends result back to LLM
```

---

## Key Design Decisions

### **1. Abstraction Layer**
- OMOS **does not** implement its own tool calling protocol
- It uses OpenCode's battle-tested tool system
- Focus is on **tool composition** and **agent orchestration**

### **2. Permission Model**
- Per-agent MCP allowlists control tool access
- Wildcards (`*`) and exclusions (`!item`) supported
- Prevents agents from accessing inappropriate tools

### **3. Tool Context**
- Tools receive `toolContext` with session metadata
- Background tools use context to track parent-child relationships
- Enables fire-and-forget delegation

### **4. Error Handling**
- Tools catch errors and return user-friendly messages
- LSP tools handle server unavailability gracefully
- Background tasks track completion/failure states

---

## Comparison: XML vs JSON Tool Calling

| Aspect | XML Tool Calling | OMOS/OpenCode Approach |
|--------|------------------|------------------------|
| **Format** | `<tool name="grep"><arg>...</arg></tool>` | JSON function calling |
| **Parsing** | Manual XML parsing | Native LLM support (OpenAI/Anthropic/Google) |
| **Standard** | Non-standard | Industry standard (OpenAI API) |
| **Flexibility** | Custom schema | Zod-validated schemas |
| **Debugging** | Harder to read | Clean JSON in logs |

---

## Conclusion

**OMOS leverages OpenCode's native tool calling** rather than implementing a custom XML-based system. This provides:

1. **Compatibility** with all models that support function calling
2. **Type Safety** via Zod schema validation
3. **Simplicity** - no custom parsing logic needed
4. **Extensibility** - easy to add new tools via the plugin SDK

The XML tags in prompts are purely for **structuring instructions and outputs**, not for tool invocation.

---

## References

- `src/tools/background.ts` - Background task tool implementation
- `src/tools/grep/tools.ts` - Grep tool definition
- `src/tools/ast-grep/tools.ts` - AST-grep tool definition
- `src/tools/lsp/tools.ts` - LSP tools definition
- `src/index.ts` - Tool registration with OpenCode
- `src/config/agent-mcps.ts` - MCP permissions per agent
