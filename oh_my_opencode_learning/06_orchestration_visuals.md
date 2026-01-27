# Orchestration Visuals

Visualizing the decision flow of the Sisyphus agent in Oh My OpenCode.

## 1. The Core Loop (Phase 0 -> Phase 3)

```mermaid
graph TD
    UserInput([User Request]) --> Phase0{Phase 0: Intent Gate}
    
    %% Phase 0 Logic
    Phase0 -- Skill Trigger? --> InvokeSkill[Invoke Skill Tool]
    InvokeSkill --> Done([Task Complete])
    
    Phase0 -- "Explore / Find"? --> Explore[Fire 'Explore' Background Agent]
    Explore --> Phase1
    
    Phase0 -- Complex / Unknown? --> Phase1{Phase 1: Codebase Assessment}
    
    %% Phase 1 Logic
    Phase1 -- Clean Repo --> DisciplinedMode[Mode: Disciplined]
    Phase1 -- Messy Repo --> ChaoticMode[Mode: Propose First]
    
    DisciplinedMode --> Phase2A
    ChaoticMode --> Phase2A
    
    %% Phase 2A Logic
    Phase2A{Phase 2A: Research}
    Phase2A -- Need Ext Info? --> Librarian[Delegate to Librarian]
    Phase2A -- Need Arch Advice? --> Oracle[Delegate to Oracle]
    Phase2A -- Ready --> Phase2B
    
    %% Phase 2B Logic
    Phase2B[Phase 2B: Implementation]
    Phase2B --> CreateTodos[Create TODOs]
    CreateTodos --> Loop{Execution Loop}
    
    Loop -- Coding --> Verify[Verify w/ LSP]
    Verify -- Errors --> Fix[Fix Errors]
    Fix --> Verify
    Verify -- Pass --> NextTodo
    
    NextTodo -- More Items --> Loop
    NextTodo -- All Done --> Phase3
    
    %% Phase 3 Logic
    Phase3[Phase 3: Completion]
    Phase3 --> Cleanup[Cancel Background Tasks]
    Cleanup --> FinalAnswer([Final Response])
```

## 2. Delegation Logic (Sisyphus vs Sub-Agents)

```mermaid
sequenceDiagram
    participant User
    participant Sisyphus as Sisyphus (Main)
    participant SubAgent as Sub-Agent (Worker)
    
    User->>Sisyphus: "Add a login page"
    
    Note over Sisyphus: Phase 0: Check Skills (None)<br/>Phase 1: Assess (React/TS)
    
    Sisyphus->>Sisyphus: Create TODO list
    Sisyphus->>Sisyphus: "1. Research Auth pattern"<br/>"2. Create Component"<br/>"3. Test"
    
    %% Background Delegation
    Sisyphus->>SubAgent: delegate_task(category="quick", prompt="Find auth pattern")
    Note right of SubAgent: Runs in Background
    
    Sisyphus->>Sisyphus: Continues thinking / preparing...
    
    SubAgent-->>Sisyphus: "Auth pattern is XYZ in auth.ts"
    
    %% Dedicated Delegation
    Sisyphus->>Sisyphus: MANDATORY JUSTIFICATION:<br/>Category: visual-engineering<br/>Skill: frontend-ui-ux
    
    Sisyphus->>SubAgent: delegate_task(category="visual", skills=["frontend"], prompt="Build Login.tsx")
    activate SubAgent
    SubAgent->>SubAgent: Writes Code (CSS/JSX)
    SubAgent-->>Sisyphus: "Done. Here is the file."
    deactivate SubAgent
    
    Sisyphus->>Sisyphus: Verify & Integration Test
    Sisyphus->>User: "Login page added and verified."
```

## 3. The Persistence Loop (Todo Enforcer)

```mermaid
stateDiagram-v2
    [*] --> ReceivingRequest
    
    state "Sisyphus Agent" as Agent {
        ReceivingRequest --> CreatingTodos
        CreatingTodos --> Working: Mark In_Progress
        Working --> ToolCall
        ToolCall --> Working
        Working --> MarkComplete: Task Done
        MarkComplete --> NextTask: Check List
        NextTask --> Working
        NextTask --> Finished: List Empty
    }
    
    state "System Hook (Enforcer)" as Hook {
        Finished --> CheckPending: Hook: PostToolUse
        CheckPending --> ForcingLoop: Pending Items Exist!
        ForcingLoop --> Working: "You have pending TODOs. Continue."
    }
```
