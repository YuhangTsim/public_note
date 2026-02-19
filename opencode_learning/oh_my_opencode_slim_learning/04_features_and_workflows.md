# Features and Workflows

Oh My OpenCode Slim optimizes the development workflow through specialized tools and a structured approach to task completion.

## Key Features

### 1. Parallel Background Execution
The Orchestrator can delegate multiple tasks to different agents simultaneously. For example:
- `@explorer` searches for relevant files.
- `@librarian` researches the API documentation.
- `@oracle` reviews the architectural plan.

All these can run in parallel, significantly reducing the total time to completion.

### 2. Tmux "Mission Control"
When tmux integration is enabled, every background task spawns a dedicated pane. This allows the user to:
- Monitor agent progress in real-time.
- Debug agent behavior by seeing their raw output.
- Feel the "pulse" of the entire team working together.

### 3. Cartography Skill
The `cartography` skill is a powerful tool for codebase understanding. It can:
- Generate a high-level map of the repository.
- Identify key entry points and dependencies.
- Create a `codemap.md` file that serves as a guide for other agents.

### 4. AST-Grep Integration
Unlike standard regex-based grep, AST-grep understands the structure of the code. This allows agents to:
- Find all implementations of an interface.
- Locate specific function calls regardless of formatting.
- Perform structural refactors with high confidence.

---

## The "Ultrawork" Workflow (Slim Edition)

While the Slim version removes the explicit `ultrawork` keyword found in the original, it implements the **Ultrawork Philosophy** directly into the Orchestrator's core logic.

### The Autonomous Loop
1.  **Decomposition**: The Orchestrator breaks a complex request into a list of TODOs.
2.  **Parallel Research**: It fires off `@explorer` and `@librarian` in the background to gather context.
3.  **Strategic Planning**: It consults `@oracle` for high-stakes decisions.
4.  **Parallel Implementation**: It spawns multiple `@fixer` instances to handle independent changes.
5.  **Verification**: It uses `lsp_diagnostics` and other tools to verify the work before declaring it done.

### Task Completion Criteria
A task is considered complete only when:
- All requirements are met.
- No new errors are introduced (verified via LSP).
- The code follows project conventions (verified via Biome/Linter).
- The Orchestrator has integrated all specialist results.

## Communication Style

OMOS enforces a "No Flattery, No Fluff" communication style:
- **Concise**: Answers directly without preamble.
- **Action-Oriented**: Focuses on what is being done rather than explaining why (unless asked).
- **Honest Pushback**: The Orchestrator will concisely state concerns if a user's approach is problematic.
- **No Praise**: Avoids phrases like "Great question!" or "Excellent idea!".
