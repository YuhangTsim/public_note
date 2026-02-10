# 06: Prompt Engineering

**Jinja2 Templates, Context Injection, and MicroAgents**

OpenHands uses a sophisticated prompt construction system managed by `PromptManager`.

---

## 1. Composition Logic

Prompts are not static strings; they are composed dynamically using **Jinja2 templates** (`.j2`).

**Hierarchical Structure:**
```
[ System Prompt ] (Role, Safety, Core Instructions)
       +
[ Additional Info ] (Runtime Context, Repo Info)
       +
[ MicroAgents ] (Task-Specific Advice)
       +
[ User Prompt ] (The actual task)
```

### Key Files
*   `openhands/utils/prompt.py`: The `PromptManager` class that loads and renders templates.
*   `openhands/agenthub/codeact_agent/prompts/system_prompt.j2`: The base system prompt.

---

## 2. Context Injection (`RuntimeInfo`)

To make the agent aware of its environment, OpenHands injects the **Sandbox State** into the prompt.

**Data Source:** `RuntimeInfo` dataclass.
**Injected Data:**
*   **Working Directory**: `{{ runtime_info.working_dir }}`
*   **User ID**: `{{ runtime_info.user_id }}`
*   **Available Ports**: List of open ports/hosts (`{{ host }}:{{ port }}`).
*   **Secrets**: Environment variables explicitly exposed to the agent.

**Template Location:** `openhands/agenthub/codeact_agent/prompts/additional_info.j2`

---

## 3. MicroAgents

MicroAgents are **Prompt Fragments** that trigger based on keywords in the user's request.

*   **Mechanism**:
    1.  User says "Deploy to Kubernetes".
    2.  System detects keyword "Kubernetes".
    3.  System loads `microagents/kubernetes.md`.
    4.  Content is injected into `microagent_info.j2`.
*   **Benefit**: Keeps the main system prompt small while providing deep knowledge on-demand.
