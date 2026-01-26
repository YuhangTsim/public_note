# Clawdbot Repository Research Report

**Date:** January 26, 2026  
**Repository:** https://github.com/clawdbot/clawdbot  
**License:** MIT  
**Current Version:** 2026.1.25

---

## Executive Summary

**Clawdbot** is a personal AI assistant platform that you run on your own devices. It connects to multiple messaging channels (WhatsApp, Telegram, Discord, Slack, Signal, iMessage, etc.) and provides an AI assistant powered by Claude/GPT models. The gateway acts as a control plane, while the product is the assistant itself.

Think of it as a **self-hosted AI assistant router** that brings conversational AI to all your existing communication channels.

---

## Project Purpose & Core Value Proposition

### What Problem Does It Solve?
- **Fragmented AI Interfaces**: Instead of switching between ChatGPT web, Claude web, etc., you interact with your AI assistant through channels you already use daily
- **Privacy & Control**: Self-hosted, runs on your devices, no third-party service processing your data
- **Multi-Channel Integration**: One AI assistant accessible from WhatsApp, Telegram, Discord, Slack, Signal, iMessage, and more
- **Always-On Personal Assistant**: Can speak/listen on macOS/iOS/Android, handle cron jobs, webhooks, and automation

### Key Features
1. **Multi-Channel Inbox**: Connect to 10+ messaging platforms simultaneously
2. **Local-First Gateway**: Single WebSocket control plane for all sessions, channels, tools, and events
3. **Voice Capabilities**: Always-on speech (Voice Wake + Talk Mode) on macOS/iOS/Android
4. **Live Canvas**: Agent-driven visual workspace with A2UI (Agent-to-UI)
5. **First-Class Tools**: Browser automation, canvas control, cron jobs, session management
6. **Multi-Agent Routing**: Route different channels/accounts to isolated agent workspaces
7. **Companion Apps**: macOS menu bar app, iOS/Android nodes
8. **Skills Platform**: Bundled, managed, and workspace skills with install gating

---

## Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Messaging Channels (User Interface Layer)              │
│  WhatsApp │ Telegram │ Discord │ Slack │ Signal │ etc. │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
         ┌────────────────────────┐
         │    Gateway (Control    │
         │     Plane - WS API)    │
         │  ws://127.0.0.1:18789  │
         └───────────┬────────────┘
                     │
        ┌────────────┼────────────────┐
        │            │                │
        ▼            ▼                ▼
   Pi Agent    WebChat UI      macOS/iOS/Android
   (RPC Mode)   CLI Tools          Nodes
```

### Core Components

#### 1. **Gateway Server** (`src/gateway/`)
- **WebSocket Control Plane**: Central hub for all communication
- **Session Management**: Handles isolated conversation sessions
- **Channel Registry**: Manages all connected messaging platforms
- **Tool Dispatch**: Routes tool calls to appropriate handlers
- **Config Management**: Centralized configuration system
- **Presence & Typing**: Real-time status indicators
- **Cron & Webhooks**: Automation and external triggers

#### 2. **Channels Layer** (`src/channels/`, `src/telegram/`, `src/discord/`, etc.)
Core channels (built-in):
- **WhatsApp**: via Baileys (WhatsApp Web protocol)
- **Telegram**: via grammY
- **Discord**: via discord.js
- **Slack**: via Bolt (Socket Mode)
- **Signal**: via signal-cli
- **iMessage**: via imsg (macOS only)
- **Google Chat**: via Chat API
- **WebChat**: Browser-based interface

Extension channels (plugins in `extensions/`):
- BlueBubbles, Matrix, Microsoft Teams, Zalo, Zalo Personal, Line, Mattermost, Nextcloud Talk, Nostr, and more

Each channel adapter:
- Handles authentication (OAuth, tokens, QR codes)
- Translates platform-specific messages to unified format
- Manages media uploads/downloads
- Implements platform-specific features (reactions, typing indicators, etc.)

#### 3. **Agent Runtime** (`src/agents/`)
- **Pi Agent Core**: Based on `@mariozechner/pi-agent-core` - the RPC-mode AI agent runtime
- **Embedded Runner**: Executes the AI agent in embedded mode
- **Session Lanes**: Manages parallel conversation threads
- **Tool Streaming**: Real-time tool execution updates
- **Block Streaming**: Chunked response delivery
- **History Management**: Context window and message pruning
- **Sandbox Support**: Docker-based isolation for non-main sessions

#### 4. **CLI Interface** (`src/cli/`)
Primary commands:
- `clawdbot gateway` - Start the gateway server
- `clawdbot agent` - Run the AI agent (direct mode)
- `clawdbot message send` - Send messages to channels
- `clawdbot channels login` - Authenticate with messaging platforms
- `clawdbot onboard` - Setup wizard
- `clawdbot doctor` - Health checks and diagnostics
- `clawdbot config` - Configuration management

#### 5. **Media Pipeline** (`src/media/`)
- **Store**: Local media storage and caching
- **Processing**: Image resizing, audio transcription, video handling
- **Serving**: HTTP server for media delivery
- **Understanding**: Vision and audio transcription via AI models
  - Vision: Anthropic Claude, OpenAI GPT-4V
  - Audio: OpenAI Whisper, Deepgram

#### 6. **Browser Control** (`src/browser/`)
- Dedicated Chrome/Chromium instance management
- Playwright-based automation
- Screenshot and action support
- Profile management
- CDP (Chrome DevTools Protocol) control

#### 7. **Platform Apps**
- **macOS App** (`apps/macos/`): Swift/SwiftUI menu bar app
  - Gateway control
  - Voice Wake (always-on speech trigger)
  - Talk Mode overlay
  - WebChat integration
  - System notifications
  
- **iOS App** (`apps/ios/`): Swift/SwiftUI node
  - Canvas surface
  - Voice Wake
  - Camera/screen recording
  - Bonjour pairing
  
- **Android App** (`apps/android/`): Kotlin app
  - Canvas surface
  - Talk Mode
  - Camera/screen recording
  - Optional SMS integration

---

## Technology Stack

### Core Technologies
- **Runtime**: Node.js 22+ (ESM modules)
- **Language**: TypeScript (strict mode)
- **Package Manager**: pnpm (with bun support)
- **Build Tool**: TypeScript Compiler (tsc)
- **Testing**: Vitest with V8 coverage
- **Linting/Formatting**: Oxlint + Oxfmt

### Key Dependencies

#### AI & Agent Runtime
- `@mariozechner/pi-agent-core` - Pi agent runtime
- `@mariozechner/pi-ai` - AI model abstractions
- `@mariozechner/pi-coding-agent` - Coding capabilities
- `@mariozechner/pi-tui` - Terminal UI

#### Messaging Platforms
- `@whiskeysockets/baileys` - WhatsApp Web protocol
- `grammy` - Telegram Bot API
- `discord.js` (via types) - Discord Bot API
- `@slack/bolt` - Slack Socket Mode
- `@line/bot-sdk` - LINE messaging

#### WebSocket & HTTP
- `ws` - WebSocket server
- `express` - HTTP server
- `hono` - Lightweight web framework
- `undici` - HTTP client

#### Media Processing
- `sharp` - Image manipulation
- `pdfjs-dist` - PDF parsing
- `@napi-rs/canvas` - Canvas rendering
- `node-edge-tts` - Text-to-speech

#### Browser Automation
- `playwright-core` - Browser control
- `chromium-bidi` - BiDi protocol

#### Database & Storage
- `sqlite-vec` - Vector database
- `proper-lockfile` - File locking

#### UI Frameworks (Apps)
- **macOS/iOS**: Swift, SwiftUI
- **Android**: Kotlin, Jetpack Compose
- **Web UI**: Lit (Web Components)

---

## Code Organization

### Source Structure (`src/`)

```
src/
├── agents/           # AI agent runtime and Pi integration
├── auto-reply/       # Automated response handling
├── browser/          # Browser automation tools
├── canvas-host/      # Canvas/A2UI host
├── channels/         # Channel abstraction layer
├── cli/              # CLI commands and interface
├── commands/         # In-chat commands (/status, /reset, etc.)
├── config/           # Configuration system
├── cron/             # Scheduled tasks
├── daemon/           # Background process management
├── discord/          # Discord channel adapter
├── gateway/          # Gateway server core
├── hooks/            # Plugin hooks system
├── imessage/         # iMessage channel adapter
├── infra/            # Infrastructure utilities
├── line/             # LINE channel adapter
├── logging/          # Structured logging
├── media/            # Media pipeline
├── media-understanding/  # Vision & audio transcription
├── memory/           # Conversation memory/RAG
├── node-host/        # Device node hosting
├── pairing/          # Device/channel pairing
├── plugins/          # Plugin system
├── process/          # Process management
├── routing/          # Message routing
├── security/         # Security & allowlists
├── sessions/         # Session management
├── signal/           # Signal channel adapter
├── slack/            # Slack channel adapter
├── telegram/         # Telegram channel adapter
├── terminal/         # Terminal UI utilities
├── tts/              # Text-to-speech
├── web/              # Web UI and WebChat
├── whatsapp/         # WhatsApp channel adapter
└── wizard/           # Onboarding wizard
```

### Configuration Files

- **`package.json`** - Node.js package manifest, scripts, dependencies
- **`tsconfig.json`** - TypeScript compiler configuration
- **`vitest.config.ts`** - Test configuration
- **`~/.clawdbot/clawdbot.json`** - User configuration (runtime)
- **`.env`** - Environment variables (optional)

### Documentation (`docs/`)
Comprehensive Mintlify documentation at https://docs.clawd.bot/
- Channels guides (`docs/channels/`)
- Platform guides (`docs/platforms/`)
- Gateway operations (`docs/gateway/`)
- Concepts and architecture
- Tool and skill documentation

### Extensions (`extensions/`)
Plugin-based extensions for:
- Additional messaging channels (msteams, matrix, zalo, etc.)
- Memory backends (lancedb)
- Authentication providers (Google Gemini, Qwen Portal)
- Specialized tools (diagnostics, voice-call)

---

## Workflow & Data Flow

### 1. **Gateway Startup Flow**

```
User runs: clawdbot gateway

1. Load configuration (~/.clawdbot/clawdbot.json + env vars)
2. Start Gateway WebSocket server (default: ws://127.0.0.1:18789)
3. Initialize channel adapters (WhatsApp, Telegram, Discord, etc.)
4. Load plugins and extensions
5. Start media server
6. Initialize browser control (if enabled)
7. Setup cron jobs and webhooks
8. Register with Bonjour/mDNS (if enabled)
9. Start Control UI web server
10. Ready to receive messages
```

### 2. **Message Processing Flow**

```
Incoming message from WhatsApp/Telegram/etc.

1. Channel adapter receives raw message
   ↓
2. Translate to unified InboundMessage format
   ↓
3. Security checks:
   - Allowlist verification
   - Pairing validation (for DMs)
   - Command gating
   ↓
4. Route to session:
   - Determine session key (user, group, channel)
   - Create or load existing session
   ↓
5. Media processing (if attachments):
   - Download media
   - Store locally
   - Run vision/audio understanding
   ↓
6. Queue message to Pi agent:
   - Add to session history
   - Trigger agent run
   ↓
7. Agent processes message:
   - Generate response
   - Execute tools (if needed)
   - Stream blocks back
   ↓
8. Response delivery:
   - Format for target channel
   - Apply chunking rules
   - Send via channel adapter
   ↓
9. Update session state:
   - Save transcript
   - Update usage metrics
   - Trigger presence updates
```

### 3. **Tool Execution Flow**

```
Agent calls a tool (e.g., browser_navigate)

1. Tool request via Pi agent RPC
   ↓
2. Gateway receives tool call
   ↓
3. Route to tool handler:
   - browser.* → Browser control
   - canvas.* → Canvas host
   - node.* → Device node
   - sessions.* → Session tools
   - discord.* → Discord actions
   ↓
4. Execute tool:
   - Validate parameters
   - Check permissions (sandbox rules)
   - Perform action
   ↓
5. Return result to agent
   ↓
6. Agent continues processing
```

### 4. **Session Management**

Sessions are isolated conversation contexts:

- **Session Key Format**: `{channel}:{chatId}` or `{channel}:group:{groupId}`
- **Main Session**: Direct messages to the owner
- **Group Sessions**: Isolated contexts per group
- **Non-Main Sessions**: Can run in Docker sandboxes for security

Session data stored in:
- `~/.clawdbot/sessions/` - Pi agent session files
- `~/.clawdbot/agents/{agentId}/sessions/` - Agent-specific sessions

### 5. **Configuration System**

Configuration is hierarchical:
1. **Defaults** - Hard-coded sensible defaults
2. **Config File** - `~/.clawdbot/clawdbot.json`
3. **Environment Variables** - Override config (e.g., `TELEGRAM_BOT_TOKEN`)
4. **CLI Flags** - Highest priority (e.g., `--port 8080`)

Example configuration structure:
```json
{
  "agent": {
    "model": "anthropic/claude-opus-4-5",
    "workspace": "~/clawd"
  },
  "gateway": {
    "bind": "loopback",
    "port": 18789,
    "mode": "local"
  },
  "channels": {
    "telegram": {
      "botToken": "123456:ABCDEF",
      "allowFrom": ["+1234567890"]
    },
    "whatsapp": {
      "allowFrom": ["*"],
      "groups": {
        "*": {
          "requireMention": true
        }
      }
    }
  },
  "browser": {
    "enabled": true,
    "controlUrl": "http://127.0.0.1:18791"
  }
}
```

---

## Development Workflow

### Setup & Installation

```bash
# Clone repository
git clone https://github.com/clawdbot/clawdbot.git
cd clawdbot

# Install dependencies
pnpm install

# Build UI
pnpm ui:build

# Build TypeScript
pnpm build

# Run onboarding wizard
pnpm clawdbot onboard --install-daemon
```

### Development Commands

```bash
# Run CLI in dev mode (auto-reload)
pnpm gateway:watch

# Run specific CLI command
pnpm clawdbot <command>

# Run tests
pnpm test

# Run tests with coverage
pnpm test:coverage

# Lint code
pnpm lint

# Format code
pnpm format:fix

# Build macOS app
pnpm mac:package

# Build iOS app
pnpm ios:build

# Build Android app
pnpm android:assemble
```

### Testing Strategy

- **Unit Tests**: Colocated `*.test.ts` files
- **E2E Tests**: `*.e2e.test.ts` files
- **Live Tests**: Real API integration tests (requires credentials)
- **Docker Tests**: Full integration tests in containers
- **Coverage Target**: 70% lines/branches/functions/statements

### Release Channels

1. **Stable** (`latest`): Tagged releases (e.g., `v2026.1.25`)
2. **Beta** (`beta`): Pre-release tags (e.g., `v2026.1.25-beta.1`)
3. **Dev** (`dev`): Moving HEAD on `main` branch

### Commit & PR Workflow

- Use `scripts/committer` for commits (enforces scoped staging)
- Follow Conventional Commits (e.g., "feat: add new channel")
- Group related changes, avoid bundling unrelated refactors
- Update CHANGELOG.md with user-facing changes
- Run full gate before merging: `pnpm lint && pnpm build && pnpm test`

---

## Key Architectural Patterns

### 1. **Plugin-Based Architecture**
- Core functionality in `src/`
- Extensions in `extensions/` as workspace packages
- Plugin SDK exposed via `clawdbot/plugin-sdk`
- Dynamic plugin loading via registry

### 2. **Dependency Injection**
- `createDefaultDeps()` pattern throughout
- Enables testing and modularity
- Allows swapping implementations

### 3. **Event-Driven**
- Gateway emits events for all state changes
- Channels listen and react
- Decoupled communication

### 4. **Type-Safe Configuration**
- TypeBox schemas for all config
- Runtime validation with Ajv
- Type inference from schemas

### 5. **Channel Abstraction**
- Unified `InboundMessage` and `OutboundMessage` types
- Platform-specific adapters
- Common routing and security layer

### 6. **Sandbox Isolation**
- Docker-based sandboxes for non-main sessions
- Configurable tool allowlists/denylists
- Security by default

### 7. **Media Pipeline**
- Unified media handling across channels
- Local storage with TTL
- AI-powered understanding (vision, audio)
- HTTP serving with authentication

---

## Security Model

### Default Security Posture

1. **DM Pairing** (`dmPolicy="pairing"`):
   - Unknown senders receive pairing code
   - Must be approved via `clawdbot pairing approve`
   - Prevents unauthorized access

2. **Allowlists**:
   - Per-channel allowlists (`allowFrom`)
   - Group allowlists (`groups`)
   - Wildcard `"*"` requires explicit opt-in

3. **Sandbox Mode**:
   - Non-main sessions run in Docker containers
   - Limited tool access (configurable)
   - Isolated file system

4. **Credential Storage**:
   - Stored in `~/.clawdbot/credentials/`
   - Platform-specific auth (OAuth, tokens, QR codes)
   - Never committed to git

### Tool Security

Default sandbox rules for non-main sessions:
- **Allowed**: bash, process, read, write, edit, sessions_*
- **Denied**: browser, canvas, nodes, cron, discord, gateway

---

## Integration Points

### External AI Providers
- **Anthropic**: Claude Pro/Max (OAuth + API keys)
- **OpenAI**: ChatGPT/Codex (API keys)
- **Google**: Gemini (via extensions)
- **AWS Bedrock**: Via AWS SDK
- **Local LLMs**: via Ollama or llama.cpp

### Messaging Platforms
- **WhatsApp**: Baileys (reverse-engineered web protocol)
- **Telegram**: Official Bot API
- **Discord**: Official Bot API
- **Slack**: Official Bolt SDK (Socket Mode)
- **Signal**: signal-cli (linked device)
- **iMessage**: imsg (macOS system integration)
- **Google Chat**: Official Chat API

### Media Understanding
- **Vision**: Anthropic Claude Vision, OpenAI GPT-4V
- **Audio Transcription**: OpenAI Whisper, Deepgram
- **TTS**: ElevenLabs (via node-edge-tts)

### Automation
- **Cron Jobs**: Built-in scheduler (croner)
- **Webhooks**: HTTP endpoints for external triggers
- **Gmail Pub/Sub**: Email event triggers

### Remote Access
- **Tailscale Serve/Funnel**: Secure gateway exposure
- **SSH Tunnels**: Alternative remote access
- **Bonjour/mDNS**: Local network discovery

---

## Notable Design Decisions

### 1. **WebSocket Control Plane**
Why: Single persistent connection for all clients (UI, CLI, nodes, apps)
- Real-time bidirectional communication
- Efficient for presence, typing, streaming
- Avoids polling

### 2. **Pi Agent Runtime**
Why: Based on Mario Zechner's pi-mono (proven agent runtime)
- RPC mode for embedded execution
- Tool streaming and block streaming
- Session management built-in

### 3. **Local-First Architecture**
Why: Privacy, control, offline capability
- No third-party service required
- Data stays on your devices
- Works on local network

### 4. **Multi-Channel Support**
Why: Meet users where they are
- No app switching needed
- Leverage existing habits
- Platform flexibility

### 5. **Plugin System**
Why: Extensibility without bloating core
- Community can add channels
- Keep core lean
- Opt-in features

### 6. **TypeScript + Strict Mode**
Why: Type safety at scale
- Catch errors at compile time
- Better IDE support
- Refactoring confidence

### 7. **Colocated Tests**
Why: Tests near code they test
- Easier to find and maintain
- Encourages test writing
- Clear relationship

---

## Common Operations

### Starting the Gateway
```bash
clawdbot gateway run --port 18789 --verbose
```

### Sending a Message
```bash
clawdbot message send --to +1234567890 --message "Hello!"
```

### Running the Agent (Direct)
```bash
clawdbot agent --message "What's the weather?" --thinking high
```

### Logging into a Channel
```bash
# WhatsApp (QR code)
clawdbot channels login whatsapp

# Telegram (with token)
clawdbot config set channels.telegram.botToken "123456:ABCDEF"
```

### Health Check
```bash
clawdbot doctor
```

### Configuration
```bash
# View current config
clawdbot config list

# Set a value
clawdbot config set agent.model "anthropic/claude-opus-4-5"

# Get a value
clawdbot config get agent.model
```

---

## Build & Deployment

### Production Build
```bash
pnpm install
pnpm ui:build
pnpm build
```

### Installation Methods
1. **npm Global**: `npm install -g clawdbot@latest`
2. **From Source**: `git clone && pnpm install && pnpm build`
3. **Docker**: `docker-compose up` (see `docker-compose.yml`)
4. **Nix**: Declarative config via Nix flakes

### Platform-Specific

#### macOS App
- Build: `pnpm mac:package`
- Requires: Xcode, signing certificate
- Output: `dist/Clawdbot.app`
- Install: Drag to Applications folder

#### iOS App
- Build: `pnpm ios:build`
- Requires: Xcode, iOS Developer account
- Deploy via Xcode or TestFlight

#### Android App
- Build: `pnpm android:assemble`
- Requires: Android Studio, SDK
- Output: `apps/android/app/build/outputs/apk/`
- Install: `adb install` or Google Play

### Daemon Installation
```bash
clawdbot onboard --install-daemon
```

This installs a system service:
- **macOS**: launchd user agent
- **Linux**: systemd user service
- **Windows**: Not supported (use WSL2)

---

## Learning Resources

### Official Documentation
- **Main Docs**: https://docs.clawd.bot
- **Getting Started**: https://docs.clawd.bot/start/getting-started
- **Configuration**: https://docs.clawd.bot/gateway/configuration
- **Channels**: https://docs.clawd.bot/channels
- **Architecture**: https://docs.clawd.bot/concepts/architecture

### Community
- **Discord**: https://discord.gg/clawd
- **GitHub**: https://github.com/clawdbot/clawdbot
- **Website**: https://clawdbot.com

### Key Files to Read
1. `README.md` - Overview and quick start
2. `AGENTS.md` - Repository guidelines and patterns
3. `CONTRIBUTING.md` - Contribution guidelines
4. `src/entry.ts` - CLI entry point
5. `src/gateway/server.impl.ts` - Gateway server core
6. `src/agents/pi-embedded-runner/run.ts` - Agent runtime

---

## Development Tips

### 1. **Use the Wizard**
The onboarding wizard (`clawdbot onboard`) is the easiest way to get started. It handles:
- Gateway setup
- Channel configuration
- Model selection
- Daemon installation

### 2. **Watch Mode for Development**
```bash
pnpm gateway:watch
```
Auto-reloads on TypeScript changes.

### 3. **Check Logs**
Gateway logs show everything:
```bash
tail -f ~/.clawdbot/logs/gateway.log
```

On macOS:
```bash
./scripts/clawlog.sh
```

### 4. **Use Doctor for Diagnostics**
```bash
clawdbot doctor
```
Checks for misconfigurations, security issues, and provides migration guidance.

### 5. **Test in Docker**
Isolated testing environment:
```bash
pnpm test:docker:onboard
pnpm test:docker:gateway-network
```

### 6. **Read the Code**
The codebase follows consistent patterns:
- Dependency injection via `createDefaultDeps()`
- Type-safe configs with TypeBox
- Colocated tests
- Clear module boundaries

---

## Glossary

- **Gateway**: The WebSocket control plane server
- **Channel**: A messaging platform integration (WhatsApp, Telegram, etc.)
- **Session**: An isolated conversation context
- **Node**: A device that provides tools (macOS/iOS/Android apps)
- **Pi Agent**: The AI agent runtime (based on pi-mono)
- **Canvas**: Agent-driven visual workspace (A2UI)
- **Voice Wake**: Always-on speech trigger
- **Talk Mode**: Continuous voice conversation
- **Pairing**: Security mechanism for DM authorization
- **Allowlist**: Permitted users/groups for a channel
- **Skill**: A plugin that adds capabilities to the agent
- **Sandbox**: Docker-based isolation for non-main sessions
- **Main Session**: Direct messages to the owner (trusted)
- **Non-Main Session**: Group chats or other users (potentially untrusted)

---

## Quick Reference

### File Locations
- Config: `~/.clawdbot/clawdbot.json`
- Credentials: `~/.clawdbot/credentials/`
- Sessions: `~/.clawdbot/sessions/`
- Logs: `~/.clawdbot/logs/`
- Workspace: `~/clawd/` (default)

### Default Ports
- Gateway WS: `18789`
- Control UI: `18789` (same as WS)
- Browser Control: `18791`
- Media Server: Dynamic

### Environment Variables
- `TELEGRAM_BOT_TOKEN` - Telegram bot token
- `DISCORD_BOT_TOKEN` - Discord bot token
- `SLACK_BOT_TOKEN` - Slack bot token
- `SLACK_APP_TOKEN` - Slack app token
- `CLAWDBOT_SKIP_CHANNELS` - Skip channel initialization (dev mode)
- `CLAWDBOT_PROFILE` - Use specific config profile

---

## Conclusion

Clawdbot is a **comprehensive personal AI assistant platform** that brings the power of modern LLMs to your existing communication channels. Its architecture is:

- **Modular**: Plugin-based, extensible
- **Secure**: Sandboxing, allowlists, pairing
- **Local-First**: Privacy and control
- **Multi-Platform**: Works everywhere you are
- **Well-Tested**: High coverage, CI/CD
- **Well-Documented**: Extensive docs and guides

The repository is actively maintained, welcomes contributions (including AI-assisted PRs), and has a growing community on Discord.

**Next Steps for Learning:**
1. Clone the repo and run `pnpm install`
2. Run `clawdbot onboard` to see the wizard
3. Read through `src/gateway/server.impl.ts` to understand the core
4. Explore a channel adapter (e.g., `src/telegram/`) to see integration
5. Check out the docs at https://docs.clawd.bot

---

**Report Generated By:** Antigravity AI (Sisyphus Agent)  
**Source:** Direct codebase analysis + documentation review  
**Last Updated:** January 26, 2026
