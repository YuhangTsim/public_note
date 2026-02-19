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

4. **[08_skill_implementation_deep_dive.md](./08_skill_implementation_deep_dive.md)**
   - Technical breakdown of the skill system.
   - **5-Tier Discovery**: Remote → Plugin → Managed → Workspace → Extra.
   - **3-Tier MCP Architecture**: Built-in, Config-based, Skill-embedded.
   - **Auto-Permission Management**: Automatic `external_directory` and `read` grants.
   - **Intent-Based Loading**: Hook-driven skill injection via `UserPromptSubmit`.
   - **Skill Marketplace**: Installation and management.

5. **[09_boulder_pattern.md](./09_boulder_pattern.md)**
   - **Persistent Task State**: Tasks survive session restarts.
   - **Atomic File Storage**: With locking for parallel access.
   - **Ralph Loop**: Verification and enforcement preventing premature completion.
   - **Enhanced Schema**: `subject`, `activeForm`, `blocks`, `blockedBy` dependencies.
   - **BackgroundManager**: 1600+ lines of concurrency lifecycle management.

6. **[10_hook_architecture.md](./10_hook_architecture.md)**
   - **160+ Lifecycle Hooks**: Event-driven agent behavior modification.
   - **Hook Categories**: UserPromptSubmit, PreToolUse, PostToolUse, Stop, onSummarize.
   - **Key Hooks**: Todo Continuation Enforcer, Ralph Loop, Babysitter, Skill Loader.
   - **Self-Healing**: Error loop detection and recovery protocols.

5. **[04_prompt_engineering.md](./04_prompt_engineering.md)**
   - Analysis of `sisyphus-prompt.md`.
   - Phase 0: Intent Gating.
   - Mandatory Justification constraints.
   - Failure recovery protocols.

5. **[05_sisyphus_prompt_example.md](./05_sisyphus_prompt_example.md)**
   - **Full text** of the Sisyphus prompt with detailed annotations.
   - Breakdown of the "Identity", "Intent Gate", and "Constraints" sections.

6. **[06_orchestration_visuals.md](./06_orchestration_visuals.md)**
   - **Mermaid diagrams** visualizing the decision flow.
   - The Core Loop (Phase 0 → Phase 3).
   - The Persistence Loop (Todo Enforcer).

7. **[07_system_design_deep_dive.md](./07_system_design_deep_dive.md)**
   - Technical architecture analysis.
   - How **Hooks** enforce the Todo rules.
   - How **Context Injection** and auto-discovery work.
   - The "Ultrawork" loop mechanics.

## 🚀 Key Takeaways

- **Orchestration First**: OMO transforms the agent from a "coder" to a "manager" who delegates.
- **Strict Protocol**: It enforces rigid protocols (e.g., skill justification) to improve reliability.
- **Persistence**: The "Todo Continuation Enforcer" is the killer feature for long-running tasks.
- **Boulder Pattern**: Tasks are persistent first-class entities that survive crashes and restarts.
- **Hook-Driven**: 160+ lifecycle hooks enable sophisticated automation and self-healing.
- **Compatibility**: It aims to bring Claude Code's best features (MCPs, hooks) to the open-source OpenCode ecosystem.

## 🔗 Resources

- **Repository**: [github.com/code-yeongyu/oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode)
- **Discord**: [Join Community](https://discord.gg/PUwSMR9XNk)
