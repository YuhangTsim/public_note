# 08: Skill Implementation Deep Dive

**Analysis of Skill Handling in Oh-My-OpenCode**

This document details the internal mechanisms of how Oh-My-OpenCode (OMO) parses, registers, and executes skills, differentiating between standardized and non-standardized approaches.

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

2.  **Tier 2: Claude Code Compatibility**
    *   **Source:** `.mcp.json` files.
    *   **Mechanism:** `src/features/claude-code-mcp-loader/` parses these JSON files.
    *   **Key Feature:** Supports `${VAR}` environment variable expansion, allowing direct compatibility with existing Claude Code projects.

3.  **Tier 3: Skill-Embedded MCPs**
    *   **Source:** `SKILL.md` frontmatter.
    *   **Mechanism:** `skill-mcp-manager` parses YAML frontmatter in skill files.
    *   **Behavior:** Dynamically spins up MCP clients only when a specific skill is active.

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

## 2. Parsing & Registration Logic

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

## 3. Comparison with other systems

*   **Vs. Roo Code:** OMO focuses on "Battery-Included" power (pre-configured MCPs, complex built-ins) while Roo Code focuses on strict adherence to the `agentskills.io` spec and native tool protocols.
*   **Vs. OpenClaw:** OMO uses a plugin architecture within OpenCode, whereas OpenClaw uses a Gateway/Sandbox architecture. OMO's skills are "tools" injected into the context, while OpenClaw's skills can be sandboxed executables.
