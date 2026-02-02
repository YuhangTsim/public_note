# OpenClaw Deep Dive: Agent Internals

> **Research Date:** 2026-02-02  
> **Focus Areas:** Main agent loop, memory handling, tooling & policy, browser control  
> **Codebase:** https://github.com/clawdbot/clawdbot (OpenClaw rebrand)

---

## Overview

This document provides a comprehensive deep dive into the OpenClaw agent's internal architecture, covering four critical subsystems:

1. **Main Agent Loop** - Message processing, turn management, and execution flow
2. **Memory Handling** - Session storage, semantic memory, and retrieval
3. **Tooling & Policy** - Tool registration, execution, and security enforcement
4. **Browser Control** - Playwright integration and browser automation

---

## 1. Main Agent Loop Architecture

### 1.1 Entry Point: `runEmbeddedPiAgent()`

**File:** `/src/agents/pi-embedded-runner/run.ts` (lines 70-679)

The main orchestrator manages the complete agent lifecycle with sophisticated retry logic:

```typescript
runEmbeddedPiAgent(params)
  ├─ Resolve session lane (concurrency control)
  ├─ Enqueue in global + session lanes
  └─ RETRY LOOP (while true) at line 297
      ├─ Attempt single turn via runEmbeddedAttempt()
      ├─ Handle errors with fallback logic
      ├─ Rotate auth profiles on failure
      ├─ Retry with different thinking levels
      └─ Return final result or throw FailoverError
```

**Key Features:**
- **Infinite retry loop** with intelligent fallback strategies
- **Auth profile rotation** on rate limits/auth failures
- **Thinking level fallback** (deep → extended → off)
- **Context overflow handling** with auto-compaction
- **Concurrency control** via session lanes

### 1.2 Single Turn Execution: `runEmbeddedAttempt()`

**File:** `/src/agents/pi-embedded-runner/run/attempt.ts` (lines 133-884)

Executes one complete agent turn with 5 distinct phases:

#### Phase 1: Initialization (lines 136-420)
```
Setup:
  ├─ Create AbortController for timeout/cancellation
  ├─ Resolve workspace and sandbox context
  ├─ Load skills and bootstrap files
  ├─ Create coding tools (bash, web, file operations)
  ├─ Build system prompt with context
  ├─ Open SessionManager (persistent conversation state)
  ├─ Create SettingsManager for compaction settings
  └─ Initialize Agent session with tools
```

#### Phase 2: Message Preparation (lines 517-793)
```
Prepare Messages:
  ├─ Sanitize session history (remove synthetic tool results)
  ├─ Validate Gemini/Anthropic turn ordering
  ├─ Limit history to DM-specific limits
  ├─ Detect and load images from prompt/history
  ├─ Inject history images into original positions
  ├─ Apply cache-TTL timestamp if configured
  └─ Ready for prompt submission
```

#### Phase 3: Prompt Submission & Internal Turn Loop (lines 683-792)
```
Submit Prompt:
  ├─ Run before_agent_start hooks
  ├─ Repair orphaned trailing user messages
  ├─ Call activeSession.prompt(effectivePrompt, { images })
  │   └─ INTERNAL TURN LOOP (pi-ai library)
  │       ├─ Stream LLM response (message_start → update* → end)
  │       ├─ Parse tool calls from response
  │       ├─ Execute tools (tool_execution_start → update* → end)
  │       ├─ Add tool results to session
  │       ├─ Continue if more tool calls needed
  │       └─ Stop when LLM says "done" or max turns reached
  └─ Run agent_end hooks
```

**Critical:** The `activeSession.prompt()` call is where the **internal turn loop** happens, managed by the `@mariozechner/pi-ai` library.

#### Phase 4: Event Subscription & Streaming (lines 597-615)
```
subscribeEmbeddedPiSession(params):
  ├─ Listen for message_start/update/end events
  ├─ Listen for tool_execution_start/update/end events
  ├─ Accumulate assistant texts
  ├─ Track tool metadata
  ├─ Emit streaming callbacks (onPartialReply, onBlockReply, onToolResult)
  └─ Return subscription with unsubscribe function
```

#### Phase 5: Result Building (lines 854-873)
```
Return Result:
  ├─ Extract last assistant message
  ├─ Normalize tool metadata
  ├─ Build payloads from assistant texts + tool results
  ├─ Return EmbeddedRunAttemptResult with:
  │   ├─ aborted, timedOut flags
  │   ├─ promptError (any LLM error)
  │   ├─ messagesSnapshot (final conversation state)
  │   ├─ assistantTexts, toolMetas
  │   └─ systemPromptReport (debugging info)
  └─ Dispose session and release lock
```

### 1.3 Turn Management & State

**SessionManager** (from `@mariozechner/pi-coding-agent`) maintains:
- **messages**: AgentMessage[] (conversation history)
- **branches**: Alternative conversation paths
- **leaf**: Current position in conversation tree
- **compaction**: Compressed message summaries
- **metadata**: Session ID, timestamps

**Message Processing Flow:**
```
User Input
  ↓
[runEmbeddedPiAgent] - Retry loop orchestrator
  ↓
[runEmbeddedAttempt] - Single attempt
  ├─ Load session history
  ├─ Validate message ordering
  ├─ Call activeSession.prompt(userMessage)
  │   ↓
  │   [Internal pi-ai turn loop]
  │   ├─ Stream LLM response
  │   ├─ Parse tool calls → Execute tools → Add results
  │   └─ Repeat until done
  │
  ├─ Collect streamed events
  └─ Build response payloads
  ↓
[Return to caller]
```

### 1.4 Loop Termination

The loop terminates when:
1. **LLM stops calling tools** - No tool_use blocks in response
2. **Max turns reached** - Prevents infinite loops
3. **Timeout** - AbortController fires after `timeoutMs`
4. **User abort** - External abort signal received

### 1.5 Error Handling & Fallbacks

**In runEmbeddedAttempt (single attempt):**
- Context overflow → Auto-compact and retry
- Role ordering error → Remove orphaned message and retry
- Image size error → Return user-friendly error
- Auth/rate-limit → Throw FailoverError for profile rotation

**In runEmbeddedPiAgent (main loop):**
```
Retry Logic (while true):
  ├─ Context overflow + not yet attempted → Auto-compact and retry
  ├─ Auth/rate-limit failure → Rotate to next auth profile
  ├─ Thinking level unsupported → Downgrade thinking level
  ├─ All fallbacks exhausted → Throw FailoverError
  └─ Success → Return result
```

### 1.6 Key Files

| File | Purpose | Key Functions |
|------|---------|---------------|
| `run.ts` | Main orchestrator | `runEmbeddedPiAgent()` - retry loop |
| `run/attempt.ts` | Single turn execution | `runEmbeddedAttempt()` - session setup, streaming |
| `pi-embedded-subscribe.ts` | Event subscription | `subscribeEmbeddedPiSession()` - streaming events |
| `pi-embedded-subscribe.handlers.ts` | Event routing | Message/tool event dispatch |
| `auto-reply/reply/agent-runner.ts` | High-level orchestration | Block streaming, followups |

---

## 2. Memory Handling Architecture

### 2.1 Storage Mechanisms

**Dual Storage System:**

1. **Session Transcripts** (Conversation History)
   - **Format:** JSONL (JSON Lines) - one JSON object per line
   - **Location:** `~/.clawdbot/agents/{agentId}/sessions/`
   - **Naming:** `{sessionId}.jsonl` or `{sessionId}-topic-{topicId}.jsonl`
   - **Metadata:** `sessions.json` registry mapping sessionKey → SessionEntry

2. **Semantic Memory** (Knowledge Base)
   - **Format:** SQLite database with vector embeddings
   - **Location:** `~/.clawdbot/memory/{agentId}.sqlite`
   - **Supports:** Full-text search (FTS5) + vector similarity (sqlite-vec)

### 2.2 SQLite Schema

**File:** `/src/memory/memory-schema.ts`

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `meta` | Index metadata | key, value (JSON) |
| `files` | File registry | path, source (memory\|sessions), hash, mtime, size |
| `chunks` | Text chunks | id, path, source, start_line, end_line, text, embedding |
| `chunks_vec` | Vector embeddings | id, embedding (vector), source |
| `chunks_fts` | Full-text search | text, id, path, source, model |
| `embedding_cache` | Embedding cache | provider, model, hash, embedding, dims |

**Meta Table Storage:**
```json
{
  "memory_index_meta_v1": {
    "model": "text-embedding-3-small",
    "provider": "openai",
    "chunkTokens": 400,
    "chunkOverlap": 80,
    "vectorDims": 1536
  }
}
```

### 2.3 Session File Structure (JSONL)

Each line in a session transcript:
```json
{
  "type": "session|message",
  "version": "...",
  "id": "sessionId",
  "timestamp": "2026-02-02T14:30:00.000Z",
  "message": {
    "role": "user|assistant",
    "content": [{ "type": "text", "text": "..." }]
  }
}
```

### 2.4 Session Lifecycle

**Creation:**
1. Session initiated via agent
2. `resolveSessionTranscriptPath()` generates path
3. `ensureSessionHeader()` writes JSONL header
4. Entry added to `sessions.json` registry

**Updates:**
1. Messages appended via `SessionManager.appendMessage()`
2. `emitSessionTranscriptUpdate()` triggers sync listeners
3. Delta tracking monitors file size and message count
4. Dirty files tracked for incremental indexing

**Retrieval:**
1. `listSessionFilesForAgent()` discovers `.jsonl` files
2. `buildSessionEntry()` parses JSONL and extracts messages
3. Text normalized: whitespace collapsed, newlines removed
4. Content hashed for change detection

**Cleanup:**
- Stale sessions detected by comparing active paths vs DB records
- Cascade deletion removes files, chunks, vectors, FTS entries

### 2.5 Memory Retrieval: Hybrid Search

**File:** `/src/memory/manager-search.ts`

**Search Strategy:**
```
query → embedQueryWithTimeout()
  ├─ Vector Search: Cosine similarity in chunks_vec
  ├─ Keyword Search: BM25 ranking in chunks_fts
  └─ Merge results with weighted scoring
```

**Default Configuration:**
```typescript
query: {
  maxResults: 6,
  minScore: 0.35,
  hybrid: {
    enabled: true,
    vectorWeight: 0.7,      // 70% vector similarity
    textWeight: 0.3,        // 30% keyword match
    candidateMultiplier: 4  // Fetch 4x before merging
  }
}
```

### 2.6 Sync Triggers

**File:** `/src/memory/manager.ts`

| Trigger | Condition | Config Key |
|---------|-----------|------------|
| **On Session Start** | Before first message | `sync.onSessionStart: true` |
| **On Search** | Before search query | `sync.onSearch: true` |
| **File Watch** | File changed in memory/ | `sync.watch: true` |
| **Interval** | Every N minutes | `sync.intervalMinutes: 60` |
| **Session Delta** | 100KB or 50 messages | `sync.sessions.deltaBytes/deltaMessages` |

**Sync Process:**
1. Check if full reindex needed (model/provider/config changes)
2. If yes: `runSafeReindex()` - atomic temp DB swap
3. Otherwise: incremental sync
   - `syncMemoryFiles()` - new/changed memory files
   - `syncSessionFiles()` - new/changed session transcripts
4. Cleanup stale entries (deleted files)
5. Progress reporting via callback

### 2.7 Embedding Providers

**Supported Providers:**
- **OpenAI:** `text-embedding-3-small` (default), batch API
- **Gemini:** `gemini-embedding-001`, batch API
- **Local:** LLaMA-based via node-llama
- **Auto:** Automatic fallback if primary fails

**Batch Processing:**
- Default: 8000 tokens per batch
- Async job submission with polling
- Retry logic with exponential backoff (max 3 attempts)
- Timeout: 60s remote, 5min local

### 2.8 Semantic Memory vs Transcripts

| Aspect | Semantic Memory | Transcripts |
|--------|-----------------|-------------|
| **Location** | `memory/*.md` or `MEMORY.md` | `sessions/{sessionId}.jsonl` |
| **Purpose** | User-curated knowledge base | Auto-generated conversation history |
| **Persistence** | Across all sessions | Per-session |
| **Management** | User-managed markdown | Agent-managed JSONL |
| **Indexing** | Chunked with embeddings | Parsed messages with embeddings |
| **Source Tag** | `source='memory'` | `source='sessions'` |

### 2.9 Key Files

| File | Purpose |
|------|---------|
| `/src/memory/manager.ts` | Core memory index manager |
| `/src/memory/memory-schema.ts` | SQLite schema definition |
| `/src/memory/session-files.ts` | Session transcript discovery |
| `/src/memory/sync-session-files.ts` | Session file synchronization |
| `/src/memory/manager-search.ts` | Vector + keyword search |
| `/src/memory/embeddings.ts` | Embedding provider abstraction |
| `/src/config/sessions/transcript.ts` | Session transcript append |

---

## 3. Tooling & Policy System

### 3.1 Tool Registration & Discovery

**Core Tools:** Registered in `createMoltbotTools()` (moltbot-tools.ts)
- exec, process, browser, sessions, memory, web, message, cron, gateway, nodes, image

**Plugin Tools:** Loaded via `resolvePluginTools()` with optional allowlisting

**Tool Groups:** Defined in `TOOL_GROUPS` (tool-policy.ts)
- `group:memory` → memory_search, memory_get
- `group:web` → web_search, web_fetch
- `group:fs` → read, write, edit, apply_patch
- `group:runtime` → exec, process
- `group:sessions` → session management
- `group:ui` → browser, canvas
- `group:automation` → cron, gateway
- `group:messaging` → message
- `group:moltbot` → all native tools (excludes plugins)

### 3.2 Tool Execution Pipeline

**File:** `/src/gateway/tools-invoke-http.ts`

```
HTTP POST /tools/invoke
  ↓
[1] Authorization Check (bearer token)
  ↓
[2] Policy Resolution (6 layers)
  ├─ Tool Profile (minimal/coding/messaging/full)
  ├─ Provider-specific policy (byProvider)
  ├─ Global policy (tools.allow/deny)
  ├─ Agent policy (agents.{id}.tools.allow/deny)
  ├─ Group policy (channel-specific for groups)
  └─ Subagent policy (restricted tool set)
  ↓
[3] Tool Filtering (deny wins)
  ├─ Apply profile allowlist
  ├─ Apply provider profile
  ├─ Apply global, agent, group, subagent policies
  └─ Sequential deny-wins evaluation
  ↓
[4] Tool Lookup (case-insensitive)
  ↓
[5] Tool Execution
  └─ Call tool.execute(toolCallId, args)
  ↓
[6] Result Return (JSON)
```

### 3.3 Exec Tool Security Pipeline

**File:** `/src/agents/bash-tools.exec.ts`

```
tool.execute("exec", {command, cwd, ...})
  ↓
[1] Resolve Exec Defaults
  ├─ host: sandbox|gateway|node
  ├─ security: deny|allowlist|full
  ├─ ask: off|on-miss|always
  └─ node: node id for host=node
  ↓
[2] Command Analysis
  ├─ Parse shell (pipes, chains &&||;)
  ├─ Tokenize segments
  ├─ Resolve executable paths
  └─ Build command segments
  ↓
[3] Allowlist Evaluation
  ├─ Check against allowlist patterns
  ├─ Check safe bins (jq, grep, cut, sort, etc.)
  ├─ Check auto-allow skills
  └─ Return: allowlistSatisfied boolean
  ↓
[4] Approval Decision
  ├─ ask=always → require approval
  ├─ ask=on-miss && !allowlistSatisfied → require approval
  ├─ security=deny → deny execution
  ├─ security=full → allow execution
  └─ security=allowlist && allowlistSatisfied → allow
  ↓
[5] If Approval Required
  ├─ Create approval request (id, command, context)
  ├─ Wait for decision (timeout: 120s)
  ├─ Forward to chat if configured
  └─ Return: allow-once|allow-always|deny
  ↓
[6] Execute Command
  ├─ host=sandbox → Docker container
  ├─ host=gateway → Local process
  └─ host=node → Remote node via gateway
```

### 3.4 Security Policies

**Policy Types:**

1. **Tool Allowlist/Denylist**
   - `allow`: Explicit allowed tools (expanded with groups)
   - `deny`: Explicit denied tools (deny wins)
   - `alsoAllow`: Additive allowlist (merged with profile)
   - Supports wildcards: `exec*`, `*_tool`, `*`

2. **Tool Profiles** (tool-policy.ts)
   ```typescript
   minimal: [session_status]
   coding: [group:fs, group:runtime, group:sessions, group:memory, image]
   messaging: [group:messaging, sessions_list, sessions_history, sessions_send]
   full: {} // all tools allowed
   ```

3. **Exec Security Modes**
   - `deny`: Block all exec commands
   - `allowlist`: Allow only allowlisted commands
   - `full`: Allow all commands without approval

4. **Exec Ask Modes**
   - `off`: Never ask for approval
   - `on-miss`: Ask only if not in allowlist
   - `always`: Always ask for approval

5. **Exec Host Routing**
   - `sandbox`: Docker container (isolated)
   - `gateway`: Local process (host machine)
   - `node`: Remote node via gateway

### 3.5 Policy Hierarchy (Deny Wins)

```
Tool Profile
  ↓ (filtered by)
Provider Profile (byProvider)
  ↓ (filtered by)
Global Policy (tools.allow/deny)
  ↓ (filtered by)
Agent Policy (agents.{id}.tools.allow/deny)
  ↓ (filtered by)
Group Policy (channel-specific)
  ↓ (filtered by)
Subagent Policy (restricted for spawned agents)
```

**Subagent Default Denies:**
- sessions_list, sessions_history, sessions_send, sessions_spawn
- gateway, agents_list
- whatsapp_login, session_status, cron
- memory_search, memory_get

### 3.6 Approval System

**File:** `/src/gateway/exec-approval-manager.ts`

**Approval Request Flow:**
```
Exec Tool Determines Approval Needed
  ↓
Create ExecApprovalRecord
  ├─ id: UUID
  ├─ request: {command, cwd, host, security, ask}
  ├─ createdAtMs, expiresAtMs (120s timeout)
  └─ Store in pending map
  ↓
Forward to Chat (if configured)
  ├─ Resolve session from sessionKey
  ├─ Send approval request message
  └─ Wait for user response
  ↓
User Responds: /approve <id> allow-once|allow-always|deny
  ↓
ExecApprovalManager.resolve(id, decision)
  ├─ Update record
  ├─ Clear timeout
  └─ Resolve promise
  ↓
Exec Tool Receives Decision
  ├─ allow-once → execute, don't record
  ├─ allow-always → execute, add to allowlist
  └─ deny → reject execution
```

**Approval Storage:**
- **In-Memory:** ExecApprovalManager (pending approvals)
- **Persistent:** `~/.clawdbot/exec-approvals.json`

**Approval Forwarding Configuration:**
```typescript
approvals: {
  exec: {
    enabled: true,
    mode: "both",              // session|targets|both
    agentFilter: ["main"],     // Only forward for specific agents
    targets: [{
      channel: "discord",
      to: "123456",
      accountId: "account-id"
    }]
  }
}
```

### 3.7 Allowlist Evaluation

**File:** `/src/infra/exec-approvals.ts`

**Command Analysis:**
- Splits by chain operators: `&&`, `||`, `;`
- Splits by pipes: `|`
- Tokenizes each segment
- Resolves executable paths (PATH lookup)
- Handles quoted arguments

**Allowlist Matching:**
```
Pattern Types:
  - Exact: /usr/bin/uname
  - Glob: ~/Projects/**/bin/rg
  - Wildcard: /usr/bin/*

Matching Logic:
  1. Expand home (~) and relative paths
  2. Resolve symlinks (Windows only)
  3. Normalize paths (lowercase, forward slashes)
  4. Compile glob to regex
  5. Test resolved path against pattern
```

**Safe Bins** (no allowlist needed):
- jq, grep, cut, sort, uniq, head, tail, tr, wc
- Configurable via `tools.exec.safeBins`

### 3.8 Sandbox Isolation

**Sandbox Modes:**
- `off`: No sandboxing (direct host execution)
- `all`: Full Docker sandboxing
- `partial`: Limited sandboxing

**Docker Execution:**
- Container: `clawdbot-{agentId}-{sessionId}`
- Workspace mounted at `/workspace`
- Environment variables passed via `-e`
- Working directory set via `-w`

**Workspace Access:**
- `rw`: Read-write access
- `ro`: Read-only access
- `none`: No workspace access

### 3.9 Key Files

| File | Purpose |
|------|---------|
| `/src/infra/exec-approvals.ts` | Approval system types and logic |
| `/src/gateway/exec-approval-manager.ts` | In-memory approval tracking |
| `/src/agents/bash-tools.exec.ts` | Exec tool with approval checking |
| `/src/agents/tool-policy.ts` | Tool categorization and profiles |
| `/src/agents/pi-tools.policy.ts` | Policy resolution |
| `/src/gateway/tools-invoke-http.ts` | HTTP endpoint with filtering |

---

## 4. Browser Control Architecture

### 4.1 Browser Automation Library

**Playwright (playwright-core)** is the primary automation library:
- Lightweight CDP-based control
- Supports local Chrome + remote CDP endpoints
- AI-friendly snapshots via `_snapshotForAI`
- High-level interaction APIs (click, type, hover, drag, select, fill)

### 4.2 Browser Session Management

**Profile Management:**
- Multiple profiles supported (default: "clawd" for isolated, "chrome" for extension)
- Each profile has `ProfileRuntimeState` tracking:
  - `profile`: Config (name, CDP port, URL, color, driver type)
  - `running`: Active Chrome process (PID, executable, user data dir, CDP port)
  - `lastTargetId`: Sticky tab selection for snapshot+act workflows

**Browser Startup:**
- Resolves Chrome executable for platform (Windows/Mac/Linux)
- Spawns Chrome with user data directory
- Monitors process lifecycle and CDP port availability
- Supports local launch and remote CDP attachment

**Connection Pooling:**
**File:** `/src/browser/pw-session.ts`
- **Persistent connection:** Single cached browser connection per CDP URL
- **Retry logic:** 3 attempts with exponential backoff (5s, 7s, 9s)
- **Auto-reconnection:** Detects disconnection, clears cache
- **Page state tracking:** WeakMap-based state for each page:
  - Console messages (max 500)
  - Page errors (max 200)
  - Network requests (max 500)
  - Role refs cache (max 50 entries)

### 4.3 Browser Tools & Capabilities

**Available Commands:**

**Session Management:**
- `status`, `start`, `stop`, `profiles`, `reset`

**Tab Management:**
- `tabs`, `open`, `focus`, `close`

**Page Interaction:**
- `snapshot` - ARIA or AI format page capture
- `screenshot` - Visual screenshot
- `navigate` - Navigate to URL
- `act` - Execute actions (click, type, press, hover, drag, select, fill, wait, evaluate)

**State Management:**
- `cookies`, `storage`, `offline`, `headers`, `geolocation`, `device`, `timezone`, `locale`

**Observation:**
- `console`, `errors`, `requests`, `trace`, `highlight`

**Act Commands (Interaction Primitives):**
```typescript
type ActKind = 
  | "click" | "type" | "press" | "hover" | "scrollIntoView"
  | "drag" | "select" | "fill" | "resize" | "wait" | "evaluate" | "close"
```

Each action supports:
- `ref`: Element reference from snapshot (e.g., "e12")
- `targetId`: Tab identifier
- `timeoutMs`: Action timeout (500-60000ms)
- Action-specific parameters (text, button, modifiers)

### 4.4 Routing Mechanism

**HTTP Server:**
**File:** `/src/browser/server.ts`
- Express-based HTTP server on `127.0.0.1:18791`
- Regex-based path matching with parameter extraction
- Profile-aware: all routes support `?profile=<name>`

**Route Structure:**
```
GET  /                    → Status
POST /start               → Start browser
POST /stop                → Stop browser
GET  /profiles            → List profiles
GET  /tabs                → List tabs
POST /tabs/open           → Open tab
POST /tabs/focus          → Focus tab
DELETE /tabs/:targetId    → Close tab
POST /navigate            → Navigate
POST /screenshot          → Screenshot
POST /pdf                 → Save PDF
POST /act                 → Execute action
POST /cookies             → Cookie operations
POST /storage             → Storage operations
POST /console             → Get console messages
POST /errors              → Get page errors
POST /requests            → Get network requests
```

**Node Proxy Routing:**
**File:** `/src/agents/tools/browser-tool.ts`

Browser commands can route to remote nodes:
1. **Auto-detection:** Checks for connected browser-capable nodes
2. **Manual routing:** `node=<id|name>` parameter
3. **Policy-based:** `gateway.nodes.browser.mode` (auto/manual/off)
4. **Proxy delegation:** Calls `node.invoke` with `browser.proxy` command

### 4.5 Browser State Persistence

**Page State Tracking:**
Each page maintains:
- **Console Messages:** Type, text, timestamp, location (URL, line, column)
- **Page Errors:** Message, name, stack, timestamp
- **Network Requests:** ID, method, URL, resource type, status, failure text
- **Role Refs:** Element references from last snapshot (e.g., e1, e2, e3)

**Role Refs Cache:**
- **Purpose:** Stable element references across requests
- **Storage:** `roleRefsByTarget` Map keyed by `${cdpUrl}::${targetId}`
- **Modes:**
  - `"role"`: Role+name-based refs (default, less stable)
  - `"aria"`: Playwright aria-ref IDs (more stable)
- **Lifecycle:** Restored when page reconnects

### 4.6 Integration with Main Agent Loop

**Tool Registration:**
```typescript
createBrowserTool(opts?: {
  sandboxBridgeUrl?: string;
  allowHostControl?: boolean;
}): AnyAgentTool
```

**Agent Tool Execution Flow:**
```
1. Parameter Parsing → Extract action, profile, node, target
2. Target Resolution → Determine host/sandbox/node
3. Node Proxy Check → Route to node if applicable
4. Local Execution → Call browser control HTTP API
5. File Handling → Persist downloads to media store
6. Result Formatting → Return JSON or image results
```

**Sandbox Integration:**
- **Bridge URL:** Sandboxed agents communicate via `sandboxBridgeUrl`
- **Policy Control:** `allowHostControl` restricts host browser access
- **Proxy Files:** Downloaded files mapped from node to local paths

### 4.7 Browser-Specific Security Policies

**Configuration Controls:**
- `browser.enabled`: Master enable/disable
- `browser.headless`: Run in headless mode
- `browser.noSandbox`: Disable Chrome sandbox (security risk)
- `browser.attachOnly`: Only attach to existing browsers (no launch)
- `browser.executablePath`: Custom Chrome executable

**Sandbox Policies:**
- `agents.defaults.sandbox.browser.enabled`: Allow sandboxed browser control
- `agents.defaults.sandbox.browser.allowHostControl`: Allow host browser access
- `gateway.nodes.browser.mode`: Control node proxy routing (auto/manual/off)

**Extension Relay Security:**
**File:** `/src/browser/extension-relay.ts`
- WebSocket bridge for attaching to existing Chrome tabs
- Requires user to click "Moltbot Browser Relay" toolbar button
- Prevents unauthorized tab takeover
- Blocks certain CDP APIs (e.g., Target.attachToBrowserTarget)

**Network Security:**
- CDP authentication via HTTP Basic Auth
- HTTPS support for CDP endpoints
- Timeout protection for all operations
- SSRF prevention via URL validation

### 4.8 Browser Driver Types

**Two Modes:**

1. **"clawd"** (Default):
   - Isolated Chrome instance managed by OpenClaw
   - User data: `~/.clawdbot/browser/<profile>/user-data`
   - Full control over browser state
   - Recommended for automation

2. **"extension"** (Chrome Extension Relay):
   - Attaches to existing Chrome tabs via extension
   - Requires user to click toolbar button
   - Preserves user's existing tabs
   - Useful for user-interactive scenarios

### 4.9 Browser Control Flow

```
Agent Tool Call
    ↓
browser-tool.ts (parameter parsing)
    ↓
[Route Decision: host/sandbox/node?]
    ├→ Node: callBrowserProxy() → gateway → node.invoke
    ├→ Sandbox: HTTP to sandboxBridgeUrl
    └→ Host: HTTP to 127.0.0.1:18791
    ↓
server.ts (Express HTTP server)
    ↓
routes/dispatcher.ts (path matching)
    ↓
routes/{basic,tabs,agent.*}.ts (handlers)
    ↓
server-context.ts (profile context)
    ↓
pw-session.ts (Playwright connection)
    ↓
client-actions-*.ts (Playwright operations)
    ↓
Result (JSON/image/file)
```

### 4.10 Key Files

| File | Purpose |
|------|---------|
| `/src/browser/pw-session.ts` | Playwright connection & state management |
| `/src/browser/server-context.ts` | Profile context, tab management |
| `/src/browser/control-service.ts` | Browser control service initialization |
| `/src/browser/server.ts` | Express HTTP server |
| `/src/browser/client.ts` | HTTP client functions |
| `/src/browser/client-actions-core.ts` | Core browser actions |
| `/src/browser/routes/agent.act.ts` | Agent action routes |
| `/src/agents/tools/browser-tool.ts` | Agent tool integration |

---

## Summary

This deep dive reveals OpenClaw's sophisticated architecture:

1. **Main Agent Loop:** Multi-layered retry logic with auth rotation, thinking fallbacks, and context management
2. **Memory Handling:** Dual storage (JSONL transcripts + SQLite embeddings) with hybrid search and incremental sync
3. **Tooling & Policy:** 6-layer policy enforcement with interactive approvals and sandbox isolation
4. **Browser Control:** Playwright-based automation with profile management, state persistence, and node proxy routing

The architecture demonstrates production-grade design with comprehensive error handling, security boundaries, and performance optimizations.

---

**Research completed:** 2026-02-02  
**Next:** Explore specific implementation patterns or extend functionality
