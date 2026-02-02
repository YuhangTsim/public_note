# OpenClaw Tool System Architecture

**Last Updated:** January 26, 2026

## Table of Contents
1. [Overview](#overview)
2. [Tool Architecture](#tool-architecture)
3. [Tool Categories](#tool-categories)
4. [Tool Discovery](#tool-discovery)
5. [Tool Execution Flow](#tool-execution-flow)
6. [Security System](#security-system)
7. [Configuration](#configuration)

---

## Overview

OpenClaw implements a **comprehensive tool system** with 37+ built-in tools plus plugin extensibility. Tools are the primary mechanism for the AI agent to interact with the system, execute commands, control browsers, manage sessions, and communicate across channels.

### Key Features
- **Type-safe schemas** using TypeBox (JSON Schema)
- **Multi-host execution** (sandbox, gateway, device nodes)
- **Approval-based security** with allowlists
- **Plugin extensibility** for custom tools
- **Streaming execution** with progress updates

---

## Tool Architecture

### Tool Type Definition

Tools implement the `AgentTool` interface from `@mariozechner/pi-agent-core`:

```typescript
interface AgentTool {
  name: string;              // Tool identifier (e.g., "exec", "browser")
  label?: string;            // Display name
  description?: string;      // What the tool does
  parameters: JSONSchema;    // TypeBox schema for parameters
  execute: (
    toolCallId: string,
    params: Record<string, unknown>,
    signal?: AbortSignal,
    onUpdate?: AgentToolUpdateCallback
  ) => Promise<AgentToolResult<unknown>>;
}
```

### Tool Result Format

```typescript
type AgentToolResult = {
  content: Array<{
    type: "text" | "image";
    text?: string;
    data?: string;  // Base64 for images
  }>;
  details?: Record<string, unknown>;  // Metadata
};
```

### Tool Registration Flow

**Step 1: Factory Creation**
```typescript
// src/agents/openclaw-tools.ts
export function createOpenClawTools(options?: {
  browserControlUrl?: string;
  agentSessionKey?: string;
  sandboxRoot?: string;
  // ... 50+ configuration options
}): AnyAgentTool[] {
  const tools: AnyAgentTool[] = [
    createBrowserTool({ browserControlUrl }),
    createCanvasTool(),
    createNodesTool({ nodePermissions }),
    createCronTool({ cronScheduler }),
    createMessageTool({ channels }),
    createGatewayTool({ gatewayClient }),
    createSessionsListTool(),
    createSessionsSendTool(),
    createSessionsSpawnTool(),
    // ... more tools
  ];
  
  // Add plugin tools
  const pluginTools = resolvePluginTools({
    context: { config, workspaceDir, agentDir },
    existingToolNames: new Set(tools.map(t => t.name)),
    toolAllowlist: options?.pluginToolAllowlist,
  });
  
  return [...tools, ...pluginTools];
}
```

**Step 2: Tool Definition Adaptation**
```typescript
// src/agents/pi-tool-definition-adapter.ts
export function toToolDefinitions(tools: AnyAgentTool[]): ToolDefinition[] {
  return tools.map((tool) => ({
    name: tool.name,
    label: tool.label ?? tool.name,
    description: tool.description ?? "",
    parameters: tool.parameters,
    execute: async (toolCallId, params, onUpdate, _ctx, signal) => {
      try {
        return await tool.execute(toolCallId, params, signal, onUpdate);
      } catch (err) {
        return jsonResult({
          status: "error",
          tool: tool.name,
          error: err.message,
        });
      }
    },
  }));
}
```

**Step 3: Schema Normalization**
```typescript
// src/agents/pi-tools.schema.ts
export function normalizeToolParameters(tool: AnyAgentTool): AnyAgentTool {
  // Provider-specific schema adaptations:
  // - Gemini: Remove unsupported JSON Schema keywords
  // - OpenAI: Ensure top-level type: "object"
  // - Flatten union schemas (anyOf/oneOf) into single object
  
  const schema = tool.parameters;
  
  if ("type" in schema && "properties" in schema) {
    return { ...tool, parameters: cleanSchemaForGemini(schema) };
  }
  
  // Handle union types by merging properties
  const variants = schema.anyOf ?? schema.oneOf;
  const mergedProperties = {};
  for (const variant of variants) {
    Object.assign(mergedProperties, variant.properties);
  }
  
  return {
    ...tool,
    parameters: {
      type: "object",
      properties: mergedProperties,
      required: [...allRequiredFields],
    },
  };
}
```

---

## Tool Categories

### 1. Execution Tools (Runtime/Bash)

**Exec Tool** - Run shell commands with approval/allowlist
```typescript
// src/agents/bash-tools.exec.ts
export function createExecTool(defaults?: ExecToolDefaults): AnyAgentTool {
  return {
    name: "exec",
    description: "Run shell commands (supports background, PTY, elevated)",
    parameters: Type.Object({
      command: Type.String({ description: "Shell command to execute" }),
      workdir: Type.Optional(Type.String()),
      env: Type.Optional(Type.Record(Type.String(), Type.String())),
      yieldMs: Type.Optional(Type.Number()),  // Background after N ms
      background: Type.Optional(Type.Boolean()),
      timeout: Type.Optional(Type.Number()),
      pty: Type.Optional(Type.Boolean()),  // Use pseudo-TTY
      elevated: Type.Optional(Type.Boolean()),  // Run on host with permissions
      host: Type.Optional(Type.String()),  // sandbox|gateway|node
      security: Type.Optional(Type.String()),  // deny|allowlist|full
      ask: Type.Optional(Type.String()),  // off|on-miss|always
    }),
    execute: async (toolCallId, params) => {
      // See Execution Flow section
    },
  };
}
```

**Process Tool** - Manage running processes
```typescript
// Actions: list, poll, kill, write stdin
createProcessTool({
  activeSessions: Map<string, ProcessSession>,
  maxBackgroundSessions: 10,
});
```

### 2. Browser/UI Tools

**Browser Tool** - Browser automation (28KB implementation)
```typescript
// Actions: start, stop, open_tab, close_tab, navigate, screenshot,
//          act (click/type/scroll), pdf_save, console_messages
createBrowserTool({
  defaultControlUrl: "http://127.0.0.1:18791",
  allowHostControl: true,
  allowedControlUrls: ["http://127.0.0.1:18791"],
});
```

**Canvas Tool** - Control node canvases (UI rendering)
```typescript
// Actions: present, hide, navigate, eval, snapshot, a2ui_push, a2ui_reset
createCanvasTool();

// Example: Snapshot
{
  action: "snapshot",
  outputFormat: "png",
  maxWidth: 1920,
  quality: 90,
}
```

### 3. Session Management Tools

```typescript
createSessionsListTool()      // List active sessions
createSessionsHistoryTool()   // Get session history
createSessionsSendTool()      // Send messages to sessions
createSessionsSpawnTool()     // Create sub-agent sessions
createSessionStatusTool()     // Get session status
```

### 4. Communication Tools

```typescript
createMessageTool()           // Send to channels (Slack, Discord, etc.)
createTtsTool()              // Text-to-speech
```

### 5. Information Tools

```typescript
createWebSearchTool()         // Web search (Brave API)
createWebFetchTool()          // Fetch web content
createImageTool()             // Image processing
createNodesTool()             // List/manage nodes
createAgentsListTool()        // List available agents
```

### 6. Automation Tools

```typescript
createCronTool()              // Schedule tasks
createGatewayTool()           // Gateway communication
```

### Tool Groups (Policy)

```typescript
// src/agents/tool-policy.ts
export const TOOL_GROUPS: Record<string, string[]> = {
  "group:memory": ["memory_search", "memory_get"],
  "group:web": ["web_search", "web_fetch"],
  "group:fs": ["read", "write", "edit", "apply_patch"],
  "group:runtime": ["exec", "process"],
  "group:sessions": ["sessions_list", "sessions_history", "sessions_send", 
                     "sessions_spawn", "session_status"],
  "group:ui": ["browser", "canvas"],
  "group:automation": ["cron", "gateway"],
  "group:messaging": ["message"],
  "group:nodes": ["nodes"],
  "group:openclaw": [/* all native tools */],
};

// Tool profiles for different use cases
const TOOL_PROFILES: Record<ToolProfileId, ToolProfilePolicy> = {
  minimal: { allow: ["session_status"] },
  coding: { allow: ["group:fs", "group:runtime", "group:sessions", "group:memory", "image"] },
  messaging: { allow: ["group:messaging", "sessions_list", "sessions_history"] },
  full: {},  // No restrictions
};
```

---

## Tool Discovery

### Discovery Mechanism

**Core Tools** - Hardcoded in factory function:
```typescript
// src/agents/openclaw-tools.ts
// All core tools are directly instantiated - no dynamic discovery
const tools = [
  createExecTool(),
  createBrowserTool(),
  createCanvasTool(),
  // ... explicit tool list
];
```

**Plugin Tools** - Discovered from plugin registry:
```typescript
// src/plugins/tools.ts
export function resolvePluginTools(params: {
  context: OpenClawPluginToolContext;
  existingToolNames?: Set<string>;
  toolAllowlist?: string[];
}): AnyAgentTool[] {
  // 1. Load plugin registry
  const registry = loadOpenClawPlugins({
    config: params.context.config,
    workspaceDir: params.context.workspaceDir,
  });

  // 2. Filter by allowlist
  const allowlist = normalizeAllowlist(params.toolAllowlist);
  
  // 3. Instantiate plugin tools
  for (const entry of registry.tools) {
    // Check for conflicts with core tools
    if (existingNormalized.has(normalizeToolName(entry.pluginId))) {
      log.error(`Plugin id conflicts with core tool name`);
      continue;
    }
    
    // Call factory function
    const resolved = entry.factory(params.context);
    
    // Filter optional tools by allowlist
    if (entry.optional) {
      const filtered = resolved.filter(tool =>
        isOptionalToolAllowed({
          toolName: tool.name,
          pluginId: entry.pluginId,
          allowlist,
        })
      );
      tools.push(...filtered);
    } else {
      tools.push(...resolved);
    }
  }
  
  return tools;
}
```

---

## Tool Execution Flow

### Complete Pipeline: Request → Execution → Result

**Phase 1: Tool Call Initiation**
```
Agent → Tool Call Request
  ├─ toolCallId: unique identifier
  ├─ toolName: "exec", "browser", etc.
  └─ params: { command: "...", ... }
```

**Phase 2: Tool Lookup & Validation**
```typescript
const tool = tools.find(t => t.name === toolName);
if (!tool) throw new Error(`Tool not found: ${toolName}`);

// Validate parameters against schema
// TypeBox validates params against tool.parameters
```

**Phase 3: Execution (Exec Tool Example)**
```typescript
// src/agents/bash-tools.exec.ts
execute: async (toolCallId, params, signal, onUpdate) => {
  // 1. PARSE PARAMETERS
  const command = readStringParam(params, "command", { required: true });
  const workdir = params.workdir?.trim() || defaults?.cwd || process.cwd();
  const timeout = params.timeout ?? defaults?.timeoutSec ?? 30;
  
  // 2. SECURITY CHECKS
  const host = normalizeExecHost(params.host) ?? defaults?.host ?? "sandbox";
  const security = normalizeExecSecurity(params.security) ?? defaults?.security;
  const ask = normalizeExecAsk(params.ask) ?? defaults?.ask;
  
  // 3. APPROVAL EVALUATION
  const approvals = resolveExecApprovals(agentId, { security, ask });
  const allowlistEval = evaluateShellAllowlist({
    command,
    allowlist: approvals.allowlist,
    safeBins: new Set(defaults?.safeBins ?? []),
    cwd: workdir,
  });
  
  if (requiresExecApproval({ ask, security, analysisOk, allowlistSatisfied })) {
    // Request approval from gateway
    return {
      content: [{ type: "text", text: `Approval required (id ${approvalSlug})...` }],
      details: {
        status: "approval-pending",
        approvalId,
        expiresAtMs,
        command,
      },
    };
  }
  
  // 4. PROCESS EXECUTION
  const run = await runExecProcess({
    command,
    workdir,
    env: mergedEnv,
    sandbox: host === "sandbox" ? defaults?.sandbox : undefined,
    usePty: params.pty === true,
    timeoutSec: timeout,
    onUpdate,  // Stream updates during execution
  });
  
  // 5. RESULT HANDLING
  return new Promise((resolve, reject) => {
    // Handle backgrounding (yield after yieldMs)
    if (allowBackground && yieldWindow !== null) {
      yieldTimer = setTimeout(() => {
        markBackgrounded(run.session);
        resolve({
          content: [{ type: "text", text: `Command still running...` }],
          details: { status: "running", sessionId: run.session.id },
        });
      }, yieldWindow);
    }
    
    // Wait for completion
    run.promise.then((outcome) => {
      if (outcome.status === "failed") {
        reject(new Error(outcome.reason ?? "Command failed."));
      } else {
        resolve({
          content: [{ type: "text", text: outcome.aggregated || "(no output)" }],
          details: {
            status: "completed",
            exitCode: outcome.exitCode ?? 0,
            durationMs: outcome.durationMs,
          },
        });
      }
    });
  });
}
```

**Phase 4: Result Sanitization**
```typescript
// src/agents/pi-embedded-subscribe.tools.ts
export function sanitizeToolResult(result: unknown): unknown {
  const content = Array.isArray(record.content) ? record.content : null;
  
  const sanitized = content.map((item) => {
    if (item.type === "text" && typeof item.text === "string") {
      // Truncate text to 8000 chars
      return { ...item, text: truncateToolText(item.text) };
    }
    if (item.type === "image") {
      // Remove image data, keep metadata
      const cleaned = { ...item };
      delete cleaned.data;
      return { ...cleaned, bytes: data.length, omitted: true };
    }
    return item;
  });
  
  return { ...record, content: sanitized };
}
```

---

## Security System

### 1. Execution Approval Architecture

```typescript
// ~/.openclaw/exec-approvals.json
{
  "version": 1,
  "socket": { "path": "...", "token": "..." },
  "defaults": {
    "security": "deny",  // deny | allowlist | full
    "ask": "on-miss",    // off | on-miss | always
    "askFallback": "deny",
    "autoAllowSkills": true
  },
  "agents": {
    "default": {
      "security": "allowlist",
      "allowlist": [
        {
          "id": "uuid",
          "pattern": "/usr/bin/python*",
          "lastUsedAt": 1703000000000,
          "lastUsedCommand": "python script.py",
          "lastResolvedPath": "/usr/bin/python3"
        },
        {
          "pattern": "npm",
          "lastUsedAt": 1703000000000
        }
      ]
    }
  }
}
```

### 2. Security Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| **deny** | Block all execution | Maximum security |
| **allowlist** | Only allow commands matching patterns | Recommended default |
| **full** | Allow all commands | Development/trusted contexts |

### 3. Ask Modes

| Mode | Description | When Approval Requested |
|------|-------------|------------------------|
| **off** | Never ask | Never |
| **on-miss** | Ask if not in allowlist | When allowlist doesn't match |
| **always** | Always ask | Every execution |

### 4. Allowlist Evaluation

```typescript
// src/infra/exec-approvals.ts
export function evaluateShellAllowlist(params: {
  command: string;
  allowlist: ExecAllowlistEntry[];
  safeBins: Set<string>;
  cwd?: string;
  env?: NodeJS.ProcessEnv;
  skillBins?: Set<string>;
  autoAllowSkills?: boolean;
}): ExecAllowlistAnalysis {
  // 1. Parse command chain (&&, ||, ;)
  const chainParts = splitCommandChain(params.command);
  
  // 2. For each part, analyze shell command
  for (const part of chainParts) {
    const analysis = analyzeShellCommand({
      command: part,
      cwd: params.cwd,
      env: params.env,
    });
    
    // 3. Evaluate against allowlist
    const evaluation = evaluateExecAllowlist({
      analysis,
      allowlist: params.allowlist,
      safeBins: params.safeBins,
      skillBins: params.skillBins,
      autoAllowSkills: params.autoAllowSkills,
    });
    
    return {
      analysisOk: analysis.ok,
      allowlistSatisfied: evaluation.allowlistSatisfied,
      allowlistMatches: evaluation.allowlistMatches,
    };
  }
}

export function requiresExecApproval(params: {
  ask: ExecAsk;
  security: ExecSecurity;
  analysisOk: boolean;
  allowlistSatisfied: boolean;
}): boolean {
  return (
    params.ask === "always" ||
    (params.ask === "on-miss" &&
      params.security === "allowlist" &&
      (!params.analysisOk || !params.allowlistSatisfied))
  );
}
```

### 5. Approval Request Flow

```typescript
if (requiresExecApproval({ ask, security, analysisOk, allowlistSatisfied })) {
  const approvalId = crypto.randomUUID();
  const approvalSlug = approvalId.slice(0, 8);
  const expiresAtMs = Date.now() + 120_000;  // 2 minute timeout
  
  // Fire-and-forget approval request
  (async () => {
    const decisionResult = await callGatewayTool(
      "exec.approval.request",
      { timeoutMs: 130_000 },
      {
        id: approvalId,
        command: commandText,
        cwd: workdir,
        host: "gateway",
        agentId,
        sessionKey,
        timeoutMs: 120_000,
      },
    );
    
    const decision = decisionResult?.decision ?? null;
    
    // Handle decision
    if (decision === "deny") {
      emitExecSystemEvent(`Exec denied (user-denied): ${commandText}`);
      return;
    } else if (decision === "allow-once") {
      // Run command once
      await runExecProcess({ ... });
    } else if (decision === "allow-always") {
      // Add to allowlist for future use
      addAllowlistEntry(approvals.file, agentId, pattern);
      await runExecProcess({ ... });
    } else if (!decision) {
      // Timeout - use askFallback
      if (askFallback === "full") {
        await runExecProcess({ ... });
      } else {
        emitExecSystemEvent(`Exec denied (approval-timeout)`);
      }
    }
  })();
  
  return {
    content: [{ type: "text", text: `Approval required (id ${approvalSlug})...` }],
    details: {
      status: "approval-pending",
      approvalId,
      approvalSlug,
      expiresAtMs,
      command: params.command,
    },
  };
}
```

### 6. Safe Binaries

```typescript
// Always allowed (no allowlist check needed)
export const DEFAULT_SAFE_BINS = [
  "jq", "grep", "cut", "sort", "uniq", "head", "tail", "tr", "wc"
];

// Configured via tools.exec.safeBins in config
```

### 7. Elevated Execution

```typescript
export type ExecElevatedDefaults = {
  enabled: boolean;
  allowed: boolean;
  defaultLevel: "on" | "off" | "ask" | "full";
};

// Elevated execution requires:
// 1. tools.elevated.enabled = true
// 2. tools.elevated.allowFrom.<provider> configured
// 3. Sender must be in allowFrom list

if (elevatedRequested) {
  if (!elevatedEnabled) {
    throw new Error("elevated not available (tools.elevated.enabled=false)");
  }
  if (elevatedMode === "off") {
    throw new Error("elevated not allowed for this sender");
  }
  // Elevated commands bypass normal approval flow
  host = "gateway";
  security = "full";
  ask = "off";
}
```

---

## Configuration

### Tool Configuration Structure

```yaml
tools:
  profile: coding  # minimal | coding | messaging | full
  allow:
    - group:runtime
    - group:fs
    - browser
  deny:
    - gateway  # Prevent gateway restarts
  
  elevated:
    enabled: true
    allowFrom:
      whatsapp: ["+15551234567"]
      discord: ["user:123456789"]
  
  exec:
    host: sandbox  # sandbox | gateway | node
    security: allowlist  # deny | allowlist | full
    ask: on-miss  # off | on-miss | always
    safeBins: ["jq", "grep", "python", "node"]
    backgroundMs: 5000
    timeoutSec: 30
    
  sandbox:
    tools:
      allow:
        - exec
        - read
        - write
      deny:
        - browser
        - gateway
```

### Tool Policy Resolution

```
1. Start with profile (minimal/coding/messaging/full)
2. Apply global allow/deny
3. Apply provider-specific overrides
4. Apply agent-specific overrides
5. Deny wins over allow
```

---

## Key Implementation Files

| File | Purpose | Size |
|------|---------|------|
| `bash-tools.exec.ts` | Exec tool with approval/allowlist | 1496 lines |
| `bash-tools.process.ts` | Process management tool | 21KB |
| `browser-tool.ts` | Browser automation | 28KB |
| `openclaw-tools.ts` | Main tool factory | 168 lines |
| `tool-policy.ts` | Tool allowlists & profiles | 229 lines |
| `exec-approvals.ts` | Approval system & allowlists | 1200+ lines |
| `pi-tool-definition-adapter.ts` | Convert to provider format | 104 lines |
| `pi-tools.schema.ts` | Schema normalization | 154 lines |
| `plugins/tools.ts` | Plugin tool discovery | 118 lines |

---

## Best Practices

1. **Use allowlists in production** - Set `security: "allowlist"` and maintain exec-approvals.json
2. **Limit elevated access** - Only enable for specific senders via `tools.elevated.allowFrom`
3. **Configure safe bins** - Add commonly used safe commands to `tools.exec.safeBins`
4. **Use tool groups** - Simplify config with `group:runtime`, `group:fs`, etc.
5. **Test in sandbox** - Default to `host: "sandbox"` for non-main sessions
6. **Monitor approvals** - Check `~/.openclaw/exec-approvals.json` for usage patterns
7. **Use ask modes wisely** - `on-miss` balances security and usability

---

**Next:** [04_skills_system.md](./04_skills_system.md) - How skills extend agent capabilities
