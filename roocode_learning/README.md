# Roo-Code Learning Materials

> **Version**: Based on Roo-Code v3.43.0 (January 2026)  
> **Breaking Change**: XML Protocol REMOVED. Native OpenAI-format tool calling is now the ONLY supported method.
> **Repository**: [Roo-Code on GitHub](https://github.com/RooVetGit/Roo-Cline)

Comprehensive learning materials for understanding Roo-Code's architecture, implementation patterns, and advanced features.

---

## 📚 Quick Navigation

### Start Here
- **[00_complete_guide.md](00_complete_guide.md)** - Comprehensive guide covering all critical topics (30KB)
- **[01_overview.md](01_overview.md)** - High-level architecture overview

### By Topic
- **Architecture** → 01, 02, 03, 07
- **Tool System** → 04, 08, 09, 10
- **Message Handling** → 05, 08, 09
- **Task Management** → 03, 10, 11
- **Advanced Features** → 12, 13, 14, 15, 16

---

## 🎯 Learning Paths

### Path 1: New Users (2-3 hours)
**Goal**: Understand what Roo-Code is and how to use it effectively

```
1. Read: 01_overview.md
   ↓ Learn: High-level architecture, what makes Roo different
   
2. Read: 02_mode_system.md
   ↓ Learn: Built-in modes, when to use each
   
3. Read: 06_skills_system.md
   ↓ Learn: How skills extend Roo's capabilities
   
4. Skim: 00_complete_guide.md
   ↓ Reference: Deep dive when needed
```

**Outcome**: Can effectively use Roo-Code modes and understand core concepts

---

### Path 2: Contributors (4-6 hours)
**Goal**: Understand codebase structure to contribute features or fixes

```
1. Read: 01_overview.md
   ↓ Foundation: Architecture overview
   
2. Read: 03_task_lifecycle.md
   ↓ Core: How tasks execute (recursivelyMakeClineRequests)
   
3. Read: 04_tool_system.md + 08_native_protocol.md
   ↓ Critical: Tool validation, protocol handling
   
4. Read: 05_dual_history.md
   ↓ Important: UI vs API messages (common confusion point)
   
5. Read: 09_message_parsing.md
   ↓ Implementation: How malformed JSON is handled
   
6. Read: 13_provider_integration.md
   ↓ Integration: How to add new LLM providers
   
7. Code exploration with docs as reference
```

**Outcome**: Can navigate codebase, understand core loops, make meaningful contributions

---

### Path 3: Researchers / Advanced Developers (6-8 hours)
**Goal**: Deep understanding of architecture, design decisions, and implementation patterns

```
1. Read: 00_complete_guide.md (all sections)
   ↓ Foundation: Complete mental model
   
2. Read in sequence: 01 → 16
   ↓ Depth: Each topic in detail
   
3. Cross-reference with source code:
   - src/core/task/Task.ts (4000 lines)
   - src/core/tools/validateToolUse.ts
   - src/core/assistant-message/
   - src/core/webview/ClineProvider.ts
   
4. Study edge cases:
   - Error recovery (09_message_parsing.md)
   - Context management (12_context_management.md)
   - Task delegation (11_todo_and_subtasks.md)
```

**Outcome**: Complete understanding, can architect similar systems or extend significantly

---

## 📖 Document Index

### Core Architecture

| Doc | Topic | Priority | Size | Key Concepts |
|-----|-------|----------|------|--------------|
| **00** | **Complete Guide** | ⭐ Critical | 30KB | All 4 critical requirements covered |
| **01** | Overview | ⭐ High | 14KB | Architecture, dual-history, VSCode integration |
| **02** | Mode System | ⭐ High | 14KB | 5 built-in modes, tool groups, custom modes |
| **03** | Task Lifecycle | ⭐ High | 16KB | Task creation, agentic loop, state management |

### Tool & Protocol System

| Doc | Topic | Priority | Size | Key Concepts |
|-----|-------|----------|------|--------------|
| **04** | Tool System | ⭐ High | 9KB | Tool validation, execution, error recovery |
| **08** | Native Protocol | ⭐ High | 2KB | Native-only (XML removed), malformed JSON handling |
| **09** | Message Parsing | Medium | 6KB | Parser implementation, error recovery |
| **10** | Task Completion | Medium | 6KB | AttemptCompletionTool, validation |

### Message & History Management

| Doc | Topic | Priority | Size | Key Concepts |
|-----|-------|----------|------|--------------|
| **05** | Dual History | ⭐ High | 6KB | UI vs API messages, side-by-side examples |
| **11** | Todo & Subtasks | ⭐ High | 2KB | Task delegation, parent/child relationships |
| **12** | Context Management | Medium | 7KB | Condensation, truncation, sliding window |

### Integration & Extensions

| Doc | Topic | Priority | Size | Key Concepts |
|-----|-------|----------|------|--------------|
| **06** | Skills System | ⭐ High | 2KB | Skills discovery, mandatory checks |
| **07** | Prompt Architecture | Medium | 4KB | System prompt assembly, dynamic generation |
| **13** | Provider Integration | Medium | 8KB | 40+ LLM providers, ApiHandler interface |
| **14** | VSCode Integration | Low | 9KB | ClineProvider, webview, terminals |
| **15** | MCP Integration | Low | 8KB | MCP servers, McpHub, tool discovery |
| **16** | Custom Modes | Low | 9KB | CustomModesManager, marketplace |

---

## 🔥 Critical Topics (Must Read)

### 1. Skills Handling
**Documents**: 06, 00 (Section 4)

Understanding how Roo discovers, validates, and uses skills. Covers:
- Skills discovery from `agentskills.io` spec
- Mandatory precondition checks before execution
- Integration with system prompt

**Why Critical**: Skills are how Roo extends capabilities. Misunderstanding causes failed tool calls.

---

### 2. Tool Validation & Malformed JSON
**Documents**: 04, 08, 09, 00 (Section 3)

How Roo validates tool calls and recovers from malformed responses. Covers:
- `validateToolUse` implementation
- Native vs XML protocol differences (XML REMOVED in v3.43.0)
- Error recovery strategies for incomplete/invalid JSON
- Graceful degradation patterns

**Why Critical**: LLMs produce invalid JSON frequently. This system prevents task failures.

---

### 3. Conversation History Examples
**Documents**: 05, 00 (Section 2)

Side-by-side comparison of UI messages vs API messages. Covers:
- Why two histories exist
- When they diverge
- Concrete examples showing both
- Persistence patterns

**Why Critical**: Common source of confusion. Understanding this prevents bugs in history management.

---

### 4. ToDo → Subtask Lifecycle
**Documents**: 11, 03, 00 (Section 5)

How tasks delegate to subtasks and manage hierarchies. Covers:
- `new_task` tool implementation
- Parent/child relationships
- State propagation
- Subtask completion handling

**Why Critical**: Task delegation is core to agentic behavior. Understanding lifecycle prevents deadlocks.

---

## 🗂️ Old Materials (Legacy Reference)

The following documents are preserved from previous organization:

| File | Content | Use Case |
|------|---------|----------|
| `architect_mode_prompt.md` | Architect mode system prompt | Reference for prompt engineering |
| `code_mode_prompt.md` | Code mode system prompt | Reference for prompt engineering |
| `conv_example.md` | Conversation flow example | Real-world conversation analysis |
| `error_handling_malformed_json.md` | Detailed error handling | Deep dive on JSON recovery |
| `native_protocol_and_completion.md` | Protocol details | Legacy protocol documentation |
| `skills_handling.md` | Skills implementation | Detailed skills exploration |
| `tool_definitions.md` | Tool schemas | Reference for all tool definitions |
| `tool_validation_system.md` | Validation deep dive | Comprehensive validation analysis |

**Note**: These are supplementary. Start with the new organized materials (00-16).

---

## 🔍 Common Questions

### Q: Where do I start?
**A**: Read `01_overview.md` first, then `00_complete_guide.md` for depth.

### Q: How is Roo different from other AI coding assistants?
**A**: See `01_overview.md` - Key differences:
- Task-based (not session-based)
- Dual history (UI + API messages)
- Mode system with tool permissions
- Native tool calling protocol
- Skills system for extensibility

### Q: Where is the main task execution logic?
**A**: `src/core/task/Task.ts` (~4000 lines). See `03_task_lifecycle.md` for explanation.

### Q: How does Roo handle errors from LLMs?
**A**: See `09_message_parsing.md` for malformed JSON recovery, `04_tool_system.md` for validation.

### Q: Can I add custom tools?
**A**: Yes, via MCP servers. See `15_mcp_integration.md`.

### Q: Can I create custom modes?
**A**: Yes. See `16_custom_modes_and_marketplace.md`.

### Q: What's the difference between UI and API messages?
**A**: See `05_dual_history.md` - UI messages are user-facing, API messages go to LLM.

### Q: How do I contribute?
**A**: Follow "Path 2: Contributors" learning path, then check Roo-Code's CONTRIBUTING.md.

---

## 🛠️ Source Code Reference

### Core Files (Must Know)

| File | Lines | Purpose | Doc Reference |
|------|-------|---------|---------------|
| `src/core/task/Task.ts` | ~4000 | Main task orchestrator | 03, 00 |
| `src/core/tools/validateToolUse.ts` | ~500 | Tool validation | 04, 00 |
| `src/core/assistant-message/NativeToolCallParser.ts` | ~300 | Protocol parsing | 08, 09 |
| `src/core/webview/ClineProvider.ts` | ~3000 | VSCode integration | 14 |
| `src/services/skills/SkillsManager.ts` | ~400 | Skills management | 06 |

### Supporting Files

| File | Purpose | Doc Reference |
|------|---------|---------------|
| `packages/types/src/mode.ts` | Mode definitions | 02 |
| `src/api/ApiHandler.ts` | Provider interface | 13 |
| `src/services/mcp/McpHub.ts` | MCP integration | 15 |
| `src/services/modes/CustomModesManager.ts` | Custom modes | 16 |

---

## 📝 Document Conventions

All documents follow these conventions:

### Structure
```markdown
# NN: Topic Name

## Overview
- What it is
- Why it matters
- Key file references

## Key Concepts
- Concept explanations

## Code Examples
- Practical implementations

## Source Code References
- Related files and purposes

**Version**: Roo-Code v3.39+ (January 2026)
```

### Code Examples
- All code is TypeScript (Roo's implementation language)
- Examples are simplified for clarity (not production code)
- File paths reference actual source code locations

### Cross-References
- `→` indicates "see also"
- Documents reference each other by number (e.g., "see 03_task_lifecycle.md")

---

## 🎓 Learning Tips

### For Visual Learners
1. Start with architecture diagrams in `01_overview.md`
2. Trace execution flow in `03_task_lifecycle.md`
3. Compare side-by-side examples in `05_dual_history.md`

### For Code-First Learners
1. Clone Roo-Code repository
2. Open `src/core/task/Task.ts` in your editor
3. Read `03_task_lifecycle.md` alongside code
4. Use docs as explanation reference

### For Concept-First Learners
1. Read `00_complete_guide.md` cover-to-cover
2. Build mental model before diving into code
3. Use source code to validate understanding

---

## 🚀 Next Steps

After completing these materials:

1. **Hands-On Practice**
   - Install Roo-Code in VSCode
   - Try different modes on real projects
   - Observe UI vs API messages in debug mode

2. **Code Exploration**
   - Clone repository
   - Set up development environment
   - Add debug logging to understand execution flow

3. **Contribution**
   - Check [Roo-Code Issues](https://github.com/RooVetGit/Roo-Cline/issues)
   - Start with "good first issue" labels
   - Reference these docs when working with codebase

4. **Research**
   - Compare Roo's architecture to other AI coding assistants
   - Study trade-offs in design decisions
   - Experiment with custom modes and MCP servers

---

## 📅 Document Version

- **Created**: January 2026
- **Based on**: Roo-Code v3.43.0
- **Last Updated**: January 26, 2026
- **Codebase Reference**: `github_repos/Roo-Code/` (main branch)

---

## 🤝 Contributing to These Docs

Found an error or want to improve these materials?

1. These docs live in `public_note/roocode_learning/`
2. Follow the same structure and conventions
3. Reference actual source code (verify file paths exist)
4. Include version information

---

## 📞 Resources

- **Official Repo**: https://github.com/RooVetGit/Roo-Cline
- **VSCode Marketplace**: Search "Roo Cline" in extensions
- **Community**: Check GitHub Discussions for Q&A

---

**Happy Learning! 🎉**

*These materials are designed to make Roo-Code's architecture accessible to everyone from casual users to core contributors.*
