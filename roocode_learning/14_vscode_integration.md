# 14: VSCode Integration & Extension Architecture

## Overview

Roo-Code runs as a VSCode extension, deeply integrated with the editor through **ClineProvider**, **webview UI**, and **terminal management**.

**Key Files**:
- `src/core/webview/ClineProvider.ts` - Main extension provider (3000+ lines)
- `src/extension.ts` - Extension entry point
- `webview-ui/` - React-based UI

## Extension Architecture

### Entry Point

```typescript
// src/extension.ts
export function activate(context: vscode.ExtensionContext) {
  // 1. Create provider instance
  const provider = new ClineProvider(context)
  
  // 2. Register webview
  context.subscriptions.push(
    vscode.window.registerWebviewViewProvider(
      ClineProvider.viewType,
      provider,
      { webviewOptions: { retainContextWhenHidden: true } }
    )
  )
  
  // 3. Register commands
  context.subscriptions.push(
    vscode.commands.registerCommand('roo-cline.newTask', () => {
      provider.createNewTask()
    }),
    vscode.commands.registerCommand('roo-cline.openSettings', () => {
      provider.openSettings()
    })
  )
  
  // 4. Initialize services
  await provider.initialize()
}
```

## ClineProvider - The Orchestrator

Central class managing extension lifecycle:

```typescript
// src/core/webview/ClineProvider.ts
export class ClineProvider implements vscode.WebviewViewProvider {
  private view?: vscode.WebviewView
  private currentTask?: Task
  private terminalManager: TerminalManager
  
  async resolveWebviewView(webviewView: vscode.WebviewView) {
    this.view = webviewView
    
    // 1. Configure webview
    webviewView.webview.options = {
      enableScripts: true,
      localResourceRoots: [this.extensionUri]
    }
    
    // 2. Load React UI
    webviewView.webview.html = this.getWebviewHtml()
    
    // 3. Set up message passing
    webviewView.webview.onDidReceiveMessage(async (message) => {
      await this.handleWebviewMessage(message)
    })
    
    // 4. Initialize state
    await this.loadState()
  }
  
  private async handleWebviewMessage(message: any) {
    switch (message.type) {
      case 'newTask':
        await this.createNewTask(message.text)
        break
      case 'sendMessage':
        await this.currentTask?.addUserMessage(message.text)
        break
      case 'approveToolUse':
        await this.currentTask?.approveToolUse(message.toolCallId)
        break
      // ... 50+ message types
    }
  }
}
```

## Webview UI (React)

Frontend built with React + Vite:

```typescript
// webview-ui/src/App.tsx
export default function App() {
  const [task, setTask] = useState<Task | null>(null)
  const [messages, setMessages] = useState<Message[]>([])
  
  // Communicate with extension
  const vscode = acquireVsCodeApi()
  
  useEffect(() => {
    // Listen for updates from extension
    window.addEventListener('message', (event) => {
      const message = event.data
      
      switch (message.type) {
        case 'taskUpdate':
          setTask(message.task)
          break
        case 'newMessage':
          setMessages(prev => [...prev, message.message])
          break
        case 'toolApprovalRequired':
          showToolApprovalUI(message.toolCall)
          break
      }
    })
  }, [])
  
  const sendMessage = (text: string) => {
    vscode.postMessage({
      type: 'sendMessage',
      text: text
    })
  }
  
  return (
    <div className="chat-container">
      <MessageList messages={messages} />
      <InputBox onSend={sendMessage} />
    </div>
  )
}
```

## Terminal Integration

Roo can execute commands in VSCode terminals:

```typescript
// src/core/terminal/TerminalManager.ts
export class TerminalManager {
  private terminals: Map<string, vscode.Terminal> = new Map()
  
  async executeCommand(
    command: string,
    options?: { cwd?: string; env?: Record<string, string> }
  ): Promise<CommandResult> {
    // 1. Get or create terminal
    const terminal = this.getOrCreateTerminal(options?.cwd)
    
    // 2. Show terminal
    terminal.show()
    
    // 3. Execute command
    terminal.sendText(command)
    
    // 4. Capture output (using VS Code tasks API)
    const execution = await vscode.tasks.executeTask(new vscode.Task(
      { type: 'shell' },
      vscode.TaskScope.Workspace,
      'Roo Command',
      'roo-cline',
      new vscode.ShellExecution(command, { cwd: options?.cwd })
    ))
    
    // 5. Wait for completion
    return new Promise((resolve) => {
      const disposable = vscode.tasks.onDidEndTaskProcess((e) => {
        if (e.execution === execution) {
          disposable.dispose()
          resolve({
            exitCode: e.exitCode,
            output: this.capturedOutput
          })
        }
      })
    })
  }
  
  private getOrCreateTerminal(cwd?: string): vscode.Terminal {
    const key = cwd || 'default'
    
    if (!this.terminals.has(key)) {
      this.terminals.set(key, vscode.window.createTerminal({
        name: 'Roo Code',
        cwd: cwd,
        iconPath: new vscode.ThemeIcon('robot')
      }))
    }
    
    return this.terminals.get(key)!
  }
}
```

## File System Operations

VSCode API for file operations:

```typescript
// src/core/tools/handlers/WriteFileTool.ts
async execute(input: { path: string; content: string }) {
  const uri = vscode.Uri.file(input.path)
  
  // 1. Check if file exists
  const exists = await this.fileExists(uri)
  
  // 2. Request permission if overwriting
  if (exists) {
    const approved = await this.requestOverwritePermission(input.path)
    if (!approved) {
      throw new Error('User rejected file overwrite')
    }
  }
  
  // 3. Write file using VSCode API
  const encoder = new TextEncoder()
  await vscode.workspace.fs.writeFile(uri, encoder.encode(input.content))
  
  // 4. Open in editor (optional)
  if (input.openAfterWrite) {
    const doc = await vscode.workspace.openTextDocument(uri)
    await vscode.window.showTextDocument(doc)
  }
  
  return { success: true, path: input.path }
}
```

## Editor Integration

Interact with open editors:

```typescript
// src/core/integrations/EditorManager.ts
export class EditorManager {
  // Get current file
  getCurrentFile(): string | undefined {
    const editor = vscode.window.activeTextEditor
    return editor?.document.uri.fsPath
  }
  
  // Get selection
  getSelection(): string | undefined {
    const editor = vscode.window.activeTextEditor
    if (!editor) return undefined
    
    const selection = editor.selection
    return editor.document.getText(selection)
  }
  
  // Insert text at cursor
  async insertAtCursor(text: string) {
    const editor = vscode.window.activeTextEditor
    if (!editor) return
    
    await editor.edit(editBuilder => {
      editBuilder.insert(editor.selection.active, text)
    })
  }
  
  // Apply diff
  async applyDiff(filePath: string, edits: Edit[]) {
    const uri = vscode.Uri.file(filePath)
    const doc = await vscode.workspace.openTextDocument(uri)
    const editor = await vscode.window.showTextDocument(doc)
    
    await editor.edit(editBuilder => {
      for (const edit of edits) {
        const range = new vscode.Range(
          edit.startLine, edit.startChar,
          edit.endLine, edit.endChar
        )
        editBuilder.replace(range, edit.newText)
      }
    })
  }
}
```

## State Persistence

Save and restore extension state:

```typescript
// src/core/webview/ClineProvider.ts
export class ClineProvider {
  private context: vscode.ExtensionContext
  
  async saveState() {
    await this.context.globalState.update('currentTask', {
      id: this.currentTask?.id,
      messages: this.currentTask?.messages,
      state: this.currentTask?.state
    })
  }
  
  async loadState() {
    const saved = this.context.globalState.get('currentTask')
    if (saved) {
      this.currentTask = await Task.restore(saved)
    }
  }
  
  // Workspace-specific state
  async saveWorkspaceState(key: string, value: any) {
    await this.context.workspaceState.update(key, value)
  }
}
```

## Commands & Keybindings

Registered VSCode commands:

```json
// package.json
{
  "contributes": {
    "commands": [
      {
        "command": "roo-cline.newTask",
        "title": "Roo: New Task",
        "icon": "$(add)"
      },
      {
        "command": "roo-cline.resumeTask",
        "title": "Roo: Resume Task"
      }
    ],
    "keybindings": [
      {
        "command": "roo-cline.newTask",
        "key": "ctrl+shift+r",
        "mac": "cmd+shift+r"
      }
    ]
  }
}
```

## Source Code References

| File | Purpose |
|------|---------|
| `src/extension.ts` | Extension activation |
| `src/core/webview/ClineProvider.ts` | Main provider class (3000+ lines) |
| `src/core/terminal/TerminalManager.ts` | Terminal execution |
| `webview-ui/src/App.tsx` | React UI entry |
| `src/core/integrations/EditorManager.ts` | Editor operations |

## Key Insights

- **ClineProvider** is the central orchestrator (3000+ lines)
- **React webview** for UI, communicates via postMessage
- **Terminal integration** executes commands in VSCode terminals
- **File operations** use VSCode FS API (permissions, watchers)
- **State persistence** across sessions using ExtensionContext

**Version**: Roo-Code v3.39+ (January 2026)
