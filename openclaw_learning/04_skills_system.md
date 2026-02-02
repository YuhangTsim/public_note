# Skills System

The skills system in OpenClaw extends the agent's capabilities by providing reusable, discoverable, installable knowledge modules. Skills are markdown documents that teach the agent how to use specific tools, services, or workflows.

## Table of Contents
- [Overview](#overview)
- [Skills Discovery](#skills-discovery)
- [SKILL.md Format](#skillmd-format)
- [Metadata Schema](#metadata-schema)
- [Installation System](#installation-system)
- [Skill Eligibility](#skill-eligibility)
- [Prompt Integration](#prompt-integration)
- [Plugin Skills](#plugin-skills)
- [Key Files](#key-files)

---

## Overview

Skills are markdown files that:
- Teach the agent domain-specific knowledge (how to use a CLI, API patterns, etc.)
- Declare binary dependencies and installation methods
- Include example code and usage patterns
- Support conditional loading based on platform, binaries, environment variables

**Architecture:**
```
Skills System
├── Discovery Layer (4-tier precedence)
│   ├── Extra dirs (lowest priority)
│   ├── Bundled skills
│   ├── Managed skills (~/.config/openclaw/skills/)
│   └── Workspace skills (highest priority)
├── Eligibility Filter
│   ├── Platform check (os)
│   ├── Binary check (requires.bins)
│   ├── Config allowlist
│   └── Remote platform compatibility
├── Installation Orchestrator
│   ├── brew installer
│   ├── node installer (npm/pnpm/yarn/bun)
│   ├── go installer
│   ├── uv installer
│   └── download installer (archives)
└── Prompt Builder
    ├── Filter by eligibility
    ├── Format for agent
    └── Inject into system prompt
```

---

## Skills Discovery

Skills are loaded from multiple directories with a **precedence hierarchy**. Higher priority sources override lower ones when skill names conflict.

### Source Precedence (Low to High)

```
extra < bundled < managed < workspace
```

**From `src/agents/skills/workspace.ts:152-157`:**
```typescript
const merged = new Map<string, Skill>();
// Precedence: extra < bundled < managed < workspace
for (const skill of extraSkills) merged.set(skill.name, skill);
for (const skill of bundledSkills) merged.set(skill.name, skill);
for (const skill of managedSkills) merged.set(skill.name, skill);
for (const skill of workspaceSkills) merged.set(skill.name, skill);
```

### 1. Extra Directories (Lowest Priority)

User-configured custom skill directories.

**Configuration:**
```yaml
# .openclaw/config.yaml
skills:
  load:
    extraDirs:
      - ~/my-custom-skills
      - /opt/company-skills
```

**Location:** Any user-specified paths via `config.skills.load.extraDirs`

### 2. Bundled Skills

Skills that ship with OpenClaw itself.

**Location:** `<openclaw-install>/skills/`

**Examples:**
- `skills/nano-pdf/` - Edit PDFs with natural language
- `skills/himalaya/` - Email client integration
- `skills/bear-notes/` - Bear notes integration
- `skills/peekaboo/` - Screen capture tool

### 3. Managed Skills

System-wide skills installed via OpenClaw CLI.

**Location:** `~/.config/openclaw/skills/`

**Installation:**
```bash
openclaw skills install <skill-name>
```

### 4. Workspace Skills (Highest Priority)

Project-specific skills that override all others.

**Location:** `<workspace>/skills/`

**Use case:** Custom workflows, internal tools, project-specific conventions

---

## SKILL.md Format

Every skill is a markdown file with YAML frontmatter containing metadata.

### Basic Structure

**From `skills/nano-pdf/SKILL.md`:**
```markdown
---
name: nano-pdf
description: Edit PDFs with natural-language instructions using the nano-pdf CLI.
homepage: https://pypi.org/project/nano-pdf/
metadata: {"openclaw":{"emoji":"📄","requires":{"bins":["nano-pdf"]},"install":[{"id":"uv","kind":"uv","package":"nano-pdf","bins":["nano-pdf"],"label":"Install nano-pdf (uv)"}]}}
---

# nano-pdf

Use `nano-pdf` to apply edits to a specific page in a PDF using a natural-language instruction.

## Quick start

```bash
nano-pdf edit deck.pdf 1 "Change the title to 'Q3 Results' and fix the typo in the subtitle"
```

Notes:
- Page numbers are 0-based or 1-based depending on the tool's version/config
- Always sanity-check the output PDF before sending it out
```

### Frontmatter Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | ✅ | Unique skill identifier (lowercase, hyphenated) |
| `description` | string | ✅ | Brief summary shown in skill lists |
| `homepage` | string | ❌ | URL to official documentation |
| `metadata` | object | ❌ | OpenClaw-specific configuration (see below) |

---

## Metadata Schema

The `metadata.openclaw` object controls skill behavior, dependencies, and installation.

### Full Schema

**From `src/agents/skills/types.ts:19-33`:**
```typescript
export type OpenClawSkillMetadata = {
  always?: boolean;              // Always include in prompt (bypass eligibility)
  skillKey?: string;             // Override for conflict resolution
  primaryEnv?: string;           // Primary environment variable to inject
  emoji?: string;                // Display emoji in UI
  homepage?: string;             // Official documentation URL
  os?: string[];                 // Platform restrictions ["darwin", "linux", "win32"]
  requires?: {                   // Eligibility requirements
    bins?: string[];             // All binaries must exist
    anyBins?: string[];          // At least one binary must exist
    env?: string[];              // Environment variables must be set
    config?: string[];           // Config keys must be truthy
  };
  install?: SkillInstallSpec[];  // Installation methods
};
```

### Example: Complex Metadata

```json
{
  "openclaw": {
    "emoji": "📧",
    "os": ["darwin", "linux"],
    "requires": {
      "bins": ["himalaya"],
      "env": ["EMAIL_ADDRESS"]
    },
    "install": [
      {
        "id": "brew",
        "kind": "brew",
        "formula": "himalaya",
        "bins": ["himalaya"],
        "label": "Install himalaya (brew)"
      },
      {
        "id": "cargo",
        "kind": "download",
        "url": "https://github.com/soywod/himalaya/releases/download/v1.0.0/himalaya.tar.gz",
        "extract": true,
        "stripComponents": 1,
        "bins": ["himalaya"]
      }
    ]
  }
}
```

---

## Installation System

Skills can declare multiple installation methods. The system tries each installer until one succeeds.

### Installer Types

**From `src/agents/skills/types.ts:3-17`:**
```typescript
export type SkillInstallSpec = {
  id?: string;              // Unique installer ID
  kind: "brew" | "node" | "go" | "uv" | "download";
  label?: string;           // UI display name
  bins?: string[];          // Binaries this installer provides
  os?: string[];            // Platform restrictions
  // Type-specific fields:
  formula?: string;         // brew formula name
  package?: string;         // npm/uv package name
  module?: string;          // go module path
  url?: string;             // download URL
  archive?: string;         // "tar.gz" | "tar.bz2" | "zip"
  extract?: boolean;        // Auto-extract archive
  stripComponents?: number; // For tar --strip-components
  targetDir?: string;       // Install destination
};
```

### 1. Brew Installer

```json
{
  "kind": "brew",
  "formula": "jq",
  "bins": ["jq"],
  "os": ["darwin", "linux"]
}
```

**Implementation (`src/agents/skills-install.ts:105-108`):**
```typescript
case "brew": {
  if (!spec.formula) return { argv: null, error: "missing brew formula" };
  return { argv: ["brew", "install", spec.formula] };
}
```

### 2. Node Installer

```json
{
  "kind": "node",
  "package": "@openclaw/skill-ts-tools",
  "bins": ["tsc", "ts-node"]
}
```

**Supports multiple package managers:**
```typescript
function buildNodeInstallCommand(packageName: string, prefs: SkillsInstallPreferences): string[] {
  switch (prefs.nodeManager) {
    case "pnpm": return ["pnpm", "add", "-g", packageName];
    case "yarn": return ["yarn", "global", "add", packageName];
    case "bun": return ["bun", "add", "-g", packageName];
    default: return ["npm", "install", "-g", packageName];
  }
}
```

**User configuration:**
```yaml
# .openclaw/config.yaml
skills:
  install:
    nodeManager: pnpm  # or npm, yarn, bun
```

### 3. Go Installer

```json
{
  "kind": "go",
  "module": "github.com/charmbracelet/glow@latest",
  "bins": ["glow"]
}
```

**Implementation:**
```typescript
case "go": {
  if (!spec.module) return { argv: null, error: "missing go module" };
  return { argv: ["go", "install", spec.module] };
}
```

**Special handling:** If brew is available, go binaries are installed to brew's bin directory for easier PATH management.

### 4. UV Installer

Python package installer using `uv` (fast pip alternative).

```json
{
  "kind": "uv",
  "package": "nano-pdf",
  "bins": ["nano-pdf"]
}
```

**Auto-bootstrapping:** If `uv` isn't installed but brew is available, OpenClaw auto-installs `uv` first.

**From `src/agents/skills-install.ts:355-378`:**
```typescript
if (spec.kind === "uv" && !hasBinary("uv")) {
  if (brewExe) {
    const brewResult = await runCommandWithTimeout([brewExe, "install", "uv"], {
      timeoutMs,
    });
    if (brewResult.code !== 0) {
      return {
        ok: false,
        message: "Failed to install uv (brew)",
        stdout: brewResult.stdout.trim(),
        stderr: brewResult.stderr.trim(),
        code: brewResult.code,
      };
    }
  } else {
    return {
      ok: false,
      message: "uv not installed (install via brew)",
      ...
    };
  }
}
```

### 5. Download Installer

Downloads and extracts archives from URLs.

```json
{
  "kind": "download",
  "url": "https://github.com/owner/repo/releases/download/v1.0.0/tool-macos.tar.gz",
  "extract": true,
  "stripComponents": 1,
  "targetDir": "~/.local/bin"
}
```

**Features:**
- Auto-detects archive type (tar.gz, tar.bz2, zip)
- Extracts to `~/.config/openclaw/tools/<skill-name>/` by default
- Supports `stripComponents` for tar archives (removes leading directories)
- Configurable target directory

**From `src/agents/skills-install.ts:237-277`:**
```typescript
const archiveType = resolveArchiveType(spec, filename);
const shouldExtract = spec.extract ?? Boolean(archiveType);

if (!shouldExtract) {
  return {
    ok: true,
    message: `Downloaded to ${archivePath}`,
    ...
  };
}

const extractResult = await extractArchive({
  archivePath,
  archiveType,
  targetDir,
  stripComponents: spec.stripComponents,
  timeoutMs,
});
```

---

## Skill Eligibility

Not all skills are available in all contexts. Eligibility filtering ensures only compatible skills load.

### Eligibility Checks

**From `src/agents/skills/config.ts`:**
1. **OS Check:** `metadata.os` must include current platform (`darwin`, `linux`, `win32`)
2. **Binary Check:** All `requires.bins` must exist in PATH
3. **AnyBin Check:** At least one `requires.anyBins` must exist
4. **Environment Check:** All `requires.env` must be set
5. **Config Check:** All `requires.config` keys must be truthy in config
6. **Allowlist Check:** Bundled skills can be restricted via config
7. **Remote Check:** For remote platforms, binaries must exist on remote system

### Example: Email Skill

```json
{
  "openclaw": {
    "os": ["darwin", "linux"],
    "requires": {
      "bins": ["himalaya"],
      "env": ["EMAIL_ADDRESS", "EMAIL_PASSWORD"]
    }
  }
}
```

**Eligibility logic:**
- ✅ Passes on macOS/Linux if `himalaya` binary exists and both env vars are set
- ❌ Fails on Windows
- ❌ Fails if `himalaya` not installed
- ❌ Fails if environment variables missing

### Remote Platform Eligibility

When running against a remote SSH host, eligibility checks run against the **remote** environment, not local.

**From `src/agents/skills/types.ts:73-80`:**
```typescript
export type SkillEligibilityContext = {
  remote?: {
    platforms: string[];                          // Remote OS platforms
    hasBin: (bin: string) => boolean;             // Check remote binary
    hasAnyBin: (bins: string[]) => boolean;       // Check any remote binary
    note?: string;                                // Context note for prompt
  };
};
```

**Usage:**
```typescript
const snapshot = buildWorkspaceSkillSnapshot(workspaceDir, {
  eligibility: {
    remote: {
      platforms: ["linux"],
      hasBin: (bin) => remoteBinaries.has(bin),
      hasAnyBin: (bins) => bins.some(b => remoteBinaries.has(b)),
      note: "Running on remote Ubuntu 22.04 server"
    }
  }
});
```

---

## Prompt Integration

Eligible skills are formatted and injected into the agent's system prompt.

### Workflow

**From `src/agents/skills/workspace.ts:177-212`:**
```typescript
export function buildWorkspaceSkillSnapshot(
  workspaceDir: string,
  opts?: {
    config?: OpenClawConfig;
    skillFilter?: string[];      // Only include specific skills
    eligibility?: SkillEligibilityContext;
  }
): SkillSnapshot {
  // 1. Load all skills from 4 sources
  const skillEntries = loadSkillEntries(workspaceDir, opts);
  
  // 2. Filter by eligibility (OS, bins, env, config)
  const eligible = filterSkillEntries(
    skillEntries,
    opts?.config,
    opts?.skillFilter,
    opts?.eligibility
  );
  
  // 3. Remove skills marked disableModelInvocation
  const promptEntries = eligible.filter(
    (entry) => entry.invocation?.disableModelInvocation !== true
  );
  
  // 4. Format for agent prompt
  const resolvedSkills = promptEntries.map((entry) => entry.skill);
  const remoteNote = opts?.eligibility?.remote?.note?.trim();
  const prompt = [
    remoteNote,
    formatSkillsForPrompt(resolvedSkills)
  ].filter(Boolean).join("\n");
  
  return { prompt, skills: eligible, resolvedSkills };
}
```

### Skill Filtering

Users can restrict which skills load:

**Via Config:**
```yaml
# .openclaw/config.yaml
skills:
  bundled:
    allowlist:
      - nano-pdf
      - bear-notes
      # All other bundled skills ignored
```

**Via Runtime:**
```typescript
const snapshot = buildWorkspaceSkillSnapshot(workspaceDir, {
  skillFilter: ["nano-pdf", "custom-skill"]
});
```

**From `src/agents/skills/workspace.ts:44-62`:**
```typescript
function filterSkillEntries(
  entries: SkillEntry[],
  config?: OpenClawConfig,
  skillFilter?: string[],
  eligibility?: SkillEligibilityContext
): SkillEntry[] {
  let filtered = entries.filter((entry) => 
    shouldIncludeSkill({ entry, config, eligibility })
  );
  
  if (skillFilter !== undefined) {
    const normalized = skillFilter.map((entry) => String(entry).trim()).filter(Boolean);
    console.log(`[skills] Applying skill filter: ${normalized.join(", ")}`);
    filtered = normalized.length > 0
      ? filtered.filter((entry) => normalized.includes(entry.skill.name))
      : [];
  }
  return filtered;
}
```

---

## Plugin Skills

Extensions can provide their own skill directories.

### Plugin Skill Discovery

**From `src/agents/skills/plugin-skills.ts`:**
```typescript
export function resolvePluginSkillDirs(params: {
  workspaceDir: string;
  config?: OpenClawConfig;
}): string[] {
  const pluginsConfig = params.config?.extensions?.plugins ?? [];
  const skillDirs: string[] = [];
  
  for (const plugin of pluginsConfig) {
    if (!plugin.dir) continue;
    const pluginDir = resolveUserPath(plugin.dir);
    const skillsDir = path.join(pluginDir, "skills");
    
    if (fs.existsSync(skillsDir)) {
      skillDirs.push(skillsDir);
    }
  }
  
  return skillDirs;
}
```

### Plugin Configuration

```yaml
# .openclaw/config.yaml
extensions:
  plugins:
    - dir: ~/openclaw-plugins/company-tools
      # If ~/openclaw-plugins/company-tools/skills/ exists, it's loaded
```

**Precedence:** Plugin skills are treated as "extra" skills (lowest priority).

---

## Key Files

### Core Skill Logic
- **`src/agents/skills.ts`** (46 lines) - Main exports, install preferences resolver
- **`src/agents/skills/workspace.ts`** (~500 lines) - Discovery, filtering, prompt building
- **`src/agents/skills/types.ts`** (88 lines) - TypeScript type definitions
- **`src/agents/skills/frontmatter.ts`** - YAML parsing, metadata extraction
- **`src/agents/skills/config.ts`** - Eligibility checking, allowlist logic

### Installation
- **`src/agents/skills-install.ts`** (449 lines) - Installation orchestration for all 5 installer types
- **`src/infra/brew.ts`** - Homebrew detection and execution
- **`src/process/exec.ts`** - Command execution with timeout

### CLI
- **`src/cli/skills-cli.ts`** - `openclaw skills` command implementation
- **`src/cli/skills-cli.test.ts`** - CLI tests

### Skill Directories
- **`skills/`** - Bundled skills shipped with OpenClaw
- **`~/.config/openclaw/skills/`** - User-installed managed skills
- **`<workspace>/skills/`** - Workspace-specific skills

### Tests
- **`src/agents/skills.*.test.ts`** - 10+ test files covering:
  - Snapshot building
  - Prompt generation
  - Command spec creation
  - Environment overrides
  - Allowlist filtering
  - Workspace skill precedence

---

## Usage Examples

### Creating a Custom Skill

**File:** `<workspace>/skills/my-tool/SKILL.md`
```markdown
---
name: my-tool
description: Internal company CLI for deployment automation
metadata: {"openclaw":{"emoji":"🚀","requires":{"bins":["my-tool"],"env":["MY_TOOL_API_KEY"]},"install":[{"kind":"download","url":"https://releases.company.com/my-tool/latest/my-tool-macos.tar.gz","extract":true,"stripComponents":1,"bins":["my-tool"]}]}}
---

# my-tool

Internal deployment automation CLI.

## Deploy to staging

```bash
my-tool deploy --env staging --branch main
```

## Rollback

```bash
my-tool rollback --env staging --version v1.2.3
```

**Important:** Always verify staging health before promoting to production.
```

### Installing a Skill

```bash
# List available skills
openclaw skills list

# Install a skill
openclaw skills install nano-pdf

# Install with specific installer
openclaw skills install nano-pdf --installer uv
```

### Programmatic Usage

```typescript
import { buildWorkspaceSkillSnapshot } from "./agents/skills.js";

const snapshot = buildWorkspaceSkillSnapshot("/path/to/workspace", {
  config: openclawConfig,
  skillFilter: ["nano-pdf", "my-custom-skill"],
  eligibility: {
    remote: {
      platforms: ["linux"],
      hasBin: (bin) => remoteBinaries.has(bin),
      note: "Remote: Ubuntu 22.04"
    }
  }
});

console.log(snapshot.prompt); // Formatted skills for agent
console.log(snapshot.skills); // Eligible skill metadata
```

---

## Best Practices

### Writing Skills

1. **Keep it focused:** One skill per tool/domain
2. **Provide examples:** Include concrete usage patterns
3. **Document gotchas:** Note edge cases, version differences
4. **Declare dependencies:** Be explicit about required binaries/env vars
5. **Test on target platforms:** Verify OS-specific installation

### Skill Naming

- Use lowercase with hyphens: `my-tool`, not `MyTool` or `my_tool`
- Be descriptive: `git-workflows` better than `git`
- Avoid version numbers: Skill name should be version-agnostic

### Installation Specs

- **Prefer brew:** Most reliable on macOS/Linux
- **Provide fallbacks:** Offer multiple installation methods
- **Test downloads:** Ensure URLs are stable and version-pinned
- **Validate binaries:** After install, verify expected binaries exist

### Eligibility Requirements

- **Be conservative:** Only require what's truly necessary
- **Use anyBins for alternatives:** E.g., `anyBins: ["gh", "hub"]` for GitHub CLI
- **Document env vars:** If requiring env, explain how to obtain values
- **OS-specific skills:** Always declare `os` to prevent cross-platform issues

---

## Related Documentation

- [Prompt Engineering](./02_prompt_system.md) - How skills integrate into agent prompts
- [Tool System](./03_tool_system.md) - How skills invoke tools
- [Access Control](./05_access_control.md) - Security implications for skill installation
