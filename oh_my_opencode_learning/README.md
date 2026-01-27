# Oh My OpenCode Learning

Documentation and analysis of the **Oh My OpenCode** (OMO) project, a sophisticated "battery-included" configuration for OpenCode.

## 📚 Documentation Index

1. **[01_overview.md](./01_overview.md)**
   - High-level introduction.
   - Core philosophy: "Ubuntu for OpenCode".
   - Key features: Sisyphus, Ultrawork, curated MCPs.

2. **[02_architecture_and_agents.md](./02_architecture_and_agents.md)**
   - The Sisyphus orchestration model.
   - Sub-agents: Oracle, Librarian, Explore, Frontend.
   - Task workflow and delegation strategy.

3. **[03_skills_and_categories.md](./03_skills_and_categories.md)**
   - The `delegate_task` protocol.
   - Categories (`visual-engineering`, `ultrabrain`).
   - Skills (`playwright`, `git-master`) and their domains.

4. **[04_prompt_engineering.md](./04_prompt_engineering.md)**
   - Analysis of `sisyphus-prompt.md`.
   - Phase 0: Intent Gating.
   - Mandatory Justification constraints.
   - Failure recovery protocols.

## 🚀 Key Takeaways

- **Orchestration First**: OMO transforms the agent from a "coder" to a "manager" who delegates.
- **Strict Protocol**: It enforces rigid protocols (e.g., skill justification) to improve reliability.
- **Persistence**: The "Todo Continuation Enforcer" is the killer feature for long-running tasks.
- **Compatibility**: It aims to bring Claude Code's best features (MCPs, hooks) to the open-source OpenCode ecosystem.

## 🔗 Resources

- **Repository**: [github.com/code-yeongyu/oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode)
- **Discord**: [Join Community](https://discord.gg/PUwSMR9XNk)
