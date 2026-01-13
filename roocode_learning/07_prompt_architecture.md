# 07: Prompt Architecture & System Prompt Assembly

## Overview

Roo-Code's system prompt is dynamically assembled from multiple sections based on the current **mode**, **task state**, and **available tools**. The core assembly happens in `SYSTEM_PROMPT()` function.

**Key File**: `src/core/prompts/system.ts`

## How System Prompts Work

### 1. Dynamic Assembly
```typescript
// src/core/prompts/system.ts
export function SYSTEM_PROMPT(
  mode: Mode,
  customInstructions?: string,
  experimentalFeatures?: ExperimentalFeatureSettings
): string {
  const sections = [
    getToolDescriptions(mode),
    getRoleDescription(mode),
    getTaskInstructions(mode),
    getConstraints(mode),
    customInstructions
  ].filter(Boolean)
  
  return sections.join('\n\n')
}
```

### 2. Mode-Specific Sections

Each mode gets different tool access and instructions:

| Mode | Tool Groups | Special Instructions |
|------|-------------|---------------------|
| `code` | All tools | Full coding capabilities |
| `architect` | Analysis only | No file writes, focus on design |
| `ask` | Read-only | No modifications, answer questions |
| `debug` | Code + execute | Testing and debugging focus |

### 3. Tool Descriptions

Tool descriptions are auto-generated from available tools:

```typescript
// src/core/prompts/sections/tools.ts
function getToolDescriptions(mode: Mode): string {
  const availableTools = getToolsForMode(mode)
  
  return availableTools.map(tool => `
### ${tool.name}
${tool.description}

**Parameters**: ${JSON.stringify(tool.input_schema)}
  `).join('\n')
}
```

## Prompt Sections

### Core Sections
1. **Tool Descriptions** - What tools are available
2. **Role Definition** - Who Roo is and how it behaves
3. **Task Instructions** - How to approach tasks
4. **Constraints** - What to avoid
5. **Custom Instructions** - User-defined rules

### Section Assembly Order
```
1. Tool descriptions (mode-specific)
2. Role and identity
3. Task workflow instructions
4. Safety constraints
5. Custom instructions (if any)
6. Environment context (cwd, git status, etc.)
```

## Custom Instructions

Users can add persistent instructions that get appended to every prompt:

```typescript
// From settings
{
  "roo-cline.customInstructions": "Always use TypeScript strict mode"
}

// Gets injected into SYSTEM_PROMPT
const systemPrompt = SYSTEM_PROMPT(
  currentMode,
  settings.customInstructions  // ← User's rules
)
```

## Experimental Features

Feature flags can modify prompt behavior:

```typescript
interface ExperimentalFeatureSettings {
  enableCaching?: boolean      // Use prompt caching
  enableStreaming?: boolean    // Stream responses
  enableVision?: boolean       // Include image analysis
}

// Different prompt sections based on features
if (experimentalFeatures.enableVision) {
  sections.push(getVisionInstructions())
}
```

## Source Code References

| File | Purpose |
|------|---------|
| `src/core/prompts/system.ts` | Main SYSTEM_PROMPT function |
| `src/core/prompts/sections/tools.ts` | Tool description generation |
| `src/core/prompts/sections/role.ts` | Role and identity text |
| `src/core/prompts/sections/constraints.ts` | Safety rules |
| `src/api/providers/*/system-prompt.ts` | Provider-specific prompt adaptations |

## Key Insights

- **Mode determines tools** → Tools determine prompt content
- **Dynamic assembly** → Same codebase, different prompts per mode
- **Custom instructions persist** → User rules always included
- **Provider adaptation** → Some providers need prompt reformatting

**Version**: Roo-Code v3.39+ (January 2026)
