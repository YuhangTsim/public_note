# 09: Message Parsing & Protocol Handling

## Overview

Roo-Code supports **two message formats**: Native (JSON) and XML. The parsing layer handles both, with robust error recovery for malformed responses.

**Key Files**:
- `src/core/assistant-message/AssistantMessageParser.ts`
- `src/core/assistant-message/NativeToolCallParser.ts`
- `src/core/assistant-message/XmlToolCallParser.ts`

## Two Protocol Support

### 1. Native Protocol (JSON)
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

### 2. XML Protocol (Legacy)
```xml
I'll read the file

<read_file>
  <path>/path/to/file.ts</path>
</read_file>
```

## AssistantMessageParser

Main parsing orchestrator:

```typescript
// src/core/assistant-message/AssistantMessageParser.ts
export class AssistantMessageParser {
  parse(message: ApiMessage): ParsedMessage {
    // 1. Detect format
    const format = this.detectFormat(message)
    
    // 2. Route to appropriate parser
    if (format === 'native') {
      return NativeToolCallParser.parse(message)
    } else {
      return XmlToolCallParser.parse(message)
    }
  }
  
  detectFormat(message: ApiMessage): 'native' | 'xml' {
    if (Array.isArray(message.content)) {
      return 'native'
    }
    return 'xml'
  }
}
```

## NativeToolCallParser

Handles JSON tool calls with error recovery:

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
    // Try to salvage partial data
    return {
      id: block.id || generateId(),
      name: block.name || 'unknown',
      input: this.extractPartialInput(block.input),
      error: error.message
    }
  }
}
```

## Malformed JSON Handling

Critical for reliability when models produce invalid JSON:

### Common Malformations
1. **Truncated JSON** - Incomplete closing braces
2. **Escaped quotes** - Extra backslashes
3. **Invalid characters** - Control characters in strings
4. **Mixed formats** - JSON inside XML

### Recovery Strategies

```typescript
// src/core/assistant-message/NativeToolCallParser.ts
function recoverMalformedJson(raw: string): any {
  try {
    // 1. Try direct parse
    return JSON.parse(raw)
  } catch {
    try {
      // 2. Try fixing common issues
      const fixed = raw
        .replace(/\n/g, '\\n')           // Fix newlines
        .replace(/\t/g, '\\t')           // Fix tabs
        .replace(/([^\\])"/g, '$1\\"')   // Fix unescaped quotes
        .replace(/,(\s*[}\]])/g, '$1')   // Remove trailing commas
      
      return JSON.parse(fixed)
    } catch {
      // 3. Extract partial data
      return extractPartialData(raw)
    }
  }
}

function extractPartialData(raw: string): any {
  // Find key-value pairs even in broken JSON
  const keyValueRegex = /"(\w+)"\s*:\s*"([^"]+)"/g
  const result: any = {}
  
  let match
  while ((match = keyValueRegex.exec(raw)) !== null) {
    result[match[1]] = match[2]
  }
  
  return result
}
```

## XmlToolCallParser

Legacy XML format support:

```typescript
// src/core/assistant-message/XmlToolCallParser.ts
export class XmlToolCallParser {
  static parse(content: string): ToolCall[] {
    const toolRegex = /<(\w+)>([\s\S]*?)<\/\1>/g
    const toolCalls: ToolCall[] = []
    
    let match
    while ((match = toolRegex.exec(content)) !== null) {
      const toolName = match[1]
      const xmlBody = match[2]
      
      toolCalls.push({
        id: generateId(),
        name: toolName,
        input: this.parseXmlParams(xmlBody)
      })
    }
    
    return toolCalls
  }
  
  static parseXmlParams(xml: string): Record<string, any> {
    const paramRegex = /<(\w+)>([\s\S]*?)<\/\1>/g
    const params: Record<string, any> = {}
    
    let match
    while ((match = paramRegex.exec(xml)) !== null) {
      params[match[1]] = match[2].trim()
    }
    
    return params
  }
}
```

## Error Recovery Flow

```
1. Receive assistant message
   ↓
2. Detect format (Native vs XML)
   ↓
3. Parse with appropriate parser
   ↓
4. Validation fails?
   ↓ YES
5. Try recovery strategies:
   - Fix common JSON issues
   - Extract partial data
   - Generate error tool call
   ↓
6. Return ParsedMessage with:
   - Valid tool calls
   - Error annotations
   - Recovery metadata
```

## Source Code References

| File | Purpose |
|------|---------|
| `src/core/assistant-message/AssistantMessageParser.ts` | Main parser orchestrator |
| `src/core/assistant-message/NativeToolCallParser.ts` | JSON protocol parsing |
| `src/core/assistant-message/XmlToolCallParser.ts` | XML protocol parsing |
| `src/core/assistant-message/types.ts` | Message type definitions |
| `src/core/tools/validateToolUse.ts` | Post-parse validation |

## Key Insights

- **Dual protocol support** ensures compatibility with all models
- **Error recovery** prevents task failures from malformed responses
- **Graceful degradation** extracts partial data when full parse fails
- **Validation happens in two stages**: parse format, then validate tool schema

**Version**: Roo-Code v3.39+ (January 2026)
