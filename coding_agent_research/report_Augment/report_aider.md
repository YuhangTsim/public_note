# Aider Context Selection and Management Analysis

## Overview
Aider is a command-line AI coding assistant that employs a sophisticated graph-based context selection system. Its core innovation lies in treating codebases as dependency graphs and using PageRank algorithms to identify the most relevant code context for any given task.

## Context Selection Methodology

### 1. Repository Map (RepoMap) System Architecture
Aider's context selection is built around its **Repository Map** system, which creates a mathematical model of code relationships:

**Core Implementation Pipeline:**
```python
# aider/repomap.py - Main context selection flow
def get_repo_map(self, chat_files, other_files, mentioned_fnames, mentioned_idents):
    1. Parse files with tree-sitter → Extract symbols (definitions + references)
    2. Build dependency graph → Files as nodes, symbol references as edges
    3. Apply PageRank algorithm → Rank nodes by importance
    4. Select top-ranked tags → Within token budget constraints
    5. Generate context map → Format for LLM consumption
```

**Tree-sitter Symbol Extraction:**
- **Definitions**: Functions, classes, variables, methods (`def`, `class`, `function`)
- **References**: Symbol usage, imports, calls (`identifier`, `call_expression`)
- **Language Support**: 40+ languages via tree-sitter grammars
- **Symbol Classification**: Distinguishes between definitions and references for accurate graph construction

### 2. PageRank-Based Context Ranking
Aider's core innovation is applying Google's PageRank algorithm to code dependency graphs:

**Mathematical Foundation:**
```python
# Personalized PageRank with weighted multipliers
personalization_weights = {
    'chat_files': 50.0,           # Files explicitly in conversation
    'mentioned_identifiers': 10.0, # Symbols mentioned by user/LLM
    'long_identifiers': 10.0,     # Identifiers ≥8 chars (likely important)
    'private_identifiers': 0.1,   # Private symbols (less relevant)
    'common_identifiers': 0.1,    # Symbols in >5 files (too generic)
}
```

**Graph Construction Logic:**
```python
# aider/repomap.py:get_ranked_tags()
1. Create MultiDiGraph G(files, symbol_references)
2. Add personalization weights to nodes
3. Run PageRank: rank = nx.pagerank(G, personalization=weights)
4. Distribute rank to definition edges
5. Sort definitions by rank, select within token budget
```

### 3. Token Budget Optimization
Aider implements sophisticated token management to maximize context relevance within constraints:

**Binary Search Algorithm:**
```python
# aider/repomap.py:get_repo_map()
def optimize_tag_selection(self, ranked_tags, token_budget):
    # Binary search for maximum tags within budget
    left, right = 0, len(ranked_tags)
    while left < right:
        mid = (left + right + 1) // 2
        if self.estimate_tokens(ranked_tags[:mid]) <= token_budget:
            left = mid
        else:
            right = mid - 1
    return ranked_tags[:left]
```

**Dynamic Context Scaling:**
- **Base Budget**: 1k tokens (configurable via `--map-tokens`)
- **No-Files Multiplier**: 8x expansion when no files in chat (`map_mul_no_files`)
- **Error Tolerance**: 10% buffer for token estimation inaccuracies
- **Cache Optimization**: Avoids recomputation of expensive PageRank calculations

### 4. Multi-Level File Selection Logic
Aider employs a hierarchical approach to file selection:

**Level 1: Manual User Control**
```python
# aider/commands.py
/add <files>     # Explicit file addition to chat context
/drop <files>    # Remove files from chat context
/ls              # List files in chat
```

**Level 2: Automatic LLM Detection**
```python
# aider/coders/base_coder.py:get_file_mentions()
def detect_file_mentions(self, content):
    # Regex patterns for file references
    # Offers to add mentioned files to chat
    # Tracks file mention confidence scores
```

**Level 3: Context-Aware Selection**
```python
# aider/coders/context_coder.py
class ContextCoder:
    # Specialized coder for identifying files needing edits
    # Uses LLM to analyze request and suggest relevant files
    # Integrates with repository map for context expansion
```

## Context Management Methodology

### 1. Multi-Level Context System
Aider manages context at multiple levels:

**Level 1: Repository Map**
- High-level overview of codebase structure
- Key symbols and their locations
- Dependency relationships

**Level 2: Full File Contents**
- Complete file contents when explicitly added to chat
- Used for actual code editing operations

**Level 3: Read-only Files**
- Files marked as read-only for reference only
- Provides additional context without allowing edits

### 2. Context State Management
**Chat State:**
- Tracks which files are currently "in chat"
- Maintains conversation history
- Manages file content versions

**Reflection System:**
- Monitors LLM responses for file mentions
- Automatically adds newly mentioned files
- Implements reflection loop to refine context selection

### 3. Context Optimization Features
**Token Management:**
- Estimates token usage for different context components
- Balances repo map size with file contents
- Implements token counting with sampling for large texts

**Cache System:**
- Caches parsed ASTs and computed rankings
- Implements cache invalidation based on file changes
- Uses SQLite for persistent tag storage

### 4. Context Delivery Strategy
**Prompt Engineering:**
- Different prompt templates for different contexts (edit, ask, help)
- Context-aware system messages
- File content prefixes to establish ground truth

**Format Management:**
- Supports multiple edit formats (diff, context, unified)
- Handles different LLM capabilities
- Provides format-specific prompts

## Methodology and Logic

### 1. Context Selection Logic
```
1. User provides request
2. If files in chat: use repo map + file contents
3. If no files in chat: expand repo map significantly
4. Apply graph ranking to select most relevant symbols
5. Include mentioned files/identifiers with high priority
6. Optimize selection to fit within token budget
7. Present context to LLM
```

### 2. Context Management Logic
```
1. Monitor LLM responses for file mentions
2. If new files mentioned: offer to add them
3. If context insufficient: trigger reflection
4. Update chat state with new files
5. Recompute repo map if needed
6. Maintain conversation continuity
```

### 3. Optimization Logic
```
1. Start with binary search for optimal tag count
2. Estimate token usage for each iteration
3. Select best configuration within error tolerance
4. Cache results for future use
5. Refresh cache when files change
```

## Limitations

### 1. Technical Limitations
- **Tree-sitter Dependency**: Limited to languages supported by tree-sitter
- **Graph Complexity**: Large repositories may cause recursion errors
- **Token Estimation**: Approximate token counting may be inaccurate
- **Cache Invalidation**: Complex cache invalidation logic may miss updates

### 2. Context Window Limitations
- **Fixed Token Budget**: Default 1k tokens may be insufficient for large repos
- **Manual Scaling**: Users must manually adjust `--map-tokens` for optimal performance
- **Context Overflow**: May still exceed context window in very large codebases

### 3. Algorithm Limitations
- **PageRank Assumptions**: Assumes that frequently referenced code is more important
- **Symbol-based Ranking**: May miss semantic relationships not captured by symbol references
- **Static Analysis**: Cannot capture runtime dependencies or dynamic imports

### 4. User Experience Limitations
- **Manual File Management**: Users must manually add/remove files for optimal results
- **Learning Curve**: Complex configuration options may confuse new users
- **Performance**: Initial repo scan can be slow for large repositories

### 5. LLM Interaction Limitations
- **Prompt Compliance**: Relies on LLM to follow system prompts for file mentions
- **Context Confusion**: LLM may get confused by large context windows
- **Format Adherence**: LLM may not always follow specified edit formats

## Strengths

### 1. Sophisticated Ranking
- **Graph-based Analysis**: Uses proven PageRank algorithm for relevance scoring
- **Multi-factor Ranking**: Considers multiple factors beyond simple frequency
- **Dynamic Adaptation**: Adjusts ranking based on chat state and user input

### 2. Efficient Context Management
- **Token Optimization**: Carefully manages token usage across different context types
- **Caching Strategy**: Implements comprehensive caching to improve performance
- **Incremental Updates**: Only recomputes what's necessary when files change

### 3. User Control
- **Manual Override**: Users can always manually control which files are included
- **Flexible Configuration**: Multiple configuration options for different use cases
- **Clear Feedback**: Provides clear information about what context is being used

### 4. Robust Architecture
- **Multiple Coders**: Different coder types for different tasks (edit, ask, help)
- **Error Handling**: Graceful handling of various error conditions
- **Extensibility**: Modular design allows for easy extension and modification

## Implementation Locations

### Core Context Selection Files
- **Repository Map System**: `aider/repomap.py` - Main implementation of graph-based context selection
- **Context Coder**: `aider/coders/context_coder.py` - Specialized coder for context identification
- **Base Coder**: `aider/coders/base_coder.py` - Core context management and file handling
- **Commands**: `aider/commands.py` - Token management and context commands (`/tokens`, `/clear`)

### Context Management Files
- **History Management**: `aider/history.py` - Chat summarization and history management
- **File Management**: `aider/file_manager.py` - File operations and read-only file handling
- **Token Counting**: `aider/models/` - Token estimation and counting logic

### Key Methods and Functions
- **Graph Ranking**: `aider/repomap.py:get_ranked_tags()` - PageRank algorithm implementation
- **Repository Map**: `aider/repomap.py:get_repo_map()` - Main context selection method
- **Token Management**: `aider/commands.py:cmd_tokens()` - Context window usage reporting
- **File Mentions**: `aider/coders/base_coder.py:get_file_mentions()` - File mention detection
- **Context History**: `aider/coders/base_coder.py:get_context_from_history()` - History extraction
