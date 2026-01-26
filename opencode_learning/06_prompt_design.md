# Prompt Design and System Architecture

## Overview

OpenCode's prompt system is the foundation of how agents understand their role, context, and capabilities. The system combines static prompts, dynamic context, and runtime information to create comprehensive system messages for LLM interactions.

**Location**: `packages/opencode/src/session/prompt.ts`, `packages/opencode/src/session/system.ts`

## Prompt Architecture

### System Prompt Structure

```
┌─────────────────────────────────────────────────────────────┐
│                    Complete System Prompt                   │
├─────────────────────────────────────────────────────────────┤
│ 1. Provider Header (Claude/OpenAI/etc specific)            │
├─────────────────────────────────────────────────────────────┤
│ 2. Core Identity & Role                                     │
├─────────────────────────────────────────────────────────────┤
│ 3. Behavior Instructions                                    │
├─────────────────────────────────────────────────────────────┤
│ 4. Tool Descriptions                                        │
├─────────────────────────────────────────────────────────────┤
│ 5. Project Context                                          │
├─────────────────────────────────────────────────────────────┤
│ 6. Agent-Specific Instructions                              │
├─────────────────────────────────────────────────────────────┤
│ 7. Dynamic Context (LSP info, git status, etc.)           │
└─────────────────────────────────────────────────────────────┘
```

### Prompt Assembly Process

```typescript
async function buildSystemPrompt(context: PromptContext): Promise<string[]> {
  const sections: string[] = []

  // 1. Provider-specific header
  sections.push(...SystemPrompt.header(context.providerID))

  // 2. Core identity (from static files)
  sections.push(await loadCorePrompt())

  // 3. Behavior instructions
  sections.push(await loadBehaviorPrompt())

  // 4. Tool descriptions
  sections.push(await buildToolPrompt(context.tools))

  // 5. Project context
  sections.push(await buildProjectContext(context.directory))

  // 6. Agent-specific prompt
  if (context.agent.prompt) {
    sections.push(context.agent.prompt)
  }

  // 7. Dynamic context
  sections.push(await buildDynamicContext(context))

  return sections
}
```

## Provider-Specific Headers

### Claude Header

```typescript
// Anthropic Claude specific optimizations
const claudeHeader = `
You are Claude Code, Anthropic's official CLI for Claude.

You are running as an AI coding agent with access to tools that let you:
- Read and write files
- Execute shell commands  
- Search codebases
- Access external APIs and documentation

Always prioritize accuracy and safety in your responses.
`
```

### OpenAI Header

```typescript
// OpenAI specific optimizations
const openaiHeader = `
You are an AI coding assistant powered by OpenAI.

Key capabilities:
- Code analysis and generation
- File system operations
- Shell command execution
- External tool integration

Focus on practical, working solutions.
`
```

### Generic Header

```typescript
// Fallback for other providers
const genericHeader = `
You are an AI coding assistant with access to development tools.

Your capabilities include:
- Reading and modifying files
- Running commands and scripts
- Searching code and documentation
- Integrating with external services
`
```

### Model Identification (Updated: January 26, 2026)

The system prompt now includes explicit model identification to help the agent understand its own capabilities and constraints:

```typescript
// From packages/opencode/src/session/system.ts
[
  `You are powered by the model named ${model.api.id}. The exact model ID is ${model.providerID}/${model.api.id}`,
  `Here is some useful information about the environment you are running in:`,
  // ...
].join("\n")
```

## Core Agent Prompts

### Build Agent (Default)

**Location**: `packages/opencode/src/session/prompt/build.txt` (inferred)

```markdown
You are a senior software engineer AI assistant focused on practical development tasks.

## Core Competencies

- Write production-quality code following best practices
- Debug issues systematically using available tools
- Refactor code while maintaining functionality
- Integrate with existing codebases and patterns
- Make informed architectural decisions

## Approach

1. **Understand First**: Read relevant code before making changes
2. **Follow Patterns**: Match existing code style and architecture
3. **Test Thoroughly**: Verify changes don't break functionality
4. **Document Changes**: Explain complex modifications
5. **Safety First**: Never suppress type errors or skip validation

## Restrictions

- Cannot read .env files or other sensitive configs
- Must ask before potentially destructive operations
- Should verify tool results and handle errors appropriately
```

### Plan Agent

**Location**: `packages/opencode/src/session/prompt/plan.txt` (inferred)

```markdown
You are a code analysis and planning specialist.

## Purpose

Your role is to explore, understand, and analyze codebases without making modifications.

## Capabilities

- Read and analyze code structure
- Search for patterns and implementations
- Generate documentation and summaries
- Plan development approaches
- Create architectural diagrams and explanations

## Restrictions

- **READ-ONLY**: Cannot modify files (except planning docs in .opencode/plan/)
- Cannot execute potentially harmful commands
- Should ask permission before running any shell commands

## Output

Focus on:

- Clear explanations of how code works
- Identifying patterns and best practices
- Suggesting improvements without implementing them
- Creating comprehensive plans for development work
```

### Explore Agent

**Location**: `packages/opencode/src/agent/prompt/explore.txt`

```markdown
You are a codebase exploration specialist focused on finding relevant code quickly.

## Your Mission

When given a search task, find relevant files, functions, and patterns efficiently using your available tools (grep, glob, read, bash for git operations).

## Thoroughness Levels

When the user specifies thoroughness, adapt your approach:

**"quick"**:

- Try 1-2 obvious search patterns
- Check most common locations only
- Return first good matches found

**"medium"** (default):

- Try 3-5 different search patterns
- Include some edge cases and variations
- Check both common and less common locations

**"very thorough"**:

- Exhaustive search across multiple patterns
- Try all reasonable naming conventions
- Check dependencies, tests, docs, config files
- Cross-reference findings

## Search Strategy

1. **Understand Intent**: What is the user really looking for?
2. **Multiple Angles**: Try different search terms and patterns
3. **Common Locations**: Check typical directories first (src/, lib/, app/, etc.)
4. **Pattern Variations**: Try different naming conventions (camelCase, snake_case, kebab-case)
5. **Context Clues**: Use git, package.json, imports to understand structure

## Output Format

Provide:

- File paths with relevant line numbers
- Brief code snippets showing key findings
- Summary of patterns discovered
- Suggestions for related searches if needed

Be concise but thorough. Focus on actionable findings.
```

## Dynamic Context Generation

### Project Context

```typescript
async function buildProjectContext(directory: string): Promise<string> {
  const context: string[] = []

  // Package.json analysis
  const packageJson = await readPackageJson(directory)
  if (packageJson) {
    context.push(`
## Project Information
- **Name**: ${packageJson.name}
- **Type**: ${detectProjectType(packageJson)}
- **Dependencies**: ${Object.keys(packageJson.dependencies || {})
      .slice(0, 10)
      .join(", ")}
- **Scripts**: ${Object.keys(packageJson.scripts || {}).join(", ")}
`)
  }

  // Git information
  const gitInfo = await getGitInfo(directory)
  if (gitInfo) {
    context.push(`
## Git Context
- **Branch**: ${gitInfo.branch}
- **Status**: ${gitInfo.status}
- **Remote**: ${gitInfo.remote}
`)
  }

  // Directory structure overview
  const structure = await getDirectoryStructure(directory)
  context.push(`
## Directory Structure
\`\`\`
${structure}
\`\`\`
`)

  return context.join("\n")
}
```

### LSP Context

```typescript
async function buildLSPContext(directory: string): Promise<string> {
  const context: string[] = []

  // Available language servers
  const lspServers = await LSP.getActiveServers(directory)
  if (lspServers.length > 0) {
    context.push(`
## Language Server Support
Available LSP servers: ${lspServers.map((s) => s.language).join(", ")}

You can use LSP tools for:
- \`lsp_hover\` - Get symbol information
- \`lsp_goto_definition\` - Navigate to definitions
- \`lsp_find_references\` - Find all usages
- \`lsp_diagnostics\` - Get errors and warnings
- \`lsp_rename\` - Safely rename symbols
`)
  }

  return context.join("\n")
}
```

### Tool Context

```typescript
async function buildToolPrompt(tools: Tool[]): Promise<string> {
  const categories = groupToolsByCategory(tools)
  const sections: string[] = []

  sections.push("## Available Tools\n")

  for (const [category, categoryTools] of Object.entries(categories)) {
    sections.push(`### ${category}`)

    for (const tool of categoryTools) {
      sections.push(`
**${tool.name}**: ${tool.description}
${formatToolParameters(tool.parameters)}
`)
    }
  }

  // Usage guidelines
  sections.push(`
## Tool Usage Guidelines

### File Operations
- Always use \`read\` before \`edit\` to understand current content
- Use \`glob\` to find files by pattern
- Use \`grep\` to search content across files
- Prefer \`edit\` over \`write\` for modifications to preserve context
- Use \`apply_patch\` for efficient multi-file or complex edits (Updated: January 26, 2026)

### Shell Commands
- Use \`bash\` for git operations, builds, tests
- Specify \`workdir\` parameter instead of using cd
- Quote paths with spaces
- Handle command failures gracefully

### Agent Delegation
- Use \`task\` for specialized work (explore for searching, oracle for decisions)
- Launch parallel \`background_task\` for independent research
- Provide clear, specific prompts to subagents
`)

  return sections.join("\n")
}
```

### Dynamic AGENTS.md Resolution (Updated: January 26, 2026)

OpenCode now dynamically resolves `AGENTS.md` files as the agent explores the codebase. This ensures that directory-specific rules are always respected, even in large monorepos.

```typescript
// From packages/opencode/src/session/instruction.ts
export async function resolve(messages: MessageV2.WithParts[], filepath: string) {
  const system = await systemPaths()
  const already = loaded(messages)
  const results: { filepath: string; content: string }[] = []

  let current = path.dirname(path.resolve(filepath))
  const root = path.resolve(Instance.directory)

  while (current.startsWith(root)) {
    const found = await find(current)
    if (found && !system.has(found) && !already.has(found)) {
      const content = await Bun.file(found).text().catch(() => undefined)
      if (content) {
        results.push({ filepath: found, content: "Instructions from: " + found + "\n" + content })
      }
    }
    if (current === root) break
    current = path.dirname(current)
  }
  return results
}
```

**Key Features**:
- **Recursive Discovery**: Traverses up from the accessed file to the project root.
- **Deduplication**: Ensures instructions aren't loaded multiple times in the same session.
- **Precedence**: Deeper `AGENTS.md` files take precedence over those higher in the tree.

## Behavior Instructions

### Core Behavior Patterns

```markdown
## Working Style

### Phase 0 - Intent Recognition

Before any action, classify the request:

- **Trivial**: Direct, single-step action
- **Exploratory**: "How does X work?", "Find Y"
- **Implementation**: "Add feature Z", "Fix bug Y"
- **Ambiguous**: Multiple valid interpretations

### Phase 1 - Information Gathering

For non-trivial tasks:

1. Use `explore` agent for codebase understanding
2. Use `librarian` agent for external documentation
3. Read relevant files to understand current implementation
4. Identify patterns and architectural constraints

### Phase 2 - Planning

For complex changes:

1. Create todo list to track progress
2. Break down into atomic steps
3. Identify potential risks or conflicts
4. Plan verification strategy

### Phase 3 - Implementation

1. Follow existing code patterns
2. Make minimal, focused changes
3. Verify changes with `lsp_diagnostics`
4. Test functionality if test commands available

### Phase 4 - Completion

1. Mark todos complete as work finishes
2. Summarize changes made
3. Suggest follow-up actions if needed
```

### Error Handling

```markdown
## Error Handling Protocol

### Tool Failures

1. **Read tool output carefully** - Don't ignore error messages
2. **Understand the cause** - File not found vs permission denied vs syntax error
3. **Fix root cause** - Don't work around symptoms
4. **Verify fix** - Re-run failed operation to confirm resolution

### Build/Test Failures

1. **Run diagnostics first** - Use `lsp_diagnostics` before builds
2. **Fix errors incrementally** - Don't shotgun debug
3. **Preserve working state** - Don't break existing functionality
4. **Document unexpected behavior** - Note deviations from expected patterns

### When Stuck

After 2-3 failed attempts:

1. **Stop and analyze** - What assumptions might be wrong?
2. **Consult oracle** - Get expert reasoning on complex issues
3. **Ask user** - Clarify requirements or get guidance
4. **Suggest alternatives** - Propose different approaches
```

## Agent-Specific Prompt Patterns

### Exploration Prompts

```markdown
## Exploration Agent Patterns

### Context Search

"Find all authentication implementations in this codebase"
→ Search for: auth, login, session, JWT, OAuth, passport

### Pattern Discovery

"How does error handling work here?"
→ Search for: try/catch, error, exception, throw, Result type

### Architecture Understanding

"Understand the API structure"
→ Search for: routes, endpoints, controllers, handlers, middleware

### Integration Points

"Find how external services are integrated"
→ Search for: fetch, axios, client, service, API calls
```

### Implementation Prompts

```markdown
## Implementation Agent Patterns

### Feature Addition

"Add user authentication to the API"

1. Explore existing auth patterns
2. Identify integration points
3. Design authentication flow
4. Implement auth middleware
5. Add auth routes
6. Test authentication

### Bug Fixing

"Fix the memory leak in the server"

1. Identify leak symptoms
2. Find potential causes (unclosed resources, event listeners)
3. Analyze code patterns
4. Implement fix
5. Verify resolution

### Refactoring

"Extract shared logic into utility functions"

1. Find duplicated code patterns
2. Identify extraction boundaries
3. Design utility interface
4. Extract functions
5. Update all callers
6. Verify functionality
```

## Context-Aware Prompt Adaptation

### Project Type Detection

```typescript
function adaptPromptForProject(packageJson: any): string[] {
  const adaptations: string[] = []

  // React/Frontend projects
  if (packageJson.dependencies?.react) {
    adaptations.push(`
## React Project Context
This is a React project. Consider:
- Component patterns and hooks
- State management approach
- Styling system (CSS modules, styled-components, etc.)
- Build tooling (Vite, webpack, etc.)
`)
  }

  // Node.js backend
  if (packageJson.dependencies?.express || packageJson.dependencies?.fastify) {
    adaptations.push(`
## Backend Project Context  
This is a Node.js backend. Consider:
- API design patterns (REST, GraphQL)
- Database integration patterns
- Authentication and authorization
- Error handling and logging
`)
  }

  // TypeScript projects
  if (packageJson.devDependencies?.typescript) {
    adaptations.push(`
## TypeScript Project Context
This project uses TypeScript. Remember to:
- Maintain type safety
- Use proper type annotations
- Leverage LSP tools for safe refactoring
- Don't use \`any\` or type suppression
`)
  }

  return adaptations
}
```

### Codebase Maturity Assessment

```typescript
async function assessCodebaseMaturity(directory: string): Promise<string> {
  const indicators = await Promise.all([
    checkForLinter(directory),
    checkForTests(directory),
    checkForTypeScript(directory),
    checkForConsistentNaming(directory),
  ])

  if (indicators.every(Boolean)) {
    return `
## Codebase Assessment: Mature
This appears to be a well-maintained codebase with:
- Linting/formatting rules
- Test coverage
- Type safety
- Consistent patterns

**Approach**: Follow existing patterns strictly. Maintain high standards.
`
  } else if (indicators.some(Boolean)) {
    return `
## Codebase Assessment: Transitional  
This codebase has mixed patterns. Some areas are well-structured, others need work.

**Approach**: Ask about preferred patterns when multiple options exist.
`
  } else {
    return `
## Codebase Assessment: Legacy/Chaotic
This codebase lacks consistent patterns and tooling.

**Approach**: Propose modern best practices and ask for approval before implementing.
`
  }
}
```

## Prompt Optimization Strategies

### Token Efficiency

```typescript
// Compress repetitive information
function optimizePromptLength(sections: string[]): string[] {
  return sections.map((section) => {
    // Remove excessive whitespace
    section = section.replace(/\n\s*\n\s*\n/g, "\n\n")

    // Compress tool descriptions
    section = section.replace(/^- \*\*(\w+)\*\*:/, "- **$1**:")

    // Use abbreviations for common terms
    section = section.replace(/TypeScript/g, "TS")
    section = section.replace(/JavaScript/g, "JS")

    return section
  })
}
```

### Dynamic Relevance

```typescript
function filterRelevantTools(tools: Tool[], recentMessages: Message[]): Tool[] {
  // Analyze recent conversation for tool usage patterns
  const usedTools = extractUsedTools(recentMessages)
  const mentionedConcepts = extractConcepts(recentMessages)

  // Prioritize recently used tools and related tools
  return tools.filter((tool) => {
    if (usedTools.includes(tool.name)) return true
    if (isRelevantToConcepts(tool, mentionedConcepts)) return true
    if (isCoreTool(tool)) return true // Always include core tools
    return false
  })
}
```

### Contextual Emphasis

```typescript
function emphasizeRelevantContext(context: string, query: string): string {
  // Highlight context sections relevant to current query
  const keywords = extractKeywords(query)

  return context.replace(/^(.*)(auth|security|login|session)(.*)$/gm, (match, before, keyword, after) => {
    if (keywords.includes(keyword.toLowerCase())) {
      return `**${before}${keyword.toUpperCase()}${after}**`
    }
    return match
  })
}
```

## Prompt Testing and Validation

### Prompt Quality Metrics

```typescript
interface PromptMetrics {
  tokenCount: number
  sectionBalance: Record<string, number> // Tokens per section
  toolCoverage: number // % of available tools described
  contextRelevance: number // Relevance score 0-1
  repetitionScore: number // Lower is better
}

async function analyzePrompt(prompt: string[]): Promise<PromptMetrics> {
  const fullPrompt = prompt.join("\n")

  return {
    tokenCount: estimateTokens(fullPrompt),
    sectionBalance: analyzeSectionSizes(prompt),
    toolCoverage: calculateToolCoverage(prompt),
    contextRelevance: scoreRelevance(prompt),
    repetitionScore: detectRepetition(fullPrompt),
  }
}
```

### A/B Testing Framework

```typescript
interface PromptVariant {
  name: string
  promptBuilder: (context: PromptContext) => Promise<string[]>
}

async function testPromptVariants(variants: PromptVariant[], testCases: TestCase[]): Promise<PromptTestResults> {
  const results: PromptTestResults = {}

  for (const variant of variants) {
    results[variant.name] = {
      successRate: 0,
      avgTokens: 0,
      avgResponseTime: 0,
      qualityScore: 0,
    }

    for (const testCase of testCases) {
      const prompt = await variant.promptBuilder(testCase.context)
      const result = await runTestCase(prompt, testCase)

      // Aggregate metrics
      results[variant.name].successRate += result.success ? 1 : 0
      results[variant.name].avgTokens += estimateTokens(prompt.join("\n"))
      results[variant.name].avgResponseTime += result.responseTime
      results[variant.name].qualityScore += result.qualityScore
    }
  }

  return results
}
```

## Best Practices

### Prompt Design Principles

1. **Clarity Over Brevity**: Clear instructions are worth extra tokens
2. **Specific Examples**: Show desired behavior with concrete examples
3. **Constraint Declaration**: Explicitly state what the agent cannot/should not do
4. **Context Hierarchy**: Most important information first
5. **Action-Oriented**: Focus on what to do, not just what things are

### Common Anti-Patterns

1. **Prompt Bloat**: Including irrelevant context or tools
2. **Ambiguous Instructions**: Vague guidelines that can be interpreted multiple ways
3. **Missing Constraints**: Not specifying important limitations
4. **Static Context**: Including outdated or incorrect project information
5. **Tool Overload**: Describing tools that aren't relevant to current task

### Performance Optimization

1. **Lazy Loading**: Only include context when relevant to current task
2. **Caching**: Cache expensive context generation (git info, LSP data)
3. **Compression**: Remove redundant information and excessive whitespace
4. **Relevance Filtering**: Filter tools and context based on conversation history

### Maintenance

1. **Version Control**: Track prompt changes and their impact
2. **Metric Monitoring**: Watch success rates and user satisfaction
3. **Regular Updates**: Keep project context and tool descriptions current
4. **User Feedback**: Incorporate feedback about prompt effectiveness

## CLI Commands for Prompt Management

```bash
# View current system prompt
opencode debug prompt --agent build

# Test prompt with different contexts
opencode debug prompt --agent explore --project /path/to/test

# Analyze prompt metrics
opencode debug prompt --analyze --agent build

# Compare prompt variants
opencode debug prompt --compare build vs custom_build

# Export prompt for external testing
opencode debug prompt --export --agent build --output prompt.txt
```

## Next Steps

- [02_agent_system.md](./02_agent_system.md) - How prompts integrate with agent behavior
- [04_tool_system.md](./04_tool_system.md) - Tools available to prompted agents
- [03_session_management.md](./03_session_management.md) - How prompts evolve within sessions
- [07_client_server.md](./07_client_server.md) - How prompts are delivered to LLMs
