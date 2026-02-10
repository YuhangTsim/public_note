# OpenHands Learning

Research and documentation on the OpenHands (formerly OpenDevin) architecture.

## Index

1.  **[Overview](./01_overview.md)** - High-level architecture, Frontend/Backend split, and the Event Stream loop.
2.  **[Task Completion & Memory](./02_task_completion_and_memory.md)** - `AgentFinishAction`, `ConversationMemory`, and context condensation.
3.  **[Agent Implementations](./03_agent_implementations.md)** - CodeActAgent (Function Calling) vs BrowsingAgent (BrowserGym).
4.  **[The Agent Controller](./04_agent_controller.md)** - The `step()` loop, State Management, and Stuck Detection logic.
5.  **[Docker Runtime & Sandbox](./05_docker_runtime.md)** - Container lifecycle, Action Execution Server, and Plugins.
