# 08: Native Protocol

**Native JSON Tool Calling (The Only Supported Protocol)**

---

## Protocol Overview

As of **v3.43.0**, the XML protocol has been **REMOVED**. Roo-Code now exclusively uses the native OpenAI-format tool calling protocol.

| Aspect | Native Protocol |
|--------|-----------------|
| **Format** | `{ tool_calls: [{ name: "read_file", arguments: "{...}" }] }` |
| **Tools** | Separate `tools` parameter in API request |
| **Parser** | `NativeToolCallParser.ts` |
| **Tokens** | Low (tools separate from system prompt) |
| **Detection** | Uses unique `id` field for each tool call |

> [!IMPORTANT]
> **XML Protocol Removal**: All legacy XML parsing logic (`AssistantMessageParser.ts`) and XML-based tool definitions in the system prompt have been deleted. This significantly reduces token overhead and improves reliability with modern LLMs.

---

## Malformed JSON Handling

Even with native tool calling, LLMs may occasionally produce malformed JSON in the `arguments` field. Roo-Code employs a multi-layer defense:

### Multi-Layer Defense

**Layer 1: Streaming with partial-json**
```typescript
import { parseJSON } from 'partial-json'

processStreamingChunk(delta: string) {
  this.accumulator += delta
  
  try {
    const partial = parseJSON(this.accumulator)
    // Show user incremental updates in the UI
  } catch {
    // Not parseable yet (incomplete JSON)
  }
}
```

**Layer 2: Final Parsing**
```typescript
finalizeParsing(toolCall) {
  try {
    return JSON.parse(toolCall.arguments)
  } catch (error) {
    console.error('Malformed JSON:', error)
    return null // Signal failure to the orchestrator
  }
}
```

**Layer 3: Execution Abortion & Feedback**
```typescript
if (!block.parsedArgs) {
  await say('error', 'Malformed JSON')
  toolResults.push({
    type: 'tool_result',
    tool_use_id: block.id,
    content: 'Error: Malformed JSON. Please try again with valid JSON arguments.',
    is_error: true
  })
  continue // Skip execution of this specific tool call
}
```

---

## Source Code

| File | Purpose |
|------|---------|
| `src/core/assistant-message/NativeToolCallParser.ts` | Native protocol parsing and streaming support |

---

**Version**: Roo-Code v3.43.0 (January 2026)
**Updated**: January 26, 2026
