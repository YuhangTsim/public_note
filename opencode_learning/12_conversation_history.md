# Conversation History and Message Flow

## Overview

This document provides a technical breakdown of how OpenCode manages conversation history, including the complete message structure from system prompts through tool calls and results.

## Message Schema Architecture

OpenCode uses a **part-based message system** where each message contains:

- **Metadata** (`MessageV2.Info`): Role, timestamps, tokens, cost
- **Parts** (`MessageV2.Part[]`): Content segments (text, tool calls, reasoning, files, etc.)

### Core Message Types

```typescript
// User message
{
  role: "user",
  id: "msg_abc123",
  sessionID: "session_xyz",
  agent: "build",
  model: { providerID: "anthropic", modelID: "claude-3-5-sonnet-20241022" },
  time: { created: 1736708258000 },
}

// Assistant message
{
  role: "assistant",
  id: "msg_def456",
  sessionID: "session_xyz",
  parentID: "msg_abc123",  // Links to user message
  agent: "build",
  providerID: "anthropic",
  modelID: "claude-3-5-sonnet-20241022",
  time: { created: 1736708260000, completed: 1736708275000 },
  cost: 0.0234,
  tokens: {
    input: 1500,
    output: 800,
    reasoning: 0,
    cache: { read: 5000, write: 0 }
  },
  finish: "stop",
}
```

## Complete Conversation Example

This example shows the actual conversation from your recent question about OpenCode architecture documentation.

### Initial State

```json
{
  "sessionID": "session_44c5abc15ffe",
  "messages": []
}
```

### Message 1: System Prompt (Internal)

**Note**: System prompts are NOT stored as messages. They're dynamically generated per request.

```typescript
// Assembled system prompt (not persisted)
{
  "role": "system",
  "content": [
    {
      "type": "text",
      "text": "You are Claude Code, Anthropic's official CLI for Claude.\n\nYou are a coding agent running in the opencode, a terminal-based coding assistant..."
    },
    {
      "type": "text",
      "text": "Instructions from: /Users/yuhangzhan/Codebase/research_workspace/opencode/AGENTS.md\n- To test opencode in the `packages/opencode` directory you can run `bun dev`\n- To regenerate the javascript SDK, run ./packages/sdk/js/script/build.ts..."
    },
    {
      "type": "text",
      "text": "Instructions from: ~/.config/opencode/AGENTS.md\n<Role>\nYou are \"Sisyphus\" - Powerful AI Agent with orchestration capabilities from OhMyOpenCode..."
    },
    {
      "type": "text",
      "text": "Here is some useful information about the environment you are running in:\n<env>\n  Working directory: /Users/yuhangzhan/Codebase/research_workspace/opencode\n  Is directory a git repo: yes\n  Platform: darwin\n  Today's date: Mon Jan 13 2026\n</env>"
    }
  ]
}
```

### Message 2: User Input

**Stored format**:

```json
{
  "info": {
    "id": "msg_01abc123",
    "sessionID": "session_44c5abc15ffe",
    "role": "user",
    "agent": "build",
    "model": {
      "providerID": "anthropic",
      "modelID": "claude-3-5-sonnet-20241022"
    },
    "time": {
      "created": 1736708258000
    }
  },
  "parts": [
    {
      "id": "part_01xyz",
      "sessionID": "session_44c5abc15ffe",
      "messageID": "msg_01abc123",
      "type": "text",
      "text": "help me understand how opencode is designed, put your learning under a new folder under root, named `opencode_learning`"
    }
  ]
}
```

**Sent to LLM** (converted via `toModelMessage`):

```json
{
  "role": "user",
  "content": [
    {
      "type": "text",
      "text": "help me understand how opencode is designed, put your learning under a new folder under root, named `opencode_learning`"
    }
  ]
}
```

### Message 3: Assistant Response (Part 1 - Text)

**Stored format**:

```json
{
  "info": {
    "id": "msg_02def456",
    "sessionID": "session_44c5abc15ffe",
    "role": "assistant",
    "parentID": "msg_01abc123",
    "agent": "build",
    "providerID": "anthropic",
    "modelID": "claude-3-5-sonnet-20241022",
    "time": {
      "created": 1736708260000,
      "completed": null
    },
    "cost": 0,
    "tokens": { "input": 0, "output": 0, "reasoning": 0, "cache": { "read": 0, "write": 0 } },
    "path": {
      "cwd": "/Users/yuhangzhan/Codebase/research_workspace/opencode",
      "root": "/Users/yuhangzhan/Codebase/research_workspace/opencode"
    }
  },
  "parts": [
    {
      "id": "part_02aaa",
      "sessionID": "session_44c5abc15ffe",
      "messageID": "msg_02def456",
      "type": "text",
      "text": "I'll gather context about opencode's design using parallel exploration and then synthesize my findings into documentation.",
      "time": {
        "start": 1736708260100,
        "end": 1736708260500
      }
    }
  ]
}
```

### Message 4: Tool Call - background_task (explore #1)

**Stored as ToolPart**:

```json
{
  "id": "part_02bbb",
  "sessionID": "session_44c5abc15ffe",
  "messageID": "msg_02def456",
  "type": "tool",
  "callID": "call_01explore",
  "tool": "background_task",
  "state": {
    "status": "pending",
    "input": {},
    "raw": ""
  }
}
```

**When LLM finishes generating input**:

```json
{
  "id": "part_02bbb",
  "type": "tool",
  "callID": "call_01explore",
  "tool": "background_task",
  "state": {
    "status": "running",
    "input": {
      "agent": "explore",
      "description": "Core architecture and design patterns",
      "prompt": "Analyze the opencode architecture and design patterns. Focus on:\n1. Main entry points and initialization flow\n2. Core architectural components and their relationships..."
    },
    "title": "Launching background task",
    "time": {
      "start": 1736708260600
    }
  }
}
```

**When tool execution completes**:

```json
{
  "id": "part_02bbb",
  "type": "tool",
  "callID": "call_01explore",
  "tool": "background_task",
  "state": {
    "status": "completed",
    "input": {
      "agent": "explore",
      "description": "Core architecture and design patterns",
      "prompt": "Analyze the opencode architecture..."
    },
    "output": "Background task launched successfully.\n\nTask ID: bg_c9861551\nSession ID: ses_44c5abc15ffeUJ120CH5vrJpWm\nDescription: Core architecture and design patterns\nAgent: explore\nStatus: running",
    "title": "Background task launched",
    "metadata": {
      "task_id": "bg_c9861551",
      "session_id": "ses_44c5abc15ffeUJ120CH5vrJpWm"
    },
    "time": {
      "start": 1736708260600,
      "end": 1736708260850
    }
  }
}
```

### Message 5: Multiple Parallel Tool Calls

The assistant fires 3 background tasks in parallel:

```json
{
  "parts": [
    {
      "id": "part_02bbb",
      "type": "tool",
      "callID": "call_01explore",
      "tool": "background_task",
      "state": { "status": "completed", "..." }
    },
    {
      "id": "part_02ccc",
      "type": "tool",
      "callID": "call_02explore",
      "tool": "background_task",
      "state": { "status": "completed", "..." }
    },
    {
      "id": "part_02ddd",
      "type": "tool",
      "callID": "call_03explore",
      "tool": "background_task",
      "state": { "status": "completed", "..." }
    },
    {
      "id": "part_02eee",
      "type": "tool",
      "callID": "call_04bash",
      "tool": "bash",
      "state": {
        "status": "completed",
        "input": {
          "command": "find . -name \"package.json\" -not -path \"*/node_modules/*\" | head -20",
          "description": "Find package.json files for project structure"
        },
        "output": "./sdks/vscode/package.json\n./.opencode/package.json\n...",
        "title": "Find package.json files",
        "time": { "start": 1736708261000, "end": 1736708261250 }
      }
    },
    {
      "id": "part_02fff",
      "type": "tool",
      "callID": "call_05bash",
      "tool": "bash",
      "state": {
        "status": "completed",
        "input": {
          "command": "ls -la",
          "description": "List root directory contents"
        },
        "output": "total 1472\ndrwxr-xr-x  37 yuhangzhan  staff    1184 Jan 12 14:17 .",
        "title": "List directory",
        "time": { "start": 1736708261100, "end": 1736708261280 }
      }
    },
    {
      "id": "part_02ggg",
      "type": "tool",
      "callID": "call_06read",
      "tool": "read",
      "state": {
        "status": "completed",
        "input": {
          "filePath": "/Users/yuhangzhan/Codebase/cc_workspace/opencode/README.md"
        },
        "output": "<file>\n00001| <p align=\"center\">\n00002|   <a href=\"https://opencode.ai\">...",
        "title": "Read README.md",
        "time": { "start": 1736708261150, "end": 1736708261400 }
      }
    }
  ]
}
```

**Sent to LLM** (tool results):

```json
{
  "role": "assistant",
  "parts": [
    {
      "type": "tool-background_task",
      "state": "output-available",
      "toolCallId": "call_01explore",
      "input": { "agent": "explore", "description": "...", "prompt": "..." },
      "output": "Background task launched successfully.\n\nTask ID: bg_c9861551..."
    },
    {
      "type": "tool-background_task",
      "state": "output-available",
      "toolCallId": "call_02explore",
      "input": { "..." },
      "output": "Background task launched successfully.\n\nTask ID: bg_d95ed260..."
    },
    // ... more tool results
  ]
}
```

### Message 6: Assistant Creates Files

```json
{
  "parts": [
    {
      "id": "part_03aaa",
      "type": "tool",
      "callID": "call_07write",
      "tool": "write",
      "state": {
        "status": "completed",
        "input": {
          "filePath": "/Users/yuhangzhan/Codebase/cc_workspace/opencode/opencode_learning/01_overview.md",
          "content": "# OpenCode Architecture Overview\n\n## What is OpenCode?..."
        },
        "output": "File written successfully",
        "title": "Created 01_overview.md",
        "metadata": {
          "bytes": 12458,
          "lines": 342
        },
        "time": { "start": 1736708270000, "end": 1736708270150 }
      }
    },
    {
      "id": "part_03bbb",
      "type": "tool",
      "callID": "call_08write",
      "tool": "write",
      "state": {
        "status": "completed",
        "input": {
          "filePath": "/Users/yuhangzhan/Codebase/cc_workspace/opencode/opencode_learning/02_agent_system.md",
          "content": "# Agent System Architecture..."
        },
        "output": "File written successfully",
        "title": "Created 02_agent_system.md",
        "time": { "start": 1736708270200, "end": 1736708270350 }
      }
    }
  ]
}
```

### Message 7: Assistant Final Response

```json
{
  "info": {
    "id": "msg_02def456",
    "time": {
      "created": 1736708260000,
      "completed": 1736708275000 // Now completed
    },
    "cost": 0.0234,
    "tokens": {
      "input": 15234,
      "output": 8956,
      "reasoning": 0,
      "cache": { "read": 45000, "write": 2000 }
    },
    "finish": "stop"
  },
  "parts": [
    // All previous parts (text, tool calls) plus final text
    {
      "id": "part_03zzz",
      "type": "text",
      "text": "Perfect! I've created comprehensive documentation for understanding OpenCode's architecture. Here's what I've documented in the `opencode_learning/` directory:\n\n## Created Documentation\n\n### 📚 **Core Architecture Guides**\n\n1. **01_overview.md** - High-level architecture...",
      "time": {
        "start": 1736708274500,
        "end": 1736708275000
      }
    }
  ]
}
```

### Message 8: background_cancel (cleanup)

```json
{
  "parts": [
    {
      "id": "part_04aaa",
      "type": "tool",
      "callID": "call_99cancel",
      "tool": "background_cancel",
      "state": {
        "status": "completed",
        "input": { "all": true },
        "output": "✅ No running background tasks to cancel.",
        "title": "Cancelled background tasks",
        "time": { "start": 1736708275100, "end": 1736708275120 }
      }
    }
  ]
}
```

## Complete Message Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ System Prompt (Not Stored)                                  │
│ - Provider header (Claude Code)                             │
│ - Core instructions (codex/anthropic.txt)                   │
│ - Custom instructions (AGENTS.md)                           │
│ - Environment info                                          │
│ - Tool definitions (generated dynamically)                  │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Message 1: User (Stored)                                    │
│ role: "user"                                                │
│ parts: [{ type: "text", text: "help me understand..." }]   │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Message 2: Assistant (Stored, streaming)                    │
│ role: "assistant"                                           │
│ parts: [                                                    │
│   { type: "text", text: "I'll gather context..." }         │
│   { type: "tool", tool: "background_task", ... }           │
│   { type: "tool", tool: "background_task", ... }           │
│   { type: "tool", tool: "bash", ... }                      │
│   { type: "tool", tool: "read", ... }                      │
│   { type: "tool", tool: "write", ... }                     │
│   { type: "text", text: "Perfect! I've created..." }       │
│ ]                                                           │
└─────────────────────────────────────────────────────────────┘
```

## Storage Structure

Messages are stored in the filesystem under `~/.opencode/session/`:

```
~/.opencode/session/session_44c5abc15ffe/
├── meta.json                    # Session metadata
├── message/
│   ├── msg_01abc123             # User message metadata
│   └── msg_02def456             # Assistant message metadata
└── part/
    └── msg_02def456/
        ├── part_02aaa           # Text part
        ├── part_02bbb           # Tool part (background_task)
        ├── part_02ccc           # Tool part (background_task)
        ├── part_02ddd           # Tool part (background_task)
        ├── part_02eee           # Tool part (bash)
        ├── part_02fff           # Tool part (bash)
        ├── part_02ggg           # Tool part (read)
        ├── part_03aaa           # Tool part (write)
        ├── part_03bbb           # Tool part (write)
        ├── part_03zzz           # Final text part
        └── part_04aaa           # Tool part (background_cancel)
```

## Conversion to LLM Format

OpenCode stores parts separately but converts them to the AI SDK format when sending to the LLM:

```typescript
// Internal storage (OpenCode)
{
  info: { role: "assistant", id: "msg_02", ... },
  parts: [
    { type: "text", text: "I'll help..." },
    { type: "tool", tool: "bash", state: { status: "completed", ... } },
  ]
}

// Sent to LLM (AI SDK format)
{
  role: "assistant",
  parts: [
    { type: "text", text: "I'll help..." },
    {
      type: "tool-bash",
      state: "output-available",
      toolCallId: "call_01",
      input: { command: "ls" },
      output: "file1.txt\nfile2.txt"
    }
  ]
}
```

## Key Design Decisions

### 1. Part-Based Architecture

**Why?** Allows fine-grained control over message content:

- Stream individual parts as they arrive
- Update tool states independently
- Support rich content (files, reasoning, snapshots)

### 2. Separate Storage

**Why?** Performance and flexibility:

- Load message metadata without all parts
- Query specific parts by type
- Efficient compaction (remove old parts)

### 3. State Tracking

**Why?** Real-time UI updates:

- Show tool execution progress
- Display partial results
- Handle long-running operations

### 4. Tool Call Persistence

**Why?** Debugging and recovery:

- Replay failed executions
- Analyze tool usage patterns
- Recover from crashes mid-execution

## Next Steps

- [04_tool_system.md](./04_tool_system.md) - Tool architecture
- [11_tool_calling_system.md](./11_tool_calling_system.md) - Tool calling internals
- [03_session_management.md](./03_session_management.md) - Session lifecycle
