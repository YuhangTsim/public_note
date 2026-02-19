# Installation and Configuration

Oh My OpenCode Slim features a streamlined installation process and a flexible configuration system designed for both ease of use and deep customization.

## Installation

The primary way to install OMOS is via the dedicated CLI installer:

```bash
bunx oh-my-opencode-slim@latest install
```

### Installer Options
The installer supports various flags for non-interactive setup:

| Flag | Description |
|------|-------------|
| `--no-tui` | Non-interactive mode (requires all flags) |
| `--opencode-free=yes` | Use OpenCode free models (`opencode/*`) |
| `--kimi=yes` | Enable Kimi API access |
| `--openai=yes` | Enable OpenAI API access |
| `--antigravity=yes` | Enable Antigravity (Google) models |
| `--chutes=yes` | Enable Chutes models |
| `--tmux=yes` | Enable tmux integration |
| `--skills=yes` | Install recommended skills (e.g., Cartography) |
| `--models-only` | Update model assignments only |

### Post-Installation
After installation, authenticate with OpenCode:

```bash
opencode auth login
```

Verify the setup by running:
```bash
ping all agents
```

---

## Configuration

The configuration is stored in `~/.config/opencode/oh-my-opencode-slim.json` (or `.jsonc`).

### Key Configuration Sections

#### 1. Agent Overrides
You can assign specific models to each agent in the Pantheon:

```json
{
  "agents": {
    "orchestrator": { "model": "kimi-for-coding/k2p5" },
    "oracle": { "model": "openai/gpt-5.2-codex" },
    "explorer": { "model": "google/gemini-3-flash" }
  }
}
```

#### 2. Tmux Settings
Enable or disable the visual monitoring system:

```json
{
  "tmux": {
    "enabled": true,
    "sessionName": "opencode-agents"
  }
}
```

#### 3. Background Tasks
Configure concurrency and timeouts for background operations:

```json
{
  "background": {
    "maxConcurrentStarts": 10
  },
  "fallback": {
    "enabled": true,
    "timeoutMs": 30000
  }
}
```

#### 4. MCP Management
Enable or disable specific Model Context Protocol (MCP) servers:

```json
{
  "disabled_mcps": ["some-unwanted-mcp"]
}
```

---

## Model Providers

OMOS supports a wide range of providers, allowing for a "Hybrid Mode" that balances cost and intelligence:

- **OpenCode Free**: Uses `opencode/*` models. The installer applies coding-first selection logic.
- **Kimi**: High-performance coding models.
- **OpenAI**: Industry-standard GPT models.
- **Antigravity**: Google Gemini models (excellent for large context).
- **Chutes**: Specialized models with daily-cap awareness.
- **Hybrid Mode**: Combines OpenCode free models for support roles (Explorer, Fixer) with premium models for reasoning roles (Orchestrator, Oracle).
