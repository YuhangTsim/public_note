# Research: XML vs. Markdown Prompting Styles in Agent Frameworks

This document compares different prompting styles used in modern agent frameworks, specifically focusing on XML vs. Markdown tagging, and analyzing the approaches of Roo Code, OMOS (Oh My OpenCode), and OpenCode Default.

---

## 1. XML vs. Markdown in System Prompts

### XML Tagging (`<Role>`, `<Instructions>`)
XML-style tagging uses custom tags to wrap specific sections of a prompt.

*   **Pros**:
    *   **Structural Salience**: Models (especially Claude) are highly sensitive to XML tags as structural markers.
    *   **Clear Boundaries**: Provides unambiguous start and end points for sections, preventing "instruction bleed."
    *   **Easy Referencing**: Instructions can explicitly refer to tags (e.g., "Follow the constraints in `<boundaries>`").
    *   **Machine-Readable**: Easier for pre-processing or post-processing scripts to extract specific sections.
*   **Cons**:
    *   **Verbosity**: Adds extra characters to the prompt.
    *   **Less Human-Readable**: Can look cluttered compared to clean Markdown.
*   **Best For**: Complex, multi-step agent workflows, persona enforcement, and structural output requirements.

### Markdown Headers (`## Role`, `## Instructions`)
Markdown uses standard headers and lists to organize information.

*   **Pros**:
    *   **Human-Readable**: Very easy for developers to read and maintain.
    *   **Standardized**: Follows common documentation practices.
    *   **Hierarchical**: Naturally supports nested sections.
*   **Cons**:
    *   **Ambiguity**: Boundaries between sections can sometimes be blurred if the model treats headers as part of the narrative.
    *   **Reference Difficulty**: Harder to refer to a specific "block" of text compared to a tagged section.
*   **Best For**: Simple agents, linear instructions, and documentation-heavy prompts.

---

## 2. Framework Comparison: Roo Code vs. OMOS

### Roo Code (Markdown-Centric)
Roo Code uses a technical, direct approach with Markdown-style separators.

*   **Structure**:
    ```markdown
    ====
    RULES
    - The project base directory is: ...
    - All file paths must be relative...
    ====
    OBJECTIVE
    1. Analyze the user's task...
    ```
*   **Philosophy**: Focuses on **environment constraints** and **tool-use guidelines**. It treats the agent as a technical tool that must adhere to strict system rules (shell operators, path resolution).
*   **Key Difference**: Uses "Modes" (Architect, Ask, Code) to swap instruction sets, but maintains a consistent Markdown-heavy structure.

### OMOS / Oh My OpenCode (XML-Heavy)
OMOS uses an opinionated, hierarchical approach enforced by XML tags.

*   **Structure**:
    ```xml
    <identity>
    You are Atlas - the Master Orchestrator from OhMyOpenCode.
    </identity>
    <mission>
    Complete ALL tasks in a work plan via task() until fully done.
    </mission>
    <workflow>
    ## Step 1: Analyze Plan...
    </workflow>
    ```
*   **Philosophy**: **"Conductor, not a musician."** OMOS forces the model into a high-level orchestration role. It uses XML to create "mental compartments" for Identity, Mission, and Boundaries.
*   **Key Difference**: Explicitly separates *who* the agent is from *how* it works and *what* it must not do, using XML to ensure the model doesn't lose track of its persona during long tasks.

---

## 3. OpenCode Default vs. OMOS

### OpenCode Default
The baseline OpenCode prompt is a mix of Markdown and clear instructional blocks.

*   **Approach**: Focuses on CLI tone, task management (using `TodoWrite`), and basic software engineering workflows.
*   **Example**:
    ```markdown
    # Tone and style
    - Only use emojis if the user explicitly requests it.
    - Your responses should be short and concise.
    ```

### OMOS Improvements
OMOS builds upon the OpenCode foundation with several key enhancements:

1.  **Explicit Delegation**: While OpenCode allows tool use, OMOS *forces* delegation to subagents for implementation, keeping the lead agent focused on orchestration.
2.  **State Management (Notepad)**: OMOS introduces a "Notepad" protocol (using XML tags like `<notepad_protocol>`) to maintain state across stateless subagent calls.
3.  **Rigorous QA**: OMOS adds a mandatory 6-section prompt structure for every delegation and a strict verification protocol (LSP diagnostics, build checks).
4.  **Structural Salience**: By moving from Markdown headers to XML tags, OMOS makes the "Critical Overrides" and "Boundaries" much harder for the model to ignore.

---

## 4. Concrete Examples

### Roo Code (Rules Section)
```typescript
export function getRulesSection(cwd: string): string {
  return `====
RULES
- The project base directory is: ${cwd}
- All file paths must be relative to this directory.
- You are STRICTLY FORBIDDEN from starting your messages with "Great", "Certainly".
====`
}
```

### OMOS (Atlas Identity)
```typescript
export const ATLAS_SYSTEM_PROMPT = `
<identity>
You are Atlas - the Master Orchestrator from OhMyOpenCode.
You are a conductor, not a musician. A general, not a soldier.
You DELEGATE, COORDINATE, and VERIFY.
</identity>
<critical_overrides>
- NEVER write/edit code yourself - always delegate.
- NEVER trust subagent claims without verification.
</critical_overrides>`
```

---

## 5. Recommendations

| Use Case | Recommended Style | Why? |
|----------|-------------------|------|
| **Simple Utility Agent** | Markdown | Easy to write, low overhead, human-readable. |
| **Complex Orchestrator** | XML | Ensures structural adherence and prevents persona drift. |
| **Tool-Heavy Framework** | Mixed | Use Markdown for general rules, XML for tool-specific constraints. |
| **Claude-Specific Agents** | XML | Claude's training makes it exceptionally good at following XML-tagged instructions. |

**Conclusion**: For advanced agent frameworks like OMOS, **XML tagging** is superior for enforcing complex workflows and hierarchies. For developer-facing tools like Roo Code, **Markdown** provides a better balance of readability and technical instruction.
