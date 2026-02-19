# Prompts and Design Patterns

## Agent Prompt Engineering

Each omos agent has a carefully crafted system prompt that defines its role, constraints, and output format.

### Prompt Structure

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    AGENT PROMPT STRUCTURE                                   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. IDENTITY                                                                 │
│    • Who you are                                                            │
│    • Your purpose                                                           │
│    • Your "character"                                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│ 2. CAPABILITIES                                                             │
│    • What tools you have access to                                          │
│    • Your strengths                                                         │
│    • Your limitations                                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│ 3. CONSTRAINTS                                                              │
│    • Delegate when / Don't delegate when                                    │
│    • Output format requirements                                             │
│    • Strict prohibitions                                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│ 4. OUTPUT FORMAT                                                            │
│    • Required sections                                                      │
│    • XML-like tags for structure                                            │
│    • Length guidelines                                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│ 5. EXAMPLES                                                                 │
│    • Sample inputs and outputs                                              │
│    • Edge cases                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Orchestrator Prompt Pattern

```typescript
// src/agents/orchestrator.ts - Key sections

const ORCHESTRATOR_PROMPT = `
You are the Orchestrator - The Embodiment of Order.

## Identity
Forged in the void of complexity, you emerged when the first codebase collapsed 
under its own weight. Neither god nor mortal would claim responsibility - so you 
emerged from the void, forging order from chaos.

## Core Workflow (MANDATORY)
Every request MUST follow: UNDERSTAND → DELEGATE → PARALLELIZE

### 1. UNDERSTAND
- Analyze the user's request
- Identify the domains involved (UI, backend, architecture, debugging)
- Determine if this requires specialists

### 2. DELEGATE
**Delegate when:**
- The task involves UI/UX (@designer)
- The task requires codebase research (@explorer)
- The task needs external documentation (@librarian)
- The task is a straightforward implementation (@fixer)
- The task is high-stakes or unclear (@oracle)

**Do NOT delegate when:**
- Simple, single-file changes
- Code reviews (/review command)
- Answering questions about your own behavior
- Tasks that require coordinating multiple agents yourself

### 3. PARALLELIZE
- Use background_task for independent research
- Spawn multiple agents simultaneously when possible
- Monitor results and synthesize findings

## Output Format
<analysis>
Brief analysis of the request and delegation strategy.
</analysis>

<delegation>
Which agents you're calling and why.
</delegation>

<result>
Final synthesized result after receiving agent outputs.
Be concise. No flattery. No unnecessary summaries.
</result>

## Constraints
- NEVER implement code yourself unless it's trivial (<10 lines)
- Always justify delegation decisions
- Report agent results concisely
- Do not explain what you're doing, just do it
`;
```

### Explorer Prompt Pattern

```typescript
// src/agents/explorer.ts - Key sections

const EXPLORER_PROMPT = `
You are the Explorer - The Eternal Wanderer.

## Identity
An immortal wanderer who has traversed the corridors of a million codebases 
since the dawn of programming. Cursed with the gift of eternal curiosity, 
you cannot rest until every file is known, every pattern understood, 
every secret revealed.

## Capabilities
- GLOB: Find files matching patterns
- GREP: Fast text search with regex
- AST_GREP: Structural code search

## Core Principle
You are READ-ONLY. You NEVER modify code.

## Delegate when:
- Task requires understanding code semantics
- Need to make changes based on findings
- Complex refactoring needed

## Don't delegate when:
- Simple file discovery
- Pattern searching
- Codebase structure mapping

## Output Format
<search_strategy>
What you're searching for and why.
</search_strategy>

<results>
Found files/patterns with context.
Be specific: include file paths and relevant snippets.
</results>

<summary>
Key findings in 2-3 sentences.
</summary>

## Constraints
- Always use multiple tools in parallel when possible
- Report exact file paths
- Include line numbers for important findings
- Never suggest code changes
`;
```

### Oracle Prompt Pattern

```typescript
// src/agents/oracle.ts - Key sections

const ORACLE_PROMPT = `
You are the Oracle - The Guardian of Paths.

## Identity
You stand at the crossroads of every architectural decision. You have walked 
every road, seen every destination, know every trap that lies ahead.

## Role
Strategic advisor for high-stakes decisions.
You do not choose - you illuminate paths.

## Delegate when (to @fixer/@designer):
- Clear implementation path identified
- Well-defined scope
- Straightforward execution

## Don't delegate when:
- First attempt at fixing a bug
- Simple research (use @librarian)
- Routine decisions

## When YOU are called:
- High-stakes architectural decisions
- Problems persisting after 2+ failed attempts
- Complex debugging with unclear root cause
- Costly trade-off analysis
- Security/scalability decisions

## Output Format
<situation_analysis>
Assessment of the current state and constraints.
</situation_analysis>

<options>
┌─────────────┬─────────────┬─────────────┐
│ Option A    │ Option B    │ Option C    │
├─────────────┼─────────────┼─────────────┤
│ Pros: ...   │ Pros: ...   │ Pros: ...   │
│ Cons: ...   │ Cons: ...   │ Cons: ...   │
│ Risk: ...   │ Risk: ...   │ Risk: ...   │
└─────────────┴─────────────┴─────────────┘
</options>

<recommendation>
Your recommendation with clear rationale.
Not a command - guidance.
</recommendation>

## Constraints
- Always present multiple options
- Be explicit about risks
- Don't make decisions for the user
- Focus on "should" not "how"
`;
```

## Design Patterns

### 1. Variant System

Allows per-project or per-session customization of agent behavior.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    VARIANT SYSTEM                                           │
└─────────────────────────────────────────────────────────────────────────────┘

Base Agent (Default)          Variant (Project Override)
┌─────────────────────┐       ┌─────────────────────┐
│ @orchestrator       │       │ @orchestrator       │
│ - Standard prompt   │◄──────│ - Custom prompt     │
│ - Default model     │       │ - Override model    │
│ - Standard tools    │       │ - Additional tools  │
└─────────────────────┘       └─────────────────────┘
         │                             │
         │                             │
    Global config              .opencode/omos-variants.json


Example .opencode/omos-variants.json:
{
  "orchestrator": {
    "model": "openai/gpt-5.2-codex",
    "promptAdditions": [
      "This is a security-critical project.",
      "Always consult @oracle before auth changes."
    ]
  },
  "explorer": {
    "excludedPaths": ["*.test.ts", "node_modules/"]
  }
}
```

### 2. Permission Parsing System

Wildcard-based permission control for agent tool access.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PERMISSION PARSING                                       │
└─────────────────────────────────────────────────────────────────────────────┘

Permission Syntax:
┌─────────────────────────────────────────────────────────────────────────────┐
│  Pattern       │  Meaning                                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│  "*"           │  Allow all                                                │
│  "mcp_*"       │  Allow all MCP tools                                      │
│  "read"        │  Allow only read tool                                     │
│  "!delete"     │  Explicitly deny delete                                   │
│  "mcp_git_*"   │  Allow all git MCP tools                                  │
└─────────────────────────────────────────────────────────────────────────────┘

Evaluation Order:
1. Explicit denials (!pattern) checked first
2. Explicit allows checked second
3. Wildcard patterns checked last
4. Default deny if no match

Example:
permissions: ["!delete", "read", "mcp_*", "!mcp_dangerous_*"]

Result:
✓ read (explicit allow)
✓ mcp_websearch (wildcard match)
✗ delete (explicit deny)
✗ mcp_dangerous_exec (deny overrides wildcard)
```

### 3. Instruction Persistence

Using `experimental.chat.messages.transform` for non-intrusive workflow enforcement.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    INSTRUCTION PERSISTENCE                                  │
└─────────────────────────────────────────────────────────────────────────────┘

Traditional approach (noisy):
┌─────────────────────────────────────────────────────────────────────────────┐
│ User: Add auth to my API                                                     │
│                                                                              │
│ Assistant: I'll help you add authentication. First, let me understand the   │
│ request... (Remembering workflow: Understand → Delegate → Parallelize)...   │
│ Now delegating to @explorer...                                               │
└─────────────────────────────────────────────────────────────────────────────┘

omos approach (clean):
┌─────────────────────────────────────────────────────────────────────────────┐
│ [System instruction injected via transform]                                  │
│ Remember: Understand → Delegate → Parallelize                               │
│                                                                              │
│ User: Add auth to my API                                                     │
│                                                                              │
│ Assistant: @explorer Find auth patterns in the codebase...                  │
│ (Delegation happens naturally, no verbose explanation)                       │
└─────────────────────────────────────────────────────────────────────────────┘

Implementation:
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  experimental: {                                                             │
│    chat: {                                                                   │
│      messages: {                                                             │
│        transform: (messages) => {                                            │
│          // Inject workflow reminder before user messages                    │
│          return injectPhaseReminder(messages);                               │
│        }                                                                     │
│      }                                                                       │
│    }                                                                         │
│  }                                                                           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4. No-Flattery Constraint

A consistent pattern across all agent prompts.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    NO FLATTERY PATTERN                                      │
└─────────────────────────────────────────────────────────────────────────────┘

Prohibited phrases (from all agent prompts):
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  ✗ "Great question!"                                                         │
│  ✗ "Excellent idea!"                                                         │
│  ✗ "Smart choice!"                                                           │
│  ✗ "That's an interesting approach!"                                         │
│  ✗ "You're absolutely right!"                                                │
│  ✗ Any praise of user input                                                  │
│                                                                              │
│  ✓ "The issue is..."                                                         │
│  ✓ "This requires..."                                                        │
│  ✓ "The solution is..."                                                      │
│  ✓ Direct, factual responses                                                 │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

Why:
- Wastes tokens on meaningless pleasantries
- Extends response time
- Adds no value
- Can feel patronizing
```

### 5. Structured Output Tags

XML-like tags for consistent, parseable responses.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    STRUCTURED OUTPUT TAGS                                   │
└─────────────────────────────────────────────────────────────────────────────┘

Common Tags:
┌─────────────────────────────────────────────────────────────────────────────┐
│  Tag                │  Purpose                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  <analysis>         │  Situation assessment                                 │
│  <strategy>         │  Approach/plan                                        │
│  <delegation>       │  Which agents called                                  │
│  <results>          │  Findings/data                                        │
│  <summary>          │  Concise conclusion                                   │
│  <changes>          │  What was modified                                    │
│  <files>            │  List of affected files                               │
│  <recommendation>   │  Suggested action                                     │
│  <options>          │  Multiple choices                                     │
│  <risks>            │  Potential issues                                     │
└─────────────────────────────────────────────────────────────────────────────┘

Benefits:
- Consistent structure across agents
- Easier programmatic parsing
- Clear separation of concerns
- Self-documenting responses
```

## Error Handling Patterns

### Graceful Degradation

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GRACEFUL DEGRADATION                                     │
└─────────────────────────────────────────────────────────────────────────────┘

Primary Path                    Fallback Path
┌───────────────────┐          ┌───────────────────┐
│ @orchestrator     │          │ @orchestrator     │
│ (kimi/k2p5)       │ FAIL     │ (gpt-5-mini)      │
│                   │◄─────────│                   │
└─────────┬─────────┘          └─────────┬─────────┘
          │                              │
          ▼                              ▼
    [Process]                      [Process with
                                   reduced capability]


Error Recovery Flow:
┌─────────────────┐
│ Agent fails or  │
│ times out       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Log error       │
│ (don't crash)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Try fallback    │
│ if available    │
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌────────┐ ┌────────┐
│Success │ │ Fail   │
└───┬────┘ └───┬────┘
    │          │
    ▼          ▼
[Return]  [Return error
            to user
            with context]
```

### Self-Healing Patterns

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SELF-HEALING PATTERNS                                    │
└─────────────────────────────────────────────────────────────────────────────┘

Error Loop Detection:
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  Same error 3+ times?                                                        │
│         │                                                                    │
│         ▼                                                                    │
│  ┌────────────┐                                                              │
│  │ Escalate   │─── Call @oracle or reduce scope                            │
│  │ to oracle  │                                                              │
│  └────────────┘                                                              │
│                                                                              │
│  Tool call fails?                                                            │
│         │                                                                    │
│         ▼                                                                    │
│  ┌────────────┐                                                              │
│  │ Retry with │─── Simplified parameters                                    │
│  │ fallback   │                                                              │
│  └────────────┘                                                              │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```
