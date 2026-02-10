# 02: Task Completion & Memory

**Explicit Completion and Event-Based Memory**

---

## 1. Task Completion Logic

OpenHands uses an **Explicit Action** model for completion.

### The Signal: `AgentFinishAction`
*   **Mechanism**: The agent does *not* just stop talking. It must explicitly emit an event of type `AgentFinishAction`.
*   **Code**: `openhands/events/action/agent.py`
*   **Controller Handling**: The `AgentController` listens for this specific event class. When detected, it sets the agent state to `STOPPED` and notifies the frontend.

### Comparison
*   **OpenHands**: "I am formally submitting my finish action." (`AgentFinishAction`)
*   **Roo Code**: "I am attempting completion for your review." (`attempt_completion`)
*   **Sisyphus**: "I have verified my work is done." (Evidence + Loop Exit)

---

## 2. Memory Architecture

OpenHands treats memory as a linear **Event Stream** of Actions and Observations.

### `ConversationMemory`
**File**: `openhands/memory/conversation_memory.py`

This component is responsible for constructing the prompt sent to the LLM. It solves the "Infinite Context" problem via **Condensation**.

### The Condensation Process
When the event history exceeds the token limit:
1.  **Identify**: It identifies older or less relevant events.
2.  **Summarize**: It may use a secondary LLM call to summarize what happened in those steps.
3.  **Replace**: It replaces detailed `CmdOutputObservation` (which might be huge) with a condensed summary (`"Ran ls -la, listed 5 files..."`).

### Long-Term Memory
OpenHands has experimental support for **Vector Stores** (e.g., ChromaDB) to index the codebase and past actions, allowing semantic search over the project history.

---

## 3. Planning

OpenHands generally relies on **Iterative Execution** (CodeAct) rather than upfront rigid planning.

*   **CodeAct Philosophy**: "Write code to explore. Write code to plan. Write code to fix."
*   **State**: The plan is implicit in the conversation history and the files created.
*   **MicroAgents**: Some specialized agents (like `BrowsingAgent`) act as sub-planners for specific domains.
