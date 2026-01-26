# 06: Skills System

**Filesystem-Based Capability Extensions**

Following the [Agent Skills specification](https://agentskills.io/)

---

## What Are Skills?

Skills extend Roo-Code's capabilities **without code changes**. They're:
- **Filesystem-based**: Defined in SKILL.md files
- **Dynamically discovered**: Scanned from skill directories
- **Lazy-loaded**: Listed in prompt, content loaded on-demand
- **Overridable**: Project skills override global skills

---

## Directory Structure

```
~/.roo/skills/                    # Global skills
  └── react-testing/
      └── SKILL.md                # Skill definition

.roo/skills/                      # Project skills (override global)
  └── api-patterns/
      └── SKILL.md

.roo/skills-architect/            # Mode-specific skills
  └── system-design/
      └── SKILL.md
```

---

## Mandatory Precondition Check

**CRITICAL**: Before EVERY response, the model MUST:

1. Check if a skill applies
2. If match → Use `read_file` to load SKILL.md
3. Follow skill instructions

**System Prompt Injection**:
```
# MANDATORY SKILL CHECK
Before responding, you MUST:
1. Check if any skill applies to this request
2. If a skill matches:
   - Use read_file on the skill's SKILL.md
   - Load full skill instructions
   - Follow those instructions

Available Skills:
- react-testing: Testing React components
  Location: ~/.roo/skills/react-testing/SKILL.md
```

---

## Skills Discovery

```typescript
// src/services/skills/SkillsManager.ts
class SkillsManager {
  async discoverSkills() {
    // 1. Scan global: ~/.roo/skills/
    // 2. Scan project: .roo/skills/
    // 3. Scan mode-specific: .roo/skills-{mode}/
    // 4. Validate each skill
    // 5. Resolve overrides (project > global)
  }
}
```

## Linked File Handling

**IMPORTANT**: Linked files mentioned within a `SKILL.md` (e.g., `[Reference](docs/api.md)`) are **NOT** automatically loaded by Roo-Code. 

- The AI must explicitly use `read_file` to access any linked files if they are needed to fulfill the task.
- Skill authors should ensure that critical instructions are contained within the `SKILL.md` itself or clearly instruct the AI to read specific linked files.

---

## Source Code

| File | Purpose |
|------|---------|
| `src/services/skills/SkillsManager.ts` | Skills discovery and management |
| `src/core/prompts/sections/skills.ts` | Integration with system prompt |

---

**Version**: Roo-Code v3.43.0 (January 2026)
**Updated**: January 26, 2026
