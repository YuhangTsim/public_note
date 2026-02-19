# Goose Context Management Analysis

## Repository Overview

**Repository**: [block/goose](https://github.com/block/goose)  
**Language**: Rust  
**Architecture**: Extension-based AI agent framework with MCP integration  
**Focus**: Local, extensible AI agent for automating engineering tasks  

## Context Management Architecture

### 1. Core Context Management System

Goose implements a sophisticated context management system built around three main components:

**Context Management Module Structure:**
```rust
// crates/goose/src/context_mgmt/
├── mod.rs              // Module exports
├── common.rs           // Token counting and limits
├── truncate.rs         // Context truncation strategies
└── summarize.rs        // Context summarization
```

**Key Implementation Features:**
- **Conservative Token Estimation**: Uses 70% of model context limit with overhead buffers
- **Dual Strategy Approach**: Both truncation and summarization for context management
- **Tool-Aware Processing**: Preserves tool call/response pairs during context operations
- **Content-Level Truncation**: Handles oversized individual messages by truncating content

### 2. Context Window Management

**Token Limit Calculation:**
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

**Context Monitoring:**
- **Real-time Token Tracking**: Continuous monitoring of token usage across all message components
- **Model-Specific Adaptation**: Adapts to different model context windows automatically
- **Overhead Management**: Accounts for system prompts and tool definitions in token calculations
- **Conservative Estimation**: Uses 70% factor to account for tokenizer differences across providers

### 3. Context Truncation Strategy

**OldestFirstTruncation Implementation:**
```rust
// crates/goose/src/context_mgmt/truncate.rs
pub struct OldestFirstTruncation;

impl TruncationStrategy for OldestFirstTruncation {
    fn determine_indices_to_remove(
        &self,
        messages: &[Message],
        token_counts: &[usize],
        context_limit: usize,
    ) -> Result<HashSet<usize>> {
        // 1. Remove oldest messages first
        // 2. Preserve tool call/response pairs
        // 3. Ensure conversation ends with user message
        // 4. Maintain conversation coherence
    }
}
```

**Truncation Logic:**
1. **Oldest-First Removal**: Removes messages starting from the oldest
2. **Tool Pair Preservation**: Ensures tool calls and responses are removed together
3. **Conversation Integrity**: Maintains proper conversation flow (user → assistant → user)
4. **Content Truncation**: For oversized individual messages, truncates content to 5000 characters
5. **Graceful Degradation**: Falls back to content truncation when standard truncation insufficient

### 4. Context Summarization Strategy

**Chunked Summarization Approach:**
```rust
// crates/goose/src/context_mgmt/summarize.rs
pub async fn summarize_messages_async(
    provider: Arc<dyn Provider>,
    messages: &[Message],
    token_counter: &AsyncTokenCounter,
    context_limit: usize,
) -> Result<(Vec<Message>, Vec<usize>), anyhow::Error> {
    let chunk_size = context_limit / 3; // 33% of context window
    // Process messages in chunks, accumulating summaries
}
```

**Summarization Process:**
1. **Chunk-Based Processing**: Breaks messages into chunks of ~33% context window size
2. **Accumulative Summarization**: Each chunk is summarized with previous accumulated summary
3. **Tool Response Preservation**: Temporarily removes last tool response pairs during summarization
4. **Reintegration**: Adds back preserved tool responses to final summary
5. **Iterative Refinement**: Multiple summarization passes for large conversation histories

### 5. Agent-Level Context Integration

**Agent Context Methods:**
```rust
// crates/goose/src/agents/context.rs
impl Agent {
    pub async fn truncate_context(
        &self,
        messages: &[Message],
    ) -> Result<(Vec<Message>, Vec<usize>), anyhow::Error> {
        // Applies truncation with user notification
    }

    pub async fn summarize_context(
        &self,
        messages: &[Message],
    ) -> Result<(Vec<Message>, Vec<usize>), anyhow::Error> {
        // Applies summarization with user notification
    }
}
```

**Context Integration Features:**
- **Transparent Operation**: Automatically handles context overflow situations
- **User Notification**: Adds assistant messages explaining context management actions
- **Error Recovery**: Graceful handling of context management failures
- **Async Processing**: Non-blocking context operations for better performance

## Context Management Methodology

### 1. Proactive Context Management

**Context Overflow Detection:**
- **Pre-emptive Monitoring**: Tracks token usage before sending to LLM
- **Threshold-Based Triggers**: Activates context management at 70% of model limit
- **Automatic Selection**: Chooses between truncation and summarization based on conversation characteristics

### 2. Tool-Aware Context Preservation

**Tool Call Integrity:**
- **Paired Removal**: Tool calls and responses are always removed together
- **Metadata Preservation**: Maintains tool call metadata for proper conversation flow
- **Error Handling**: Graceful handling of incomplete tool call pairs

### 3. Content-Level Truncation

**Oversized Message Handling:**
```rust
const MAX_TRUNCATED_CONTENT_SIZE: usize = 5000;

fn truncate_message_content(message: &Message, max_content_size: usize) -> Result<Message> {
    // Truncates individual message content while preserving structure
    // Handles text content, tool responses, and resource content
}
```

**Advanced Content Processing:**
- **Structured Truncation**: Preserves message structure while truncating content
- **Multi-Content Support**: Handles text, tool responses, and resource content
- **Truncation Indicators**: Adds clear markers showing content was truncated
- **Size Estimation**: Uses character-based estimation for token approximation

### 4. Conversation Flow Preservation

**Message Ordering Rules:**
1. **User-First Requirement**: Conversations must start with user message
2. **User-Last Requirement**: Conversations must end with user message
3. **Tool Completion**: Tool calls must have corresponding responses
4. **Coherence Maintenance**: Preserves logical conversation flow

## Implementation Strengths

### 1. **Robust Error Handling**
- Comprehensive error recovery for context management failures
- Graceful degradation when standard strategies insufficient
- Clear error messages and logging for debugging

### 2. **Performance Optimization**
- Async token counting for better performance
- Efficient memory management during context operations
- Minimal overhead for context monitoring

### 3. **Model Agnostic Design**
- Works with any LLM provider through abstraction layer
- Adapts to different context window sizes automatically
- Handles tokenizer differences through conservative estimation

### 4. **Tool Integration**
- Seamless integration with MCP (Model Context Protocol)
- Preserves tool call integrity during context management
- Supports complex tool interaction patterns

## Key Innovations

### 1. **Dual-Strategy Context Management**
- Intelligent selection between truncation and summarization
- Context-aware strategy selection based on conversation characteristics
- Fallback mechanisms for edge cases

### 2. **Content-Aware Truncation**
- Handles oversized individual messages through content truncation
- Preserves message structure while reducing size
- Clear indication of truncated content to users

### 3. **Tool-Preserving Algorithms**
- Ensures tool call/response pairs remain intact
- Maintains conversation coherence during context operations
- Handles complex tool interaction scenarios

### 4. **Conservative Token Management**
- Uses safety factors to prevent context overflow
- Accounts for provider-specific tokenizer differences
- Maintains buffer space for system prompts and tools

## Context Management Files

### Core Implementation
- **Context Management**: `crates/goose/src/context_mgmt/mod.rs` - Main module exports
- **Token Utilities**: `crates/goose/src/context_mgmt/common.rs` - Token counting and limits
- **Truncation Logic**: `crates/goose/src/context_mgmt/truncate.rs` - Context truncation strategies
- **Summarization**: `crates/goose/src/context_mgmt/summarize.rs` - Context summarization

### Agent Integration
- **Agent Context**: `crates/goose/src/agents/context.rs` - Agent-level context management
- **Token Counter**: `crates/goose/src/token_counter.rs` - Token counting utilities

### Key Methods and Functions
- **Context Truncation**: `Agent::truncate_context()` - Main truncation method
- **Context Summarization**: `Agent::summarize_context()` - Main summarization method
- **Token Estimation**: `estimate_target_context_limit()` - Context limit calculation
- **Message Truncation**: `truncate_messages()` - Core truncation algorithm
- **Content Truncation**: `truncate_message_content()` - Individual message content truncation
