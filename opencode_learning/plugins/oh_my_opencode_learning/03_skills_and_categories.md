# Skills & Categories

Oh My OpenCode introduces a rigid **Category + Skill** system for task delegation. This ensures that sub-agents are correctly prompted and equipped for their specific tasks.

## Delegation Protocol

When calling `delegate_task`, Sisyphus **MUST** provide:
1.  **Category**: Defines the domain model (e.g., "visual-engineering").
2.  **Skills**: Specific toolsets injected into the agent (e.g., "playwright").
3.  **Justification**: Explicit reasoning for why skills were included *or omitted*.

### Categories

Categories determine the "flavor" of the sub-agent (likely influencing the system prompt or temperature).

- **`visual-engineering`**: Frontend, UI/UX, CSS, animations.
- **`ultrabrain`**: Deep logic, architecture, complex refactoring.
- **`artistry`**: Creative writing, novel ideas.
- **`quick`**: Trivial fixes, typos.
- **`writing`**: Documentation, technical prose.
- **`unspecified-low` / `unspecified-high`**: Catch-all buckets.

### Skills

Skills are "capability modules" that grant access to specific tools and instructions.

#### 1. `playwright`
- **Domain**: Browser automation, E2E testing, web scraping.
- **Tools**: `browser_open`, `browser_click`, `browser_screenshot`.
- **Usage**: "Verify the login page works," "Scrape this documentation."

#### 2. `frontend-ui-ux`
- **Domain**: Visual design, CSS, React/Vue/Svelte best practices.
- **Usage**: "Make this button pop," "Implement this Figma design."

#### 3. `git-master`
- **Domain**: Advanced git operations.
- **Tools**: `git_commit`, `git_rebase`, `git_blame`.
- **Usage**: "Squash these commits," "Find who introduced this bug."

## The "Mandatory Justification" Rule

To prevent lazy delegation, Sisyphus is forced to explain its choices:

```markdown
I will use delegate_task with:
- **Category**: visual-engineering
- **Why**: Task involves creating a React component.
- **load_skills**: ["frontend-ui-ux"]
- **Skill evaluation**:
  - frontend-ui-ux: INCLUDED - Core requirement for component design.
  - playwright: OMITTED - No browser testing required yet.
  - git-master: OMITTED - No complex git ops needed.
```

This ensures the agent *thinks* before firing off a sub-task.
