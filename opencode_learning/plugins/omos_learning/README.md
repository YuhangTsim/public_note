# oh-my-opencode-slim (omos) Learning

Comprehensive documentation and analysis of the **oh-my-opencode-slim** project - a lightweight, high-performance multi-agent orchestration plugin for OpenCode.

## 📚 Documentation Index

1. **[01_overview.md](./01_overview.md)**
   - Introduction and core philosophy
   - The "Pantheon" concept - six specialist agents
   - Key design principles

2. **[02_architecture_and_agents.md](./02_architecture_and_agents.md)**
   - Deep dive into the 6 Pantheon agents
   - Agent roles and responsibilities
   - System architecture and components

3. **[03_installation_and_config.md](./03_installation_and_config.md)**
   - Installation system and TUI
   - Configuration schema and dynamic model engine
   - Presets and failover chains

4. **[04_features_and_workflows.md](./04_features_and_workflows.md)**
   - Tmux integration for real-time monitoring
   - Background task system
   - Hook system for workflow enforcement

5. **[05_prompts_and_design.md](./05_prompts_and_design.md)**
   - Agent prompt engineering patterns
   - Design patterns and conventions
   - Variant system and permission parsing

6. **[06_tool_calling_design.md](./06_tool_calling_design.md)**
   - Custom tools (AST-Grep, LSP, Grep)
   - MCP integrations (Exa, Context7, Grep.app)
   - Tool calling architecture

## 🏛️ The Pantheon

| Agent | Role | Tagline |
|-------|------|---------|
| **Orchestrator** | Master Delegator | "Forged in the void of complexity" |
| **Explorer** | Codebase Reconnaissance | "The wind that carries knowledge" |
| **Oracle** | Strategic Advisor | "The voice at the crossroads" |
| **Librarian** | Knowledge Weaver | "The weaver of understanding" |
| **Designer** | Visual Guardian | "Beauty is essential" |
| **Fixer** | Fast Builder | "The final step between vision and reality" |

## 🛠 Key Commands

```bash
# Build the plugin
bun run build

# Run interactive installer
bunx oh-my-opencode-slim@latest install

# Authenticate providers
opencode auth login

# Verify all agents
ping all agents
```

## 🔗 Resources

- **Repository**: github.com/alvinunreal/oh-my-opencode-slim
- **Built with**: TypeScript, Bun, Biome
- **License**: MIT
