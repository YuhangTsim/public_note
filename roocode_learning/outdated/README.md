# Roo-Code Learning Materials

**Updated: January 2026 | Based on v3.39+ Codebase**

Comprehensive documentation for understanding Roo-Code's architecture, from high-level concepts to implementation details.

---

## 🚀 Quick Start

**New to Roo-Code?** Start here:
1. **[00: Complete Guide](./00_complete_guide.md)** ⭐ **START HERE** - Comprehensive guide covering all critical topics
2. [01: Overview](./01_overview.md) - Architecture overview and key components
3. [02: Mode System](./02_mode_system.md) - Understanding modes and tool groups

**Want to dive deep?** See the [Original Notes](#original-learning-materials-legacy) section below.

---

## 📚 New Learning Materials (January 2026)

### Core Architecture Documents

| Document | Topics Covered | Priority |
|----------|----------------|----------|
| **[00: Complete Guide](./00_complete_guide.md)** | **All 4 critical requirements in one place** | ⭐ **Must Read** |
| [01: Overview](./01_overview.md) | VSCode integration, dual history, architecture | High |
| [02: Mode System](./02_mode_system.md) | Modes, tool groups, file restrictions, custom modes | High |

### Critical Topics (Your Requirements)

All four of your requirements are **fully covered** in `00_complete_guide.md`:

| Requirement | Section in Complete Guide | Status |
|-------------|---------------------------|--------|
| **#1: Skills Handling** | Skills System | ✅ Complete with discovery, validation, mandatory checks |
| **#2: Tool Validation** | Tool System with Validation | ✅ Complete with flow diagrams and error recovery |
| **#2: Malformed JSON** | Malformed JSON Handling | ✅ Complete with multi-layer defense explanation |
| **#3: Conversation Examples** | Dual History \u0026 Conversation Examples | ✅ Complete with side-by-side UI/API examples |
| **#4: ToDo → Subtask Lifecycle** | ToDo → Subtask Lifecycle | ✅ Complete step-by-step with code |

---

## 🎯 Learning Paths

### Path 1: Quick Understanding (30 minutes)
1. Read **[00: Complete Guide](./00_complete_guide.md)** - Focus on:
   - Overview \u0026 Architecture
   - Mode System
   - Skills System (Requirement #1)
   - Tool Validation (Requirement #2)

### Path 2: Deep Dive (2-3 hours)
1. **[00: Complete Guide](./00_complete_guide.md)** - Read completely
2. **[01: Overview](./01_overview.md)** - Understand high-level architecture
3. **[02: Mode System](./02_mode_system.md)** - Learn mode details
4. Original notes (see below) - For historical context

### Path 3: Implementation (Full Day)
1. Read all new documents above
2. Read original notes below for detailed examples
3. Trace source code:
   - `src/core/task/Task.ts` - Main orchestrator
   - `src/core/tools/validateToolUse.ts` - Tool validation
   - `src/core/assistant-message/NativeToolCallParser.ts` - Protocol parsing
   - `src/services/skills/SkillsManager.ts` - Skills system

---

## 📖 Original Learning Materials (Legacy)

These are the original detailed notes from your previous learning. They remain valuable for:
- Detailed conversation examples
- Historical context (XML → Native transition)
- In-depth code walkthroughs

### Original Documents

| Document | Topics | Lines | Complexity |
|----------|--------|-------|------------|
| [architect_mode_prompt.md](./architect_mode_prompt.md) | Full Architect mode prompt | ~180 | ⭐ Beginner |
| [code_mode_prompt.md](./code_mode_prompt.md) | Full Code mode prompt | ~175 | ⭐ Beginner |
| [tool_definitions.md](./tool_definitions.md) | Tool system, XML→Native transition | ~350 | ⭐⭐⭐ Advanced |
| [skills_handling.md](./skills_handling.md) | Skills system details | ~520 | ⭐⭐ Intermediate |
| [conv_example.md](./conv_example.md) | Complete conversation walkthrough | ~650 | ⭐⭐ Intermediate |
| [native_protocol_and_completion.md](./native_protocol_and_completion.md) | Protocol deep dive | ~1350 | ⭐⭐⭐ Advanced |
| [error_handling_malformed_json.md](./error_handling_malformed_json.md) | Error handling details | ~1150 | ⭐⭐⭐ Advanced |

**Total Original Materials**: ~4,375 lines

---

## 🔍 Topic Index

### Skills System
- **New**: [00: Complete Guide - Skills System](./00_complete_guide.md#skills-system)
- Original: [skills_handling.md](./skills_handling.md)

### Tool System \u0026 Validation
- **New**: [00: Complete Guide - Tool System with Validation](./00_complete_guide.md#tool-system-with-validation)
- **New**: [00: Complete Guide - Malformed JSON Handling](./00_complete_guide.md#malformed-json-handling)
- Original: [tool_definitions.md](./tool_definitions.md)
- Original: [error_handling_malformed_json.md](./error_handling_malformed_json.md)

### Conversation History
- **New**: [00: Complete Guide - Dual History \u0026 Conversation Examples](./00_complete_guide.md#dual-history--conversation-examples)
- Original: [conv_example.md](./conv_example.md)

### ToDo \u0026 Subtasks
- **New**: [00: Complete Guide - ToDo → Subtask Lifecycle](./00_complete_guide.md#todo--subtask-lifecycle)
- Related: [native_protocol_and_completion.md](./native_protocol_and_completion.md)

### Mode System
- **New**: [02: Mode System](./02_mode_system.md)
- Original: [architect_mode_prompt.md](./architect_mode_prompt.md), [code_mode_prompt.md](./code_mode_prompt.md)

### Protocols (XML vs Native)
- **New**: [00: Complete Guide - Native Protocol](./00_complete_guide.md#native-protocol)
- Original: [native_protocol_and_completion.md](./native_protocol_and_completion.md)

---

## 🗺️ Documentation Map

```
Roo-Code Learning Materials
│
├─── 🌟 NEW MATERIALS (January 2026)
│    ├── 00_complete_guide.md ............ ⭐ ALL 4 REQUIREMENTS + Full Overview
│    ├── 01_overview.md .................. High-level architecture
│    └── 02_mode_system.md ............... Mode details and tool groups
│
└─── 📚 ORIGINAL MATERIALS (Historical)
     ├── architect_mode_prompt.md ........ Architect mode prompt
     ├── code_mode_prompt.md ............. Code mode prompt
     ├── tool_definitions.md ............. Tool system deep dive
     ├── skills_handling.md .............. Skills system details
     ├── conv_example.md ................. Conversation walkthrough
     ├── native_protocol_and_completion.md Protocol \u0026 completion
     └── error_handling_malformed_json.md  Error handling
```

### Relationship Flow

```
START HERE → 00_complete_guide.md (Covers ALL 4 requirements)
                    ↓
         Need more details?
                    ↓
         ┌──────────┴──────────┐
         ↓                     ↓
  01_overview.md        02_mode_system.md
         ↓                     ↓
  Original notes for historical context
```

---

## 💡 Key Insights

### What's New in This Update?

1. **✅ Complete Coverage of Your 4 Requirements**:
   - Skills handling with discovery and validation
   - Tool validation with error recovery
   - Malformed JSON handling with multi-layer defense
   - Conversation examples with side-by-side UI/API
   - ToDo → Subtask lifecycle with complete flow

2. **Organized Learning Path**:
   - Start with Complete Guide (all critical topics)
   - Dive into specific areas as needed
   - Reference original notes for details

3. **Updated for v3.39+**:
   - Latest codebase analysis
   - Current file paths and patterns
   - Modern architecture explanations

4. **Practical Examples**:
   - Code snippets from actual source
   - Concrete conversation examples
   - Step-by-step flows with diagrams

---

## 🔗 Source Code References

### Key Files by Topic

| Topic | File Path |
|-------|-----------|
| **Task Orchestrator** | `src/core/task/Task.ts` |
| **Skills Manager** | `src/services/skills/SkillsManager.ts` |
| **Tool Validation** | `src/core/tools/validateToolUse.ts` |
| **Native Parser** | `src/core/assistant-message/NativeToolCallParser.ts` |
| **Tool Execution** | `src/core/assistant-message/presentAssistantMessage.ts` |
| **NewTask Tool** | `src/core/tools/NewTaskTool.ts` |
| **Completion Tool** | `src/core/tools/AttemptCompletionTool.ts` |
| **UI Messages** | `src/core/task-persistence/taskMessages.ts` |
| **API Messages** | `src/core/task-persistence/apiMessages.ts` |
| **System Prompt** | `src/core/prompts/system.ts` |
| **Mode Definitions** | `packages/types/src/mode.ts`, `src/shared/modes.ts` |
| **Context Management** | `src/core/condense/index.ts` |

---

## 📊 Documentation Statistics

| Metric | Count |
|--------|-------|
| **New Documents** | 3 (00, 01, 02) |
| **Original Documents** | 7 |
| **Total Lines** | ~10,000+ |
| **Topics Covered** | 15+ |
| **Code Examples** | 50+ |
| **Diagrams** | 20+ |

---

## 🎓 Recommended Reading Order

### For First-Time Learners
1. **[00: Complete Guide](./00_complete_guide.md)** - Read sections:
   - Overview \u0026 Architecture
   - Mode System
   - Skills System
   - Tool System with Validation
2. **[01: Overview](./01_overview.md)** - For high-level context
3. Original [conv_example.md](./conv_example.md) - To see a complete conversation

### For Developers Contributing to Roo-Code
1. **[00: Complete Guide](./00_complete_guide.md)** - Complete read
2. **[02: Mode System](./02_mode_system.md)** - Understand tool groups
3. Original [native_protocol_and_completion.md](./native_protocol_and_completion.md)
4. Original [error_handling_malformed_json.md](./error_handling_malformed_json.md)
5. Source code (use references above)

### For Researchers/Advanced Users
1. **[00: Complete Guide](./00_complete_guide.md)** - Fast overview
2. All original documents (for historical context)
3. Source code deep dive
4. Compare with other agentic systems

---

## 🔄 Updates \u0026 Maintenance

**Last Updated**: January 13, 2026
**Roo-Code Version**: v3.39+
**Based On**: 
- Direct codebase analysis
- 3 parallel explore agents (comprehensive search)
- 2 librarian agents (external research)
- OpenCode learning structure as template

**Maintenance Notes**:
- Original materials preserved for historical reference
- New materials designed for quick learning
- All 4 critical requirements fully covered
- Organized for different learning paths

---

## ❓ FAQ

**Q: Which document should I read first?**
→ **[00: Complete Guide](./00_complete_guide.md)** - It covers all critical topics

**Q: Do I need to read the original materials?**
→ No, the new materials cover everything. Original materials provide additional detail and historical context.

**Q: Where can I find conversation examples?**
→ **[00: Complete Guide - Dual History section](./00_complete_guide.md#dual-history--conversation-examples)**

**Q: How does the ToDo system trigger subtasks?**
→ **[00: Complete Guide - ToDo → Subtask Lifecycle](./00_complete_guide.md#todo--subtask-lifecycle)**

**Q: How are skills discovered and loaded?**
→ **[00: Complete Guide - Skills System](./00_complete_guide.md#skills-system)**

**Q: What happens when tool calls have malformed JSON?**
→ **[00: Complete Guide - Malformed JSON Handling](./00_complete_guide.md#malformed-json-handling)**

---

## 📞 Related Resources

- **Official Roo-Code Docs**: https://docs.roocode.com
- **GitHub Repository**: https://github.com/RooCodeInc/Roo-Code
- **Agent Skills Spec**: https://agentskills.io/
- **Discord Community**: https://discord.gg/roocode

---

**Happy Learning! 🦘**

*These materials were created through comprehensive codebase analysis, parallel agent searches, and following the excellent structure of the OpenCode learning materials.*
