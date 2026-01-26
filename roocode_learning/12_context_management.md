# 12: Context Management & History Optimization

## Overview

Roo-Code manages context window limits through **conversation condensation**, **sliding window**, and **smart truncation**. This prevents hitting token limits while preserving critical information.

**Key File**: `src/core/task/HistoryManager.ts`

## The Context Problem

LLMs have finite context windows:
- GPT-4: 8k-128k tokens
- Claude: 100k-200k tokens
- Long tasks accumulate messages faster than limits

Without management, tasks fail with "context too long" errors.

## Three Strategies

### 1. Sliding Window
Keep only recent N messages:

```typescript
// src/core/task/HistoryManager.ts
class SlidingWindowStrategy {
  apply(messages: ApiMessage[], maxTokens: number): ApiMessage[] {
    let tokenCount = 0
    const kept: ApiMessage[] = []
    
    // Keep messages from end until limit
    for (let i = messages.length - 1; i >= 0; i--) {
      const msgTokens = this.countTokens(messages[i])
      
      if (tokenCount + msgTokens > maxTokens) {
        break
      }
      
      kept.unshift(messages[i])
      tokenCount += msgTokens
    }
    
    return kept
  }
}
```

**Pros**: Simple, preserves recent context  
**Cons**: Loses early task context

### 2. Conversation Condensation
Summarize old messages into compact form:

```typescript
// src/core/task/ConversationCondenser.ts
class ConversationCondenser {
  async condense(messages: ApiMessage[]): Promise<ApiMessage[]> {
    const sections = this.splitIntoSections(messages)
    const condensed: ApiMessage[] = []
    
    for (const section of sections) {
      if (section.age < RECENT_THRESHOLD) {
        // Keep recent messages as-is
        condensed.push(...section.messages)
      } else {
        // Condense old sections
        const summary = await this.summarizeSection(section)
        condensed.push({
          role: 'assistant',
          content: `[Condensed ${section.messages.length} messages]: ${summary}`
        })
      }
    }
    
    return condensed
  }
  
  async summarizeSection(section: MessageSection): Promise<string> {
    // Use LLM to create summary
    const response = await this.llm.complete({
      prompt: `Summarize this conversation section concisely:\n${section.text}`,
      maxTokens: 200
    })
    
    return response.text
  }
}
```

**Pros**: Retains key information from entire history  
**Cons**: Costs extra LLM calls, may lose details

### 3. Smart Truncation
Remove low-value messages while keeping important ones:

```typescript
// src/core/task/SmartTruncation.ts
class SmartTruncation {
  apply(messages: ApiMessage[], maxTokens: number): ApiMessage[] {
    // 1. Score each message by importance
    const scored = messages.map(msg => ({
      message: msg,
      score: this.scoreMessage(msg)
    }))
    
    // 2. Always keep first and last messages
    const keep = [scored[0], scored[scored.length - 1]]
    
    // 3. Keep high-scoring messages until token limit
    const middle = scored.slice(1, -1).sort((a, b) => b.score - a.score)
    
    let tokenCount = this.countTokens([keep[0].message, keep[1].message])
    
    for (const item of middle) {
      const msgTokens = this.countTokens(item.message)
      if (tokenCount + msgTokens > maxTokens) break
      
      keep.push(item)
      tokenCount += msgTokens
    }
    
    // 4. Re-sort by original order
    return keep.sort((a, b) => a.originalIndex - b.originalIndex)
      .map(item => item.message)
  }
  
  scoreMessage(msg: ApiMessage): number {
    let score = 0
    
    // High value indicators
    if (msg.content.includes('error')) score += 10
    if (msg.role === 'user') score += 5
    if (this.hasToolCalls(msg)) score += 8
    if (this.hasFileOperations(msg)) score += 7
    
    // Low value indicators
    if (msg.content.length < 50) score -= 3
    if (msg.content.includes('thinking')) score -= 2
    
    return score
  }
}
```

**Pros**: Intelligent selection, preserves critical messages  
**Cons**: More complex, may misjudge importance

## Hybrid Strategy (What Roo Uses)

Combines all three approaches:

```typescript
// src/core/task/HistoryManager.ts
export class HistoryManager {
  async optimize(
    messages: ApiMessage[],
    maxTokens: number
  ): Promise<ApiMessage[]> {
    // 1. Check if optimization needed
    const currentTokens = this.countTokens(messages)
    if (currentTokens <= maxTokens) {
      return messages
    }
    
    // 2. Try sliding window (cheapest)
    const windowed = new SlidingWindowStrategy().apply(messages, maxTokens)
    if (this.isAcceptable(windowed)) {
      return windowed
    }
    
    // 3. Try smart truncation
    const truncated = new SmartTruncation().apply(messages, maxTokens)
    if (this.isAcceptable(truncated)) {
      return truncated
    }
    
    // 4. Fall back to condensation (expensive)
    const condensed = await new ConversationCondenser().condense(messages)
    return new SlidingWindowStrategy().apply(condensed, maxTokens)
  }
  
  isAcceptable(messages: ApiMessage[]): boolean {
    // Ensure we keep minimum context quality
    return messages.length >= MIN_MESSAGES &&
           this.hasSystemPrompt(messages) &&
           this.hasRecentUserMessage(messages)
  }
}
```

## Preservation Rules

Certain messages are NEVER removed:

```typescript
const ALWAYS_KEEP = [
  messages[0],                    // System prompt
  messages.filter(m => m.role === 'user').slice(-2),  // Last 2 user messages
  messages.filter(m => this.hasToolCalls(m)),         // Tool calls
  messages.filter(m => m.content.includes('error'))   // Errors
]
```

## Token Counting

Accurate token estimation is critical:

```typescript
// src/core/task/TokenCounter.ts
class TokenCounter {
  count(message: ApiMessage): number {
    // Use tiktoken for accurate counting
    const encoder = getEncoding('cl100k_base')
    
    let text = ''
    if (typeof message.content === 'string') {
      text = message.content
    } else {
      // Handle native format
      text = message.content
        .map(block => block.type === 'text' ? block.text : JSON.stringify(block))
        .join('')
    }
    
    const tokens = encoder.encode(text)
    return tokens.length
  }
}
```

## Dynamic Context Limits

Different providers have different limits:

```typescript
// src/api/providers/provider-config.ts
const CONTEXT_LIMITS = {
  'anthropic:claude-3-opus': 200000,
  'openai:gpt-4-turbo': 128000,
  'openai:gpt-4': 8192,
  'google:gemini-pro': 32000
}

// Adjust strategy based on available space
if (contextLimit > 100000) {
  // Large context - use simple sliding window
  strategy = new SlidingWindowStrategy()
} else {
  // Small context - aggressive optimization
  strategy = new HybridStrategy()
}
```

## Source Code References

| File | Purpose |
|------|---------|
| `src/core/task/HistoryManager.ts` | Main optimization orchestrator |
| `src/core/task/ConversationCondenser.ts` | Message summarization |
| `src/core/task/TokenCounter.ts` | Token counting utilities |
| `src/api/providers/provider-config.ts` | Provider-specific limits |

## Key Insights

- **Prevention over cure** - Manage context proactively, not when hitting limits
- **Multi-strategy** - No single approach works for all cases
- **Cost awareness** - Condensation uses LLM calls, use sparingly
- **Preserve critical info** - System prompts, errors, tool calls never removed

**Version**: Roo-Code v3.43.0 (January 2026)
**Updated**: January 26, 2026
