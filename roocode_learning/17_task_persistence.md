# Task Persistence & History

Roo-Code utilizes a **hybrid persistence strategy** that deeply integrates with VS Code's storage mechanisms. It splits storage between the editor's managed state (for metadata and indexes) and the filesystem (for heavy content).

## 1. Hybrid Storage Architecture

### Component A: VS Code Memento (`globalState`)
Roo-Code uses the `ExtensionContext.globalState` (a SQLite-backed key-value store managed by VS Code) for lightweight, high-frequency access data.

**What's stored here:**
- **Task Index**: List of recent task IDs and summaries.
- **Extension State**: Active provider, API keys (encrypted), and UI settings (e.g., sound enabled, always-allow modes).
- **Update Metadata**: Migration flags (`defaultCommandsMigrationCompleted`).

**Why?** fast access, synchronous reads, and automatic synchronization across VS Code windows.

### Component B: Filesystem Storage
For the actual conversation history (which can be large), Roo-Code writes to JSON files.

**Location**: 
- **Default**: VS Code Global Storage URI (`~/Library/Application Support/Code/User/globalStorage/roovet.roo-cline/`)
- **Custom**: User can override this via the `customStoragePath` setting.

**Directory Structure**:
```text
globalStorage/
├── tasks/
│   └── {taskId}/
│       ├── ui_messages.json             # Full conversation history for the UI
│       ├── api_conversation_history.json # Optimized history for LLM context
│       └── task_metadata.json           # (Created implicitly in some versions)
├── settings/                           # Global settings files
└── cache/                              # Temporary artifacts
```

## 2. Dual History System

Roo-Code maintains two parallel history files for each task. This is a critical architectural decision.

### `ui_messages.json`
- **Purpose**: Rendering the chat interface.
- **Content**: Contains everything the user sees—rich text, images, tool call details, and "thoughts" (which might be hidden from the LLM in some modes).
- **Format**: Array of `ClineMessage` objects.

### `api_conversation_history.json`
- **Purpose**: Sending context to the LLM.
- **Content**: A "context-condensed" version of the history. It may have summarized older messages, removed large tool outputs, or stripped out UI-only metadata.
- **Format**: Array of `Anthropic.MessageParam` (or equivalent provider format).

**Syncing**: These two files are updated in tandem but serve different consumers.

## 3. Persistence Logic

**Key File**: `src/core/task-persistence/taskMessages.ts`

```typescript
export async function saveTaskMessages({ messages, taskId, globalStoragePath }) {
  const taskDir = await getTaskDirectoryPath(globalStoragePath, taskId)
  const filePath = path.join(taskDir, GlobalFileNames.uiMessages)
  await safeWriteJson(filePath, messages)
}
```

- **Atomic Writes**: Uses `safeWriteJson` to prevent partial file corruption.
- **Task Isolation**: Each task gets its own folder, making it easy to export or delete individual tasks without affecting others.

## 4. No Database Dependency

Roo-Code avoids bundling SQLite or other databases directly.
- It relies on **VS Code** to handle the "database" aspect via `globalState`.
- It relies on **Files** for bulk data.

This keeps the extension lightweight and ensures compatibility with remote development environments (Codespaces, SSH, WSL), where the extension host file access might be restricted or virtualized.

## 5. Pruning & Limits

Unlike OpenCode, Roo-Code currently has **no automatic pruning** of old tasks based on disk usage.
- Tasks persist until explicitly deleted by the user in the "History" view.
- Within a *single active task*, context is managed via "Context Condensation" (summarization), but the `ui_messages.json` file on disk continues to grow to preserve the full record for the user.

## 6. Key Files

- **`src/core/webview/ClineProvider.ts`**: Orchestrates state updates and event handling.
- **`src/core/task-persistence/index.ts`**: Entry point for storage operations.
- **`src/utils/storage.ts`**: Path resolution logic.
