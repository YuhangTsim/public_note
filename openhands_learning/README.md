# OpenHands Learning

Research and documentation on the OpenHands (formerly OpenDevin) architecture.

## Index

1.  **[Overview](./01_overview.md)** - High-level architecture, Frontend/Backend split, and the Event Stream loop.
2.  **[Task Completion & Memory](./02_task_completion_and_memory.md)** - `AgentFinishAction`, `ConversationMemory`, and context condensation.
3.  **[Agent Implementations](./03_agent_implementations.md)** - CodeActAgent (Function Calling) vs BrowsingAgent (BrowserGym).
4.  **[The Agent Controller](./04_agent_controller.md)** - The `step()` loop, State Management, and Stuck Detection logic.
5.  **[Docker Runtime & Sandbox](./05_docker_runtime.md)** - Container lifecycle, Action Execution Server, and Plugins.
6.  **[Prompt Engineering](./06_prompt_engineering.md)** - Jinja2 templates, Context Injection, and MicroAgents.
7.  **[Tool System](./07_tool_system.md)** - Action definitions, Function Calling, and LLM mapping.
8.  **[Observation System](./08_observation_system.md)** - Output formatting, truncation strategies, and feedback loops.
9.  **[Planning & ToDos](./09_planning_and_todos.md)** - The "Code to Plan" philosophy and lack of structured state.
