# 08: DM vs Channel Logic

**Security, Etiquette, and Context Separation**

OpenClaw treats Direct Messages (DMs) and Channel/Group chats as fundamentally different contexts. This separation is hardcoded into the system prompt builder and tool logic to ensure security and social grace.

## 1. Security: The Memory Wall

The most critical distinction is **access to long-term memory**.

| Feature | Direct Message (DM) | Channel / Group Chat |
| :--- | :--- | :--- |
| **`MEMORY.md` Access** | ✅ **Loaded** | ❌ **BLOCKED** |
| **Assumption** | "I am talking to my owner." | "I am in a public space." |
| **Risk Profile** | Low (Private) | High (Leakage Risk) |

### Why Block `MEMORY.md`?
`MEMORY.md` often contains sensitive data: home addresses, API keys, personal thoughts, and family details.
By strictly preventing this file from loading in shared contexts, OpenClaw eliminates the risk of an agent "hallucinating" or accidentally mentioning private data in a public Discord server or WhatsApp group.

### Implementation
In `src/agents/system-prompt.ts` (conceptual flow):
```typescript
if (isMainSession(sessionKey)) {
  injectFile("MEMORY.md"); // Only injected for direct owner chats
}
```

---

## 2. Behavioral Etiquette: The "Shut Up" Rule

The default `AGENTS.md` template injects specific rules for group conduct.

### DM Behavior
*   **Always Reply:** The user is speaking directly to the agent. Silence is an error.

### Channel/Group Behavior
*   **Default:** **Silence** (`HEARTBEAT_OK` or `¿¿silent`).
*   **Trigger:** Reply **ONLY** if:
    *   Directly mentioned (@bot).
    *   Asked a specific question.
    *   Can add *significant* value (correcting a fact, providing a requested link).
*   **Prohibition:** Do not respond to casual banter ("lol", "yeah"). Do not answer questions meant for others.

> **"Participate, don't dominate."** — *Standard AGENTS.md instruction*

---

## 3. Technical Differences

### A. Session Keys
The system identifies the context via the session key structure:
*   **DM:** `[provider]:[user_id]` (e.g., `discord:123456`)
*   **Channel:** `[provider]:channel:[channel_id]` (e.g., `discord:channel:98765`)

### B. Citation Visibility
**File:** `src/agents/tools/memory-tool.ts`

*   **DMs:** When `memory_search` is used, the agent includes citations (`Source: memory/log.md:L15`) to prove where it got the info.
*   **Channels:** Citations are **suppressed by default**.
    *   *Reason:* It looks robotic and noisy to spam file paths in a casual group chat. The agent just gives the answer.

```typescript
function shouldIncludeCitations(params) {
  const chatType = deriveChatTypeFromSessionKey(params.sessionKey);
  // Auto-hide citations in groups/channels
  return chatType === "direct"; 
}
```

### C. Reply Routing
*   **DMs:** Responses go directly to the user.
*   **Channels:** The agent must be aware of *reply threads*.
    *   The system prompts the agent to use `[[reply_to_current]]` tags if it wants to threaded-reply to a specific message in a busy channel.

---

## Summary

OpenClaw is designed to be a **Personal Assistant first, Chatbot second**.

*   **In Private:** It is your second brain (Full Memory).
*   **In Public:** It is a helpful utility (Stateless, Polite, Secure).

This dual-mode operation allows users to safely add their assistant to work Slacks or friend groups without fear of it acting weird or leaking secrets.
