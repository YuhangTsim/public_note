# Goose Context Selection and Management Analysis

## Overview

Goose is a local, extensible, open-source AI agent that automates engineering tasks. It implements a sophisticated context management system built around three main components: truncation, summarization, and token counting. The system is designed to handle context overflow situations gracefully while preserving important conversation context.

## Context Selection Methodology

### 1. Conservative Context Window Management

Goose implements a conservative approach to context window management:

```rust
// crates/goose/src/context_mgmt/common.rs
const ESTIMATE_FACTOR: f32 = 0.7;
const SYSTEM_PROMPT_TOKEN_OVERHEAD: usize = 3_000;
const TOOLS_TOKEN_OVERHEAD: usize = 5_000;

pub fn estimate_target_context_limit(provider: Arc<dyn Provider>) -> usize {
    let model_context_limit = provider.get_model_config().context_limit();
    let target_limit = (model_context_limit as f32 * ESTIMATE_FACTOR) as usize;
    target_limit - (SYSTEM_PROMPT_TOKEN_OVERHEAD + TOOLS_TOKEN_OVERHEAD)
}
```

**Key Features:**
- **Conservative Estimation**: Uses only 70% of the model's context limit
- **Overhead Buffering**: Reserves 3,000 tokens for system prompts and 5,000 tokens for tools
- **Model-Specific Adaptation**: Automatically adapts to different model context windows
- **Token Counting**: Provides both sync and async token counting methods

### 2. Dual Strategy Context Management

Goose employs two complementary strategies for context management:

#### A. Context Truncation Strategy
```rust
// crates/goose/src/context_mgmt/truncate.rs
pub fn truncate_messages(
    messages: &[Message],
    token_counts: &[usize],
    context_limit: usize,
    strategy: &dyn TruncationStrategy,
) -> Result<(Vec<Message>, Vec<usize>), anyhow::Error>
```

**Truncation Features:**
- **Oversized Message Handling**: Truncates individual messages that exceed context limits
- **Content Preservation**: Maintains message structure while truncating content
- **Tool-Aware Processing**: Preserves tool call/response pairs during truncation
- **Oldest-First Strategy**: Removes oldest messages when context overflow occurs

#### B. Context Summarization Strategy
```rust
// crates/goose/src/context_mgmt/summarize.rs
pub async fn summarize_messages(
    provider: Arc<dyn Provider>,
    messages: &[Message],
    token_counter: &TokenCounter,
    context_limit: usize,
) -> Result<(Vec<Message>, Vec<usize>), anyhow::Error>
```

**Summarization Features:**
- **Chunk-Based Processing**: Breaks messages into chunks of ~33% context window size
- **Accumulative Summarization**: Combines previous summaries with new chunks
- **Tool Response Preservation**: Temporarily removes tool responses during summarization
- **LLM-Powered Summarization**: Uses the same LLM provider for intelligent summarization

### 3. Context Overflow Detection and Handling

```rust
// crates/goose/src/context_mgmt/truncate.rs
fn handle_oversized_messages(
    messages: &[Message],
    token_counts: &[usize],
    context_limit: usize,
    strategy: &dyn TruncationStrategy,
) -> Result<(Vec<Message>, Vec<usize>), anyhow::Error>
```

**Overflow Handling:**
- **Individual Message Truncation**: Handles messages larger than context limit
- **Content Truncation**: Truncates message content while preserving structure
- **Graceful Degradation**: Skips messages that cannot be truncated
- **User Notification**: Logs warnings about truncated content

## Context Management Methodology

### 1. Proactive Context Management

Goose implements proactive context management rather than reactive:

**Context Overflow Detection:**
- **Token Monitoring**: Continuously tracks token usage across all messages
- **Threshold-Based Triggers**: Uses conservative thresholds to prevent overflow
- **Model-Specific Limits**: Adapts to different model context windows automatically

**Context Preservation Strategies:**
- **Tool Call Preservation**: Maintains tool call/response pairs during context operations
- **Message Structure Preservation**: Preserves message roles and metadata
- **Content Truncation**: Intelligently truncates large content while maintaining readability

### 2. Context State Management

**Message Processing Flow:**
1. **Token Counting**: Calculate tokens for all messages
2. **Overflow Detection**: Check if total tokens exceed context limit
3. **Strategy Selection**: Choose between truncation and summarization
4. **Context Processing**: Apply selected strategy
5. **State Update**: Update message list and token counts

**Context Integration Features:**
- **Transparent Operation**: Automatically handles context overflow situations
- **User Notification**: Adds assistant messages explaining context management actions
- **Error Recovery**: Graceful handling of context management failures
- **Async Processing**: Non-blocking context operations for better performance

### 3. Context Optimization Features

**Token Management:**
- **Conservative Estimation**: Uses 70% of model context limit with overhead buffers
- **Dual Strategy Approach**: Both truncation and summarization for context management
- **Tool-Aware Processing**: Preserves tool call/response pairs during context operations

**Performance Optimizations:**
- **Async Token Counting**: Provides async versions for better performance
- **Chunk-Based Processing**: Breaks large contexts into manageable chunks
- **Incremental Summarization**: Builds summaries incrementally to reduce token usage

## Implementation Details

### 1. Context Selection Logic

**Context Selection Flow:**
1. **Token Estimation**: Calculate tokens for all messages
2. **Context Limit Check**: Compare against conservative context limit
3. **Strategy Decision**: Choose truncation or summarization based on context size
4. **Context Processing**: Apply selected strategy
5. **State Update**: Update conversation state with processed context
6. **User Notification**: Inform user of context management actions
7. **Present Context**: Send processed context to LLM

### 2. Context Management Logic

**Context Management Flow:**
1. **Monitor Context Size**: Track token usage continuously
2. **Detect Overflow**: Identify when context exceeds limits
3. **If context insufficient**: trigger reflection
4. **Apply Strategy**: Use truncation or summarization
5. **Update State**: Modify conversation state
6. **Continue Processing**: Resume normal operation

### 3. Context Delivery Strategy

**Context Formatting:**
- **Message Preservation**: Maintains message roles and structure
- **Tool Call Handling**: Preserves tool call/response relationships
- **Content Truncation**: Intelligently truncates large content
- **Summary Integration**: Seamlessly integrates summaries into conversation

## Strengths and Limitations

### Strengths

1. **Conservative Approach**: Uses only 70% of context window, preventing overflow
2. **Dual Strategy**: Both truncation and summarization provide flexibility
3. **Tool-Aware Processing**: Preserves important tool call/response pairs
4. **Async Support**: Non-blocking operations for better performance
5. **Model Adaptation**: Automatically adapts to different model context windows
6. **Error Recovery**: Graceful handling of context management failures

### Limitations

1. **Context Window Limitations**: May still exceed context window in very large codebases
2. **Summarization Quality**: Depends on LLM quality for summarization
3. **Token Estimation**: Uses rough token estimation for some operations
4. **Context Confusion**: LLM may get confused by large context windows
5. **Performance Overhead**: Context management operations add computational cost

## Technical Architecture

### Core Context Management Files

- **Context Management Module**: `crates/goose/src/context_mgmt/` - Main context management implementation
- **Common Utilities**: `crates/goose/src/context_mgmt/common.rs` - Token counting and limit estimation
- **Truncation Strategy**: `crates/goose/src/context_mgmt/truncate.rs` - Message truncation implementation
- **Summarization Strategy**: `crates/goose/src/context_mgmt/summarize.rs` - LLM-powered summarization

### Key Methods

- **Context Limit Estimation**: `estimate_target_context_limit()` - Conservative context limit calculation
- **Token Counting**: `get_messages_token_counts()` - Accurate token counting for messages
- **Message Truncation**: `truncate_messages()` - Intelligent message truncation
- **Context Summarization**: `summarize_messages()` - LLM-powered context summarization

### Context Management Integration

- **Agent Integration**: `crates/goose/src/agents/context.rs` - Agent-level context management
- **Provider Integration**: Works with any LLM provider through the Provider trait
- **Message Integration**: Seamlessly integrates with the Message system
- **Tool Integration**: Preserves tool calls and responses during context operations

## Summary

Goose implements a sophisticated, conservative context management system that prioritizes reliability and context preservation. Its dual-strategy approach (truncation + summarization) provides flexibility in handling different context overflow scenarios, while its tool-aware processing ensures that important conversation elements are preserved. The system's conservative token estimation and proactive overflow detection make it well-suited for long-running conversations and complex engineering tasks. 