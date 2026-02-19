# 06: Task Completion Strategies

**Explicit, Implicit, and Evidence-Based Completion**

Oh-My-OpenCode (OMO) employs a sophisticated, multi-layered approach to task completion that differs significantly from standard "chat" interfaces. It prioritizes **verifiable results** over simple conversation.

## 1. The Three Models of Completion

To understand OMO's approach, it helps to contrast it with other systems:

| System | Completion Model | Signal | Philosophy |
| :--- | :--- | :--- | :--- |
| **Roo Code** | **Explicit Tooling** | `attempt_completion()` tool | "I think I'm done. Human, do you agree?" |
| **OpenClaw** | **Implicit / Text** | Text Output (or `NO_REPLY`) | "Here is the answer. Waiting for next turn." |
| **Sisyphus (OMO)** | **Evidence-Based** | **Ralph Loop Verification** | "I have proved I am done. Exiting loop." |

---

## 2. Sisyphus: Evidence-Based Completion

Sisyphus (the OMO orchestrator) does not trust itself to just "say" it is done. It uses the **Ralph Loop** (`src/hooks/ralph-loop/`) to enforce rigor.

### A. The Completion Criteria
A task is NOT complete until **all** of the following are true:
1.  **Todos are Empty:** All items in the `todowrite` list are marked `completed`.
2.  **Diagnostics are Clean:** `lsp_diagnostics` returns no errors on changed files.
3.  **Tests Pass:** If tests exist, they must pass (or at least not regress).
4.  **Promise Tag:** The transcript contains a specific `<promise>DONE</promise>` tag (or similar) indicating logical conclusion.

### B. The Ralph Loop
If Sisyphus tries to stop early (e.g., by just outputting text "I'm done"), the **Ralph Loop Hook** intervenes:
*   **Intervention:** It injects a system prompt: *"Wait, you still have 2 pending todos and 1 lint error. You are NOT done. Fix them."*
*   **Forced Loop:** It forces Sisyphus back into the "Ultrawork" cycle.

### C. "Ultrawork" Mode
When the user activates "Ultrawork" (`/ulw`), the completion criteria become even stricter:
*   **No Human Handoff:** Sisyphus is forbidden from asking "What do you think?" until verifiable completion.
*   **Self-Correction:** If a fix fails, Sisyphus must self-correct, loop, and try again (up to a limit).

---

## 3. Handling Trivial Chat ("Hello")

Even in a rigorous system, you need to handle "Hello".

*   **Scenario:** User says "Hello".
*   **Analysis:** Sisyphus analyzes the intent.
    *   *Is this a task?* No.
    *   *Is this a complex query?* No.
*   **Action:** Sisyphus bypasses the Ralph Loop strictness for trivial chit-chat.
*   **Output:** It simply streams text: "Hello! Ready to code?"
*   **Result:** The turn ends naturally. The "Task" is implicitly considered complete because there were no Todos created.

**Key Distinction:**
*   **Task Mode:** Todos Created → Ralph Loop Active → Must mark Todos complete.
*   **Chat Mode:** No Todos → Ralph Loop Dormant → Text output ends turn.

---

## 4. Comparison with OpenClaw & Roo Code

### OpenClaw's "One-Shot" Nature
OpenClaw is designed as a **Gateway**. It receives a webhook, processes it, and responds.
*   **Completion:** When the LLM outputs text, the turn ends.
*   **Silence:** If it does work but has nothing to say (e.g., checking a calendar and finding nothing), it outputs `NO_REPLY` (`¿¿silent`) to close the turn without sending a message.

### Roo Code's "Human-in-the-Loop"
Roo Code is designed as a **Co-Pilot**.
*   **Completion:** It *never* assumes it is done. It *proposes* completion via `attempt_completion`.
*   **Review:** The user sees a "Task Completion" screen with a diff and cost summary.
*   **Decision:** The user must click "Approve" to actually close the task.

### Sisyphus's "Agentic" Approach
Sisyphus is designed as an **Autonomous Worker**.
*   **Goal:** Minimizing human management overhead.
*   **Logic:** "If I have verified my work (Tests passed, Linter clean), I don't need to ask permission to finish. I will just finish and report."

---

## Summary

*   **Roo Code:** "Did I do this right?" (Ask for permission)
*   **OpenClaw:** "Here is the info." (One-shot response)
*   **Sisyphus:** "I verified it works. I'm done." (Verify and exit)
