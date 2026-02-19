# Tools and MCP Integrations

## Custom Tools

omos provides several custom tools that extend OpenCode's capabilities.

### Tool Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TOOL ARCHITECTURE                                        │
└─────────────────────────────────────────────────────────────────────────────┘

OpenCode Tool System
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  Tool Call                        Tool Implementation                        │
│  ┌───────────────┐                ┌───────────────────────────────────────┐  │
│  │ {             │                │ src/tools/                            │  │
│  │   name:       │───────────────▶│ ├── lsp/          # LSP tools        │  │
│  │   "lsp_goto_ │                │ ├── grep/         # Grep tools       │  │
│  │   definition│                │ └── background.ts # Background tasks │  │
│  │   arguments:  │                │                                       │  │
│  │   {...}       │                │ Each tool exports:                    │  │
│  │ }             │                │ - Schema (Zod)                        │  │
│  └───────────────┘                │ - Handler function                    │  │
│                                   │ - Error handling                      │  │
│                                   └───────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### AST-Grep Tool

Structural code search using the ast-grep engine.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    AST-GREP TOOL                                            │
└─────────────────────────────────────────────────────────────────────────────┘

Pattern Matching Levels:
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  Text Search (grep)              AST Search (ast_grep)                       │
│  ┌─────────────────────┐         ┌─────────────────────┐                     │
│  │ Search: "function"  │         │ Search: function    │                     │
│  │                     │         │   with 3 args       │                     │
│  │ Matches:            │         │   where arg[0]      │                     │
│  │ - "function" in     │         │   is async          │                     │
│  │   comments          │         │                     │                     │
│  │ - "function" in     │         │ Matches only:       │                     │
│  │   strings           │         │ - Semantic          │                     │
│  │ - var function      │         │   structures        │                     │
│  │                     │         │ - Code elements     │                     │
│  │ (False positives)   │         │ - Type-aware        │                     │
│  └─────────────────────┘         └─────────────────────┘                     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Usage Examples:**

```typescript
// Find all async functions with at least 3 parameters
{
  tool: "ast_grep_search",
  arguments: {
    pattern: `
      async function $NAME($$$ARGS) { $$$BODY }
    `,
    where: {
      "len(ARGS) >= 3": true
    },
    lang: "typescript"
  }
}

// Find React components using useEffect
{
  tool: "ast_grep_search", 
  arguments: {
    pattern: `
      function $COMPONENT() { $$$ useEffect($CALLBACK, $DEPS) $$$ }
    `,
    lang: "typescript"
  }
}
```

### LSP Tools

Direct integration with Language Servers for IDE-like capabilities.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    LSP TOOL SUITE                                           │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────┬───────────────────────────────────────────────────────────┐
│ Tool            │ Description                                               │
├─────────────────┼───────────────────────────────────────────────────────────┤
│ lsp_goto_       │ Jump to symbol definition                                 │
│ definition      │ (across entire workspace)                                 │
├─────────────────┼───────────────────────────────────────────────────────────┤
│ lsp_find_       │ Find all references to a symbol                         │
│ references      │                                                           │
├─────────────────┼───────────────────────────────────────────────────────────┤
│ lsp_rename      │ Rename symbol across all files                          │
│                 │ (safe refactoring)                                        │
├─────────────────┼───────────────────────────────────────────────────────────┤
│ lsp_diagnostics │ Get errors/warnings from                                │
│                 │ language server                                           │
└─────────────────┴───────────────────────────────────────────────────────────┘

Architecture:
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  Agent Request                                                               │
│       │                                                                      │
│       ▼                                                                      │
│  ┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐   │
│  │   omos Plugin    │─────▶│  LSP Client      │─────▶│  Language Server │   │
│  │   (src/tools/lsp)│      │  (src/tools/lsp/ │      │  (External)      │   │
│  │                  │      │   client.ts)     │      │                  │   │
│  │ • Validate       │      │                  │      │ • TypeScript     │   │
│  │   request        │      │ • JSON-RPC       │◄─────│ • Python         │   │
│  │ • Route to       │      │   protocol       │      │ • Rust           │   │
│  │   handler        │      │ • Manage         │      │ • Go             │   │
│  └──────────────────┘      │   connections    │      │ • etc.           │   │
│                            └──────────────────┘      └──────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Usage Examples:**

```typescript
// Find where a function is defined
{
  tool: "lsp_goto_definition",
  arguments: {
    filePath: "/project/src/app.ts",
    line: 42,
    character: 15
  }
}

// Find all usages of a variable
{
  tool: "lsp_find_references",
  arguments: {
    filePath: "/project/src/utils.ts",
    line: 10,
    character: 5,
    includeDeclaration: true
  }
}

// Rename a symbol
{
  tool: "lsp_rename",
  arguments: {
    filePath: "/project/src/api.ts",
    line: 20,
    character: 8,
    newName: "fetchUserData"
  }
}
```

### Grep Tool

Optimized ripgrep wrapper for fast text search.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GREP TOOL                                                │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  grep_search                                                                │
│                                                                             │
│  Arguments:                                                                 │
│  • pattern: string (regex)        - Search pattern                          │
│  • path: string                   - Root directory                          │
│  • include: string[]              - File patterns (*.ts, *.tsx)             │
│  • caseSensitive: boolean         - Case matching                           │
│  • fixedStrings: boolean          - Literal string search                   │
│  • wholeWord: boolean             - Match whole words only                  │
│                                                                             │
│  Returns:                                                                   │
│  • Array of { filePath, line, column, match, context }                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

Performance Optimizations:
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  1. Uses ripgrep (Rust-based, extremely fast)                               │
│  2. Respects .gitignore automatically                                       │
│  3. Parallel file searching                                                 │
│  4. Memory-mapped file reading                                              │
│  5. Output truncated at 10MB with continuation                              │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Usage Example:**

```typescript
// Find all TODO comments in TypeScript files
{
  tool: "grep_search",
  arguments: {
    pattern: "TODO|FIXME|XXX",
    path: "/project",
    include: ["*.ts", "*.tsx"],
    caseSensitive: false
  }
}
```

## MCP Integrations

Model Context Protocol integrations for external tool access.

### MCP Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MCP ARCHITECTURE                                         │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  OpenCode                                                                   │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │  MCP Client                                                           │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                   │ │
│  │  │  Exa AI     │  │  Context7   │  │  Grep.app   │                   │ │
│  │  │  MCP        │  │  MCP        │  │  MCP        │                   │ │
│  │  │             │  │             │  │             │                   │ │
│  │  │ • Web       │  │ • Library   │  │ • GitHub    │                   │ │
│  │  │   search    │  │   docs      │  │   search    │                   │ │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘                   │ │
│  │         │                │                │                           │ │
│  │         └────────────────┼────────────────┘                           │ │
│  │                          │                                            │ │
│  │                          ▼                                            │ │
│  │              ┌───────────────────────┐                                │ │
│  │              │  Agent Tool Calls     │                                │ │
│  │              └───────────────────────┘                                │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  External Services                                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                         │
│  │  Exa AI     │  │  Context7   │  │  Grep.app   │                         │
│  │  API        │  │  API        │  │  API        │                         │
│  └─────────────┘  └─────────────┘  └─────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Exa AI (websearch)

Real-time web search for current information.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    EXA AI MCP                                               │
└─────────────────────────────────────────────────────────────────────────────┘

Use Case: @librarian needs current information

┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  User: "What are the latest React 19 features?"                             │
│                                                                              │
│  @librarian:                                                                 │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ MCP: websearch                                                        │  │
│  │ query: "React 19 features 2024 2025"                                  │  │
│  │                                                                       │  │
│  │ Results:                                                              │  │
│  │ • React 19 introduces the Actions API                                │  │
│  │ • New use() hook for promises                                        │  │
│  │ • Automatic memoization                                              │  │
│  │ • [Sources: react.dev, web.dev, etc.]                                │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

Features:
• Real-time search (not training data cutoff)
• Content extraction (not just links)
• Source credibility scoring
• Code snippet detection
• Academic paper search
```

### Context7

Official library documentation lookup.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CONTEXT7 MCP                                             │
└─────────────────────────────────────────────────────────────────────────────┘

Use Case: @librarian needs official API documentation

┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  User: "How does Zod's coerce work?"                                        │
│                                                                              │
│  @librarian:                                                                 │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ MCP: context7                                                         │  │
│  │ library: "zod"                                                        │  │
│  │ query: "coerce method"                                                │  │
│  │                                                                       │  │
│  │ Results:                                                              │  │
│  │ • coerce transforms input before validation                          │  │
│  │ • coerce.string() converts to string                                 │  │
│  │ • coerce.number() converts to number                                 │  │
│  │ • [From official Zod docs]                                           │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

Supported Libraries:
┌─────────────────────────────────────────────────────────────────────────────┐
│  • React        • Vue           • Angular       • Svelte                    │
│  • Express      • Fastify       • NestJS        • Next.js                   │
│  • TypeScript   • Zod           • Prisma        • Drizzle                   │
│  • Tailwind     • shadcn        • And 100+ more...                          │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Grep.app

Search across 500,000+ GitHub repositories.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GREP.APP MCP                                             │
└─────────────────────────────────────────────────────────────────────────────┘

Use Case: @librarian needs real-world implementation examples

┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  User: "Show me how to use tanstack query with Next.js App Router"         │
│                                                                              │
│  @librarian:                                                                 │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ MCP: grep_app                                                         │  │
│  │ query: "useQuery" + "next/navigation" + "app router"                  │  │
│  │ language: "typescript"                                                │  │
│  │                                                                       │  │
│  │ Results:                                                              │  │
│  │ • 45 repositories found                                               │  │
│  │ • Top result: vercel/commerce                                         │  │
│  │ • Code: [actual implementation example]                               │  │
│  │ • Pattern: [common patterns found]                                    │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

Search Capabilities:
• Regex pattern matching
• Language filtering
• Repository filtering (stars, updated)
• File path filtering
• Code snippet extraction
```

## Tool Calling Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TOOL CALLING FLOW                                        │
└─────────────────────────────────────────────────────────────────────────────┘

Agent Decision
     │
     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Need external info?                                                         │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │  YES                                                                  │ │
│  │   │                                                                   │ │
│  │   ▼                                                                   │ │
│  │  Web search? ──YES──▶ @librarian + websearch                         │ │
│  │   │ NO                                                                │ │
│  │   ▼                                                                   │ │
│  │  Official docs? ──YES──▶ @librarian + context7                       │ │
│  │   │ NO                                                                │ │
│  │   ▼                                                                   │ │
│  │  Code examples? ──YES──▶ @librarian + grep_app                       │ │
│  │   │ NO                                                                │ │
│  │   ▼                                                                   │ │
│  │  Codebase search? ──YES──▶ @explorer + grep/ast_grep                 │ │
│  │   │ NO                                                                │ │
│  │   ▼                                                                   │ │
│  │  Symbol navigation? ──YES──▶ lsp_* tools                             │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│   │                                                                         │
│   │ NO                                                                      │
│   ▼                                                                         │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │  Need to implement?                                                   │ │
│  │   │                                                                   │ │
│  │   │ YES                                                               │ │
│  │   ▼                                                                   │ │
│  │  UI/UX involved? ──YES──▶ @designer                                  │ │
│  │   │ NO                                                                │ │
│  │   ▼                                                                   │ │
│  │  Standard coding ──YES──▶ @fixer                                     │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Tool Permissions

Agents have restricted access to tools based on their role.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TOOL PERMISSIONS BY AGENT                                │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────┬────────┬────────┬──────────┬─────────┬────────────┬──────────┐
│ Agent       │ Read   │ Write  │ LSP      │ MCP    │ Background │ Tmux     │
├─────────────┼────────┼────────┼──────────┼─────────┼────────────┼──────────┤
│ Explorer    │   ✓    │   ✗    │    ✓     │   ✗    │     ✗      │   ✗      │
├─────────────┼────────┼────────┼──────────┼─────────┼────────────┼──────────┤
│ Librarian   │   ✓    │   ✗    │    ✗     │   ✓    │     ✗      │   ✗      │
├─────────────┼────────┼────────┼──────────┼─────────┼────────────┼──────────┤
│ Oracle      │   ✓    │   ✗    │    ✓     │   ✓    │     ✓      │   ✗      │
├─────────────┼────────┼────────┼──────────┼─────────┼────────────┼──────────┤
│ Designer    │   ✓    │   ✓    │    ✗     │   ✗    │     ✗      │   ✗      │
├─────────────┼────────┼────────┼──────────┼─────────┼────────────┼──────────┤
│ Fixer       │   ✓    │   ✓    │    ✓     │   ✗    │     ✗      │   ✗      │
├─────────────┼────────┼────────┼──────────┼─────────┼────────────┼──────────┤
│ Orchestrator│   ✓    │   ✓*   │    ✓     │   ✓    │     ✓      │   ✓      │
└─────────────┴────────┴────────┴──────────┴─────────┴────────────┴──────────┘

* Orchestrator writes only for trivial changes (<10 lines)
```
