# 08: Native Protocol

**Native JSON vs XML Tool Calling**

---

## Protocols Comparison

| Aspect | XML Protocol | Native Protocol |
|--------|--------------|-----------------|
| **Format** | `<read_file><path>...</path></read_file>` | `{ tool_calls: [{ name: "read_file", arguments: "{...}" }] }` |
| **Tools** | In system prompt | Separate `tools` parameter |
| **Parser** | `AssistantMessageParser.ts` | `NativeToolCallParser.ts` |
| **Tokens** | High (tools in every prompt) | Low (tools separate) |
| **Detection** | No `id` field | Has `id` field |

---

## Malformed JSON Handling

### Multi-Layer Defense

**Layer 1: Streaming with partial-json**
```typescript
import { parseJSON } from 'partial-json'

processStreamingChunk(delta: string) {
  this.accumulator += delta
  
  try {
    const partial = parseJSON(this.accumulator)
    // Show user incremental updates
  } catch {
    // Not parseable yet
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
    return null // Signal failure
  }
}
```

**Layer 3: Execution Abortion**
```typescript
if (!block.parsedArgs) {
  await say('error', 'Malformed JSON')
  toolResults.push({
    type: 'tool_result',
    tool_use_id: block.id,
    content: 'Error: Malformed JSON',
    is_error: true
  })
  continue // Skip execution
}
```

---

## Source Code

| File | Purpose |
|------|---------|
| `src/core/assistant-message/NativeToolCallParser.ts` | Native protocol parsing |
| `src/core/assistant-message/AssistantMessageParser.ts` | XML protocol parsing |

---

**Version**: Roo-Code v3.39+ (January 2026)
