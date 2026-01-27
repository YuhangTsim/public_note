# System Design Deep Dive

Oh My OpenCode (OMO) is not just a configuration; it's a runtime environment that sits on top of OpenCode. It uses OpenCode's extensibility points—specifically **Hooks** and **Context Injection**—to enforce its behaviors.

## 1. The Hook System

OMO leverages the Claude Code compatibility layer to inject logic at critical points in the agent's lifecycle.

### `PostToolUse` Hook: The Enforcer
This is the mechanism behind the "Todo Continuation Enforcer".

**Logic Flow:**
1.  **Event**: Agent finishes executing a tool (e.g., `edit` or `bash`).
2.  **Check**: The hook inspects the current state of the `todowrite` tool.
    - Are there items marked `pending` or `in_progress`?
3.  **Action**:
    - If **Yes**: The hook injects a system message: *"You have pending tasks. Proceed to the next item immediately."*
    - If **No**: It allows the agent to generate a final response.

**Why it matters**: This prevents the "lazy agent" problem where the LLM stops after doing 80% of the work.

### `PreToolUse` Hook: The Validator
This hook runs *before* a tool is executed.

**Logic Flow:**
1.  **Event**: Agent requests to call `delegate_task`.
2.  **Check**: Does the `prompt` argument contain the mandatory justification block?
    - `SKILL EVALUATION for...`
3.  **Action**:
    - If **Missing**: The tool call is **blocked**. The agent receives an error: *"Delegation rejected. You must provide skill evaluation."*
    - If **Present**: The call proceeds.

**Why it matters**: It forces the model to adhere to the Chain-of-Thought protocols defined in the system prompt.

## 2. Context Injection Architecture

Sisyphus needs to know about the codebase without reading every file. OMO uses a dynamic context injection system.

### Auto-Discovery
- **AGENTS.md**: The system recursively searches parent directories for `AGENTS.md` files and injects them. This allows folder-specific rules (e.g., "In `/frontend`, always use React functional components").
- **README.md**: The root README is often summarized and injected to give the agent high-level project awareness.

### Conditional Injection
The "Intent Gate" (Phase 0) drives conditional context loading.
- If the user mentions "database", the system might proactively inject the schema file (if configured).
- If the user mentions "testing", it might inject the `TESTING.md` guide.

## 3. Agent Runtime & State

### The "Sisyphus" Persona
Sisyphus isn't just a text prompt; it's a configured `Agent` object in OpenCode's registry.

```typescript
// Conceptual definition
export const sisyphus = {
  name: "sisyphus",
  model: "anthropic/claude-opus-4-5", // High-intelligence model
  permissions: {
    "delegate_task": "allow", // Can spawn sub-agents
    "doom_loop": "ask",       // Safety brake
  },
  systemPrompt: loadFromFile("sisyphus-prompt.md")
}
```

### Sub-Agent Isolation
When Sisyphus calls `delegate_task`, OMO spawns a **new session** (or child process) for the sub-agent.
- **Isolation**: The sub-agent has its own context window. It doesn't see Sisyphus's full history, only the `prompt` passed to it.
- **Reintegration**: The sub-agent returns a text result, which is inserted into Sisyphus's context. This acts as a "memory compression" mechanism.

## 4. The "Ultrawork" Loop

The `ultrawork` keyword triggers a meta-state in the client.

1.  **User**: `ulw fix the login bug`
2.  **Client**: Sets a flag `ULTRAWORK_MODE = true`.
3.  **Agent**: Starts executing.
4.  **Middleware**:
    - Suppresses "Ask for permission?" prompts for low-risk tools.
    - Automatically answers "Yes" to "Continue?" prompts.
    - Only stops on **Critical Errors** or **Todo Completion**.

This transforms the interactive chat experience into an autonomous job runner.
