# Installation and Configuration

## Installation System

The omos installer is a sophisticated TUI (Text User Interface) that automates the entire setup process.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    INSTALLATION FLOW                                         │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐
│   START         │─── bunx oh-my-opencode-slim@latest install
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 1. DETECT       │─── Check for existing providers
│    PROVIDERS    │    • Kimi (KIMI_API_KEY)
└────────┬────────┘    • OpenAI (OPENAI_API_KEY)
         │              • Anthropic
         │              • Copilot
         │              • And more...
         ▼
┌─────────────────┐
│ 2. DISCOVER     │─── opencode models --refresh --verbose
│    MODELS       │    • Filter free opencode/* models
└────────┬────────┘    • Detect provider models
         │              • Build available model list
         ▼
┌─────────────────┐
│ 3. FETCH        │─── Artificial Analysis API
│    SIGNALS      │    • Quality scores
└────────┬────────┘    • Speed benchmarks
         │              • Price data
         ▼
┌─────────────────┐
│ 4. PLAN         │─── Dynamic agent-to-model mapping
│    AGENTS       │    • Orchestrator → High-IQ model
└────────┬────────┘    • Explorer → Fast/cheap model
         │              • etc.
         ▼
┌─────────────────┐
│ 5. INSTALL      │─── Write config file
│    CONFIG       │    • Install skills (cartography, simplify)
└────────┬────────┘    • Set up hooks
         │
         ▼
┌─────────────────┐
│ 6. VERIFY       │─── Run diagnostic checks
│                 │    • Provider connectivity
└─────────────────┘    • Model availability
```

### Quick Install Commands

```bash
# Interactive TUI installer
bunx oh-my-opencode-slim@latest install

# Automated install with specific providers
bunx oh-my-opencode-slim@latest install \
  --no-tui \
  --kimi=yes \
  --openai=yes \
  --antigravity=yes \
  --chutes=yes \
  --opencode-free=yes \
  --opencode-free-model=auto \
  --tmux=no \
  --skills=yes
```

## Configuration System

### Configuration File Location

```
~/.config/opencode/oh-my-opencode-slim.json
# or
~/.config/opencode/oh-my-opencode-slim.jsonc  (with comments support)
```

### Configuration Schema

```typescript
// src/config/schema.ts

export const ConfigSchema = z.object({
  // Model assignments for each agent
  agents: z.record(z.object({
    primary: z.string(),      // Primary model (e.g., "kimi-for-coding/k2p5")
    fallback: z.string(),     // Fallback model
    temperature: z.number().optional(),
  })),
  
  // Preset configuration
  preset: z.enum(['speed', 'quality', 'balanced', 'custom']).optional(),
  
  // Tmux settings
  tmux: z.object({
    enabled: z.boolean(),
    layout: z.enum(['main-vertical', 'main-horizontal', 'tiled']),
  }),
  
  // Feature flags
  features: z.object({
    backgroundTasks: z.boolean(),
    autoUpdate: z.boolean(),
    hooks: z.boolean(),
  }),
})
```

### Example Configuration

```json
{
  "agents": {
    "orchestrator": {
      "primary": "kimi-for-coding/k2p5",
      "fallback": "openai/gpt-5.1-codex-mini"
    },
    "explorer": {
      "primary": "cerebras/zai-glm-4.7",
      "fallback": "google/gemini-3-flash"
    },
    "oracle": {
      "primary": "openai/gpt-5.2-codex",
      "fallback": "kimi-for-coding/k2p5"
    },
    "librarian": {
      "primary": "google/gemini-3-flash",
      "fallback": "openai/gpt-5.1-codex-mini"
    },
    "designer": {
      "primary": "google/gemini-3-flash",
      "fallback": "openai/gpt-5.1-codex-mini"
    },
    "fixer": {
      "primary": "cerebras/zai-glm-4.7",
      "fallback": "google/gemini-3-flash"
    }
  },
  "preset": "balanced",
  "tmux": {
    "enabled": true,
    "layout": "main-vertical"
  },
  "features": {
    "backgroundTasks": true,
    "autoUpdate": true,
    "hooks": true
  }
}
```

## Dynamic Model Selection Engine

The dynamic planner fetches real-time signals to optimize model assignments.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    DYNAMIC MODEL SELECTION                                   │
└─────────────────────────────────────────────────────────────────────────────┘

External Signals:
┌───────────────────────┐    ┌───────────────────────┐
│  Artificial Analysis  │    │     OpenRouter        │
│                       │    │                       │
│  • Quality scores     │    │  • Price data         │
│  • Speed benchmarks   │    │  • Availability       │
│  • Context window     │    │  • Provider status    │
└───────────┬───────────┘    └───────────┬───────────┘
            │                            │
            └────────────┬───────────────┘
                         ▼
            ┌───────────────────────┐
            │   SCORING ENGINE      │
            │   (src/cli/scoring-v2/)│
            │                       │
            │  Score = f(quality,   │
            │           speed,      │
            │           price,      │
            │           reliability)│
            └───────────┬───────────┘
                        ▼
            ┌───────────────────────┐
            │   AGENT MAPPING       │
            │                       │
            │  Orchestrator: High-Q │
            │  Explorer: Fast/Cheap │
            │  Oracle: Max Quality  │
            │  etc...               │
            └───────────┬───────────┘
                        ▼
            ┌───────────────────────┐
            │   CONFIG OUTPUT       │
            │                       │
            │  oh-my-opencode-slim  │
            │  .json                │
            └───────────────────────┘
```

### Scoring Factors

| Factor | Weight | Description |
|--------|--------|-------------|
| Quality | 40% | MMLU, HumanEval scores |
| Speed | 25% | Tokens/second |
| Price | 20% | Cost per 1M tokens |
| Reliability | 15% | Uptime, consistency |

### Presets

```typescript
// Preset configurations for different optimization targets

const PRESETS = {
  speed: {
    // Optimize for fastest response
    explorer: 'cerebras/zai-glm-4.7',  // 1800+ tok/sec
    fixer: 'cerebras/zai-glm-4.7',
    orchestrator: 'google/gemini-3-flash',
  },
  
  quality: {
    // Optimize for best output quality
    orchestrator: 'openai/gpt-5.2-codex',
    oracle: 'openai/gpt-5.2-codex',
    fixer: 'kimi-for-coding/k2p5',
  },
  
  balanced: {
    // Balance quality and cost
    orchestrator: 'kimi-for-coding/k2p5',
    explorer: 'google/gemini-3-flash',
    fixer: 'cerebras/zai-glm-4.7',
  },
  
  custom: {
    // User-defined mappings
    // From config file
  }
}
```

## Model Selection Modes

### OpenCode Free Mode

```bash
# Use only free OpenCode models
bunx oh-my-opencode-slim install --opencode-free=yes --opencode-free-model=auto
```

Features:
- Filters to `opencode/*` models only
- Can use multiple free models across agents
- No external API keys required

### Hybrid Mode

```bash
# Combine OpenCode free with external providers
bunx oh-my-opencode-slim install \
  --opencode-free=yes \
  --kimi=yes \
  --openai=yes
```

Features:
- Uses OpenCode free for appropriate agents
- Delegates to Kimi/OpenAI for complex tasks
- `designer` stays on external provider for better UI results

### Chutes Mode

```bash
# Use Chutes AI for decentralized inference
bunx oh-my-opencode-slim install --chutes=yes
```

Features:
- Auto-selects primary/support models
- Daily cap awareness (300/2000/5000)
- Distributed inference

## Failover and Reliability

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    FAILOVER CHAIN                                          │
└─────────────────────────────────────────────────────────────────────────────┘

Agent Request
     │
     ▼
┌─────────────────┐
│ Primary Model   │────┐
│ (kimi/k2p5)     │    │
└────────┬────────┘    │
         │ Success     │ Failure/Timeout
         ▼             │
    [Process]         ▼
              ┌─────────────────┐
              │ Fallback Model  │────┐
              │ (openai/gpt-5)  │    │
              └────────┬────────┘    │
                       │ Success     │ Failure
                       ▼             │
                  [Process]          ▼
                            ┌─────────────────┐
                            │ Default Model   │
                            │ (gemini-flash)  │
                            └────────┬────────┘
                                     │
                                     ▼
                                [Process]
```

### Balanced Spend

The system can distribute usage across multiple providers to maximize subscription value:

```typescript
// Example: Rotate between providers
const balancedStrategy = {
  orchestrator: ['kimi/k2p5', 'openai/gpt-5.2-codex'],  // Alternate
  explorer: ['cerebras/zai-glm-4.7'],  // Always use (cheap)
  fixer: ['google/gemini-3-flash', 'cerebras/zai-glm-4.7'],  // Distribute
}
```

## CLI Commands

### Configuration Management

```bash
# Re-run installer to update configuration
bunx oh-my-opencode-slim install

# Validate current configuration
bunx oh-my-opencode-slim validate

# Show current agent-to-model mappings
bunx oh-my-opencode-slim show-plan

# Export configuration
bunx oh-my-opencode-slim export-config > my-config.json

# Import configuration
bunx oh-my-opencode-slim import-config my-config.json
```

### Agent Testing

```bash
# Test all agents
ping all agents

# Test specific agent
ping orchestrator
ping explorer

# Test with verbose output
ping all agents --verbose
```

## Per-Project Configuration

Override global settings per project using `.opencode/config.toml`:

```toml
[omos]
preset = "quality"  # Use quality preset for this project

[omos.agents.orchestrator]
primary = "openai/gpt-5.2-codex"  # Override for this project

[omos.tmux]
enabled = false  # Disable tmux for this project
```
