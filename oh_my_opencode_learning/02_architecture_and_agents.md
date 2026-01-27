# Architecture & Agents

Oh My OpenCode replaces the standard OpenCode agent hierarchy with a more structured, role-based system centered around **Sisyphus**.

## The Sisyphus Architecture

Sisyphus is not just a prompt; it's an operating mode. The core principle is **Orchestration over Execution**. Sisyphus prefers to plan and delegate rather than doing everything himself.

### Phase 0: Intent Gate
Every interaction starts with an "Intent Gate" check:
1.  **Check Skills**: Does this match a specific skill (e.g., browser automation)? If so, invoke `playwright` immediately.
2.  **Classify Request**: Is it Trivial, Exploratory, or Open-ended?
3.  **Validate**: Are there ambiguities?

### Delegation System
Sisyphus uses `delegate_task` to spawn sub-agents. This is mandatory for complex tasks.

#### The Team

| Agent | Role | Underlying Model (Typical) |
| :--- | :--- | :--- |
| **Sisyphus** | Orchestrator, Planner, Executor of last resort | Claude 3.5 Sonnet / Opus |
| **Oracle** | "High-IQ" Consultant. Read-only. Used for architectural decisions, hard debugging, and "sanity checks". | GPT-4o / GPT-5 |
| **Librarian** | Researcher. Searches external docs, GitHub code, and web. Answers "How do I use X?". | Claude 3.5 Sonnet |
| **Explore** | Contextual Grep. Searches *internal* codebase. fast and cheap. | Grok Beta / Haiku |
| **Frontend UI/UX** | Visual Specialist. Writes CSS, React components, handles design. | Gemini 1.5 Pro |

### Task Workflow

1.  **User Request**: "Add a dark mode toggle."
2.  **Sisyphus Analysis**: "This involves UI work and state management."
3.  **Delegation 1 (Explore)**: "Find where theme state is currently stored." (Background)
4.  **Delegation 2 (Frontend)**: "Create a Toggle component matching our design system." (Delegate)
5.  **Integration**: Sisyphus integrates the component and wires up the state.
6.  **Verification**: Sisyphus runs tests/lints.

## Background Tasks

OMO heavily utilizes `run_in_background=true` for exploration agents (`explore`, `librarian`). This allows Sisyphus to continue thinking or planning while information is being gathered, parallelizing the workflow.

## Context Management

By aggressively delegating, Sisyphus keeps its own context window clean. Sub-agents return concise summaries or specific code blocks, rather than Sisyphus reading entire files just to find one function. This "Context Injection" strategy is key to handling large codebases.
