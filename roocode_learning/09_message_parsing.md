# 09: Message Parsing & Protocol Handling

## Overview

As of **v3.43.0**, Roo-Code exclusively uses the **Native Protocol (JSON)** for tool calling. The legacy XML protocol has been removed to reduce token overhead and improve reliability. The parsing layer is optimized for native tool calls with robust error recovery for malformed responses.

**Key Files**:
- `src/core/assistant-message/NativeToolCallParser.ts` - Primary parser for native tool calls

---

## Native Protocol (JSON)

Roo-Code uses the standard OpenAI-format tool calling protocol:

```json
{
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "I'll read the file"
    },
    {
      "type": "tool_use",
      "id": "toolu_123",
      "name": "read_file",
      "input": {
        "path": "/path/to/file.ts"
      }
    }
  ]
}
```

---

## NativeToolCallParser

Handles JSON tool calls with error recovery and streaming support:

```typescript
// src/core/assistant-message/NativeToolCallParser.ts
export class NativeToolCallParser {
  static parse(message: ApiMessage): ToolCall[] {
    const toolCalls: ToolCall[] = []
    
    for (const block of message.content) {
      if (block.type === 'tool_use') {
        try {
          // Validate JSON structure
          const validated = this.validateInput(block.input)
          
          toolCalls.push({
            id: block.id,
            name: block.name,
            input: validated
          })
        } catch (error) {
          // Malformed JSON recovery
          toolCalls.push(this.recoverFromMalformedJson(block, error))
        }
      }
    }
    
    return toolCalls
  }
  
  static recoverFromMalformedJson(block: any, error: Error): ToolCall {
    // Try to salvage partial data using partial-json
    return {
      id: block.id || generateId(),
      name: block.name || 'unknown',
      input: this.extractPartialInput(block.input),
      error: error.message
    }
  }
}
```

---

## Malformed JSON Handling

Critical for reliability when models produce invalid JSON (e.g., due to context limits or streaming interruptions):

### Common Malformations
1. **Truncated JSON** - Incomplete closing braces
2. **Escaped quotes** - Extra backslashes
3. **Invalid characters** - Control characters in strings

### Recovery Strategies

Roo-Code uses the `partial-json` library to extract as much data as possible from incomplete or malformed JSON strings during streaming.

```typescript
// src/core/assistant-message/NativeToolCallParser.ts
function recoverMalformedJson(raw: string): any {
  try {
    // 1. Try direct parse
    return JSON.parse(raw)
  } catch {
    try {
      // 2. Try fixing common issues (newlines, tabs, trailing commas)
      const fixed = raw
        .replace(/\n/g, '\\n')
        .replace(/\t/g, '\\t')
        .replace(/,(\s*[}\]])/g, '$1')
      
      return JSON.parse(fixed)
    } catch {
      // 3. Extract partial data using regex or partial-json
      return extractPartialData(raw)
    }
  }
}
```

---

## Error Recovery Flow

1. **Receive assistant message**
   ↓
2. **Parse with NativeToolCallParser**
   ↓
3. **Validation fails?**
   ↓ YES
4. **Try recovery strategies**:
   - Fix common JSON issues
   - Extract partial data
   - Generate error tool call for feedback to the model
   ↓
5. **Return ParsedMessage** with valid tool calls or recovery metadata

---

## Source Code References

| File | Purpose |
|------|---------|
| `src/core/assistant-message/NativeToolCallParser.ts` | JSON protocol parsing and recovery |
| `src/core/assistant-message/types.ts` | Message type definitions |
| `src/core/tools/validateToolUse.ts` | Post-parse validation |

---

## Key Insights

- **Native-only protocol** reduces token usage and simplifies the parsing pipeline.
- **Error recovery** prevents task failures from malformed responses.
- **Streaming support** allows the UI to update progressively as the model generates JSON.
- **Validation happens in two stages**: parse format, then validate tool schema against the current mode.

**Version**: Roo-Code v3.43.0 (January 2026)
**Updated**: January 26, 2026
