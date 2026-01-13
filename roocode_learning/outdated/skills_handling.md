# Skills Handling in Roo

This document explains how skills are handled in Roo, including discovery, validation, override resolution, and integration with the system prompt.

## References
- Skills Manager: `src/services/skills/SkillsManager.ts`
- Skills section generation: `src/core/prompts/sections/skills.ts`
- Skills types: `src/shared/skills.ts`

---

## Overview

Skills in Roo follow the **Agent Skills specification** (https://agentskills.io/), which provides a standardized way to extend agent capabilities through filesystem-based skill definitions.

### What Are Skills?

Skills are reusable capabilities defined in markdown files with YAML frontmatter. They allow users to:
- Extend Roo's behavior with custom instructions
- Create mode-specific capabilities
- Share and reuse skills across projects
- Override global skills with project-specific ones

---

## Skill File Structure

### Directory Layout

Skills are organized in specific directories:

```
~/.roo/                           # Global skills (all projects)
├── skills/                       # Generic skills
│   ├── skill-name/
│   │   └── SKILL.md
│   └── another-skill/
│       └── SKILL.md
├── skills-code/                  # Code mode specific
│   └── code-skill/
│       └── SKILL.md
└── skills-architect/             # Architect mode specific
    └── plan-skill/
        └── SKILL.md

project/.roo/                     # Project-local skills
├── skills/                       # Generic skills
│   └── project-skill/
│       └── SKILL.md
└── skills-code/                  # Code mode specific
    └── custom-code-skill/
        └── SKILL.md
```

Reference: `src/services/skills/SkillsManager.ts:244-275`

### SKILL.md Format

Each skill is defined in a `SKILL.md` file with frontmatter:

```markdown
---
name: skill-name
description: Brief description of what this skill does
---

# Skill Instructions

Detailed instructions for the agent to follow when this skill is invoked...
```

**Required frontmatter fields:**
- `name` - Must match parent directory name
- `description` - What the skill does (1-1024 chars)

Reference: `src/services/skills/SkillsManager.ts:96-109`

---

## Skill Discovery

### Discovery Process

The `SkillsManager.discoverSkills()` method (line 37) scans for skills in this order:

1. **Global generic skills:** `~/.roo/skills/`
2. **Global mode-specific skills:** `~/.roo/skills-{mode}/` (for each mode)
3. **Project generic skills:** `project/.roo/skills/`
4. **Project mode-specific skills:** `project/.roo/skills-{mode}/` (for each mode)

```typescript
async discoverSkills(): Promise<void> {
  this.skills.clear()
  const skillsDirs = await this.getSkillsDirectories()

  for (const { dir, source, mode } of skillsDirs) {
    await this.scanSkillsDirectory(dir, source, mode)
  }
}
```

Reference: `src/services/skills/SkillsManager.ts:37-44`

### Symlink Support

Skills support two types of symlinks:

1. **Skills directory symlink:** `.roo/skills` can be a symlink to a shared directory
2. **Individual skill symlinks:** `.roo/skills/my-skill` can be a symlink to a skill directory

The skill name is determined by the symlink name, not the target directory name.

Reference: `src/services/skills/SkillsManager.ts:33-34,52-77`

---

## Skill Validation

### Strict Specification Compliance

Skills must comply with the Agent Skills specification (https://agentskills.io/specification).

### Name Validation

From `src/services/skills/SkillsManager.ts:119-137`:

**Requirements:**
- Length: 1-64 characters
- Format: lowercase letters, numbers, hyphens only
- Must not start or end with hyphen
- Must not contain consecutive hyphens
- Must match parent directory name

**Validation regex:** `/^[a-z0-9]+(?:-[a-z0-9]+)*$/`

**Examples:**
- ✅ `my-skill`
- ✅ `skill123`
- ✅ `code-review-helper`
- ❌ `MySkill` (uppercase)
- ❌ `-my-skill` (leading hyphen)
- ❌ `my--skill` (consecutive hyphens)
- ❌ `my_skill` (underscore)

### Description Validation

From `src/services/skills/SkillsManager.ts:139-148`:

**Requirements:**
- Length: 1-1024 characters (after trimming)
- Must be non-empty string

### Validation Errors

Invalid skills are logged to console and excluded from the skills map:

```typescript
if (!frontmatter.name || typeof frontmatter.name !== "string") {
  console.error(`Skill at ${skillDir} is missing required 'name' field`)
  return
}
if (!nameFormat.test(effectiveSkillName)) {
  console.error(`Skill name "${effectiveSkillName}" is invalid: must be lowercase...`)
  return
}
```

---

## Override Resolution

### Override Priority Rules

When multiple skills have the same name, the following priority applies:

1. **Project > Global** - Project-local skills override global skills
2. **Mode-specific > Generic** - Mode-specific skills override generic skills

From `src/services/skills/SkillsManager.ts:199-210`:

```typescript
private shouldOverrideSkill(existing: SkillMetadata, newSkill: SkillMetadata): boolean {
  // Project always overrides global
  if (newSkill.source === "project" && existing.source === "global") return true
  if (newSkill.source === "global" && existing.source === "project") return false

  // Same source: mode-specific overrides generic
  if (newSkill.mode && !existing.mode) return true
  if (!newSkill.mode && existing.mode) return false

  // Same source and same mode-specificity: keep existing (first wins)
  return false
}
```

### Override Examples

**Scenario 1: Project overrides global**
```
~/.roo/skills/code-review/SKILL.md        <- Global
project/.roo/skills/code-review/SKILL.md  <- PROJECT WINS (used)
```

**Scenario 2: Mode-specific overrides generic**
```
project/.roo/skills/deploy/SKILL.md       <- Generic
project/.roo/skills-code/deploy/SKILL.md  <- MODE-SPECIFIC WINS (in code mode)
```

**Scenario 3: Combined priority**
```
~/.roo/skills/analyze/SKILL.md                <- Global generic
~/.roo/skills-debug/analyze/SKILL.md          <- Global mode-specific
project/.roo/skills/analyze/SKILL.md          <- Project generic
project/.roo/skills-debug/analyze/SKILL.md    <- PROJECT MODE-SPECIFIC WINS (in debug mode)
```

### Mode Filtering

The `getSkillsForMode()` method (line 171) returns only skills relevant to the current mode:

```typescript
getSkillsForMode(currentMode: string): SkillMetadata[] {
  const resolvedSkills = new Map<string, SkillMetadata>()

  for (const skill of this.skills.values()) {
    // Skip mode-specific skills that don't match current mode
    if (skill.mode && skill.mode !== currentMode) continue

    const existingSkill = resolvedSkills.get(skill.name)

    if (!existingSkill) {
      resolvedSkills.set(skill.name, skill)
    } else {
      // Apply override rules
      const shouldOverride = this.shouldOverrideSkill(existingSkill, skill)
      if (shouldOverride) {
        resolvedSkills.set(skill.name, skill)
      }
    }
  }

  return Array.from(resolvedSkills.values())
}
```

Reference: `src/services/skills/SkillsManager.ts:171-193`

---

## Integration with System Prompt

### Skills Section Generation

From `src/core/prompts/sections/skills.ts:22-96`, the `getSkillsSection()` function generates XML-formatted skill information for the system prompt:

```xml
====

AVAILABLE SKILLS

<available_skills>
  <skill>
    <name>skill-name</name>
    <description>Description of what the skill does</description>
    <location>/absolute/path/to/SKILL.md</location>
  </skill>
  <skill>
    <name>another-skill</name>
    <description>Another skill description</description>
    <location>/absolute/path/to/another/SKILL.md</location>
  </skill>
</available_skills>

<mandatory_skill_check>
REQUIRED PRECONDITION

Before producing ANY user-facing response, you MUST perform a skill applicability check.

Step 1: Skill Evaluation
- Evaluate the user's request against ALL available skill <description> entries in <available_skills>.
- Determine whether at least one skill clearly and unambiguously applies.

Step 2: Branching Decision

<if_skill_applies>
- Select EXACTLY ONE skill.
- Prefer the most specific skill when multiple skills match.
- Read the full SKILL.md file at the skill's <location>.
- Load the SKILL.md contents fully into context BEFORE continuing.
- Follow the SKILL.md instructions precisely.
- Do NOT respond outside the skill-defined flow.
</if_skill_applies>

<if_no_skill_applies>
- Proceed with a normal response.
- Do NOT load any SKILL.md files.
</if_no_skill_applies>

CONSTRAINTS:
- Do NOT load every SKILL.md up front.
- Load SKILL.md ONLY after a skill is selected.
- Do NOT skip this check.
- FAILURE to perform this check is an error.
</mandatory_skill_check>
```

Reference: `src/core/prompts/sections/skills.ts:43-82`

### Skill Check Workflow

The mandatory skill check ensures that:

1. **Before every response**, the agent evaluates if any skill applies
2. **If a skill matches**, the agent must:
   - Select the most specific skill
   - Use `read_file` to load the `SKILL.md` at the provided `<location>`
   - Follow the skill's instructions precisely
3. **If no skill matches**, proceed with normal response
4. **Never load skills speculatively** - only load when needed

### Adding to System Prompt

From `src/core/prompts/system.ts:107,154`:

```typescript
const skillsSection = await getSkillsSection(skillsManager, mode as string)

// Later in prompt assembly:
${modesSection}
${skillsSection ? `\n${skillsSection}` : ""}  // <- Skills section added here
${getRulesSection(cwd, settings)}
```

The skills section is inserted between MODES and RULES sections.

---

## File Watching and Hot Reload

### Automatic Skill Reloading

The SkillsManager sets up file watchers to automatically reload skills when they change.

From `src/services/skills/SkillsManager.ts:301-352`:

```typescript
private async setupFileWatchers(): Promise<void> {
  // Watch for changes in skills directories
  const globalSkillsDir = path.join(getGlobalRooDirectory(), "skills")
  const projectSkillsDir = path.join(provider.cwd, ".roo", "skills")

  // Watch global and project skills directories
  this.watchDirectory(globalSkillsDir)
  this.watchDirectory(projectSkillsDir)

  // Watch mode-specific directories for all available modes
  const modesList = await this.getAvailableModes()
  for (const mode of modesList) {
    this.watchDirectory(path.join(getGlobalRooDirectory(), `skills-${mode}`))
    this.watchDirectory(path.join(provider.cwd, ".roo", `skills-${mode}`))
  }
}

private watchDirectory(dirPath: string): void {
  const pattern = new vscode.RelativePattern(dirPath, "**/SKILL.md")
  const watcher = vscode.workspace.createFileSystemWatcher(pattern)

  watcher.onDidChange(async (uri) => { await this.discoverSkills() })
  watcher.onDidCreate(async (uri) => { await this.discoverSkills() })
  watcher.onDidDelete(async (uri) => { await this.discoverSkills() })

  this.disposables.push(watcher)
}
```

**Watched events:**
- File created - New `SKILL.md` added
- File changed - Existing `SKILL.md` modified
- File deleted - `SKILL.md` removed

When any event occurs, `discoverSkills()` is called to refresh the skills map.

---

## Skill Metadata Structure

### SkillMetadata Type

```typescript
export interface SkillMetadata {
  name: string                      // Skill name (matches directory)
  description: string               // Brief description (1-1024 chars)
  path: string                      // Absolute path to SKILL.md
  source: "global" | "project"      // Where the skill is defined
  mode?: string                     // Mode slug if mode-specific, undefined for generic
}
```

Reference: `src/shared/skills.ts`

### SkillContent Type

```typescript
export interface SkillContent extends SkillMetadata {
  instructions: string              // Full markdown body from SKILL.md
}
```

The `getSkillContent()` method (line 219) loads the full content:

```typescript
async getSkillContent(name: string, currentMode?: string): Promise<SkillContent | null> {
  let skill: SkillMetadata | undefined

  if (currentMode) {
    const modeSkills = this.getSkillsForMode(currentMode)
    skill = modeSkills.find((s) => s.name === name)
  } else {
    skill = Array.from(this.skills.values()).find((s) => s.name === name)
  }

  if (!skill) return null

  const fileContent = await fs.readFile(skill.path, "utf-8")
  const { content: body } = matter(fileContent)

  return {
    ...skill,
    instructions: body.trim(),
  }
}
```

Reference: `src/services/skills/SkillsManager.ts:219-240`

---

## Example Usage

### Creating a Skill

**1. Create skill directory and file:**

```bash
mkdir -p ~/.roo/skills/code-review
```

**2. Create `SKILL.md`:**

```markdown
---
name: code-review
description: Perform comprehensive code review with focus on security and best practices
---

# Code Review Skill

When invoked, you should:

1. Analyze the code for:
   - Security vulnerabilities (OWASP Top 10)
   - Performance issues
   - Code quality and maintainability
   - Best practices adherence

2. Provide detailed feedback with:
   - Severity levels (Critical, High, Medium, Low)
   - Specific line numbers
   - Suggested fixes with code examples

3. Generate a summary report at the end.

Format your review using markdown with clear sections and code blocks.
```

**3. Skill is automatically discovered** on next prompt or via file watcher

### Using a Skill

When a user's request matches a skill description, the agent:

1. **Detects the match** during mandatory skill check
2. **Reads the SKILL.md** using `read_file` tool with the `<location>` path
3. **Follows the instructions** from the skill's markdown body
4. **Responds according to the skill** instead of default behavior

---

## Key Takeaways

### Skills System Design

1. **Filesystem-based** - No database, just markdown files
2. **Specification-compliant** - Follows agentskills.io standard
3. **Override hierarchy** - Project > Global, Mode-specific > Generic
4. **Lazy loading** - Skills are listed, but content loaded only when needed
5. **Hot reload** - File watchers automatically update skills
6. **Mode filtering** - Only relevant skills shown per mode

### Benefits

- ✅ **Extensibility** - Users can add custom capabilities without code changes
- ✅ **Portability** - Skills can be shared across projects and teams
- ✅ **Isolation** - Project skills don't affect other projects
- ✅ **Customization** - Mode-specific skills tailor behavior per mode
- ✅ **Validation** - Strict validation ensures quality and consistency

### Implementation Details

- Skills are discovered during `SkillsManager.initialize()`
- Skills section is generated during system prompt assembly
- Agent checks skills before every response (mandatory precondition)
- Skills are resolved with override priority during `getSkillsForMode()`
- File watchers keep skills in sync with filesystem changes
