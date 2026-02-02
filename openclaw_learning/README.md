# OpenClaw/OpenClaw Learning Documentation

> **🔄 IMPORTANT REBRAND (2026.1.29):** The project was renamed from **Clawdbot** to **OpenClaw**. The npm package is now `openclaw`, documentation moved to https://docs.openclaw.dev, but the GitHub repository URL remains the same. See **[Version History](./10_version_history.md)** for migration details.

Comprehensive documentation for **Clawdbot/OpenClaw** - a personal AI assistant platform with multi-channel support, featuring gateway-based architecture, extensive security controls, and powerful skill extensibility.

---

## 📚 Documentation Index

### Core Architecture

1. **[01_overview.md](./01_overview.md)** - Repository structure, technology stack, and architectural overview
2. **[Prompt System](./02_prompt_system.md)** - Workspace files (SOUL.md, AGENTS.md, etc.), prompt engineering, and agent behavior configuration
3. **[Tool System](./03_tool_system.md)** - Tool categories, execution flow, approval systems, and plugin architecture

### Advanced Systems

4. **[Skills System](./04_skills_system.md)** - Skills discovery, SKILL.md format, installation orchestration, and eligibility filtering
5. **[Access Control & Security](./05_access_control.md)** - DM pairing, allowlists, exec approvals, sandbox policies, elevated execution, and security audit
6. **[Task Completion & Agent Lifecycle](./06_task_completion.md)** - Agent run states, completion detection, session management, and streaming events
7. **[09_session_storage.md](./09_session_storage.md)** - Session persistence, JSONL logging, metadata separation, and pruning logic

### Version History & Updates

8. **[Version History](./10_version_history.md)** - Release notes, changelog, migration guides (Clawdbot → OpenClaw rebrand)
9. **[Architectural Changes (v2026.1.29)](./11_architectural_changes_2026_01_29.md)** - Design & architecture changes in latest release

### Deep Dive & Internals

10. **[Deep Dive: Agent Internals](./12_deep_dive_agent_internals.md)** - Comprehensive exploration of:
    - Main agent loop (runEmbeddedPiAgent, turn management, streaming)
    - Memory handling (JSONL transcripts, SQLite embeddings, hybrid search)
    - Tooling & policy (tool registration, security enforcement, approval system)
    - Browser control (Playwright integration, session management, routing)

---

## 🚀 Quick Start

### What is OpenClaw?

OpenClaw (renamed from Clawdbot in 2026.1.29) is a **self-hosted AI assistant platform** that connects Claude AI to multiple messaging platforms (WhatsApp, Telegram, Discord, Slack, iMessage, Signal, etc.) with a focus on security, extensibility, and developer experience.

**Key Differentiators:**
- **Gateway-based architecture** - WebSocket control plane separates runtime from channels
- **Multi-channel support** - Single agent, multiple platform integrations
- **Security-first** - Layered access control, sandbox isolation, exec approvals
- **Extensible** - Skills system, plugin architecture, custom tools
- **Canvas/A2UI** - Render interactive UIs directly in supported channels
- **Voice Wake** - Always-on speech interaction for Mac

---

## 📖 Reading Guide

### For First-Time Learners

Start here to understand OpenClaw from the ground up:

1. **[Overview](./01_overview.md)** - Understand the project structure and architecture
2. **[Prompt System](./02_prompt_system.md)** - Learn how to configure agent behavior
3. **[Tool System](./03_tool_system.md)** - Understand how the agent executes commands
4. **[Access Control](./05_access_control.md)** - Set up secure access for yourself
5. **[Skills System](./04_skills_system.md)** - Extend the agent with new capabilities

### For Security-Conscious Users

Focus on these sections to harden your deployment:

1. **[Access Control & Security](./05_access_control.md)** - Complete security architecture
   - DM pairing for user authentication
   - Exec approvals for bash command safety
   - Sandbox tool policies
   - Security audit tool
2. **[Tool System](./03_tool_system.md)** - Tool execution and approval flow
3. **[Prompt System](./02_prompt_system.md)** - Security implications of workspace files

### For Developers Building Extensions

Deep dive into extensibility APIs:

1. **[Skills System](./04_skills_system.md)** - Create custom skills
2. **[Tool System](./03_tool_system.md)** - Build custom tools and plugins
3. **[Task Completion](./06_task_completion.md)** - Agent run lifecycle and event handling

---

## 🔑 Key Concepts

### Gateway Architecture

OpenClaw uses a **gateway-based architecture** where:
- **Gateway** - WebSocket server managing sessions, routing, and state
- **Channels** - Platform-specific adapters (Discord, Telegram, etc.)
- **Agent Runtime** - Pi coding agent execution environment

```
User (Discord) → Discord Adapter → Gateway → Agent Runtime → Claude API
                                      ↓
User (Telegram) → Telegram Adapter ───┘
```

**Benefits:**
- Single agent serves multiple channels simultaneously
- Centralized session management and logging
- Platform-agnostic tool execution
- Remote deployment support (gateway on server, channels on desktop)

See: [Overview - Architecture](./01_overview.md#architecture)

### Workspace Files

OpenClaw/OpenClaw reads markdown files from `.openclaw/` (or legacy `.openclaw/`) to configure agent behavior:

| File | Purpose |
|------|---------|
| `SOUL.md` | Agent personality and behavior guidelines |
| `AGENTS.md` | Multi-agent definitions and coordination |
| `WORKSPACE.md` | Project context and conventions |
| `PLAN.md` | Current task plans and priorities |
| `SESSION.md` | Per-session context (ephemeral) |

> **Note:** Config directory changed from `~/.clawdbot/` to `~/.openclaw/` in version 2026.1.29. Legacy paths are auto-migrated.

See: [Prompt System](./02_prompt_system.md)

### Skills

Skills teach the agent how to use specific tools or APIs through markdown documentation:

```markdown
---
name: nano-pdf
description: Edit PDFs with natural-language instructions
metadata: {"openclaw":{"requires":{"bins":["nano-pdf"]},"install":[...]}}
---

# nano-pdf

Use `nano-pdf` to apply edits to PDF pages.

## Quick start

```bash
nano-pdf edit deck.pdf 1 "Change title to 'Q3 Results'"
```
```

See: [Skills System](./04_skills_system.md)

### Security Layers

Four security layers protect against unauthorized access:

1. **Channel Access** - DM pairing, allowlists, group policies
2. **Tool Execution** - Sandbox policies, exec approvals
3. **Gateway & Remote** - Token auth, Tailscale integration
4. **Audit** - Security scanning, file permission checks

See: [Access Control & Security](./05_access_control.md)

---

## 🛠️ Common Tasks

### Setting Up Secure DM Access

```bash
# 1. User sends DM to bot (e.g., on Discord)
User: "pair"

# 2. Bot responds with pairing code
Bot: "Your pairing code is: AB3K7MNP (expires in 1 hour)"

# 3. On server, approve the pairing
$ openclaw pairing approve AB3K7MNP
✓ Approved user 123456789012345678

# 4. User is now authorized to DM the bot
```

See: [Access Control - DM Pairing](./05_access_control.md#dm-pairing-system)

### Approving Bash Commands

```bash
# 1. Agent attempts to run bash command
Agent: Running `git status`...

# 2. If not in allowlist, OpenClaw prompts for approval
OpenClaw: Approve 'git status'? (y/n)

# 3. User approves
User: y

# 4. Command executes and is added to ~/.openclaw/exec-approvals.json
✓ Command approved and executed

# 5. Future `git` commands auto-approved (pattern matching)
```

See: [Access Control - Exec Approvals](./05_access_control.md#exec-approvals-bash-security)

### Creating a Custom Skill

```markdown
<!-- workspace/skills/my-tool/SKILL.md -->
---
name: my-tool
description: Internal deployment automation CLI
metadata: {"openclaw":{"requires":{"bins":["my-tool"]},"install":[{"kind":"download","url":"https://releases.company.com/my-tool-latest.tar.gz"}]}}
---

# my-tool

Internal deployment CLI.

## Deploy to staging

```bash
my-tool deploy --env staging --branch main
```

## Rollback

```bash
my-tool rollback --env staging --version v1.2.3
```
```

Place in `<workspace>/skills/my-tool/SKILL.md` and restart.

See: [Skills System - Creating Custom Skills](./04_skills_system.md#usage-examples)

### Running Security Audit

```bash
# Basic audit (config only)
$ openclaw security audit  # or 'openclaw' for legacy compat

# Deep audit (includes live gateway probe)
$ openclaw security audit --deep

# Example output:
Security Audit Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Critical: 2
Warnings: 5
Info: 3

[CRITICAL] channels.discord.dm.open
DMs are open; anyone can message the bot
→ Remediation: Use pairing/allowlist

[CRITICAL] fs.config.perms_world_readable
Config file is world-readable (mode=0644)
→ Remediation: chmod 600 .openclaw/config.yaml
```

See: [Access Control - Security Audit](./05_access_control.md#security-audit)

---

## 📁 Repository Structure

```
openclaw/
├── src/
│   ├── agents/          # Agent runtime, tools, skills
│   │   ├── pi-embedded-runner/  # Core agent execution
│   │   ├── tools/              # Built-in tools
│   │   ├── skills/             # Skills discovery
│   │   └── sandbox/            # Sandbox isolation
│   ├── channels/        # Platform adapters
│   │   ├── discord/
│   │   ├── telegram/
│   │   ├── whatsapp/
│   │   └── slack/
│   ├── gateway/         # WebSocket control plane
│   ├── security/        # Access control, audit
│   ├── pairing/         # DM pairing system
│   └── infra/           # Exec approvals, skills installation
├── skills/              # Bundled skills
├── extensions/          # Plugin system
├── docs/                # Official documentation
└── .openclaw/           # Workspace files (SOUL.md, etc.)
```

See: [Overview - Directory Structure](./01_overview.md#directory-structure)

---

## 🔗 External Resources

- **Official Repository:** https://github.com/openclaw/openclaw (repo name unchanged)
- **Official Documentation:** https://docs.openclaw.dev (formerly https://docs.clawd.bot)
- **NPM Package:** https://www.npmjs.com/package/openclaw (formerly `clawdbot`)
- **Pi Coding Agent:** https://github.com/mariozechner/pi-coding-agent
- **Claude API Docs:** https://docs.anthropic.com/claude/reference
- **Discord Bot Setup:** https://docs.openclaw.dev/channels/discord
- **Tailscale Integration:** https://docs.openclaw.dev/gateway/tailscale

---

## 🤝 Contributing to This Documentation

Found an error or want to add content?

1. Fork [YuhangTsim/public_note](https://github.com/YuhangTsim/public_note)
2. Edit files in `openclaw_learning/`
3. Submit a pull request

---

## 📝 Document Versions

| File | Last Updated | Topics Covered |
|------|--------------|----------------|
| 01_overview.md | 2026-01-26 | Architecture, tech stack, directory structure |
| 02_prompt_system.md | 2026-01-26 | SOUL.md, AGENTS.md, workspace files, prompt engineering |
| 03_tool_system.md | 2026-01-26 | Tool categories, execution, approvals, plugins |
| 04_skills_system.md | 2026-01-26 | Discovery, SKILL.md format, installation, eligibility |
| 05_access_control.md | 2026-01-26 | DM pairing, allowlists, exec approvals, sandbox, audit |
| 06_task_completion.md | 2026-01-26 | Run lifecycle, completion detection, session management |
| 09_session_storage.md | 2026-01-26 | Session persistence, JSONL logging, pruning logic |
| **10_version_history.md** | **2026-01-29** | **Version history, changelog, OpenClaw→OpenClaw migration** |
| **11_architectural_changes_2026_01_29.md** | **2026-01-29** | **Architectural & design changes in v2026.1.29** |

---

## ⚠️ Important Notes

### Security Warnings

1. **Never use `dmPolicy: open` in production** - Always use `allowlist` or `disabled`
2. **Protect your config file** - `chmod 600 ~/.openclaw/config.yaml` (or `~/.openclaw/` for legacy)
3. **Review exec-approvals regularly** - Remove unused command patterns
4. **Run security audit often** - `openclaw security audit --deep`
5. **Use strong tokens** - 32+ random characters for gateway auth
6. **⚠️ Gateway auth now required** - As of v2026.1.29, `auth: none` is removed (breaking change)

### Platform Limitations

- **WhatsApp** - Requires WhatsApp Business API or unofficial library
- **iMessage** - Mac only, requires accessibility permissions
- **Voice Wake** - Mac only, requires microphone access
- **Canvas/A2UI** - Discord and Telegram only (as of current version)

### Performance Considerations

- **Large skills directory** - Can slow startup (use bundled allowlist)
- **Many active sessions** - Increase `session.maxAge` or reduce `session.maxTurns`
- **Remote gateway** - Network latency affects tool execution speed
- **Sandbox isolation** - Adds overhead but improves security

---

## 💡 Tips & Tricks

### Efficient Skill Management

```yaml
# Use bundled skill allowlist to reduce startup time
skills:
  bundled:
    allowlist:
      - nano-pdf
      - bear-notes
      - himalaya
```

### Session Scope Isolation

```yaml
# Prevent context leakage between DM senders
session:
  dmScope: per-channel-peer
```

### Tool Timeout Configuration

```yaml
# Increase timeout for slow operations
agents:
  list:
    - id: default
      tools:
        timeout: 600000  # 10 minutes for npm install, etc.
```

### Auto-Allow Safe Commands

Edit `~/.openclaw/exec-approvals.json` (or `~/.openclaw/` for legacy):
```json
{
  "agents": {
    "default": {
      "allowlist": [
        {"pattern": "git"},
        {"pattern": "npm*"},
        {"pattern": "ls"},
        {"pattern": "cat"}
      ]
    }
  }
}
```

---

**Happy Learning! 🚀**

For questions or issues, consult the official OpenClaw documentation at https://docs.molt.bot or community resources.

---

## 🆕 What's New?

**Latest Update: 2026-01-29**

- **Major Rebrand:** Clawdbot → OpenClaw (npm package, CLI, docs all renamed)
- **New Channels:** Twitch plugin, Google Chat (beta)
- **Security:** Gateway auth now required (breaking change), SSH hardening, Windows ACL audits
- **Providers:** Venice AI, Xiaomi MiMo support
- **Telegram:** Quote replies, edit messages, stickers with vision
- **Tools:** Per-sender group policies, `tools.alsoAllow` additive allowlist
- **Architecture:** Browser control routing via gateway/node, direct gateway transport, per-account session scope

See **[Version History](./10_version_history.md)** for complete changelog and **[Architectural Changes](./11_architectural_changes_2026_01_29.md)** for design/architecture changes.
