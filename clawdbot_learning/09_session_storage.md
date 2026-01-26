# Session Storage & Persistence

Clawdbot implements a high-performance **logging-style storage architecture** using JSON Lines (`.jsonl`). This approach prioritizes write performance and streaming reliability, making it ideal for a long-running bot service.

## 1. Storage Location

Sessions are stored in the `memory` directory within the user's configuration folder.

- **Path**: `~/.clawdbot/memory/transcripts/{agentId}/`
- **Agent Isolation**: Each agent (default, etc.) has its own subdirectory, ensuring complete data isolation between different personas.

## 2. JSON Lines Architecture

Instead of rewriting a massive JSON array every time a new message arrives, Clawdbot appends a single line to a `.jsonl` file.

### File Format
Each line is a self-contained, valid JSON object representing an event.

```jsonl
{"type":"info","ts":1706284800000,"msg":"Session started"}
{"type":"message","message":{"role":"user","content":"Hello"}}
{"type":"message","message":{"role":"assistant","content":"Hi there"}}
{"type":"tool_use","tool":{"name":"bash","input":"ls"}}
{"type":"tool_result","tool_use_id":"call_123","content":"file.txt"}
```

### Benefits
1.  **Append-Only Performance**: Writing is O(1) regardless of conversation length.
2.  **Corruption Resistance**: If the process crashes mid-write, only the last line is corrupted, not the entire history.
3.  **Streaming**: Tools like `tail -f` or log processors can consume the session in real-time.

## 3. Metadata Separation

While the *content* is in `.jsonl` files, the *metadata* (which sessions exist, their tokens usage, last update time) is stored in a separate registry.

- **Registry File**: `~/.config/clawdbot/sessions.json`
- **Purpose**: Allows the bot to quickly list active sessions or find a session by ID without scanning thousands of transcript files.

## 4. SQLite vs Files

Clawdbot **DOES use SQLite**, but not for storing the conversation logs.

- **Session History**: Stored in **Files** (`.jsonl`).
- **Semantic Memory**: Stored in **SQLite** (`~/.clawdbot/memory/{agentId}.sqlite`).
  - Uses `sqlite-vec` extension for vector embeddings.
  - Indexes chunks of conversation for retrieval (RAG).
  - This is an *index* of the history, not the source of truth.

## 5. Pruning Strategy

Clawdbot includes an auto-pruning mechanism to keep disk usage manageable.

- **Max Age**: `session.maxAge` (Default: 7 days). Sessions older than this are deleted.
- **Max Turns**: `session.maxTurns`. Sessions exceeding this length may be rotated or archived.

## 6. Key Files

- **`src/memory/session-files.ts`**: Core logic for reading/writing `.jsonl` transcripts.
- **`src/commands/agent/session-store.ts`**: Manages the `sessions.json` metadata registry.
- **`src/memory/manager.ts`**: Orchestrates the sync between the raw `.jsonl` logs and the SQLite vector index.
