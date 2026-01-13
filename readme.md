# AI Coding Agent Learning Repository

Personal learning notes and research on AI coding agents, focusing on architecture, implementation patterns, and context management strategies.

## 📂 Repository Structure

### [opencode_learning/](./opencode_learning/)
Comprehensive documentation on **OpenCode** and **Oh-My-OpenCode** architecture and design.

**Topics covered:**
- Agent system architecture (build, plan, explore, oracle, librarian)
- Session lifecycle and state management
- Tool registry and execution
- Model Context Protocol (MCP) integration
- Prompt design and optimization
- OpenCode vs Oh-My-OpenCode comparison
- Task completion detection and TODO system
- LSP integration and refactoring tools

**Key documents:**
- [01_overview.md](./opencode_learning/01_overview.md) - High-level architecture
- [02_agent_system.md](./opencode_learning/02_agent_system.md) - Agent orchestration
- [06_prompt_design.md](./opencode_learning/06_prompt_design.md) - Prompt engineering
- [07_opencode_vs_oh_my_opencode.md](./opencode_learning/07_opencode_vs_oh_my_opencode.md) - Architecture comparison
- [09_task_completion_detection.md](./opencode_learning/09_task_completion_detection.md) - Task flow
- [10_todo_system.md](./opencode_learning/10_todo_system.md) - TODO tracking

See [opencode_learning/README.md](./opencode_learning/README.md) for complete documentation index.

### [roocode_learning/](./roocode_learning/)
In-depth analysis of **Roo Code** (VS Code extension) architecture, with focus on the XML → Native protocol transition.

**Topics covered:**
- System prompt structure (Architect vs Code modes)
- Native Protocol vs XML Protocol
- Tool definitions and API integration
- Skills system (Agent Skills specification)
- Conversation flow and task completion
- Error handling and malformed JSON resilience
- Incremental JSON parsing

**Key documents:**
- [architect_mode_prompt.md](./roocode_learning/architect_mode_prompt.md) - Planning mode prompt
- [code_mode_prompt.md](./roocode_learning/code_mode_prompt.md) - Implementation mode prompt
- [native_protocol_and_completion.md](./roocode_learning/native_protocol_and_completion.md) - Protocol deep dive
- [conv_example.md](./roocode_learning/conv_example.md) - Complete conversation example
- [error_handling_malformed_json.md](./roocode_learning/error_handling_malformed_json.md) - Error resilience
- [tool_definitions.md](./roocode_learning/tool_definitions.md) - Tool system architecture
- [skills_handling.md](./roocode_learning/skills_handling.md) - Extensibility via skills

See [roocode_learning/README.md](./roocode_learning/README.md) for detailed documentation map.

### [coding_agent_research/](./coding_agent_research/)
Research on context selection and management methodologies in open-source coding agents.

**Focus areas:**
- Context selection strategies given a prompt
- Context management during execution
- Comparative analysis across different agents
- Limitations and trade-offs

**Analyzed agents:**
- Cursor
- Augment
- Aider
- Continue
- Cline
- OpenHands
- Roo-Code
- And more...

See [coding_agent_research/readme.md](./coding_agent_research/readme.md) for research objectives.

## 🎯 Key Concepts Explored

### Agent Architectures
- **Primary agents** (user-facing): build, plan
- **Specialized subagents**: explore (contextual grep), oracle (expert advisor), librarian (reference search)
- **Agent orchestration**: Parallel execution, delegation patterns, background tasks

### Protocol Evolution
- **XML Protocol**: Tools embedded in system prompt (deprecated)
- **Native Protocol**: Tools passed as separate API parameter (current standard)
- **Benefits**: Token savings, type safety, cleaner parsing

### Context Management
- Session-based conversation history
- Snapshot and diff systems
- Message compaction strategies
- Tool permission systems

### Prompt Engineering
- Multi-layer prompt assembly
- Provider-specific optimizations
- Dynamic context injection
- Mode-specific behaviors (Architect vs Code)

### Task Completion
- LLM finish reason detection (stop, tool-calls, length, error)
- Streaming architecture and event processing
- TODO continuation enforcement
- Decision logic (continue vs stop vs compact)

## 🚀 Getting Started

### For Understanding OpenCode/Oh-My-OpenCode:
1. Read [opencode_learning/01_overview.md](./opencode_learning/01_overview.md) for big picture
2. Explore [opencode_learning/02_agent_system.md](./opencode_learning/02_agent_system.md) for agent orchestration
3. Review [opencode_learning/07_opencode_vs_oh_my_opencode.md](./opencode_learning/07_opencode_vs_oh_my_opencode.md) for architecture comparison

### For Understanding Roo Code:
1. Start with [roocode_learning/conv_example.md](./roocode_learning/conv_example.md) to see complete conversation flow
2. Read [roocode_learning/native_protocol_and_completion.md](./roocode_learning/native_protocol_and_completion.md) for protocol details
3. Explore mode prompts: [architect_mode_prompt.md](./roocode_learning/architect_mode_prompt.md) and [code_mode_prompt.md](./roocode_learning/code_mode_prompt.md)

### For Comparative Research:
1. Review [coding_agent_research/](./coding_agent_research/) for context management strategies
2. Compare different approaches across agents

## 📚 Documentation Statistics

- **OpenCode Learning**: 13+ comprehensive documents covering architecture, agents, tools, and prompts
- **Roo Code Learning**: 7 documents totaling ~4,375 lines of in-depth analysis
- **Coding Agent Research**: Analysis of 10+ open-source coding agents

## 🔗 External Resources

### OpenCode
- **GitHub**: [anomalyco/opencode](https://github.com/anomalyco/opencode)
- **Discord**: https://opencode.ai/discord
- **Documentation**: https://opencode.ai/docs

### Roo Code
- **VS Code Extension**: [Search "Roo Code" in VS Code Marketplace](https://marketplace.visualstudio.com/)
- **Agent Skills Spec**: https://agentskills.io/

### Research References
- Various open-source coding agent repositories (see coding_agent_research/)

## 📝 Notes

This is a personal learning repository documenting my exploration of AI coding agent architectures. The materials are organized for:

- **Understanding**: Deep dives into how these systems work
- **Comparison**: Side-by-side analysis of different approaches
- **Implementation**: Practical insights for building similar systems
- **Research**: Context management and selection strategies

## 🤝 Contributing

This is a personal learning repository. However, if you find errors or have suggestions:

1. Open an issue to discuss
2. Submit a pull request with corrections

Keep documentation accurate, clear, and well-referenced.

---

**Created**: January 2026  
**Last Updated**: January 13, 2026  
**Focus**: AI coding agent architecture, protocols, and context management
