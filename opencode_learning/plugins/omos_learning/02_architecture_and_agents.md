# Architecture and Agents

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         oh-my-opencode-slim Architecture                     │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  OPENCODE CORE                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │  Plugin System (src/index.ts)                                         │ │
│  │  • Wires agents, tools, hooks                                         │ │
│  │  • Manages lifecycle events                                           │ │
│  │  • Handles session coordination                                       │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  AGENT LAYER (The Pantheon)                                                 │
│                                                                             │
│   ┌──────────────┐                                                          │
│   │ Orchestrator │◄────────────────────────────────────────────────────┐   │
│   │   (Master)   │                                                    │   │
│   └──────┬───────┘                                                    │   │
│          │ Delegates                                                   │   │
│          ▼                                                            │   │
│   ┌──────────┬──────────┬──────────┬──────────┬──────────┐           │   │
│   │          │          │          │          │          │           │   │
│   ▼          ▼          ▼          ▼          ▼          ▼           │   │
│ ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐          │   │
│ │Explorer│ │Librarian│ │ Oracle │ │Designer│ │ Fixer  │ │ Background│          │   │
│ │ (Fast) │ │(Research│ │(High-IQ│ │ (UI/UX)│ │(Execute│ │  Tasks   │          │   │
│ └──────┘  └──────┘  └──────┘  └──────┘  └──────┘  └──────┘          │   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  SUPPORTING SYSTEMS                                                         │
│                                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐             │
│  │ Background      │  │ Tmux Manager    │  │ Dynamic Planner │             │
│  │ Manager         │  │ (src/utils/     │  │ (src/cli/       │             │
│  │ (src/background/│  │  tmux.ts)       │  │  scoring-v2/)   │             │
│  │  background-    │  │                 │  │                 │             │
│  │  manager.ts)    │  │ • Pane spawn    │  │ • Model ranking │             │
│  │                 │  │ • Lifecycle     │  │ • Cost/quality  │             │
│  │ • Task spawn    │  │ • Layout mgmt   │  │ • Auto-select   │             │
│  │ • Result fetch  │  │                 │  │                 │             │
│  │ • Cleanup       │  │                 │  │                 │             │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘             │
│                                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐             │
│  │ Hook System     │  │ Config System   │  │ Tool Registry   │             │
│  │ (src/hooks/)    │  │ (src/config/)   │  │ (src/tools/)    │             │
│  │                 │  │                 │  │                 │             │
│  │ • Phase reminder│  │ • Schema (Zod)  │  │ • LSP tools     │             │
│  │ • Post-read     │  │ • Loader        │  │ • Grep tools    │             │
│  │ • Auto-update   │  │ • Validation    │  │ • AST-grep      │             │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  MCP INTEGRATIONS                                                           │
│                                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                         │
│  │   Exa AI    │  │  Context7   │  │  Grep.app   │                         │
│  │ (websearch) │  │   (docs)    │  │  (GitHub)   │                         │
│  │             │  │             │  │             │                         │
│  │ Real-time   │  │ Official    │  │ 500K repos  │                         │
│  │ web search  │  │ library docs│  │ search      │                         │
│  └─────────────┘  └─────────────┘  └─────────────┘                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## The 6 Pantheon Agents

### 01. Orchestrator: The Embodiment Of Order

**Role**: Master delegator and strategic coordinator

```
┌─────────────────────────────────────────────────────────────┐
│                    ORCHESTRATOR WORKFLOW                     │
└─────────────────────────────────────────────────────────────┘

User Request
     │
     ▼
┌─────────────────┐
│ 1. UNDERSTAND   │─── Analyze request
│    INTENT       │    Identify domains
└────────┬────────┘    Plan approach
         │
         ▼
┌─────────────────┐
│ 2. DELEGATE     │─── Choose specialist
│                 │    Pass minimal context
└────────┬────────┘    Set clear scope
         │
         ▼
┌─────────────────┐
│ 3. PARALLELIZE  │─── Spawn background tasks
│                 │    Monitor progress
└────────┬────────┘    Coordinate results
         │
         ▼
┌─────────────────┐
│ 4. SYNTHESIZE   │─── Integrate findings
│                 │    Produce final output
└─────────────────┘
```

**System Prompt**: `src/agents/orchestrator.ts`

**Key Responsibilities**:
- Parse user intent and identify task domains
- Delegate to appropriate specialist agents
- Coordinate parallel background tasks
- Synthesize results into coherent responses
- Enforce the "Understand → Delegate → Parallelize" workflow

**Recommended Models**: `kimi-for-coding/k2p5`, `openai/gpt-5.2-codex`

---

### 02. Explorer: The Eternal Wanderer

**Role**: Codebase reconnaissance and fast discovery

```
┌─────────────────────────────────────────────────────────────┐
│                    EXPLORER CAPABILITIES                     │
└─────────────────────────────────────────────────────────────┘

┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│    GLOB      │    │    GREP      │    │  AST-GREP    │
│              │    │              │    │              │
│ Find files   │    │ Text search  │    │ Structural   │
│ by pattern   │    │ with regex   │    │ code search  │
└──────────────┘    └──────────────┘    └──────────────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           ▼
              ┌──────────────────────┐
              │   PARALLEL SEARCH    │
              │   (up to 10 tasks)   │
              └──────────┬───────────┘
                         ▼
              ┌──────────────────────┐
              │  CONTEXT SUMMARY     │
              │  • File structure    │
              │  • Key patterns      │
              │  • Relevant code     │
              └──────────────────────┘
```

**System Prompt**: `src/agents/explorer.ts`

**Key Responsibilities**:
- Fast codebase exploration
- Parallel glob/grep/AST searches
- Report findings without modification
- Identify relevant files and patterns

**Recommended Models**: `cerebras/zai-glm-4.7`, `google/gemini-3-flash`, `openai/gpt-5.1-codex-mini`

---

### 03. Oracle: The Guardian of Paths

**Role**: Strategic advisor and debugger of last resort

```
┌─────────────────────────────────────────────────────────────┐
│                     ORACLE USAGE PATTERNS                    │
└─────────────────────────────────────────────────────────────┘

When to Call Oracle:
┌─────────────────────────────────────────────────────────────┐
│  ✓ High-stakes architectural decisions                       │
│  ✓ Complex debugging after 2+ failed attempts                │
│  ✓ Costly trade-off analysis                                 │
│  ✓ Security/scalability decisions                            │
│  ✓ Genuinely uncertain and cost of wrong choice is high      │
└─────────────────────────────────────────────────────────────┘

When NOT to Call Oracle:
┌─────────────────────────────────────────────────────────────┐
│  ✗ Routine first bug fix attempt                             │
│  ✗ Straightforward trade-offs                                │
│  ✗ Quick research/testing can answer                         │
│  ✗ Tactical "how" vs strategic "should"                      │
└─────────────────────────────────────────────────────────────┘

Oracle Decision Flow:

  Complex problem?
       │
       ▼
  ┌────────┐
  │ High   │──NO──▶ Handle yourself
  │ stakes?│
  └────┬───┘
       │ YES
       ▼
  ┌────────┐
  │ Unclear│──NO──▶ Use @librarian for research
  │ path?  │
  └────┬───┘
       │ YES
       ▼
  ┌────────┐
  │ Costly │──NO──▶ Try simple fix first
  │ mistake?│
  └────┬───┘
       │ YES
       ▼
   @oracle
```

**System Prompt**: `src/agents/oracle.ts`

**Key Responsibilities**:
- Deep architectural reasoning
- System-level trade-off analysis
- Complex debugging assistance
- High-stakes decision guidance

**Recommended Models**: `openai/gpt-5.2-codex`, `kimi-for-coding/k2p5`

---

### 04. Librarian: The Weaver of Knowledge

**Role**: External knowledge retrieval and documentation research

```
┌─────────────────────────────────────────────────────────────┐
│                  LIBRARIAN RESEARCH SOURCES                  │
└─────────────────────────────────────────────────────────────┘

┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   EXA AI    │     │  CONTEXT7   │     │  GREP.APP   │
│             │     │             │     │             │
│ Web Search  │     │ Official    │     │ GitHub Code │
│             │     │ Docs        │     │ Search      │
├─────────────┤     ├─────────────┤     ├─────────────┤
│ • Real-time │     │ • Library   │     │ • 500K      │
│   web data  │     │   docs      │     │   repos     │
│ • News      │     │ • API refs  │     │ • Examples  │
│ • Tutorials │     │ • Guides    │     │ • Patterns  │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           ▼
              ┌──────────────────────┐
              │  SYNTHESIZED ANSWER  │
              │  (not just links)    │
              └──────────────────────┘
```

**System Prompt**: `src/agents/librarian.ts`

**Key Responsibilities**:
- Fetch official documentation
- Search GitHub for implementation examples
- Real-time web research
- Synthesize findings into understanding (not just links)

**Recommended Models**: `google/gemini-3-flash`, `openai/gpt-5.1-codex-mini`

---

### 05. Designer: The Guardian of Aesthetics

**Role**: UI/UX implementation and visual excellence

```
┌─────────────────────────────────────────────────────────────┐
│                  DESIGNER RESPONSIBILITIES                   │
└─────────────────────────────────────────────────────────────┘

Visual Direction          Implementation          Polish
┌─────────────┐          ┌─────────────┐        ┌─────────────┐
│ • Design    │          │ • Tailwind  │        │ • Micro-    │
│   systems   │          │   CSS       │        │   interactions│
│ • Color     │          │ • Component │        │ • Animations│
│   theory    │          │   architecture│      │ • Responsive│
│ • Typography│          │ • Accessibility      │   testing   │
└─────────────┘          └─────────────┘        └─────────────┘
         │                      │                      │
         └──────────────────────┼──────────────────────┘
                                ▼
                    ┌──────────────────────┐
                    │  DELIGHTFUL UX       │
                    │  "Beauty is essential"│
                    └──────────────────────┘
```

**System Prompt**: `src/agents/designer.ts`

**Key Responsibilities**:
- Visual direction and design systems
- Responsive layout implementation
- Animation and micro-interactions
- Component architecture
- Accessibility compliance

**Recommended Models**: `google/gemini-3-flash`

---

### 06. Fixer: The Last Builder

**Role**: Fast implementation specialist for well-defined tasks

```
┌─────────────────────────────────────────────────────────────┐
│                    FIXER EXECUTION FLOW                      │
└─────────────────────────────────────────────────────────────┘

Prerequisites (from Orchestrator):
┌─────────────────────────────────────────────────────────────┐
│  ✓ Clear specification                                       │
│  ✓ Defined approach                                          │
│  ✓ Necessary context only                                    │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────┐
│  IMPLEMENT      │─── Write code efficiently
│                 │    Follow patterns
└────────┬────────┘    Maintain consistency
         │
         ▼
┌─────────────────┐
│  VERIFY         │─── Run tests
│                 │    Type check
└────────┬────────┘    Lint check
         │
         ▼
┌─────────────────┐
│  REPORT         │─── Concise summary
│                 │    Key changes
└─────────────────┘    No fluff
```

**System Prompt**: `src/agents/fixer.ts`

**Key Responsibilities**:
- Fast, efficient code implementation
- Work from clear specifications
- Execute without over-engineering
- Report concisely

**Recommended Models**: `cerebras/zai-glm-4.7`, `google/gemini-3-flash`, `openai/gpt-5.1-codex-mini`

## Agent Communication Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       TYPICAL TASK LIFECYCLE                                 │
└─────────────────────────────────────────────────────────────────────────────┘

User: "Add authentication to my API"
     │
     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ ORCHESTRATOR                                                                │
│ • Identifies: auth system, API routes, middleware needed                    │
│ • Plans: Research → Design → Implement                                       │
└─────────────────────────────────────────────────────────────────────────────┘
     │
     ├───────────────────────────────────────────────────────────────────────┐
     │                                                                       │
     ▼                                                                       ▼
┌─────────────────────────────────┐                    ┌─────────────────────────────┐
│ @librarian                      │                    │ @explorer                   │
│ "Research auth best practices   │                    │ "Find existing auth code    │
│  for FastAPI"                   │                    │  patterns in codebase"      │
│                                 │                    │                             │
│ MCP: websearch, context7        │                    │ Tools: glob, grep, ast_grep │
└──────────────┬──────────────────┘                    └─────────────┬───────────────┘
               │                                                    │
               │ (background tasks running in parallel)             │
               │                                                    │
               ▼                                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ ORCHESTRATOR (receives results)                                             │
│ • Synthesizes research findings                                             │
│ • Identifies implementation approach                                        │
└─────────────────────────────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ @designer (if UI needed)                                                    │
│ • Design login/logout forms                                                  │
│ • Create auth flow mockups                                                   │
└─────────────────────────────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ @fixer                                                                      │
│ • Implement auth middleware                                                  │
│ • Add protected routes                                                       │
│ • Write tests                                                                │
└─────────────────────────────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ ORCHESTRATOR (final synthesis)                                              │
│ • Presents completed implementation                                          │
│ • Summarizes key changes                                                     │
└─────────────────────────────────────────────────────────────────────────────┘
```
