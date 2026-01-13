# 13: Provider Integration & ApiHandler

## Overview

Roo-Code supports **40+ LLM providers** through a unified `ApiHandler` interface. Each provider implements the same contract, allowing seamless switching between models.

**Key Files**:
- `src/api/ApiHandler.ts` - Unified interface
- `src/api/providers/*` - Provider-specific implementations

## Supported Providers (40+)

| Provider | Models | Notable Features |
|----------|--------|------------------|
| **Anthropic** | Claude 3 (Opus, Sonnet, Haiku) | Native tool calling, vision |
| **OpenAI** | GPT-4, GPT-3.5 | Function calling, streaming |
| **Google** | Gemini Pro, Ultra | Multimodal, large context |
| **AWS Bedrock** | Claude, Titan, Llama | Enterprise security |
| **Azure OpenAI** | GPT-4, GPT-3.5 | Microsoft integration |
| **OpenRouter** | 100+ models | Model aggregator |
| **Ollama** | Local models | Offline support |
| **LM Studio** | Local models | Developer-friendly |
| **Groq** | Llama, Mixtral | Ultra-fast inference |
| **DeepSeek** | DeepSeek-V2 | Long context specialist |

## ApiHandler Interface

All providers implement this contract:

```typescript
// src/api/ApiHandler.ts
export interface ApiHandler {
  // Create completion
  createMessage(params: {
    systemPrompt: string
    messages: ApiMessage[]
    tools: Tool[]
  }): Promise<ApiResponse>
  
  // Stream completion
  streamMessage(params: {
    systemPrompt: string
    messages: ApiMessage[]
    tools: Tool[]
  }): AsyncGenerator<ApiStreamChunk>
  
  // Get model info
  getModel(): {
    id: string
    contextWindow: number
    supportsTools: boolean
    supportsVision: boolean
  }
}
```

## Provider Implementation Example

### Anthropic Provider

```typescript
// src/api/providers/anthropic.ts
export class AnthropicHandler implements ApiHandler {
  async createMessage(params: {
    systemPrompt: string
    messages: ApiMessage[]
    tools: Tool[]
  }): Promise<ApiResponse> {
    // 1. Convert to Anthropic format
    const anthropicMessages = this.convertMessages(params.messages)
    const anthropicTools = this.convertTools(params.tools)
    
    // 2. Make API call
    const response = await this.client.messages.create({
      model: this.modelId,
      max_tokens: 4096,
      system: params.systemPrompt,
      messages: anthropicMessages,
      tools: anthropicTools
    })
    
    // 3. Convert response back to unified format
    return this.convertResponse(response)
  }
  
  async *streamMessage(params): AsyncGenerator<ApiStreamChunk> {
    const stream = await this.client.messages.stream({
      model: this.modelId,
      max_tokens: 4096,
      system: params.systemPrompt,
      messages: this.convertMessages(params.messages),
      tools: this.convertTools(params.tools)
    })
    
    for await (const chunk of stream) {
      yield this.convertStreamChunk(chunk)
    }
  }
  
  getModel() {
    return {
      id: 'claude-3-opus-20240229',
      contextWindow: 200000,
      supportsTools: true,
      supportsVision: true
    }
  }
}
```

## Message Format Conversion

Each provider has different message formats:

### Anthropic (Native)
```typescript
{
  role: 'user',
  content: [
    { type: 'text', text: 'Hello' },
    { type: 'image', source: { ... } }
  ]
}
```

### OpenAI (Function Calling)
```typescript
{
  role: 'user',
  content: 'Hello'
}
// Tools separate
{
  role: 'assistant',
  content: null,
  function_call: { name: 'read_file', arguments: '{"path": "..."}' }
}
```

### Conversion Logic
```typescript
// src/api/providers/openai.ts
convertToOpenAIFormat(message: ApiMessage): OpenAIMessage {
  if (Array.isArray(message.content)) {
    // Anthropic native format
    return {
      role: message.role,
      content: message.content.map(block => {
        if (block.type === 'text') return block.text
        if (block.type === 'tool_use') {
          return {
            function_call: {
              name: block.name,
              arguments: JSON.stringify(block.input)
            }
          }
        }
      }).join('')
    }
  } else {
    // Already simple format
    return {
      role: message.role,
      content: message.content
    }
  }
}
```

## Provider Selection

Users select provider via settings:

```typescript
// src/core/config/ProviderManager.ts
export class ProviderManager {
  getHandler(config: {
    provider: string
    model: string
    apiKey: string
  }): ApiHandler {
    switch (config.provider) {
      case 'anthropic':
        return new AnthropicHandler(config)
      case 'openai':
        return new OpenAIHandler(config)
      case 'bedrock':
        return new BedrockHandler(config)
      case 'ollama':
        return new OllamaHandler(config)
      // ... 36+ more providers
      default:
        throw new Error(`Unknown provider: ${config.provider}`)
    }
  }
}
```

## Streaming Support

Real-time response streaming:

```typescript
// src/core/task/Task.ts
async streamResponse() {
  const handler = this.getApiHandler()
  
  let fullText = ''
  let toolCalls: ToolCall[] = []
  
  for await (const chunk of handler.streamMessage({
    systemPrompt: this.systemPrompt,
    messages: this.apiMessages,
    tools: this.availableTools
  })) {
    if (chunk.type === 'text') {
      fullText += chunk.text
      this.updateUI(fullText)  // Live update
    } else if (chunk.type === 'tool_call') {
      toolCalls.push(chunk.toolCall)
    }
  }
  
  return { text: fullText, toolCalls }
}
```

## Error Handling

Provider-specific error translation:

```typescript
// src/api/providers/base.ts
abstract class BaseHandler {
  protected handleError(error: any): ApiError {
    // Common error patterns
    if (error.status === 429) {
      return new RateLimitError('Rate limit exceeded', error)
    }
    if (error.status === 401) {
      return new AuthenticationError('Invalid API key', error)
    }
    if (error.message?.includes('context_length_exceeded')) {
      return new ContextLengthError('Message too long', error)
    }
    
    // Provider-specific errors
    return this.handleProviderSpecificError(error)
  }
  
  protected abstract handleProviderSpecificError(error: any): ApiError
}
```

## Local Provider Support

Ollama and LM Studio for offline usage:

```typescript
// src/api/providers/ollama.ts
export class OllamaHandler implements ApiHandler {
  async createMessage(params): Promise<ApiResponse> {
    // No API key needed - connects to localhost
    const response = await fetch('http://localhost:11434/api/chat', {
      method: 'POST',
      body: JSON.stringify({
        model: this.modelId,  // e.g., 'llama2', 'codellama'
        messages: params.messages,
        stream: false
      })
    })
    
    const data = await response.json()
    return this.convertResponse(data)
  }
  
  getModel() {
    return {
      id: this.modelId,
      contextWindow: 4096,  // Depends on model
      supportsTools: false,  // Most local models don't support tools
      supportsVision: false
    }
  }
}
```

## Source Code References

| File | Purpose |
|------|---------|
| `src/api/ApiHandler.ts` | Unified provider interface |
| `src/api/providers/anthropic.ts` | Anthropic implementation |
| `src/api/providers/openai.ts` | OpenAI implementation |
| `src/api/providers/bedrock.ts` | AWS Bedrock implementation |
| `src/api/providers/ollama.ts` | Ollama local models |
| `src/core/config/ProviderManager.ts` | Provider selection logic |

## Key Insights

- **40+ providers** through unified interface
- **Automatic format conversion** between native and provider-specific formats
- **Streaming support** for real-time responses
- **Local model support** (Ollama, LM Studio) for offline work
- **Error normalization** across providers

**Version**: Roo-Code v3.39+ (January 2026)
