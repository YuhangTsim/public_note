# Architectural & Design Changes (v2026.1.29)

**Last Updated:** 2026-01-29  
**Scope:** Major architectural changes between v2026.1.25 → v2026.1.29

---

## 🏗️ Overview

While the v2026.1.29 update included a major rebrand (Clawdbot → OpenClaw), it also introduced **significant architectural and design changes** affecting how components communicate, how authorization works, and how browser automation is routed.

---

## 1. Browser Control Routing Architecture Change

**Commit:** `e7fdccce3` - "refactor: route browser control via gateway/node"

### Old Architecture (≤2026.1.25)
```
Browser Tool → Direct Connection → Chrome Extension
     ↓
   Relay Target (browser-specific URL)
```

### New Architecture (≥2026.1.29)
```
Browser Tool → Gateway → Node → Chrome Extension
     ↓              ↓       ↓
   Unified      Central   Capability
   Routing      Control    Host
```

### Key Changes

**Before:**
- Browser control had **direct connections** to browser targets
- Extension relay used browser-specific URLs
- Security policies applied directly at browser level

**After:**
- Browser control **routes through gateway/node** architecture
- Nodes expose `browser.*` commands as capabilities
- Gateway enforces tool policies before routing to nodes
- Fallback URL matching for relay targets

### Impact

| Aspect | Benefit |
|--------|---------|
| **Security** | Centralized policy enforcement at gateway level |
| **Remote Gateways** | Node-host proxy auto-routing for remote setups |
| **Consistency** | Browser tools follow same pattern as camera/screen/location |
| **Observability** | All browser operations logged through gateway |

### Configuration Changes

**Old config (deprecated):**
```yaml
browser:
  relay:
    url: "http://localhost:8080"
```

**New config:**
```yaml
# Browser routing now automatic via gateway/node
# No explicit relay configuration needed
# Nodes declare browser caps at connection time
```

### Documentation References
- `docs/tools/browser.md` - Updated browser routing documentation
- `docs/gateway/configuration.md` - Gateway routing configuration
- `docs/gateway/security.md` - Security implications

---

## 2. Per-Sender Group Tool Policies

**Commit:** `3b0c80ce2` - "Add per-sender group tool policies and fix precedence (#1757)"

### New Authorization Model

**Old Model:** Tool policies applied at **group level** (all members same access)

**New Model:** Tool policies can be **per-sender** within a group

### Architecture

```
Group Message Received
    ↓
Identify Sender → Apply Sender-Specific Policy
    ↓                      ↓
Per-Sender Policy → Global Group Policy → Default Policy
    (highest)             (medium)          (lowest)
```

### Policy Precedence (Highest → Lowest)

1. **Per-sender policy** (`groups.<groupId>.members.<senderId>.tools`)
2. **Group-wide policy** (`groups.<groupId>.tools`)
3. **Agent default policy** (`agents.list[].tools`)
4. **Global default** (`agents.defaults.tools`)

### Configuration Example

```yaml
groups:
  "120363424282127706@g.us":  # WhatsApp group
    allow: ["read", "write"]  # Default for all members
    
    members:
      "+1234567890":  # Specific sender
        allow: ["read", "write", "exec", "browser"]  # Extended access
        
      "+0987654321":  # Another sender
        allow: ["read"]  # Read-only access
        deny: ["exec", "write", "browser"]
```

### Use Cases

| Scenario | Policy Configuration |
|----------|---------------------|
| **Admin in group** | Per-sender: `allow: ["exec", "browser"]` |
| **Regular members** | Group default: `allow: ["read", "write"]` |
| **Restricted user** | Per-sender: `deny: ["exec"]` |
| **Guest access** | Per-sender: `allow: ["read"]` only |

### Tool Policy Resolution Algorithm

```typescript
function resolveToolPolicy(groupId, senderId, tool) {
  // 1. Check per-sender policy
  if (config.groups[groupId].members[senderId]?.tools) {
    return evaluatePolicy(config.groups[groupId].members[senderId].tools, tool);
  }
  
  // 2. Check group-wide policy
  if (config.groups[groupId]?.tools) {
    return evaluatePolicy(config.groups[groupId].tools, tool);
  }
  
  // 3. Check agent default
  if (config.agents.list[agentId]?.tools) {
    return evaluatePolicy(config.agents.list[agentId].tools, tool);
  }
  
  // 4. Global default
  return evaluatePolicy(config.agents.defaults.tools, tool);
}
```

### Documentation References
- `docs/multi-agent-sandbox-tools.md` - Comprehensive policy guide
- `docs/concepts/groups.md` - Group messaging and policies
- `docs/gateway/security.md` - Security architecture

---

## 3. Direct Gateway Transport for macOS

**Commits:** `#2033`, `#2046`

### New Transport Mode

**Traditional Setup (SSH/Tailscale tunnel):**
```
macOS App → SSH/Tailscale Tunnel → Gateway (remote)
```

**New Direct Transport:**
```
macOS App → Direct WebSocket → Gateway (local or remote)
              (ws:// or wss://)
```

### Configuration

```yaml
gateway:
  remote:
    transport: "direct"  # New option (default: tunnel)
    url: "ws://gateway-host:18789"  # Direct WebSocket URL
    # or
    url: "wss://gateway-host:18789"  # Secure WebSocket
    tlsFingerprint: "..."  # Optional TLS pinning
```

### Default Ports

| Transport | Default Port | Protocol |
|-----------|-------------|----------|
| Direct (ws) | 18789 | WebSocket |
| Direct (wss) | 18789 | WebSocket over TLS |
| SSH Tunnel | 22 → 18789 | SSH tunnel to WebSocket |
| Tailscale | Auto | Tailscale network to WebSocket |

### Benefits

| Aspect | Improvement |
|--------|-------------|
| **Simplicity** | No SSH/Tailscale setup required for direct connections |
| **Performance** | Eliminates tunnel overhead for local networks |
| **Debugging** | Easier to troubleshoot direct connections |
| **Flexibility** | Custom SSH usernames preserved for advanced setups |

### Security Considerations

⚠️ **Important:** Direct transport over `ws://` (non-TLS) should only be used on trusted networks.

**Recommended:**
- Use `wss://` with TLS for remote connections
- Use TLS fingerprint pinning for added security
- Keep SSH/Tailscale for production remote setups

### Documentation References
- `docs/gateway/remote.md` - Remote gateway setup
- `docs/platforms/mac/remote.md` - macOS remote configuration
- `docs/gateway/configuration.md` - Transport configuration

---

## 4. Session Routing & Scope Changes

**Commit:** `#3095` - "Routing: add per-account DM session scope + guidance for multi-account setups"

### New Session Scope Options

**Previous Scopes:**
- `per-channel-peer` - Separate session per channel + peer
- `global` - Single session across all channels

**New Scope (v2026.1.29):**
- `per-account-channel-peer` - Separate session per **account** + channel + peer

### Use Case: Multi-Account Telegram

```yaml
session:
  dmScope: per-account-channel-peer  # New option
```

**Scenario:**
- User has 2 Telegram accounts configured
- Same person DMs both accounts
- **Old behavior:** Shared session (context leak between accounts)
- **New behavior:** Separate sessions per account

### Session Key Generation

**Old:**
```typescript
sessionKey = `${channelType}:${peerId}`
// Example: "telegram:123456789"
```

**New (with per-account):**
```typescript
sessionKey = `${accountId}:${channelType}:${peerId}`
// Example: "telegram-work:telegram:123456789"
// Example: "telegram-personal:telegram:123456789"
```

### Benefits

| Aspect | Improvement |
|--------|-------------|
| **Privacy** | No context leakage between accounts |
| **Organization** | Clearer separation of work/personal contexts |
| **Multi-Agent** | Better routing in multi-agent setups |
| **Compliance** | Meets requirements for isolated account contexts |

### Configuration

```yaml
session:
  dmScope: per-account-channel-peer  # Isolate by account
  
channels:
  telegram:
    accounts:
      - id: "work"
        apiId: "..."
        apiHash: "..."
      - id: "personal"
        apiId: "..."
        apiHash: "..."
```

### Documentation References
- `docs/concepts/session.md` - Session management
- `docs/concepts/channel-routing.md` - Channel routing logic
- `docs/gateway/configuration.md` - Session configuration

---

## 5. OAuth Architecture Refactoring

**Commit:** `526303d9a` - "refactor(auth)!: remove external CLI OAuth reuse" (Breaking)

### What Changed

**Removed:** Ability to reuse OAuth credentials from external CLI tools

**Before (≤2026.1.25):**
```bash
# Could reuse tokens from anthropic CLI
openclaw login --reuse-anthropic-cli
```

**After (≥2026.1.29):**
```bash
# Must authenticate directly
openclaw login anthropic
# Or use API keys directly
```

### Rationale

| Reason | Explanation |
|--------|-------------|
| **Security** | Reduces attack surface by not accessing external token stores |
| **Reliability** | No dependency on external CLI token format stability |
| **Simplicity** | Clearer authentication flow |
| **Control** | Better token lifecycle management |

### Migration Path

**Old workflow:**
```bash
# 1. Authenticate with Anthropic CLI
anthropic login

# 2. Reuse credentials
openclaw login --reuse-anthropic-cli
```

**New workflow:**
```bash
# Direct authentication
openclaw login anthropic
# Opens browser for OAuth flow
```

**Or use API keys:**
```yaml
providers:
  anthropic:
    credentials:
      apiKey: "${ANTHROPIC_API_KEY}"  # From environment
```

### Documentation References
- `docs/concepts/oauth.md` - OAuth flow documentation
- `docs/providers/anthropic.md` - Anthropic provider setup
- `docs/cli/providers.md` - Provider CLI commands

---

## 6. Gateway Authentication Hardening (Breaking Change)

### Removed: `auth: none` Option

**Before (≤2026.1.25):**
```yaml
gateway:
  auth:
    mode: none  # ⚠️ No longer supported
```

**After (≥2026.1.29):**
```yaml
gateway:
  auth:
    mode: token  # Required (or password)
    token: "${GATEWAY_TOKEN}"  # Must set token
```

### Alternative: Tailscale Serve Identity

**Still allowed** (for Tailscale users):
```yaml
gateway:
  auth:
    mode: token
    # Tailscale Serve identity headers satisfy auth
```

### Impact

| Before | After |
|--------|-------|
| Optional gateway auth | **Mandatory** gateway auth |
| `mode: none` allowed | `mode: none` **removed** |
| Unauthenticated access possible | Always requires token/password |

### Security Benefits

- Eliminates accidentally exposed gateways
- Forces explicit security configuration
- Aligns with production security best practices

### Documentation References
- `docs/gateway/authentication.md` - Authentication configuration
- `docs/gateway/security/index.md` - Security architecture
- `docs/gateway/security/formal-verification.md` - Formal security model

---

## 7. Tools Architecture: `tools.alsoAllow` Pattern

**Commit:** `#1762` - "feat(config): add tools.alsoAllow additive allowlist"

### New Pattern: Additive Allowlists

**Problem:** Plugin tools need to be explicitly allowed, but maintaining allowlists is tedious.

**Solution:** `tools.alsoAllow` for additive opt-in

### Configuration Pattern

```yaml
agents:
  list:
    - id: default
      tools:
        allow: ["read", "write", "exec"]  # Core tools
        
        alsoAllow: ["plugin:twitch.*"]  # Plugin tools (additive)
        # Expands to: allow + alsoAllow = full allowlist
```

### Behavior

**Without `alsoAllow`:**
```yaml
tools:
  allow: ["read", "write"]
  # Plugin tools are DENIED unless explicitly in allow list
```

**With `alsoAllow`:**
```yaml
tools:
  allow: ["read", "write"]  # Core tools
  alsoAllow: ["plugin:*"]   # All plugin tools (additive)
  # Effective allowlist: ["read", "write", "plugin:*"]
```

### Use Cases

| Scenario | Configuration |
|----------|---------------|
| **Allow all plugins** | `alsoAllow: ["plugin:*"]` |
| **Specific plugin** | `alsoAllow: ["plugin:twitch.*"]` |
| **Multiple plugins** | `alsoAllow: ["plugin:twitch.*", "plugin:matrix.*"]` |
| **With base allow** | `allow: ["read"], alsoAllow: ["plugin:*"]` |

### Mutual Exclusion Rule

```yaml
# ❌ INVALID: Cannot use both at same scope
tools:
  allow: ["read", "write"]
  alsoAllow: ["plugin:*"]  # Error: use one or the other at scope level
```

**Correct usage:**
```yaml
# ✅ VALID: alsoAllow at different scope
agents:
  defaults:
    tools:
      allow: ["read", "write", "exec"]
      
  list:
    - id: plugin-user
      tools:
        alsoAllow: ["plugin:*"]  # Additive to defaults
```

### Documentation References
- `docs/tools/index.md` - Tool system overview
- `docs/plugin.md` - Plugin architecture
- `docs/gateway/configuration.md` - Tool configuration

---

## 8. Memory Search: Extra Paths

**Commit:** `#3600` - "Memory Search: allow extra paths for memory indexing"

### New Capability

**Before:** Memory search indexed only default workspace paths

**After:** Configurable extra paths for memory indexing

### Configuration

```yaml
memory:
  paths:
    - "~/Documents/notes"
    - "~/Projects/research"
    - "/mnt/knowledge-base"
```

### Architecture

```
Memory Indexing
    ↓
Default Workspace Paths
    + Extra Configured Paths
    ↓
Unified Search Index
```

### Use Cases

| Scenario | Configuration |
|----------|---------------|
| **External knowledge base** | `paths: ["/mnt/kb"]` |
| **Multiple workspaces** | `paths: ["~/work", "~/personal"]` |
| **Shared team docs** | `paths: ["/shared/docs"]` |
| **Reference materials** | `paths: ["~/References"]` |

### Performance Considerations

⚠️ **Note:** Large path sets increase indexing time. Monitor performance with:
```bash
openclaw memory status
```

### Documentation References
- `docs/concepts/memory.md` - Memory system overview
- `docs/cli/memory.md` - Memory CLI commands

---

## 9. Config Environment Variable Substitution Order

**Commit:** `#1813` - "Config: apply config.env before ${VAR} substitution"

### Execution Order Change

**Before:**
```
1. Load config.yaml
2. Substitute ${VAR} from environment
3. Apply config.env overrides
```

**After:**
```
1. Load config.yaml
2. Apply config.env entries to environment  ← Changed
3. Substitute ${VAR} from (now-modified) environment
```

### Impact Example

**config.yaml:**
```yaml
gateway:
  auth:
    token: "${GATEWAY_TOKEN}"
    
config:
  env:
    GATEWAY_TOKEN: "my-secret-token"
```

**Old behavior:**
```
1. GATEWAY_TOKEN not in environment → substitution fails
2. config.env sets GATEWAY_TOKEN → but too late
```

**New behavior:**
```
1. config.env sets GATEWAY_TOKEN → environment now has it
2. ${GATEWAY_TOKEN} substitutes successfully
```

### Benefits

- **Consistency:** config.env can provide defaults for ${VAR} substitutions
- **Flexibility:** Mix config-level and environment-level variables
- **Testing:** Easier to override values in test configs

### Documentation References
- `docs/gateway/configuration.md` - Configuration loading
- `docs/environment.md` - Environment variable handling

---

## Summary Table: Major Architectural Changes

| Change | Type | Impact | Breaking |
|--------|------|--------|----------|
| **Browser Control Routing** | Architecture | High - Changes communication flow | No |
| **Per-Sender Tool Policies** | Authorization | Medium - Enables fine-grained control | No |
| **Direct Gateway Transport** | Infrastructure | Medium - Simplifies remote setup | No |
| **Per-Account Session Scope** | Routing | Medium - Prevents context leakage | No |
| **OAuth Refactoring** | Authentication | Low - Removes external CLI reuse | **Yes** |
| **Gateway Auth Required** | Security | High - Mandates authentication | **Yes** |
| **tools.alsoAllow Pattern** | Configuration | Low - Simplifies plugin tool config | No |
| **Memory Extra Paths** | Features | Low - Expands memory indexing | No |
| **Config.env Order** | Configuration | Low - Fixes substitution order | No |

---

## Migration Checklist

### Breaking Changes

- [ ] **Gateway Auth:** Remove `auth.mode: none`, add `auth.token`
- [ ] **OAuth:** Stop using `--reuse-anthropic-cli`, use direct `openclaw login`

### Recommended Updates

- [ ] **Browser Tools:** Review browser tool policies (now routed via gateway)
- [ ] **Group Policies:** Consider per-sender policies for groups with mixed access levels
- [ ] **Multi-Account:** Switch to `per-account-channel-peer` if running multiple accounts
- [ ] **macOS Remote:** Consider direct transport for local network setups
- [ ] **Plugin Tools:** Use `tools.alsoAllow` to simplify plugin tool allowlists
- [ ] **Memory Paths:** Add extra memory paths if you have external knowledge bases

---

## References

### Documentation
- `docs/concepts/architecture.md` - Overall architecture
- `docs/gateway/protocol.md` - Gateway protocol details
- `docs/gateway/security/index.md` - Security architecture
- `docs/gateway/configuration.md` - Configuration reference
- `docs/multi-agent-sandbox-tools.md` - Tool policies

### Commits
- `e7fdccce3` - Browser routing refactor
- `3b0c80ce2` - Per-sender tool policies
- `526303d9a` - OAuth refactoring (breaking)
- `#2033, #2046` - Direct gateway transport
- `#3095` - Per-account session scope
- `#1762` - tools.alsoAllow pattern
- `#3600` - Memory extra paths
- `#1813` - Config.env order

---

**Last Updated:** 2026-01-29  
**Applies to:** v2026.1.29 and later
