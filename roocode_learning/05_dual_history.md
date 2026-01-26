# 05: Dual History System

**UI Messages vs API Messages - Why Two Histories?**

---

## Overview

Roo-Code maintains **two separate message histories** for every task:

| History | Format | Purpose | File |
|---------|--------|---------|------|
| **UI Messages** | `ClineMessage[]` | Display, user interaction, metadata | `ui_messages.json` |
| **API Messages** | `ApiMessage[]` | LLM context (Anthropic format) | `api_conversation_history.json` |

---

## Why Two Histories?

### Different Concerns

**UI Messages Need**:
- Timestamps for display
- Approval states (pending/approved/rejected)
- Partial content for streaming
- Tool execution metadata
- User feedback text
- Ask/say message types

**API Messages Need**:
- Clean standardized format
- Role-based structure (user/assistant)
- Tool use/tool result pairing
- No UI-specific metadata
- Optimized for LLM consumption

### Example: Same Event, Different Representations

**Event**: AI calls `read_file` tool

**UI Message**:
```json
{
  "ts": 1704067200000,
  "type": "say",
  "say": "tool",
  "tool": "read_file",
  "path": "src/auth.ts",
  "text": "Reading auth.ts...",
  "partial": false,
  "approvalState": "approved",
  "result": "export function login() { ... }"
}
```

**API Message**:
```json
{
  "role": "assistant",
  "content": [
    {
      "type": "tool_use",
      "id": "toolu_abc123",
      "name": "read_file",
      "input": {
        "path": "src/auth.ts"
      }
    }
  ]
}
```

---

## Complete Conversation Example

**User Request**: "Add error handling to auth.ts"

### UI Messages (`ui_messages.json`)

```json
[
  {
    "ts": 1704067200000,
    "type": "ask",
    "ask": "request_limit_reached",
    "text": "Add error handling to auth.ts"
  },
  {
    "ts": 1704067201000,
    "type": "say",
    "say": "text",
    "text": "I'll add comprehensive error handling.",
    "partial": false
  },
  {
    "ts": 1704067202000,
    "type": "say",
    "say": "tool",
    "tool": "read_file",
    "path": "src/auth.ts",
    "text": "Reading src/auth.ts...",
    "approvalState": "approved"
  },
  {
    "ts": 1704067205000,
    "type": "say",
    "say": "tool",
    "tool": "write_to_file",
    "path": "src/auth.ts",
    "diff": "...",  
    "approvalState": "pending"
  },
  {
    "ts": 1704067210000,
    "type": "say",
    "say": "completion_result",
    "text": "Error handling added successfully."
  }
]
```

### API Messages (`api_conversation_history.json`)

```json
[
  {
    "role": "user",
    "content": [
      { "type": "text", "text": "Add error handling to auth.ts" }
    ]
  },
  {
    "role": "assistant",
    "content": [
      { "type": "text", "text": "I'll add comprehensive error handling." },
      {
        "type": "tool_use",
        "id": "toolu_abc123",
        "name": "read_file",
        "input": { "path": "src/auth.ts" }
      }
    ]
  },
  {
    "role": "user",
    "content": [
      {
        "type": "tool_result",
        "tool_use_id": "toolu_abc123",
        "content": "export async function login(creds) {\n  const response = await fetch('/api/login', ...);\n  return response.json();\n}"
      }
    ]
  },
  {
    "role": "assistant",
    "content": [
      { "type": "text", "text": "I'll add try-catch blocks..." },
      {
        "type": "tool_use",
        "id": "toolu_def456",
        "name": "write_to_file",
        "input": {
          "path": "src/auth.ts",
          "content": "export async function login(creds) {\n  try {\n    const response = await fetch('/api/login', ...);\n    if (!response.ok) throw new Error('Login failed');\n    return response.json();\n  } catch (error) {\n    console.error('Login error:', error);\n    throw error;\n  }\n}"
        }
      }
    ]
  },
  {
    "role": "user",
    "content": [
      {
        "type": "tool_result",
        "tool_use_id": "toolu_def456",
        "content": "Successfully wrote to src/auth.ts"
      }
    ]
  },
  {
    "role": "assistant",
    "content": [
      {
        "type": "tool_use",
        "id": "toolu_ghi789",
        "name": "attempt_completion",
        "input": {
          "result": "Error handling added successfully."
        }
      }
    ]
  }
]
```

---

## Persistence

### File Locations

```
~/.roo/tasks/task_{taskId}/
├── ui_messages.json                # UI history
├── api_conversation_history.json   # API history
└── task_metadata.json              # Task info
```

### Saving

```typescript
// src/core/task-persistence/taskMessages.ts
export async function saveTaskMessages(
  globalStoragePath: string,
  taskId: string,
  messages: ClineMessage[]
): Promise<void> {
  const filePath = path.join(
    globalStoragePath,
    'tasks',
    `task_${taskId}`,
    'ui_messages.json'
  )
  
  await fs.writeFile(filePath, JSON.stringify(messages, null, 2))
}

// src/core/task-persistence/apiMessages.ts
export async function saveApiMessages(
  globalStoragePath: string,
  taskId: string,
  messages: ApiMessage[]
): Promise<void> {
  const filePath = path.join(
    globalStoragePath,
    'tasks',
    `task_${taskId}`,
    'api_conversation_history.json'
  )
  
  await fs.writeFile(filePath, JSON.stringify(messages, null, 2))
}
```

---

## Synchronization

### MessageManager

```typescript
// src/core/message-manager/index.ts
class MessageManager {
  // Ensures both histories stay in sync
  
  async rewindToMessage(messageId: string) {
    // 1. Find message in UI history
    const uiIndex = findMessageIndex(this.clineMessages, messageId)
    
    // 2. Truncate UI messages
    this.clineMessages = this.clineMessages.slice(0, uiIndex + 1)
    
    // 3. Truncate API messages correspondingly
    this.apiConversationHistory = this.syncApiHistory(
      this.apiConversationHistory,
      this.clineMessages
    )
    
    // 4. Save both
    await this.saveMessages()
  }
}
```

---

## Source Code References

| Component | File Path |
|-----------|-----------|
| **UI Messages** | `src/core/task-persistence/taskMessages.ts` |
| **API Messages** | `src/core/task-persistence/apiMessages.ts` |
| **Message Manager** | `src/core/message-manager/index.ts` |
| **Task Class** | `src/core/task/Task.ts` |

---

**Version**: Roo-Code v3.43.0 (January 2026)
**Updated**: January 26, 2026
