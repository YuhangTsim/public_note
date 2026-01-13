# OpenCode vs Oh-My-OpenCode: Architecture Comparison

This document provides a comprehensive comparison between the base OpenCode architecture and the oh-my-opencode plugin enhancement layer.

## Executive Summary

| Aspect            | OpenCode (Base)                  | Oh-My-OpenCode (Plugin)               |
| ----------------- | -------------------------------- | ------------------------------------- |
| **Philosophy**    | Minimal, extensible foundation   | "Batteries included" agent harness    |
| **Target User**   | Developers who want full control | Users who want immediate productivity |
| **Agent Model**   | 2 primary + 2 subagents          | 7+ specialized agents with roles      |
| **Tools**         | Core file/code operations        | LSP, AST-grep, background tasks, MCPs |
| **Configuration** | Manual setup required            | Works out of the box                  |

---

## Architecture Overview

### Visual Comparison

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              USER PROMPT                                     │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  ┌─────────────────────────────┐    ┌─────────────────────────────────────┐ │
│  │      OPENCODE (BASE)        │    │       OH-MY-OPENCODE (PLUGIN)       │ │
│  │                             │    │                                     │ │
│  │  ┌───────────────────────┐  │    │  ┌─────────────────────────────────┐│ │
│  │  │      AGENTS           │  │    │  │    ENHANCED AGENTS (Sisyphus)   ││ │
│  │  │  ┌─────┐  ┌─────┐     │  │    │  │  ┌───────────────────────────┐  ││ │
│  │  │  │build│  │plan │     │  │    │  │  │ Sisyphus (Orchestrator)   │  ││ │
│  │  │  └─────┘  └─────┘     │  │    │  │  │ Claude Opus 4.5 High      │  ││ │
│  │  │  ┌───────┐ ┌───────┐  │  │    │  │  └───────────────────────────┘  ││ │
│  │  │  │general│ │explore│  │  │    │  │        │                        ││ │
│  │  │  └───────┘ └───────┘  │  │    │  │        ▼                        ││ │
│  │  └───────────────────────┘  │    │  │  ┌─────────────────────────┐    ││ │
│  │                             │    │  │  │ SPECIALIZED SUBAGENTS   │    ││ │
│  │  ┌───────────────────────┐  │    │  │  │                         │    ││ │
│  │  │       TOOLS           │  │    │  │  │ ┌─────────┐ ┌─────────┐ │    ││ │
│  │  │  read, write, edit    │  │    │  │  │ │ Oracle  │ │Librarian│ │    ││ │
│  │  │  grep, glob, bash     │  │    │  │  │ │GPT-5.2  │ │Sonnet4.5│ │    ││ │
│  │  │  task, todo, webfetch │  │    │  │  │ └─────────┘ └─────────┘ │    ││ │
│  │  │  lsp (analysis only)  │  │    │  │  │ ┌─────────┐ ┌─────────┐ │    ││ │
│  │  └───────────────────────┘  │    │  │  │ │Explore  │ │Frontend │ │    ││ │
│  │                             │    │  │  │ │GrokCode │ │Gemini3  │ │    ││ │
│  │  ┌───────────────────────┐  │    │  │  │ └─────────┘ └─────────┘ │    ││ │
│  │  │    MCP SERVERS        │  │    │  │  │ ┌─────────┐ ┌─────────┐ │    ││ │
│  │  │  User-configured      │  │    │  │  │ │Doc-     │ │Multi-   │ │    ││ │
│  │  │  Local/Remote         │  │    │  │  │ │Writer   │ │modal    │ │    ││ │
│  │  └───────────────────────┘  │    │  │  │ └─────────┘ └─────────┘ │    ││ │
│  │                             │    │  │  └─────────────────────────┘    ││ │
│  │  ┌───────────────────────┐  │    │  └─────────────────────────────────┘│ │
│  │  │     PLUGINS           │  │    │                                     │ │
│  │  │  Extensible hooks     │  │    │  ┌─────────────────────────────────┐│ │
│  │  │  Auth plugins         │  │    │  │      ENHANCED TOOLS             ││ │
│  │  │  Custom tools         │  │    │  │  ┌─────────────────────────┐    ││ │
│  │  └───────────────────────┘  │    │  │  │ LSP (Full IDE Support)  │    ││ │
│  │                             │    │  │  │ • hover, goto_definition│    ││ │
│  │  ┌───────────────────────┐  │    │  │  │ • find_references       │    ││ │
│  │  │     SKILLS            │  │    │  │  │ • rename (workspace)    │    ││ │
│  │  │  .opencode/skill/     │  │    │  │  │ • code_actions          │    ││ │
│  │  │  .claude/skills/      │  │    │  │  └─────────────────────────┘    ││ │
│  │  └───────────────────────┘  │    │  │  ┌─────────────────────────┐    ││ │
│  │                             │    │  │  │ AST-Grep                │    ││ │
│  │                             │    │  │  │ • search (25 languages) │    ││ │
│  │                             │    │  │  │ • replace (dry-run)     │    ││ │
│  │                             │    │  │  └─────────────────────────┘    ││ │
│  │                             │    │  │  ┌─────────────────────────┐    ││ │
│  │                             │    │  │  │ Background Tasks        │    ││ │
│  │                             │    │  │  │ • Parallel agents       │    ││ │
│  │                             │    │  │  │ • Async execution       │    ││ │
│  │                             │    │  │  └─────────────────────────┘    ││ │
│  │                             │    │  │  ┌─────────────────────────┐    ││ │
│  │                             │    │  │  │ Session Management      │    ││ │
│  │                             │    │  │  │ • list, read, search    │    ││ │
│  │                             │    │  │  │ • info, history         │    ││ │
│  │                             │    │  │  └─────────────────────────┘    ││ │
│  │                             │    │  └─────────────────────────────────┘│ │
│  │                             │    │                                     │ │
│  │                             │    │  ┌─────────────────────────────────┐│ │
│  │                             │    │  │      CURATED MCPs              ││ │
│  │                             │    │  │  • Exa (Web Search)            ││ │
│  │                             │    │  │  • Context7 (Official Docs)    ││ │
│  │                             │    │  │  • Grep.app (GitHub Search)    ││ │
│  │                             │    │  │  • Playwright (Browser)        ││ │
│  │                             │    │  └─────────────────────────────────┘│ │
│  │                             │    │                                     │ │
│  │                             │    │  ┌─────────────────────────────────┐│ │
│  │                             │    │  │        HOOKS                   ││ │
│  │                             │    │  │  • Todo Continuation Enforcer  ││ │
│  │                             │    │  │  • Comment Checker             ││ │
│  │                             │    │  │  • Context Window Monitor      ││ │
│  │                             │    │  │  • Auto Compact                ││ │
│  │                             │    │  │  • Session Recovery            ││ │
│  │                             │    │  │  • Think Mode Detector         ││ │
│  │                             │    │  └─────────────────────────────────┘│ │
│  │                             │    │                                     │ │
│  │                             │    │  ┌─────────────────────────────────┐│ │
│  │                             │    │  │    CLAUDE CODE COMPAT          ││ │
│  │                             │    │  │  • Hook system                 ││ │
│  │                             │    │  │  • Config loaders              ││ │
│  │                             │    │  │  • Skill loader                ││ │
│  │                             │    │  │  • MCP loader                  ││ │
│  │                             │    │  └─────────────────────────────────┘│ │
│  └─────────────────────────────┘    └─────────────────────────────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Detailed Comparison

### 1. Agent Architecture

#### OpenCode Base Agents

```
┌─────────────────────────────────────────────────────────────┐
│                    OPENCODE AGENTS                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  PRIMARY AGENTS (User-facing)                               │
│  ┌─────────────────────┐  ┌─────────────────────┐          │
│  │       build         │  │        plan         │          │
│  │ ─────────────────── │  │ ─────────────────── │          │
│  │ Full access agent   │  │ Read-only agent     │          │
│  │ Development work    │  │ Code exploration    │          │
│  │ All tools enabled   │  │ Denies file edits   │          │
│  │ Default agent       │  │ Asks before bash    │          │
│  └─────────────────────┘  └─────────────────────┘          │
│                                                             │
│  SUBAGENTS (Internal)                                       │
│  ┌─────────────────────┐  ┌─────────────────────┐          │
│  │      general        │  │      explore        │          │
│  │ ─────────────────── │  │ ─────────────────── │          │
│  │ Complex searches    │  │ Fast exploration    │          │
│  │ Multi-step tasks    │  │ Pattern matching    │          │
│  │ Parallel work       │  │ Grep, glob, read    │          │
│  └─────────────────────┘  └─────────────────────┘          │
│                                                             │
│  SYSTEM AGENTS (Hidden)                                     │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐                │
│  │compaction │ │   title   │ │  summary  │                │
│  └───────────┘ └───────────┘ └───────────┘                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### Oh-My-OpenCode Agents ("Sisyphus Team")

```
┌───────────────────────────────────────────────────────────────────────────┐
│                      OH-MY-OPENCODE AGENTS                                 │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                    SISYPHUS (ORCHESTRATOR)                          │  │
│  │                    Claude Opus 4.5 High                             │  │
│  │  ─────────────────────────────────────────────────────────────────  │  │
│  │  • Plans and delegates complex tasks                                │  │
│  │  • Uses extended thinking (32k budget)                              │  │
│  │  • Aggressive parallel execution                                    │  │
│  │  • Todo-driven workflow enforcement                                 │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                              │                                            │
│              ┌───────────────┼───────────────┐                           │
│              ▼               ▼               ▼                           │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐            │
│  │     ORACLE      │ │   LIBRARIAN     │ │    EXPLORE      │            │
│  │   GPT-5.2       │ │  Sonnet 4.5     │ │   Grok Code     │            │
│  │ ─────────────── │ │ ─────────────── │ │ ─────────────── │            │
│  │ Architecture    │ │ Documentation   │ │ Codebase search │            │
│  │ Code review     │ │ Multi-repo      │ │ Pattern match   │            │
│  │ Strategy        │ │ GitHub examples │ │ Fast grep       │            │
│  │ Debugging       │ │ Context7 lookup │ │ AST queries     │            │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘            │
│                                                                           │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐            │
│  │FRONTEND-UI-UX   │ │ DOCUMENT-WRITER │ │MULTIMODAL-LOOKER│            │
│  │  Gemini 3 Pro   │ │  Gemini 3 Flash │ │  Gemini 3 Flash │            │
│  │ ─────────────── │ │ ─────────────── │ │ ─────────────── │            │
│  │ UI/UX design    │ │ Technical docs  │ │ PDF analysis    │            │
│  │ Visual code     │ │ README files    │ │ Image analysis  │            │
│  │ CSS/Animation   │ │ API docs        │ │ Diagram reading │            │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘            │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
```

### 2. Tool Comparison

#### OpenCode Base Tools

| Tool        | Purpose          | Capabilities                 |
| ----------- | ---------------- | ---------------------------- |
| `read`      | File reading     | Read files with line limits  |
| `write`     | File writing     | Create/overwrite files       |
| `edit`      | File editing     | String replacement           |
| `grep`      | Content search   | Regex pattern search         |
| `glob`      | File finding     | Pattern-based file discovery |
| `bash`      | Shell commands   | Execute terminal commands    |
| `task`      | Agent delegation | Spawn subagents              |
| `todo`      | Task tracking    | Todo list management         |
| `webfetch`  | Web content      | Fetch URLs                   |
| `websearch` | Web search       | Search via Exa               |
| `lsp`       | Code analysis    | Diagnostics only             |
| `skill`     | Load skills      | Skill activation             |

#### Oh-My-OpenCode Additional Tools

| Tool                      | Purpose         | Capabilities                       |
| ------------------------- | --------------- | ---------------------------------- |
| **LSP Full Suite**        |                 |                                    |
| `lsp_hover`               | Type info       | Docs and signatures at position    |
| `lsp_goto_definition`     | Navigation      | Jump to symbol definition          |
| `lsp_find_references`     | Usage search    | All usages across workspace        |
| `lsp_document_symbols`    | File outline    | Symbol hierarchy                   |
| `lsp_workspace_symbols`   | Global search   | Search symbols by name             |
| `lsp_prepare_rename`      | Rename check    | Validate before rename             |
| `lsp_rename`              | Refactoring     | **Rename across entire workspace** |
| `lsp_code_actions`        | Quick fixes     | Available refactorings             |
| `lsp_code_action_resolve` | Apply action    | Execute code action                |
| **AST-Grep**              |                 |                                    |
| `ast_grep_search`         | Pattern search  | AST-aware search (25 languages)    |
| `ast_grep_replace`        | Pattern replace | AST-aware code replacement         |
| **Background Tasks**      |                 |                                    |
| `background_task`         | Async agents    | Run agents in background           |
| `background_output`       | Get results     | Retrieve background task output    |
| `background_cancel`       | Stop tasks      | Cancel running background tasks    |
| `call_omo_agent`          | Agent spawning  | Spawn explore/librarian agents     |
| **Session Tools**         |                 |                                    |
| `session_list`            | History         | List all sessions                  |
| `session_read`            | Read history    | Read session messages              |
| `session_search`          | Search history  | Full-text session search           |
| `session_info`            | Metadata        | Session statistics                 |
| **Other**                 |                 |                                    |
| `look_at`                 | Multimodal      | Extract info from files/images     |
| `skill_mcp`               | MCP invoke      | Invoke skill-embedded MCPs         |
| `interactive_bash`        | Tmux            | Interactive terminal via tmux      |

### 3. Plugin Architecture Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        PLUGIN LOADING FLOW                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  OPENCODE STARTUP                                                       │
│         │                                                               │
│         ▼                                                               │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    CONFIG LOADING                                │   │
│  │  1. Remote/well-known configs (lowest precedence)               │   │
│  │  2. Global user config (~/.config/opencode/)                    │   │
│  │  3. Custom config path (OPENCODE_CONFIG)                        │   │
│  │  4. Project config (opencode.json/jsonc) - highest precedence   │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│         │                                                               │
│         ▼                                                               │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    PLUGIN INITIALIZATION                         │   │
│  │                                                                  │   │
│  │  opencode.json:                                                  │   │
│  │  {                                                               │   │
│  │    "plugin": ["oh-my-opencode@latest"]                          │   │
│  │  }                                                               │   │
│  │                                                                  │   │
│  │  Plugin receives:                                                │   │
│  │  • client (SDK client)                                          │   │
│  │  • project, worktree, directory paths                           │   │
│  │  • serverUrl                                                    │   │
│  │  • Bun shell access ($)                                         │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│         │                                                               │
│         ▼                                                               │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │              OH-MY-OPENCODE INITIALIZATION                       │   │
│  │                                                                  │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │   │
│  │  │  Load Agents    │  │  Register Tools │  │  Setup Hooks    │  │   │
│  │  │  • Sisyphus     │  │  • LSP suite    │  │  • PreToolUse   │  │   │
│  │  │  • Oracle       │  │  • AST-grep     │  │  • PostToolUse  │  │   │
│  │  │  • Librarian    │  │  • Background   │  │  • Stop         │  │   │
│  │  │  • Frontend     │  │  • Session      │  │  • UserPrompt   │  │   │
│  │  │  • ...          │  │  • ...          │  │  • ...          │  │   │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘  │   │
│  │                                                                  │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │   │
│  │  │  Load MCPs      │  │  Claude Compat  │  │  Load Skills    │  │   │
│  │  │  • Context7     │  │  • .claude/     │  │  • Playwright   │  │   │
│  │  │  • Grep.app     │  │  • settings     │  │  • Custom       │  │   │
│  │  │  • Exa          │  │  • hooks        │  │                 │  │   │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 4. MCP (Model Context Protocol) Comparison

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         MCP ARCHITECTURE                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  OPENCODE (BASE)                                                        │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                                                                  │   │
│  │  User-Configured MCPs (opencode.json):                          │   │
│  │  {                                                               │   │
│  │    "mcp": {                                                      │   │
│  │      "my-server": {                                              │   │
│  │        "type": "local",                                         │   │
│  │        "command": ["npx", "-y", "@my/mcp-server"]               │   │
│  │      },                                                          │   │
│  │      "remote-server": {                                          │   │
│  │        "type": "remote",                                        │   │
│  │        "url": "https://example.com/mcp"                         │   │
│  │      }                                                           │   │
│  │    }                                                             │   │
│  │  }                                                               │   │
│  │                                                                  │   │
│  │  Features:                                                       │   │
│  │  • Local process MCPs                                           │   │
│  │  • Remote HTTP/SSE MCPs                                         │   │
│  │  • OAuth authentication support                                 │   │
│  │  • Tool, prompt, and resource discovery                         │   │
│  │                                                                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  OH-MY-OPENCODE (ADDITIONS)                                            │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                                                                  │   │
│  │  CURATED MCPs (Pre-configured):                                 │   │
│  │  ┌───────────────────┐  ┌───────────────────┐                   │   │
│  │  │       EXA         │  │     CONTEXT7      │                   │   │
│  │  │  Web Search API   │  │  Official Docs    │                   │   │
│  │  │  Real-time search │  │  Library lookup   │                   │   │
│  │  │  Content scraping │  │  Code examples    │                   │   │
│  │  └───────────────────┘  └───────────────────┘                   │   │
│  │  ┌───────────────────┐  ┌───────────────────┐                   │   │
│  │  │     GREP.APP      │  │    PLAYWRIGHT     │                   │   │
│  │  │  GitHub Search    │  │  Browser Control  │                   │   │
│  │  │  Code patterns    │  │  Screenshots      │                   │   │
│  │  │  OSS examples     │  │  Web scraping     │                   │   │
│  │  └───────────────────┘  └───────────────────┘                   │   │
│  │                                                                  │   │
│  │  CLAUDE CODE COMPAT (Loaders):                                  │   │
│  │  • ~/.claude/.mcp.json                                          │   │
│  │  • ./.mcp.json                                                  │   │
│  │  • ./.claude/.mcp.json                                          │   │
│  │                                                                  │   │
│  │  SKILL-EMBEDDED MCPs:                                           │   │
│  │  Skills can declare their own MCP servers in frontmatter        │   │
│  │                                                                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5. Hook System Comparison

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          HOOK ARCHITECTURE                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  OPENCODE (BASE)                                                        │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                                                                  │   │
│  │  Plugin Hooks (via @opencode-ai/plugin):                        │   │
│  │                                                                  │   │
│  │  interface Hooks {                                               │   │
│  │    auth?: (...)  => Promise<...>                                │   │
│  │    event?: (...) => void                                        │   │
│  │    tool?: (...)  => Promise<...>                                │   │
│  │    config?: (...) => Promise<void>                              │   │
│  │  }                                                               │   │
│  │                                                                  │   │
│  │  Plugins register hooks, OpenCode triggers them                 │   │
│  │                                                                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  OH-MY-OPENCODE (EXTENSIVE HOOKS)                                      │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                                                                  │   │
│  │  AGENT BEHAVIOR HOOKS                                           │   │
│  │  ┌───────────────────────────────────────────────────────────┐  │   │
│  │  │ Todo Continuation Enforcer                                │  │   │
│  │  │ • Forces agent to complete all TODOs                      │  │   │
│  │  │ • Injects prompts if agent stops prematurely              │  │   │
│  │  │ • "Keep rolling that boulder"                             │  │   │
│  │  └───────────────────────────────────────────────────────────┘  │   │
│  │  ┌───────────────────────────────────────────────────────────┐  │   │
│  │  │ Comment Checker                                           │  │   │
│  │  │ • Detects excessive comments in code                      │  │   │
│  │  │ • Demands justification or removal                        │  │   │
│  │  │ • Ignores valid patterns (BDD, docstrings)                │  │   │
│  │  └───────────────────────────────────────────────────────────┘  │   │
│  │  ┌───────────────────────────────────────────────────────────┐  │   │
│  │  │ Context Window Monitor                                    │  │   │
│  │  │ • Tracks token usage                                      │  │   │
│  │  │ • At 70%+: reminds agent there's headroom                 │  │   │
│  │  │ • Prevents rushed work                                    │  │   │
│  │  └───────────────────────────────────────────────────────────┘  │   │
│  │  ┌───────────────────────────────────────────────────────────┐  │   │
│  │  │ Think Mode Detector                                       │  │   │
│  │  │ • Detects "ultrathink", "think deeply"                    │  │   │
│  │  │ • Auto-switches to extended thinking mode                 │  │   │
│  │  └───────────────────────────────────────────────────────────┘  │   │
│  │                                                                  │   │
│  │  SESSION HOOKS                                                  │   │
│  │  ┌───────────────────────────────────────────────────────────┐  │   │
│  │  │ Session Recovery                                          │  │   │
│  │  │ • Recovers from missing tool results                      │  │   │
│  │  │ • Handles thinking block issues                           │  │   │
│  │  │ • Fixes empty messages                                    │  │   │
│  │  └───────────────────────────────────────────────────────────┘  │   │
│  │  ┌───────────────────────────────────────────────────────────┐  │   │
│  │  │ Auto Compact                                              │  │   │
│  │  │ • Summarizes when hitting token limits                    │  │   │
│  │  │ • No manual intervention needed                           │  │   │
│  │  └───────────────────────────────────────────────────────────┘  │   │
│  │                                                                  │   │
│  │  CLAUDE CODE HOOKS (Compatibility)                              │   │
│  │  ┌───────────────────────────────────────────────────────────┐  │   │
│  │  │ PreToolUse  - Before tool execution                       │  │   │
│  │  │ PostToolUse - After tool execution                        │  │   │
│  │  │ UserPromptSubmit - On prompt submission                   │  │   │
│  │  │ Stop - When session goes idle                             │  │   │
│  │  └───────────────────────────────────────────────────────────┘  │   │
│  │                                                                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 6. Workflow Comparison

#### OpenCode Base Workflow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      OPENCODE BASE WORKFLOW                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  User Prompt ──► Build Agent ──► Direct Tool Usage ──► Response        │
│                      │                                                  │
│                      ├──► read/write/edit                              │
│                      ├──► grep/glob                                    │
│                      ├──► bash                                         │
│                      └──► task (spawn general/explore)                 │
│                                                                         │
│  Characteristics:                                                       │
│  • Single agent handles most work                                      │
│  • Sequential tool execution                                           │
│  • Manual context management                                           │
│  • User manages agent switching (Tab key)                              │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### Oh-My-OpenCode Workflow (Sisyphus)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                  OH-MY-OPENCODE WORKFLOW (SISYPHUS)                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│                         User Prompt                                     │
│                              │                                          │
│                              ▼                                          │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                    KEYWORD DETECTION                              │ │
│  │  "ultrawork" / "ulw" ──► Maximum parallel execution               │ │
│  │  "ultrathink" ──► Extended thinking mode                          │ │
│  │  "search" / "find" ──► Maximized search effort                    │ │
│  │  "analyze" ──► Multi-phase expert consultation                    │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                              │                                          │
│                              ▼                                          │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                 SISYPHUS ORCHESTRATOR                             │ │
│  │                                                                   │ │
│  │  1. Analyze task complexity                                       │ │
│  │  2. Create detailed TODO list                                     │ │
│  │  3. Delegate to specialized agents                                │ │
│  │  4. Monitor progress                                              │ │
│  │  5. Aggregate results                                             │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                              │                                          │
│         ┌────────────────────┼────────────────────┐                    │
│         ▼                    ▼                    ▼                    │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐              │
│  │ Background  │     │ Background  │     │ Background  │              │
│  │   Task 1    │     │   Task 2    │     │   Task 3    │              │
│  │  (explore)  │     │ (librarian) │     │  (oracle)   │              │
│  └─────────────┘     └─────────────┘     └─────────────┘              │
│         │                    │                    │                    │
│         └────────────────────┴────────────────────┘                    │
│                              │                                          │
│                              ▼                                          │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                  PARALLEL RESULTS AGGREGATION                     │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                              │                                          │
│                              ▼                                          │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                    HOOK ENFORCEMENT                               │ │
│  │  • Todo Continuation: "Are all TODOs complete?"                   │ │
│  │  • Comment Checker: "Are there excessive comments?"               │ │
│  │  • Context Monitor: "Is context window healthy?"                  │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                              │                                          │
│                              ▼                                          │
│                         Response                                        │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Key Differentiators Summary

### What Oh-My-OpenCode Adds

| Category   | Feature                   | Benefit                            |
| ---------- | ------------------------- | ---------------------------------- |
| **Agents** | 7+ specialized agents     | Right model for each task          |
| **Agents** | Background task execution | Parallel work, team-like behavior  |
| **Tools**  | Full LSP refactoring      | Safe, surgical code changes        |
| **Tools**  | AST-grep                  | Language-aware code search/replace |
| **Tools**  | Session management        | History search and continuity      |
| **MCPs**   | Pre-configured servers    | Immediate web/docs/code search     |
| **Hooks**  | Todo continuation         | Forces task completion             |
| **Hooks**  | Comment checker           | Cleaner code output                |
| **Hooks**  | Session recovery          | Resilient sessions                 |
| **Compat** | Claude Code layer         | Existing configs work              |
| **UX**     | Keyword activation        | "ultrawork" triggers everything    |

### When to Use Each

| Use Case                          | Recommendation |
| --------------------------------- | -------------- |
| Full control over configuration   | OpenCode base  |
| Learning/understanding the system | OpenCode base  |
| Maximum productivity immediately  | Oh-My-OpenCode |
| Complex multi-agent workflows     | Oh-My-OpenCode |
| Frontend development              | Oh-My-OpenCode |
| Large codebase refactoring        | Oh-My-OpenCode |
| Coming from Claude Code           | Oh-My-OpenCode |

---

## Configuration Locations

### OpenCode Base

- `~/.config/opencode/opencode.json` - Global config
- `./opencode.json` or `./opencode.jsonc` - Project config
- `./.opencode/` - Project-specific directory

### Oh-My-OpenCode Additions

- `~/.config/opencode/oh-my-opencode.json` - Global plugin config
- `./.opencode/oh-my-opencode.json` - Project plugin config
- `~/.claude/` - Claude Code compatibility directory
- `./.claude/` - Project Claude Code compatibility

---

_Document generated from analysis of OpenCode v1.0.x and oh-my-opencode v2.x/v3.x_
