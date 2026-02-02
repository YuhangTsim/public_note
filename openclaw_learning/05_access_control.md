# Access Control & Security

OpenClaw implements a comprehensive security model spanning user authentication, tool execution sandboxing, and audit capabilities. This document covers the multi-layered access control architecture that protects against unauthorized access and dangerous operations.

## Table of Contents
- [Overview](#overview)
- [DM Pairing System](#dm-pairing-system)
- [Allowlist Matching](#allowlist-matching)
- [Exec Approvals (Bash Security)](#exec-approvals-bash-security)
- [Sandbox Tool Policy](#sandbox-tool-policy)
- [Elevated Execution](#elevated-execution)
- [Security Audit](#security-audit)
- [Key Files](#key-files)

---

## Overview

OpenClaw security operates across four layers:

```
Layer 1: Channel Access Control
├── DM Pairing (ephemeral codes)
├── Allowlists (config + persistent store)
└── Group/Guild policies (open/allowlist/disabled)

Layer 2: Tool Execution
├── Sandbox tool policy (allow/deny lists)
├── Exec approvals (~/.openclaw/exec-approvals.json)
└── Elevated execution (sudo-like capability)

Layer 3: Gateway & Remote Access
├── Gateway auth (token/password)
├── Tailscale Serve/Funnel
└── Browser control tokens

Layer 4: Audit & Compliance
├── Security audit (openclaw security audit)
├── File permission checks
└── Attack surface analysis
```

---

## DM Pairing System

The pairing system enables users to authorize themselves without editing config files. It uses ephemeral codes stored in a secure pairing store.

### How Pairing Works

**From `src/pairing/pairing-store.ts:11-14`:**
```typescript
const PAIRING_CODE_LENGTH = 8;
const PAIRING_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // No ambiguous chars
const PAIRING_PENDING_TTL_MS = 60 * 60 * 1000; // 1 hour
const PAIRING_PENDING_MAX = 3; // Maximum pending requests
```

### Workflow

1. **User requests pairing** via DM to the bot
2. **Bot generates 8-char code** (e.g., `AB3K7MNP`) and stores in `~/.config/openclaw/oauth/<channel>-pairing.json`
3. **User approves code** by running `openclaw pairing approve AB3K7MNP` on the server
4. **User ID added to allowlist** in `~/.config/openclaw/oauth/<channel>-allowFrom.json`
5. **Pairing request removed** from pending store

### Pairing Request Structure

**From `src/pairing/pairing-store.ts:28-34`:**
```typescript
export type PairingRequest = {
  id: string;              // User ID (platform-specific)
  code: string;            // 8-char approval code
  createdAt: string;       // ISO 8601 timestamp
  lastSeenAt: string;      // Last time user requested pairing
  meta?: Record<string, string>;  // Optional metadata (username, etc.)
};
```

### Security Features

**Code Generation** (`src/pairing/pairing-store.ts:173-189`):
```typescript
function randomCode(): string {
  // Human-friendly: 8 chars, upper, no ambiguous chars (0O1I).
  let out = "";
  for (let i = 0; i < PAIRING_CODE_LENGTH; i++) {
    const idx = crypto.randomInt(0, PAIRING_CODE_ALPHABET.length);
    out += PAIRING_CODE_ALPHABET[idx];
  }
  return out;
}

function generateUniqueCode(existing: Set<string>): string {
  for (let attempt = 0; attempt < 500; attempt += 1) {
    const code = randomCode();
    if (!existing.has(code)) return code;
  }
  throw new Error("failed to generate unique pairing code");
}
```

**Expiration** (`src/pairing/pairing-store.ts:142-146`):
```typescript
function isExpired(entry: PairingRequest, nowMs: number): boolean {
  const createdAt = parseTimestamp(entry.createdAt);
  if (!createdAt) return true;
  return nowMs - createdAt > PAIRING_PENDING_TTL_MS; // 1 hour
}
```

**Rate Limiting:** Maximum 3 pending requests per channel. Oldest requests are pruned when limit exceeded.

### File Storage

**Pairing Requests:**
```
~/.config/openclaw/oauth/<channel>-pairing.json
```

**Allowlist (Post-Approval):**
```
~/.config/openclaw/oauth/<channel>-allowFrom.json
```

**From `src/pairing/pairing-store.ts:60-69`:**
```typescript
function resolvePairingPath(channel: PairingChannel, env: NodeJS.ProcessEnv = process.env): string {
  return path.join(resolveCredentialsDir(env), `${safeChannelKey(channel)}-pairing.json`);
}

function resolveAllowFromPath(
  channel: PairingChannel,
  env: NodeJS.ProcessEnv = process.env,
): string {
  return path.join(resolveCredentialsDir(env), `${safeChannelKey(channel)}-allowFrom.json`);
}
```

**File Permissions:** Files are created with `mode: 0o600` (owner read/write only).

### CLI Commands

```bash
# List pending pairing requests
openclaw pairing list

# Approve a pairing code
openclaw pairing approve AB3K7MNP

# Revoke an approved user
openclaw pairing revoke <user-id>
```

---

## Allowlist Matching

Allowlists determine who can interact with the bot on each channel. They support wildcards, exact matches, and platform-specific identifiers.

### Allowlist Sources

**Two sources** (merged at runtime):
1. **Config allowlist** (`channels.<provider>.dm.allowFrom` in `.openclaw/config.yaml`)
2. **Pairing store** (`~/.config/openclaw/oauth/<channel>-allowFrom.json`)

**From `src/security/audit.ts:452-464`:**
```typescript
const configAllowFrom = normalizeAllowFromList(input.allowFrom);
const storeAllowFrom = await readChannelAllowFromStore(input.provider).catch(() => []);
const normalizedCfg = configAllowFrom
  .filter((value) => value !== "*")
  .map((value) => normalizeEntry(value))
  .map((value) => value.trim())
  .filter(Boolean);
const normalizedStore = storeAllowFrom
  .map((value) => normalizeEntry(value))
  .map((value) => value.trim())
  .filter(Boolean);
const allowCount = Array.from(new Set([...normalizedCfg, ...normalizedStore])).length;
```

### Match Types

**From `src/channels/allowlist-match.ts:1-11`:**
```typescript
export type AllowlistMatchSource =
  | "wildcard"        // "*" matches everyone
  | "id"              // Exact platform ID (e.g., Discord user ID)
  | "name"            // Display name
  | "tag"             // Platform tag (e.g., Discord tag)
  | "username"        // Username handle
  | "prefixed-id"     // "id:123456"
  | "prefixed-user"   // "user:alice"
  | "prefixed-name"   // "name:Bob Smith"
  | "slug"            // Slugified name
  | "localpart";      // Email localpart
```

### DM Policies

Each channel supports three DM policies:

| Policy | Behavior | Security |
|--------|----------|----------|
| `disabled` | Ignores all DMs | Safest |
| `allowlist` | Only approved users can DM (via config or pairing) | Recommended |
| `open` | Anyone can DM the bot (requires `allowFrom: ["*"]`) | ⚠️ **Critical risk** |

**Configuration:**
```yaml
# .openclaw/config.yaml
channels:
  discord:
    dm:
      policy: allowlist  # or: open, disabled
      allowFrom:
        - "123456789012345678"  # Discord user ID
        - "alice"               # Username
```

### Group/Guild Policies

Similar to DM policies but for group chats or Discord guilds:

```yaml
channels:
  discord:
    groupPolicy: allowlist  # or: open, disabled
    guilds:
      "987654321098765432":
        users:
          - "123456789012345678"
        channels:
          "111222333444555666":
            users:
              - "alice"
```

### Security Warnings

**From `src/security/audit.ts:467-484`:**
```typescript
if (input.dmPolicy === "open") {
  const allowFromKey = `${input.allowFromPath}allowFrom`;
  findings.push({
    checkId: `channels.${input.provider}.dm.open`,
    severity: "critical",
    title: `${input.label} DMs are open`,
    detail: `${policyPath}="open" allows anyone to DM the bot.`,
    remediation: `Use pairing/allowlist; if you really need open DMs, ensure ${allowFromKey} includes "*".`,
  });
  if (!hasWildcard) {
    findings.push({
      checkId: `channels.${input.provider}.dm.open_invalid`,
      severity: "warn",
      title: `${input.label} DM config looks inconsistent`,
      detail: `"open" requires ${allowFromKey} to include "*".`,
    });
  }
}
```

---

## Exec Approvals (Bash Security)

Exec approvals control which commands the `bash` tool can execute. This prevents arbitrary code execution while allowing approved workflows.

### Approval File

**Location:** `~/.openclaw/exec-approvals.json`

**Structure (from `src/infra/exec-approvals.ts:32-40`):**
```typescript
export type ExecApprovalsFile = {
  version: 1;
  socket?: {
    path?: string;  // Unix socket for UI integration
    token?: string; // Auth token for socket
  };
  defaults?: ExecApprovalsDefaults;
  agents?: Record<string, ExecApprovalsAgent>;
};
```

### Security Modes

**From `src/infra/exec-approvals.ts:10-11, 60-63`:**
```typescript
export type ExecSecurity = "deny" | "allowlist" | "full";
export type ExecAsk = "off" | "on-miss" | "always";

const DEFAULT_SECURITY: ExecSecurity = "deny";
const DEFAULT_ASK: ExecAsk = "on-miss";
const DEFAULT_ASK_FALLBACK: ExecSecurity = "deny";
```

| Mode | Behavior |
|------|----------|
| `deny` | All commands blocked (safest default) |
| `allowlist` | Only approved commands allowed |
| `full` | All commands allowed (⚠️ **dangerous**) |

### Ask Modes

| Mode | Behavior |
|------|----------|
| `off` | Never prompt user, use security setting |
| `on-miss` | Prompt when command not in allowlist |
| `always` | Prompt for every command execution |

### Allowlist Entry

**From `src/infra/exec-approvals.ts:20-26`:**
```typescript
export type ExecAllowlistEntry = {
  id?: string;               // Unique entry ID
  pattern: string;           // Command pattern (supports wildcards)
  lastUsedAt?: number;       // Timestamp of last use
  lastUsedCommand?: string;  // Actual command executed
  lastResolvedPath?: string; // Binary path resolution
};
```

### Example Configuration

```json
{
  "version": 1,
  "defaults": {
    "security": "allowlist",
    "ask": "on-miss",
    "askFallback": "deny",
    "autoAllowSkills": false
  },
  "agents": {
    "default": {
      "security": "allowlist",
      "allowlist": [
        {
          "id": "uuid-1234",
          "pattern": "git",
          "lastUsedAt": 1706284800000,
          "lastUsedCommand": "git status"
        },
        {
          "pattern": "npm*",
          "lastUsedCommand": "npm install"
        },
        {
          "pattern": "ls",
          "lastUsedAt": 1706284900000
        }
      ]
    }
  }
}
```

### Safe Binaries (Auto-Allowed)

**From `src/infra/exec-approvals.ts:66`:**
```typescript
export const DEFAULT_SAFE_BINS = ["jq", "grep", "cut", "sort", "uniq", "head", "tail", "tr", "wc"];
```

These commands are considered safe and don't require approval.

### Pattern Matching

Supports wildcards:
- `git` → matches `git` exactly
- `npm*` → matches `npm`, `npm install`, `npx`, etc.
- `*` → matches everything (⚠️ equivalent to `full` mode)

---

## Sandbox Tool Policy

The sandbox restricts which agent tools are available in sandboxed sessions (e.g., when using remotessh or serving web UIs).

### Default Policy

**From `src/agents/sandbox/constants.ts`:**
```typescript
export const DEFAULT_TOOL_ALLOW = [
  "bash",
  "cd",
  "computertext",
  "computerscreen",
  "computerclick",
  "computercursor",
  "computerkey",
  "computertypingdelay",
  "edit",
  "grep",
  "image",  // Always included for multimodal
  "list",
  "read",
  "write"
];

export const DEFAULT_TOOL_DENY = [
  "computerrebootdelay",
  "computerscreenshotdelay",
  "computerexecbg",
  "computergetscreens",
  "computerlaunchapp",
  "computermovecursor",
  // ... other high-risk tools
];
```

### Configuration

**Global:**
```yaml
# .openclaw/config.yaml
tools:
  sandbox:
    tools:
      allow:
        - bash
        - read
        - write
        - edit
      deny:
        - bash
        - exec
```

**Per-Agent:**
```yaml
agents:
  list:
    - id: sandbox-agent
      tools:
        sandbox:
          tools:
            allow:
              - read
              - grep
            deny:
              - bash
```

### Resolution Logic

**From `src/agents/sandbox/tool-policy.ts:53-124`:**
```typescript
export function resolveSandboxToolPolicyForAgent(
  cfg?: OpenClawConfig,
  agentId?: string
): SandboxToolPolicyResolved {
  const agentConfig = cfg && agentId ? resolveAgentConfig(cfg, agentId) : undefined;
  const agentAllow = agentConfig?.tools?.sandbox?.tools?.allow;
  const agentDeny = agentConfig?.tools?.sandbox?.tools?.deny;
  const globalAllow = cfg?.tools?.sandbox?.tools?.allow;
  const globalDeny = cfg?.tools?.sandbox?.tools?.deny;

  // Precedence: agent > global > default
  const deny = Array.isArray(agentDeny)
    ? agentDeny
    : Array.isArray(globalDeny)
      ? globalDeny
      : [...DEFAULT_TOOL_DENY];
  const allow = Array.isArray(agentAllow)
    ? agentAllow
    : Array.isArray(globalAllow)
      ? globalAllow
      : [...DEFAULT_TOOL_ALLOW];

  let expandedAllow = expandToolGroups(allow);

  // `image` is essential for multimodal workflows; always include it unless explicitly denied.
  if (
    !expandedDeny.map((v) => v.toLowerCase()).includes("image") &&
    !expandedAllow.map((v) => v.toLowerCase()).includes("image")
  ) {
    expandedAllow = [...expandedAllow, "image"];
  }

  return { allow: expandedAllow, deny: expandedDeny, sources: {...} };
}
```

### Tool Matching

**From `src/agents/sandbox/tool-policy.ts:44-51`:**
```typescript
export function isToolAllowed(policy: SandboxToolPolicy, name: string) {
  const normalized = name.trim().toLowerCase();
  const deny = compilePatterns(policy.deny);
  if (matchesAny(normalized, deny)) return false;  // Deny list takes precedence
  const allow = compilePatterns(policy.allow);
  if (allow.length === 0) return true;  // Empty allow = allow all
  return matchesAny(normalized, allow);
}
```

**Supports wildcards:**
- `bash*` → matches `bash`, `bashhistory`, etc.
- `*` → matches all tools

---

## Elevated Execution

Elevated execution grants specific users permission to run commands that would normally be blocked (similar to `sudo`).

### Configuration

```yaml
# .openclaw/config.yaml
tools:
  elevated:
    enabled: true
    allowFrom:
      discord:
        - "123456789012345678"  # User ID with elevated access
      telegram:
        - "alice"
        - "bob"
```

### Security Warnings

**From `src/security/audit.ts:396-425`:**
```typescript
function collectElevatedFindings(cfg: OpenClawConfig): SecurityAuditFinding[] {
  const findings: SecurityAuditFinding[] = [];
  const enabled = cfg.tools?.elevated?.enabled;
  const allowFrom = cfg.tools?.elevated?.allowFrom ?? {};
  
  for (const [provider, list] of Object.entries(allowFrom)) {
    const normalized = normalizeAllowFromList(list);
    if (normalized.includes("*")) {
      findings.push({
        checkId: `tools.elevated.allowFrom.${provider}.wildcard`,
        severity: "critical",
        title: "Elevated exec allowlist contains wildcard",
        detail: `tools.elevated.allowFrom.${provider} includes "*" which effectively approves everyone on that channel for elevated mode.`,
      });
    } else if (normalized.length > 25) {
      findings.push({
        checkId: `tools.elevated.allowFrom.${provider}.large`,
        severity: "warn",
        title: "Elevated exec allowlist is large",
        detail: `tools.elevated.allowFrom.${provider} has ${normalized.length} entries; consider tightening elevated access.`,
      });
    }
  }
  
  return findings;
}
```

**Best practice:** Keep elevated allowlists small and avoid wildcards.

---

## Security Audit

OpenClaw includes a comprehensive security audit tool that scans configuration for vulnerabilities.

### Running Audit

```bash
# Basic audit
openclaw security audit

# Deep audit (includes gateway connectivity test)
openclaw security audit --deep
```

### Audit Checks

**From `src/security/audit.ts:839-898`:**
```typescript
export async function runSecurityAudit(opts: SecurityAuditOptions): Promise<SecurityAuditReport> {
  const findings: SecurityAuditFinding[] = [];
  
  findings.push(...collectAttackSurfaceSummaryFindings(cfg));
  findings.push(...collectSyncedFolderFindings({ stateDir, configPath }));
  findings.push(...collectGatewayConfigFindings(cfg));
  findings.push(...collectBrowserControlFindings(cfg));
  findings.push(...collectLoggingFindings(cfg));
  findings.push(...collectElevatedFindings(cfg));
  findings.push(...collectHooksHardeningFindings(cfg));
  findings.push(...collectSecretsInConfigFindings(cfg));
  findings.push(...collectModelHygieneFindings(cfg));
  findings.push(...collectSmallModelRiskFindings({ cfg, env }));
  findings.push(...collectExposureMatrixFindings(cfg));
  
  if (opts.includeFilesystem !== false) {
    findings.push(...(await collectFilesystemFindings({ stateDir, configPath })));
    findings.push(...(await collectStateDeepFilesystemFindings({ cfg, env, stateDir })));
    findings.push(...(await collectPluginsTrustFindings({ cfg, stateDir })));
  }
  
  if (opts.includeChannelSecurity !== false) {
    findings.push(...(await collectChannelSecurityFindings({ cfg, plugins })));
  }
  
  const summary = countBySeverity(findings);
  return { ts: Date.now(), summary, findings, deep };
}
```

### Finding Severity Levels

**From `src/security/audit.ts:36`:**
```typescript
export type SecurityAuditSeverity = "info" | "warn" | "critical";
```

### Example Findings

**Gateway Binding Without Auth:**
```typescript
{
  checkId: "gateway.bind_no_auth",
  severity: "critical",
  title: "Gateway binds beyond loopback without auth",
  detail: `gateway.bind="0.0.0.0" but no gateway.auth token/password is configured.`,
  remediation: `Set gateway.auth (token recommended) or bind to loopback.`,
}
```

**World-Writable State Directory:**
```typescript
{
  checkId: "fs.state_dir.perms_world_writable",
  severity: "critical",
  title: "State dir is world-writable",
  detail: `~/.openclaw mode=0o777; other users can write into your OpenClaw state.`,
  remediation: `chmod 700 ~/.openclaw`,
}
```

**Open DM Policy:**
```typescript
{
  checkId: "channels.discord.dm.open",
  severity: "critical",
  title: "Discord DMs are open",
  detail: `channels.discord.dm.policy="open" allows anyone to DM the bot.`,
  remediation: `Use pairing/allowlist; if you really need open DMs, ensure allowFrom includes "*".`,
}
```

### Filesystem Checks

**From `src/security/audit.ts:119-202`:**
```typescript
async function collectFilesystemFindings(params: {
  stateDir: string;
  configPath: string;
}): Promise<SecurityAuditFinding[]> {
  const findings: SecurityAuditFinding[] = [];
  
  const stateDirStat = await safeStat(params.stateDir);
  if (stateDirStat.ok) {
    const bits = modeBits(stateDirStat.mode);
    if (isWorldWritable(bits)) {
      findings.push({
        checkId: "fs.state_dir.perms_world_writable",
        severity: "critical",
        title: "State dir is world-writable",
        detail: `${params.stateDir} mode=${formatOctal(bits)}; other users can write into your OpenClaw state.`,
        remediation: `chmod 700 ${params.stateDir}`,
      });
    }
    // ... more permission checks
  }
  
  const configStat = await safeStat(params.configPath);
  if (configStat.ok) {
    const bits = modeBits(configStat.mode);
    if (isWorldWritable(bits) || isGroupWritable(bits)) {
      findings.push({
        checkId: "fs.config.perms_writable",
        severity: "critical",
        title: "Config file is writable by others",
        detail: `${params.configPath} mode=${formatOctal(bits)}; another user could change gateway/auth/tool policies.`,
        remediation: `chmod 600 ${params.configPath}`,
      });
    }
  }
  
  return findings;
}
```

---

## Key Files

### Pairing & Allowlists
- **`src/pairing/pairing-store.ts`** (466 lines) - Pairing request management, allowlist storage
- **`src/pairing/pairing-messages.ts`** - User-facing pairing messages
- **`src/pairing/pairing-labels.ts`** - Channel-specific pairing label generation
- **`src/channels/allowlist-match.ts`** (24 lines) - Allowlist match type definitions
- **`src/channels/plugins/pairing.ts`** - Pairing adapter registry

### Exec Approvals
- **`src/infra/exec-approvals.ts`** (~450 lines) - Bash command approval system
- **`src/gateway/server-methods/exec-approvals.ts`** - Gateway API for managing approvals
- **`src/gateway/protocol/schema/exec-approvals.ts`** - Protocol schema

### Sandbox
- **`src/agents/sandbox/tool-policy.ts`** (125 lines) - Sandbox tool allow/deny logic
- **`src/agents/sandbox/constants.ts`** - Default sandbox policies
- **`src/agents/sandbox/types.ts`** - Type definitions

### Security Audit
- **`src/security/audit.ts`** (900 lines) - Main security audit orchestrator
- **`src/security/audit-extra.ts`** - Additional audit checks (attack surface, model hygiene, etc.)
- **`src/security/audit-fs.ts`** - Filesystem permission utilities
- **`src/security/external-content.ts`** - External content safety checks

### CLI
- **`src/cli/pairing-cli.ts`** - `openclaw pairing` command
- **`src/cli/security-cli.ts`** - `openclaw security audit` command

### Storage Locations
- **Pairing store:** `~/.config/openclaw/oauth/<channel>-pairing.json`
- **Allowlist store:** `~/.config/openclaw/oauth/<channel>-allowFrom.json`
- **Exec approvals:** `~/.openclaw/exec-approvals.json`
- **Config file:** `.openclaw/config.yaml`

---

## Best Practices

### User Access
1. **Prefer pairing over config allowlists** - Easier user onboarding, no server restart required
2. **Never use wildcard (`*`) in production** - Always use explicit user IDs
3. **Use `allowlist` DM policy** - `open` is almost never necessary and highly risky
4. **Limit elevated execution** - Keep `tools.elevated.allowFrom` lists small

### Tool Execution
1. **Start with `deny` security mode** - Gradually approve commands as needed
2. **Use `on-miss` ask mode** - Balance security and usability
3. **Review exec-approvals.json regularly** - Remove unused command patterns
4. **Prefer skill-specific patterns** - `git*` instead of `*`

### Filesystem
1. **Protect state directory** - `chmod 700 ~/.openclaw`
2. **Protect config file** - `chmod 600 .openclaw/config.yaml`
3. **Avoid symlinks** - Can introduce unexpected trust boundaries
4. **Run security audit regularly** - `openclaw security audit --deep`

### Gateway & Remote Access
1. **Always use auth tokens on non-loopback bindings** - Never expose unauthenticated gateways
2. **Prefer Tailscale Serve over Funnel** - Tailnet-only is safer than public internet
3. **Use strong tokens** - 32+ random characters
4. **Don't reuse tokens** - Browser control tokens should differ from gateway tokens

---

## Related Documentation

- [Tool System](./03_tool_system.md) - How tools are executed and restricted
- [Gateway Architecture](./08_gateway_architecture.md) - Remote access and WebSocket control plane
- [Prompt Engineering](./02_prompt_system.md) - Security implications of workspace files
