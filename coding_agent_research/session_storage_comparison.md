# Session Storage Comparison: OpenCode vs Roo-Code vs OpenClaw

**Research Date**: January 26, 2026
**Objective**: Analyze how three leading AI coding agents persist conversation history, session state, and metadata.

## Executive Summary

All three agents rely on **file-based storage** for their primary session history, avoiding complex database dependencies (like Postgres) for core operations. However, their approaches differ significantly in structure and optimization:

- **OpenCode** uses a **sophisticated split-file architecture** (normalized data) optimized for concurrent access and incremental updates.
- **Roo-Code** uses a **hybrid approach**, leveraging VS Code's `globalState` Memento for metadata and simple JSON files for full message history.
- **OpenClaw** uses **JSON Lines (.jsonl)** for append-only log efficiency, with SQLite used *only* for semantic search (vectors), not for session storage.

---

## 1. OpenCode Architecture

OpenCode implements a custom file-based database pattern designed for high concurrency and granular access.

### Storage Location
- **Linux**: `~/.local/share/opencode/storage/`
- **macOS**: `~/Library/Application Support/opencode/storage/`
- **Windows**: `%LOCALAPPDATA%\opencode\storage\`

### Data Structure (Split-File System)
OpenCode normalizes data into separate directories by entity type, similar to a relational database table structure but with files.

```text
storage/
├── session/
│   └── {projectID}/
│       └── {sessionID}.json    # Session metadata (created_at, status)
├── message/
│   └── {sessionID}/
│       └── {messageID}.json    # Message metadata (role, author)
├── part/
│   └── {messageID}/
│       └── {partID}.json       # Content payload (text, tool_use, tool_result)
└── session_diff/
    └── {sessionID}.json        # Accumulated file changes
```

### Key Characteristics
- **Atomic Writes**: Each entity (session, message, part) is a separate file.
- **Lazy Loading**: Messages are loaded via async generators only when needed.
- **Concurrency**: Fine-grained file locking prevents corruption during parallel agent execution.
- **Compaction**: Active pruning system removes tool outputs older than ~40k tokens.

---

## 2. Roo-Code Architecture

Roo-Code integrates deeply with the VS Code extension ecosystem, separating lightweight metadata from heavy conversation history.

### Storage Location
- **Base**: VS Code Extension Global Storage (`~/Library/Application Support/Code/User/globalStorage/roovet.roo-cline/`)
- **Configurable**: Users can override this via `customStoragePath`.

### Data Structure
Roo-Code organizes data by "Task" (equivalent to a session).

```text
globalStorage/
├── tasks/
│   └── {taskId}/
│       ├── ui_messages.json             # Full conversation history for UI
│       ├── api_conversation_history.json # Protocol-specific API history
│       └── task_metadata.json           # (Implicit/Derived)
└── globalState (VS Code Memento)        # Indexes, recent tasks list, state
```

### Key Characteristics
- **Hybrid Storage**:
    - **VS Code Memento**: Stores "Recent Tasks" list and active state.
    - **Filesystem**: Stores actual message content.
- **Dual History**: Maintains `ui_messages.json` (human-readable) and `api_conversation_history.json` (LLM-optimized) separately.
- **No Database**: Purely JSON serialization/deserialization.

---

## 3. OpenClaw Architecture

OpenClaw optimizes for append-only logging and streaming performance using JSONL.

### Storage Location
- **Sessions**: `~/.openclaw/memory/transcripts/{agentId}/`
- **Metadata**: `~/.config/openclaw/sessions.json`

### Data Structure (JSON Lines)
Session files are stored as `.jsonl` files, where each line is a complete JSON object representing a single event or message.

```text
~/.openclaw/
├── memory/
│   └── transcripts/
│       └── default/
│           ├── {sessionTimestamp}-{slug}.jsonl
│           └── ...
└── config/
    └── sessions.json  # Global registry of active sessions
```

**File Content Example (`.jsonl`):**
```json
{"type":"message", "message": {"role": "user", "content": "Hello"}}
{"type":"message", "message": {"role": "assistant", "content": "Hi there"}}
```

### Key Characteristics
- **Append-Only**: New messages are simply appended to the file (efficient write performance).
- **SQLite Integration**: Uses `sqlite` and `sqlite-vec` *exclusively* for vector embedding search (memory), NOT for storing the conversation logs themselves.
- **Pruning**: Configurable `maxAge` (default 7 days) and `maxTurns` auto-delete old session files.

---

## Comparison Matrix

| Feature | OpenCode | Roo-Code | OpenClaw |
| :--- | :--- | :--- | :--- |
| **Storage Medium** | **Split JSON Files** | **JSON Files + Memento** | **JSON Lines (.jsonl)** |
| **Database** | None | None | SQLite (Vectors Only) |
| **Atomicity** | High (per-message part) | Low (per-task file) | Medium (append-line) |
| **Pruning** | **Token-based** (smart) | Manual/None | **Time/Turn-based** |
| **Concurrency** | File Locking | VS Code Managed | Process Managed |
| **History Loading** | Lazy Stream | Full File Load | Full File/Stream |

## Conclusion

- **OpenCode** has the most robust storage architecture, mimicking a NoSQL database structure with files. This allows it to handle very long conversations with minimal memory footprint (loading only what is needed).
- **OpenClaw** chooses simplicity and write-performance with JSONL, making it excellent for logging and streaming but potentially slower for random access reads.
- **Roo-Code** relies on VS Code primitives, which makes it tightly coupled to the editor but ensures seamless integration with the IDE's state management.
