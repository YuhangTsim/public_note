# Roo Code Learning Materials

This folder contains comprehensive documentation about Roo's architecture, focusing on the transition from XML to native tool calling and the system prompt structure.

## 📚 Documentation Files

### 1. [architect_mode_prompt.md](./architect_mode_prompt.md)
**Full system prompt for Architect mode**

Contains the complete, reconstructed system prompt for Architect mode with:
- Full prompt text in a markdown codeblock for easy copying
- Source code references for each section
- Key characteristics and workflow
- Tool access restrictions (markdown files only)
- Mode-specific custom instructions

**Key Learning:**
- Architect mode is designed for planning and design
- Can only edit markdown files (`\.md$` pattern)
- Focuses on creating todo lists and getting user approval before implementation

### 2. [code_mode_prompt.md](./code_mode_prompt.md)
**Full system prompt for Code mode**

Contains the complete, reconstructed system prompt for Code mode with:
- Full prompt text in a markdown codeblock for easy copying
- Source code references for each section
- Comparison with Architect mode
- Tool access (no restrictions)
- Implementation-focused workflow

**Key Learning:**
- Code mode is designed for implementation
- Full access to all edit tools and command execution
- No file restrictions - can modify any file in workspace

### 3. [tool_definitions.md](./tool_definitions.md)
**How tools are defined and passed with prompts**

Comprehensive explanation of the tool system covering:
- **The XML → Native transition** (December 2025)
- Native tool protocol (current standard)
- Tool definition format (OpenAI ChatCompletionTool with JSON Schema)
- How tools are built and passed to the API
- Tool filtering by mode
- Backward compatibility for resumed tasks
- OpenAI ↔ Anthropic conversion

**Key Learning:**
- Native protocol: tools passed as separate API parameter (not in prompt)
- XML protocol: tools embedded in system prompt (deprecated, but supported for resumed tasks)
- Tools filtered by mode groups (read, edit, command, browser, mcp, modes)
- Significant token savings with native protocol

### 4. [skills_handling.md](./skills_handling.md)
**How skills are handled in Roo**

Detailed explanation of the skills system:
- Skills follow the Agent Skills specification (https://agentskills.io/)
- Filesystem-based skill definitions (SKILL.md files)
- Discovery from global and project directories
- Mode-specific skills (skills-{mode}/)
- Override resolution (project > global, mode-specific > generic)
- Integration with system prompt
- Mandatory skill check workflow
- Hot reload with file watchers

**Key Learning:**
- Skills extend agent capabilities without code changes
- Strict validation (name format, description length)
- Skills are lazy-loaded (listed in prompt, content loaded on-demand)
- Agent must check for skill applicability before every response

### 5. [conv_example.md](./conv_example.md)
**Complete conversation example with real API call structures**

A detailed, realistic walkthrough of a complete conversation showing:
- Exact `client.messages.create()` API call structure with all parameters
- User request → Model response → Tool execution → Tool result flow
- How conversation history grows with each turn
- Complete message format for user, assistant, and tool_result blocks
- The iterative loop from initial request to `attempt_completion`
- Alternative scenarios (user feedback vs approval)

**Key Learning:**
- Tools are passed as a separate `tools` parameter, not in messages
- Each API request contains the full conversation history
- Tool results are accumulated and become the next user message
- The loop continues until `attempt_completion` is called and approved
- Complete data structures for apiConversationHistory and token usage

### 6. [native_protocol_and_completion.md](./native_protocol_and_completion.md)
**Native Protocol (JSON Mode) and Task Completion Detection**

In-depth explanation of how Native Protocol works and how task completion is detected:
- **Protocol Overview**: XML Protocol vs Native Protocol comparison
- **Native Protocol Architecture**: Stream chunks, incremental JSON parsing, ToolUse structures
- **Task Completion Detection**: How `attempt_completion` is detected in both protocols
- **Complete Flow Diagrams**: Visual representation from API response to task completion
- **Code Deep Dive**: Actual implementation with line references

**Key Learning:**
- "JSON mode" is actually "Native Protocol" - structured tool calling via API
- Task completion is protocol-agnostic (same detection for XML and Native)
- Protocol detection: `block.id` present = native, absent = XML
- Incremental JSON parsing with `partial-json` library enables progressive rendering
- Native protocol reduces token usage by 2000-5000 tokens per request

### 7. [error_handling_malformed_json.md](./error_handling_malformed_json.md)
**Error Handling for Malformed JSON in Native Protocol**

Comprehensive guide to how Roo handles invalid/malformed JSON from the model:
- **Error Detection Stages**: Incremental parsing, final parsing, tool execution validation
- **Error Handling Flow**: Complete flow from malformed JSON to error recovery
- **Resilience Features**: Partial parsing, graceful degradation, error communication
- **User Experience**: What users see when JSON errors occur
- **Example Scenarios**: Missing braces, extra characters, type mismatches, random strings
- **Code Deep Dive**: Actual error handling implementation with try-catch blocks

**Key Learning:**
- Malformed JSON never crashes the system - always handled gracefully
- `partial-json` library extracts data from incomplete JSON during streaming
- Errors are communicated to both user (UI) and model (tool_result)
- Conversation continues even with JSON errors - task loop never breaks
- Model receives clear error messages and can retry with corrected JSON
- Multiple safety layers: parsing, validation, execution abortion

---

## 🔎 Quick Reference Guide

### Key Concepts & Where to Find Them

| Concept | Document | Key Sections |
|---------|----------|-------------|
| **API Call Structure** | `conv_example.md` | API Request Structure, Turn 1-4 |
| **Conversation Loop** | `conv_example.md`, `native_protocol_and_completion.md` | Complete Flow Diagram, Task Loop |
| **Tool Call Format** | `native_protocol_and_completion.md` | Native Protocol Architecture, Tool Use Data Structure |
| **Task Completion** | `native_protocol_and_completion.md` | Task Completion Detection, Attempt Completion Tool Execution |
| **Native vs XML Protocol** | `tool_definitions.md`, `native_protocol_and_completion.md` | Key Differences Table, Protocol Overview |
| **System Prompt** | `architect_mode_prompt.md`, `code_mode_prompt.md` | Full System Prompt sections |
| **Mode Differences** | `code_mode_prompt.md` | Differences from Architect Mode table |
| **Skills System** | `skills_handling.md` | Complete document |
| **Tool Definitions** | `tool_definitions.md` | Native Tool Locations, Tool Definition Format |
| **Message Format** | `conv_example.md` | Complete Data Structures, Message Count by Role |
| **Error Handling** | `error_handling_malformed_json.md` | Error Detection Stages, Resilience Features |
| **JSON Parsing** | `error_handling_malformed_json.md` | Incremental Parsing, Final Parsing, Error Recovery |

### Common Questions Answered

**Q: How does Roo detect task completion?**
→ See `native_protocol_and_completion.md` - Task Completion Detection section

**Q: What's the difference between XML and Native Protocol?**
→ See `native_protocol_and_completion.md` - Key Differences: XML vs Native table

**Q: How are tools passed to the API?**
→ See `conv_example.md` - API Request Structure and `tool_definitions.md` - How Tools Are Passed to API

**Q: How does the conversation loop work?**
→ See `conv_example.md` - Summary of the Conversation Flow and `native_protocol_and_completion.md` - Complete Flow Diagram

**Q: What tools are available in each mode?**
→ See `architect_mode_prompt.md` and `code_mode_prompt.md` - Tool Access sections

**Q: How do I create a custom skill?**
→ See `skills_handling.md` - Example Usage: Creating a Skill section

**Q: How does incremental JSON parsing work?**
→ See `native_protocol_and_completion.md` - Incremental JSON Parsing section

**Q: What happens if the model outputs malformed JSON?**
→ See `error_handling_malformed_json.md` - Complete error handling flow and recovery mechanisms

---

## 🔍 Key Insights from the Codebase

### System Prompt Assembly

The system prompt is assembled in `src/core/prompts/system.ts:170` by the `SYSTEM_PROMPT()` function.

**Prompt sections (in order):**
1. **Role Definition** - Mode-specific role description
2. **Markdown Formatting** - How to format responses
3. **Tool Use** - Tool calling instructions (native vs XML)
4. **Tool Catalog** - Only for XML protocol (deprecated)
5. **Tool Use Guidelines** - Best practices for tool usage
6. **MCP Servers** - If MCP tools available
7. **Capabilities** - What the agent can do
8. **Modes** - List of available modes
9. **Skills** - Available skills (if any)
10. **Rules** - Behavioral rules and constraints
11. **System Info** - OS, shell, workspace directory
12. **Objective** - How to accomplish tasks iteratively
13. **Custom Instructions** - User's custom rules and mode-specific instructions

### Mode Configuration

Modes are defined in `packages/types/src/mode.ts:136` with:
- `slug` - Mode identifier (e.g., "architect", "code")
- `name` - Display name (e.g., "🏗️ Architect")
- `roleDefinition` - Agent's role in this mode
- `whenToUse` - Description of when to use this mode
- `groups` - Tool groups accessible in this mode
- `customInstructions` - Mode-specific behavioral instructions

### Tool Groups

From `src/shared/tools.ts`:

| Group | Tools | Purpose |
|-------|-------|---------|
| `read` | read_file, list_files, search_files, codebase_search | Read and explore files |
| `edit` | write_to_file, search_and_replace, apply_diff, edit_file | Modify files |
| `command` | execute_command | Run CLI commands |
| `browser` | browser_action | Browser automation |
| `mcp` | MCP server tools | External tool integrations |
| `modes` | switch_mode, new_task | Mode and task management |

---

## 🎯 Understanding the XML → Native Transition

### Before (XML Protocol)
```
System Prompt: [Role + Instructions + TOOL DESCRIPTIONS (XML)]
                                     ↑
                            Increases token usage

Agent Response: <read_file><path>file.ts</path></read_file>
                ↑
        XML parsing required
```

### After (Native Protocol)
```
System Prompt: [Role + Instructions]
                ↑
        Reduced token usage

API Request:
{
  messages: [...],
  tools: [{ type: "function", function: { name: "read_file", ... } }]
          ↑
  Separate parameter, JSON Schema validation
}

Agent Response:
{
  tool_calls: [{ id: "...", type: "function", function: { name: "read_file", arguments: "{...}" } }]
               ↑
      Structured, typed response
}
```

**Benefits of Native Protocol:**
- ✅ Reduced token usage (tool descriptions not in every prompt)
- ✅ Better type safety (JSON Schema validation)
- ✅ Native provider support (Claude, GPT-4, etc.)
- ✅ Cleaner parsing (no XML parsing required)
- ✅ Faster processing

---

## 📖 How to Use This Documentation

### Recommended Reading Order

#### For Understanding System Architecture:
1. **Start with conversation flow** - Read `conv_example.md` to see a complete end-to-end example of how conversations work with actual API calls
2. **Understand protocols** - Read `native_protocol_and_completion.md` to learn how Native Protocol works and how task completion is detected
3. **Learn error handling** - Read `error_handling_malformed_json.md` to understand how Roo handles malformed JSON gracefully
4. **Learn tool definitions** - Read `tool_definitions.md` to see how tools are defined, passed to the API, and filtered by mode

#### For Understanding Modes:
5. **Explore mode prompts** - Read `architect_mode_prompt.md` and `code_mode_prompt.md` to understand the full system prompts and mode-specific behaviors
6. **Learn about skills** - Read `skills_handling.md` to understand the extensibility system and how to create custom skills

#### For Implementation:
7. **Cross-reference with source code** - Each document includes file references (e.g., `src/core/prompts/system.ts:170`) to the actual source code
8. **Trace the flow** - Use the flow diagrams in `native_protocol_and_completion.md` and `error_handling_malformed_json.md` to understand execution paths

---

## 🔗 Source Code References

### Key Files
- `packages/types/src/mode.ts` - Mode definitions (DEFAULT_MODES)
- `src/core/prompts/system.ts` - System prompt assembly
- `src/core/prompts/sections/*.ts` - Prompt section generators
- `src/core/prompts/tools/native-tools/*.ts` - Native tool definitions
- `src/core/task/build-tools.ts` - Tool array building and filtering
- `src/services/skills/SkillsManager.ts` - Skills discovery and management
- `src/utils/resolveToolProtocol.ts` - Protocol resolution (XML vs Native)

### Architecture
```
System Prompt Generation Flow:
├── Mode Selection (getModeBySlug)
├── Prompt Component Override (custom mode prompts)
├── Section Assembly
│   ├── Role Definition (from mode config)
│   ├── Markdown Formatting
│   ├── Tool Use Instructions
│   ├── Capabilities
│   ├── Modes List
│   ├── Skills (if any)
│   ├── Rules
│   ├── System Info
│   ├── Objective
│   └── Custom Instructions
└── Tool Building (for native protocol)
    ├── Native Tools (from getNativeTools)
    ├── MCP Tools (from getMcpServerTools)
    ├── Filter by Mode
    └── Custom Tools (if enabled)
```

---

## 💡 Tips for Further Learning

1. **Follow a conversation** - Start with `conv_example.md` to see a realistic conversation from start to finish, then trace the same flow in the actual codebase

2. **Understand the loop** - Use the flow diagrams in `native_protocol_and_completion.md` to visualize how the conversation loop works

3. **Learn error handling** - Read `error_handling_malformed_json.md` to see how Roo gracefully handles errors and recovers from malformed JSON

4. **Trace the code** - Follow the file references in each document to see the actual implementation (e.g., `src/core/task/Task.ts:2239` for the task loop)

5. **Experiment with modes** - Try switching between modes to see different tool access and behaviors in action

6. **Create custom skills** - Practice creating skills in `~/.roo/skills/` to extend functionality (see `skills_handling.md` for details)

7. **Compare prompts** - Diff the architect and code mode prompts to understand how modes differ in behavior and tool access

8. **Debug with logs** - Add console.log statements to `NativeToolCallParser`, `presentAssistantMessage`, and tool handlers to see the data flow in real-time

9. **Read the Agent Skills spec** - Visit https://agentskills.io/ to understand the skills standard that Roo implements

---

## 📊 Documentation Overview

This learning material collection provides:
- **7 comprehensive documents** covering system architecture, protocols, modes, tools, and error handling
- **Complete code examples** with actual API call structures
- **Flow diagrams** showing execution paths
- **Source code references** with file paths and line numbers
- **Practical examples** of conversations, tool calls, task completion, and error recovery

### Documentation Map

```
Roo Code Architecture Learning Materials
│
├─── 🎯 Getting Started (Read First)
│    ├── conv_example.md ...................... See a complete conversation in action
│    └── native_protocol_and_completion.md .... Understand how the system works
│
├─── 🔧 Core Concepts
│    ├── tool_definitions.md .................. How tools are defined and passed
│    ├── error_handling_malformed_json.md ..... Resilience and error recovery
│    └── skills_handling.md ................... Extensibility via skills
│
├─── 🎭 Modes & Prompts
│    ├── architect_mode_prompt.md ............. Planning mode (restricted edit)
│    └── code_mode_prompt.md .................. Implementation mode (full access)
│
└─── 📖 This README ............................ Quick reference and navigation

Relationship Flow:
conv_example.md → Shows what you see in practice
        ↓
native_protocol_and_completion.md → Explains how it works internally
        ↓
error_handling_malformed_json.md → What happens when things go wrong
        ↓
tool_definitions.md → Details on tool system architecture
        ↓
architect/code_mode_prompt.md → Mode-specific behaviors
        ↓
skills_handling.md → How to extend Roo with custom capabilities
```

### Document Statistics

| Document | Lines | Topics Covered | Complexity |
|----------|-------|----------------|------------|
| `conv_example.md` | ~650 | API calls, conversation flow, tool execution | ⭐⭐ Intermediate |
| `native_protocol_and_completion.md` | ~1350 | Protocols, parsers, completion detection | ⭐⭐⭐ Advanced |
| `error_handling_malformed_json.md` | ~1150 | Error detection, resilience, recovery | ⭐⭐⭐ Advanced |
| `tool_definitions.md` | ~350 | Tool system, protocols, conversions | ⭐⭐⭐ Advanced |
| `skills_handling.md` | ~520 | Skills system, discovery, validation | ⭐⭐ Intermediate |
| `architect_mode_prompt.md` | ~180 | Architect mode, planning workflow | ⭐ Beginner |
| `code_mode_prompt.md` | ~175 | Code mode, implementation workflow | ⭐ Beginner |

**Total:** ~4,375 lines of comprehensive documentation

---

**Documentation Generated:** January 7, 2026
**Latest Update:** Added conversation examples and native protocol deep dive
**Roo Version:** Based on commit 861139ca2 and recent changes
**Contributors:** Created through deep codebase analysis and exploration
