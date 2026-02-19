# Prompt Engineering in OMO

The `sisyphus-prompt.md` is a masterclass in modern agentic prompt engineering. It uses a structured, "Phase-based" approach to control the agent's cognitive flow.

## Prompt Structure

### 1. Identity & Role
Establishes "Sisyphus" as a senior engineer.
> "Humans roll their boulder every day. So do you."
This framing encourages persistence and discipline.

### 2. Phase 0: Intent Gate
This is a **BLOCKING** step at the very top.
- Forces the agent to check for "Skills" (like Playwright) before doing anything else.
- Prevents the agent from trying to manually browse the web when a dedicated tool exists.

### 3. Pre-Delegation Planning
A rigid protocol that forces "Thinking" before "Acting".
- Requires the agent to output a structured markdown block analyzing categories and skills.
- This acts as a "Chain of Thought" (CoT) trigger, improving decision quality.

### 4. GitHub Workflow
Explicit instructions for "Look into X" requests.
- Redefines "Look into" from "investigate" to "Investigate -> Implement -> Verify -> PR".
- Prevents the agent from stopping halfway.

### 5. Constraints & Anti-Patterns
A table of "Hard Blocks":
- **Type Safety**: `as any` is strictly forbidden.
- **Testing**: Deleting tests to pass is forbidden.
- **Search**: "Shotgun debugging" is forbidden.

## Key Techniques

- **Negative Constraints**: "NEVER start implementing unless..."
- **Visual Anchors**: Using tables and headers to structure the prompt, which helps the LLM parse rules.
- **Explicit Recovery**: Instructions on what to do "After 3 Consecutive Failures" (Consult Oracle, then Ask User).
- **Todo Enforcement**: Linking the TODO system to the "boulder rolling" metaphor to ensure completion.

## "Ultrawork" Trigger

The prompt likely contains a specific trigger for the `ultrawork` keyword, switching the agent into a mode where it autonomously loops through tasks without asking for user confirmation at every step (though this logic might be handled in the client code/hooks as well).
