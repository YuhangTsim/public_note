# Session Storage Architecture

OpenCode employs a custom file-based storage system designed for high concurrency, incremental updates, and lazy loading. It deliberately avoids using a traditional database (like SQLite) in favor of a normalized, split-file JSON architecture.

## 1. Storage Location

Sessions are persisted in the **XDG Data Directory** to ensure compliance with OS standards and to keep user data separate from configuration.

- **Path**: `$XDG_DATA_HOME/opencode/storage/`
- **Defaults**:
  - **Linux**: `~/.local/share/opencode/storage/`
  - **macOS**: `~/Library/Application Support/opencode/storage/`
  - **Windows**: `%LOCALAPPDATA%\opencode\storage\`

## 2. Split-File Architecture

Unlike simple implementations that dump an entire conversation history into a single JSON file, OpenCode "normalizes" the data into separate files for sessions, messages, and message parts. This mimics a relational database structure.

### Directory Structure

```text
storage/
├── migration/                          # Schema version tracking
├── project/
│   └── {projectID}.json               # Project metadata
├── session/
│   └── {projectID}/
│       └── {sessionID}.json           # Session metadata (created_at, status)
├── message/
│   └── {sessionID}/
│       └── {messageID}.json           # Message metadata (role, author, timestamps)
├── part/
│   └── {messageID}/
│       └── {partID}.json              # The actual content (text, tool calls, images)
├── session_diff/
│   └── {sessionID}.json               # Accumulated file edits/diffs
└── share/
    └── {sessionID}.json               # Public share link metadata
```

### Benefits of this Approach

1.  **Atomic & Incremental Writes**: When a new token arrives or a tool finishes, only the specific `part` file needs to be updated. The massive conversation history doesn't need to be rewritten.
2.  **Concurrency**: Multiple processes (e.g., the CLI, the GUI, and background tasks) can read/write different parts of the session simultaneously with fine-grained file locking.
3.  **Lazy Loading**: The UI can load the list of sessions without reading messages. It can load messages without reading heavy payloads (like images or large tool outputs) until they are scrolled into view.

## 3. Storage Mechanism

### No Database
There is **no dependency on SQLite, PostgreSQL, or LevelDB**. The "database" is purely the filesystem.

- **Write Operations**: Uses `Storage.write()` which acquires a file lock, writes the JSON content atomically (write-to-temp-then-rename), and releases the lock.
- **Read Operations**: Uses `Storage.read()` with shared read locks.

### Streaming & Lazy Loading
Data retrieval is built on async generators to support streaming:

```typescript
// Example: Streaming messages in reverse chronological order
export const stream = fn(Identifier.schema("session"), async function* (sessionID) {
  // 1. List all message IDs for the session (directory listing)
  const list = await Array.fromAsync(await Storage.list(["message", sessionID]))
  
  // 2. Yield them one by one, reading file content on demand
  for (let i = list.length - 1; i >= 0; i--) {
    yield await get({ sessionID, messageID: list[i][2] })
  }
})
```

## 4. Compaction & Pruning

OpenCode implements an active garbage collection system for session history to manage context window limits.

**Location**: `packages/opencode/src/session/compaction.ts`

### Pruning Logic
- **Trigger**: When the context window overflows (total tokens > model limit).
- **Thresholds**:
  - `PRUNE_MINIMUM`: 20,000 tokens (minimum amount to trigger a prune).
  - `PRUNE_PROTECT`: 40,000 tokens (amount of recent tool output to preserve).
- **Behavior**: It selectively deletes the *content* of old tool outputs (e.g., large `read` or `grep` results) while preserving the fact that the tool was run.

### Summarization
- If pruning isn't enough, the system uses a specialized **Compaction Agent**.
- It generates a summary of the older conversation history.
- The history is then "compacted" by replacing old messages with a summary message (`summary: true`).

## 5. Migration System

The storage engine includes a migration framework (`storage/migration`) that runs on startup. This allows the data schema (e.g., how JSON files are structured) to evolve over time without breaking existing user sessions.

## 6. Key Files

- **`packages/opencode/src/storage/storage.ts`**: Core filesystem driver with locking.
- **`packages/opencode/src/session/index.ts`**: Session management logic.
- **`packages/opencode/src/session/compaction.ts`**: Pruning and summarization logic.
- **`packages/opencode/src/global/index.ts`**: Path resolution logic.
