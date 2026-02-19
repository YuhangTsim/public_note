# 08: Skill Implementation Deep Dive

**How Oh-My-OpenCode Handles Skills: Discovery, Permissions, and Execution**

This document details the internal mechanisms of how Oh-My-OpenCode (OMO) parses, registers, and executes skills, differentiating between standardized and non-standardized approaches.

---

## Overview

OMOS extends OpenCode's base skill system with sophisticated auto-discovery, permission management, and a three-tier MCP integration model. Unlike the base OpenCode skill system which requires manual loading via `skill()` tool calls, OMOS implements **automatic skill discovery and injection** based on intent classification and the 160+ hook system.

```
┌─────────────────────────────────────────────────────────────────┐
│                    OMOS Skill Architecture                      │
└─────────────────────────────────────────────────────────────────┘

  User Prompt
       │
       ▼
┌──────────────────┐    ┌──────────────────┐    ┌──────────────┐
│ Intent           │───►│ Skill Discovery  │───►│ Auto-Inject  │
│ Classification   │    │ (5-tier system)  │    │ via Hook     │
└──────────────────┘    └──────────────────┘    └──────────────┘
                                                          │
                       ┌──────────────────┐              │
                       │ MCP Integration  │◄─────────────┘
                       │ (3-tier model)   │
                       └──────────────────┘
```

---

## 1. The Two Types of Skills

OMO handles two distinct types of skills:
1.  **Standardized Skills (MCP & Claude Code Compat):** Designed for interoperability and rapid extension.
2.  **Non-Standardized / Built-in Skills:** Hardcoded or highly customized capabilities.

### A. Standardized Skills (3-Tier MCP System)

OMO implements a sophisticated **Three-Tier MCP Architecture** to handle standardized tools:

1.  **Tier 1: Built-in MCPs**
    *   **Source:** `src/mcp/index.ts`
    *   **Mechanism:** Hardcoded factory functions (`createBuiltinMcps`).
    *   **Examples:**
        *   `websearch` (Exa AI)
        *   `context7` (Library Documentation)
        *   `grep_app` (GitHub Code Search)
    *   **Configuration:** Loaded as remote MCPs with optional authentication headers.

2.  **Tier 2: Claude Code Compatibility (`.mcp.json`)**
    *   **Source:** `.mcp.json` files in project or home directory.
    *   **Mechanism:** `src/features/claude-code-mcp-loader/` parses these JSON files.
    *   **Key Feature:** Supports `${VAR}` environment variable expansion, allowing direct compatibility with existing Claude Code projects.
    *   **Example:**
        ```json
        {
          "mcpServers": {
            "github": {
              "command": "npx",
              "args": ["-y", "@modelcontextprotocol/server-github"],
              "env": {
                "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
              }
            }
          }
        }
        ```

3.  **Tier 3: Skill-Embedded MCPs (SKILL.md Frontmatter)**
    *   **Source:** `SKILL.md` YAML frontmatter.
    *   **Mechanism:** `skill-mcp-manager` parses YAML frontmatter in skill files.
    *   **Behavior:** Dynamically spins up MCP clients only when a specific skill is active.
    *   **Example:**
        ```markdown
        ---
        name: database-query
        metadata: {
          "oh-my-opencode": {
            "mcp": {
              "server": {
                "command": "docker",
                "args": ["run", "--rm", "-i", "my-db-mcp"]
              }
            }
          }
        }
        ---
        ```

**MCP Loading Priority:** `Skill-Embedded > Config-Based > Built-in`

### B. Non-Standardized Skills

1.  **Hardcoded Built-ins**
    *   **Source:** `src/features/builtin-skills/skills.ts` (1700+ lines).
    *   **Mechanism:** Factory functions (`createBuiltinSkills`).
    *   **Core Skills:**
        *   `playwright` (Browser Automation)
        *   `git-master` (Atomic Git Operations)
        *   `dev-browser` (Persistent Browser State)
        *   `frontend-ui-ux` (UI/UX logic)
    *   **Feature:** Allows for complex logic (e.g., selecting different browser providers) that simple declarative files cannot handle.

2.  **Directory-Based Loading**
    *   **Source:** `SKILL.md` files in:
        *   `.opencode/skills/` (Project-level)
        *   `~/.config/opencode/skills/` (User-level)
        *   `.claude/skills/` (Compatibility)
    *   **Priority:** Project > User > Claude Compat.

---

## 2. Five-Tier Skill Discovery

OMOS discovers skills from five sources, with explicit precedence:

```
remote < plugin < managed < workspace < extra
```

| Tier | Location | Priority | Use Case |
|------|----------|----------|----------|
| **Remote** | `https://.../.well-known/skills/` | Lowest | Shared organization skills |
| **Plugin** | `~/openclaw-plugins/*/skills/` | Low | Extension-provided skills |
| **Managed** | `~/.config/opencode/skills/` | Medium | User-installed skills |
| **Workspace** | `<project>/.opencode/skills/` | High | Project-specific skills |
| **Extra** | Custom paths in config | Highest | Override everything |

### Discovery Implementation

```typescript
// From: oh-my-opencode/src/skills/discovery.ts
async function discoverAllSkills(workspaceDir: string): Promise<Skill[]> {
  const sources = [
    // 1. Remote skills (fetched and cached)
    await fetchRemoteSkills(config.skills.remoteUrls),
    
    // 2. Plugin skills
    resolvePluginSkillDirs({ workspaceDir, config }),
    
    // 3. Managed (user-installed)
    scanSkillDir(`${os.homedir()}/.config/opencode/skills`),
    
    // 4. Workspace (project-specific)
    scanSkillDir(`${workspaceDir}/.opencode/skills`),
    
    // 5. Extra (custom paths - highest priority)
    ...config.skills.extraDirs.map(scanSkillDir)
  ]
  
  // Merge with precedence: later sources override earlier
  const merged = new Map<string, Skill>()
  for (const source of sources) {
    for (const skill of source) {
      merged.set(skill.name, skill) // Override if exists
    }
  }
  
  return Array.from(merged.values())
}
```

---

## 3. Parsing & Registration Logic

The parsing pipeline is rigorous and heavily typed.

### Step 1: Loading (`opencode-skill-loader`)
The loader recursively scans skill directories for `SKILL.md` files.

### Step 2: Extraction
It uses `yaml-front-matter` (or similar) to extract:
*   **Metadata:** `name`, `description`.
*   **Restrictions:** `agent` (which agents can use this), `allowed-tools`.
*   **Template:** The markdown content between `<skill-instruction>` tags.

### Step 3: Validation
Everything is validated against strict **Zod schemas** defined in `src/config/schema.ts`. This ensures that bad config files fail fast before the agent ever sees them.

### Step 4: Registration
Tools are registered via the `@opencode-ai/plugin` API using a unified `tool()` registration system.
*   **Static Tools:** Exported directly as `ToolDefinition`.
*   **Dynamic Tools:** Created via factory functions (e.g., `createSkillTool()`, `createSkillMcpTool()`) which bind the tool to the specific context.

---

## 4. Automatic Permission Management

OMOS automatically grants permissions when skills are loaded:

### Permission Auto-Grant

```typescript
// From: oh-my-opencode/src/skills/permissions.ts
async function onSkillLoaded(skill: Skill, sessionId: string): Promise<void> {
  // Grant external_directory permission for skill folder
  await grantPermission({
    session: sessionId,
    category: 'external_directory',
    path: skill.directory,
    action: 'allow'
  })
  
  // Grant read permission for skill files
  for (const file of skill.files) {
    await grantPermission({
      session: sessionId,
      category: 'read',
      path: `${skill.directory}/${file}`,
      action: 'allow'
    })
  }
  
  // Grant tool permissions declared by skill
  if (skill.metadata.tools) {
    for (const tool of skill.metadata.tools) {
      await grantPermission({
        session: sessionId,
        category: 'tool',
        tool: tool.name,
        action: tool.permission || 'ask'
      })
    }
  }
}
```

### Permission Categories

| Category | Description | Auto-Granted |
|----------|-------------|--------------|
| `external_directory` | Access skill directory | ✅ Yes |
| `read` | Read skill files | ✅ Yes |
| `tool` | Use skill-specific tools | ⚠️ Configurable |
| `mcp` | Use embedded MCP | ⚠️ Configurable |
| `bash` | Execute shell commands | ❌ No |
| `browser` | Browser automation | ❌ No |

---

## 5. Intent-Based Auto-Loading

OMOS uses the `UserPromptSubmit` hook to automatically load relevant skills:

### Intent Classification

```typescript
// From: oh-my-opencode/src/hooks/skill-loader/intent.ts
type IntentClassification = {
  primaryIntent: string
  confidence: number
  suggestedSkills: string[]
  requiresMCP: boolean
}

async function classifyIntent(prompt: string): Promise<IntentClassification> {
  // Keyword-based classification
  const patterns = {
    'browser-automation': ['browser', 'click', 'page', 'e2e', 'test'],
    'git-operations': ['git', 'commit', 'rebase', 'merge', 'branch'],
    'frontend-ui': ['css', 'react', 'component', 'ui', 'design'],
    'database': ['sql', 'query', 'database', 'migration', 'schema'],
    'api-integration': ['api', 'endpoint', 'http', 'request', 'fetch']
  }
  
  // Score each pattern
  const scores = Object.entries(patterns).map(([intent, keywords]) => {
    const matches = keywords.filter(kw => 
      prompt.toLowerCase().includes(kw)
    ).length
    return { intent, score: matches / keywords.length }
  })
  
  // Return best match if confidence > 0.5
  const best = scores.sort((a, b) => b.score - a.score)[0]
  
  return {
    primaryIntent: best.intent,
    confidence: best.score,
    suggestedSkills: await findSkillsForIntent(best.intent),
    requiresMCP: intentRequiresMCP(best.intent)
  }
}
```

### Skill Loader Hook

```typescript
// From: oh-my-opencode/src/hooks/skill-loader/loader.ts
export function registerSkillLoader(plugin: Plugin): void {
  plugin.on('UserPromptSubmit', async (event) => {
    // Classify intent
    const intent = await classifyIntent(event.userPrompt)
    
    if (intent.confidence > 0.5 && intent.suggestedSkills.length > 0) {
      // Load suggested skills
      for (const skillName of intent.suggestedSkills) {
        const skill = await loadSkill(skillName)
        
        // Inject skill instructions into system prompt
        event.systemPrompt += `\n\n`
        event.systemPrompt += `<!-- Skill: ${skill.name} -->\n`
        event.systemPrompt += skill.content
        
        // Grant permissions
        await onSkillLoaded(skill, event.sessionID)
        
        // Log for debugging
        console.log(`[skills] Auto-loaded "${skill.name}" for intent: ${intent.primaryIntent}`)
      }
      
      // If MCP required, ensure servers are running
      if (intent.requiresMCP) {
        await ensureMCPServersRunning(intent.suggestedSkills)
      }
    }
  })
}
```

---

## 6. Skill Marketplace

OMOS includes a skill marketplace for discovering and installing skills:

### Listing Available Skills

```bash
$ opencode skills list

Available Skills:
🎭 playwright      Browser automation and E2E testing
📊 data-analysis   Python pandas and data visualization
🐳 docker          Container management workflows
☁️  aws-cli         AWS command-line operations
🗄️  database        SQL query and migration helpers
```

### Installing Skills

```bash
# Install from marketplace
$ opencode skills install playwright

# Install from GitHub
$ opencode skills install github:user/repo

# Install from local directory
$ opencode skills install ./my-custom-skill
```

### Skill Installation Process

```typescript
// From: oh-my-opencode/src/skills/install.ts
async function installSkill(source: string): Promise<Skill> {
  // 1. Resolve source (marketplace, github, local)
  const resolved = await resolveSkillSource(source)
  
  // 2. Download/fetch skill
  const skillDir = await fetchSkill(resolved)
  
  // 3. Validate SKILL.md
  const skill = await parseSkill(skillDir)
  validateSkill(skill)
  
  // 4. Install dependencies (if MCP embedded)
  if (skill.metadata.mcp?.install) {
    await installMCPDependencies(skill.metadata.mcp)
  }
  
  // 5. Copy to managed directory
  const targetDir = `${os.homedir()}/.config/opencode/skills/${skill.name}`
  await fs.copy(skillDir, targetDir)
  
  // 6. Update skill index
  await updateSkillIndex(skill)
  
  return skill
}
```

---

## 7. Comparison with Other Systems

*   **Vs. Roo Code:** OMO focuses on "Battery-Included" power (pre-configured MCPs, complex built-ins) while Roo Code focuses on strict adherence to the `agentskills.io` spec and native tool protocols.
*   **Vs. OpenClaw:** OMO uses a plugin architecture within OpenCode, whereas OpenClaw uses a Gateway/Sandbox architecture. OMO's skills are "tools" injected into the context, while OpenClaw's skills can be sandboxed executables.
*   **Vs. Base OpenCode:**

| Feature | OpenCode Base | OMOS |
|---------|---------------|------|
| **Discovery** | Manual scan | 5-tier auto-discovery |
| **Loading** | `skill()` tool call | Intent-based auto-load |
| **Permissions** | Manual grant | Auto-grant on load |
| **MCP Integration** | Config-based only | 3-tier (builtin/config/skill) |
| **Remote Skills** | ❌ No | ✅ Yes |
| **Marketplace** | ❌ No | ✅ Built-in |
| **Hook Integration** | Basic | 160+ hooks |
| **Context Injection** | Manual | Automatic via hooks |

---

## 8. Best Practices

### For Skill Authors

1. **Declare requirements explicitly**: List bins, env vars, files needed in metadata
2. **Provide examples**: Include working code samples in `examples/` directory
3. **Document MCP tools**: If embedding MCP, document available tools
4. **Use semantic naming**: Skill name should indicate purpose
5. **Test auto-load**: Verify intent classification works correctly

### For Users

1. **Project-specific skills**: Use workspace tier for project conventions
2. **Global utilities**: Use managed tier for tools you use everywhere
3. **Override carefully**: Extra tier overrides everything—use sparingly
4. **Review permissions**: Check what permissions skills are requesting
5. **Update regularly**: Skills may have security updates

### For Admins (Teams)

1. **Remote skill server**: Host organization-specific skills
2. **Curated marketplace**: Pre-approve skills for team use
3. **Permission templates**: Define standard permission sets
4. **Audit trail**: Log skill usage and permission grants

---

## Key Files

- `src/skills/discovery.ts` - 5-tier discovery system
- `src/skills/permissions.ts` - Auto-permission management
- `src/hooks/skill-loader/` - Intent classification and auto-loading
- `src/skills/install.ts` - Marketplace and installation
- `src/mcp/integration.ts` - 3-tier MCP system
- `src/features/builtin-skills/skills.ts` - Hardcoded built-in skills (1700+ lines)
- `src/features/claude-code-mcp-loader/` - Claude Code MCP compatibility

---

**Updated**: February 2026  
**Based on**: oh-my-opencode v3.x skill system
