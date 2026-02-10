# 04: The Agent Controller

**The Event Loop, State Management, and Stuck Detection**

The `AgentController` (`openhands/controller/agent_controller.py`) is the orchestrator of the OpenHands system. It runs the continuous loop that drives the agent.

---

## 1. The `step()` Loop

The `step()` method is the heartbeat of the system.

**Logic Flow:**
1.  **Check State**: Is the agent `RUNNING`?
2.  **Pending Actions**: Are there actions waiting for execution? If so, wait.
3.  **Stuck Detection**: Call `_is_stuck()` to see if we are looping.
4.  **Get Action**: Ask the `Agent` for the next action.
    *   *Input*: `AgentState` (History, Inputs).
    *   *Output*: `Action` object.
5.  **Condensation**: If context is full, condense history (summarize old events).
6.  **Security**: Check if the action is allowed (e.g., confirmation required).
7.  **Execute**: Push the action to the Event Stream (which triggers the Runtime).

---

## 2. State Management

The `AgentState` tracks the current status of the session.

| State | Description |
|-------|-------------|
| `INIT` | Session starting. |
| `RUNNING` | Agent is thinking or executing. |
| `AWAITING_USER_INPUT` | Agent sent a message, waiting for reply. |
| `PAUSED` | System paused (e.g., stuck detected). |
| `STOPPED` | Task completed or cancelled. |
| `ERROR` | Critical failure. |

**Transitions:**
*   `AgentFinishAction` -> `STOPPED`
*   `AgentRejectAction` -> `REJECTED`
*   `MessageAction` -> `AWAITING_USER_INPUT`

---

## 3. Stuck Detection

The `StuckDetector` (`openhands/controller/stuck.py`) prevents infinite loops and wasted tokens.

It analyzes the event history for **5 Patterns**:
1.  **Repeating Actions**: 4 identical Action/Observation pairs in a row.
2.  **Error Loops**: 3 cycles of Action -> Error.
3.  **Monologue**: 3 identical Agent Messages without user reply.
4.  **Alternating Loops**: A1 -> O1 -> A2 -> O2 -> A1 -> O1... (Ping-pong).
5.  **Context Errors**: 10+ consecutive context window errors.

**Recovery:**
If stuck, the controller sets state to `PAUSED` and offers the user options to restart or skip the loop.
