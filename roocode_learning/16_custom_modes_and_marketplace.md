# 16: Custom Modes & Mode Marketplace

## Overview

Beyond the 5 built-in modes, users can create **custom modes** with specific tool sets, prompts, and behaviors. Custom modes can be shared via the **mode marketplace**.

**Key Files**:
- `src/services/modes/CustomModesManager.ts` - Custom mode management
- `src/services/marketplace/MarketplaceClient.ts` - Mode marketplace integration
- `packages/types/src/mode.ts` - Mode type definitions

## Custom Mode Structure

A mode is defined by JSON configuration:

```typescript
// ~/.roo/modes/my-mode.json
{
  "id": "security-auditor",
  "name": "Security Auditor",
  "description": "Specialized mode for security analysis and vulnerability detection",
  "version": "1.0.0",
  "author": "username",
  
  // Tool configuration
  "tools": [
    "read_file",
    "list_files",
    "search_files",
    "execute_command"
  ],
  
  // System prompt additions
  "systemPrompt": "You are a security expert. Focus on finding vulnerabilities, insecure patterns, and potential exploits. Always consider OWASP Top 10.",
  
  // Additional constraints
  "constraints": [
    "Never execute code that could harm the system",
    "Always verify dependencies for known vulnerabilities",
    "Report findings in CVE format when applicable"
  ],
  
  // Metadata
  "tags": ["security", "audit", "vulnerability"],
  "icon": "shield"
}
```

## CustomModesManager

Manages custom mode lifecycle:

```typescript
// src/services/modes/CustomModesManager.ts
export class CustomModesManager {
  private customModes: Map<string, Mode> = new Map()
  
  async loadCustomModes() {
    // Load from user config directory
    const modesDir = path.join(os.homedir(), '.roo', 'modes')
    const files = await fs.readdir(modesDir)
    
    for (const file of files) {
      if (file.endsWith('.json')) {
        const mode = await this.loadModeFromFile(path.join(modesDir, file))
        this.customModes.set(mode.id, mode)
      }
    }
    
    console.log(`Loaded ${this.customModes.size} custom modes`)
  }
  
  async loadModeFromFile(filePath: string): Promise<Mode> {
    const content = await fs.readFile(filePath, 'utf-8')
    const config = JSON.parse(content)
    
    // Validate mode configuration
    this.validateMode(config)
    
    // Convert to internal Mode type
    return {
      id: config.id,
      name: config.name,
      description: config.description,
      tools: this.resolveTools(config.tools),
      systemPrompt: config.systemPrompt,
      constraints: config.constraints || [],
      metadata: {
        version: config.version,
        author: config.author,
        tags: config.tags
      }
    }
  }
  
  validateMode(config: any) {
    if (!config.id || !config.name) {
      throw new Error('Mode must have id and name')
    }
    
    if (!Array.isArray(config.tools)) {
      throw new Error('Mode must specify tools array')
    }
    
    // Validate tool names
    for (const toolName of config.tools) {
      if (!this.isValidTool(toolName)) {
        throw new Error(`Unknown tool: ${toolName}`)
      }
    }
  }
  
  async createMode(config: ModeConfig): Promise<Mode> {
    // Validate configuration
    this.validateMode(config)
    
    // Save to disk
    const filePath = path.join(os.homedir(), '.roo', 'modes', `${config.id}.json`)
    await fs.writeFile(filePath, JSON.stringify(config, null, 2))
    
    // Load into memory
    const mode = await this.loadModeFromFile(filePath)
    this.customModes.set(mode.id, mode)
    
    return mode
  }
  
  getAllModes(): Mode[] {
    return [
      ...BUILTIN_MODES,
      ...Array.from(this.customModes.values())
    ]
  }
}
```

## Mode Marketplace

Share and discover custom modes:

```typescript
// src/services/marketplace/MarketplaceClient.ts
export class MarketplaceClient {
  private apiUrl = 'https://marketplace.roo-code.com/api'
  
  async searchModes(query: string): Promise<MarketplaceMode[]> {
    const response = await fetch(`${this.apiUrl}/modes/search?q=${query}`)
    return await response.json()
  }
  
  async installMode(modeId: string): Promise<void> {
    // 1. Fetch mode from marketplace
    const mode = await this.fetchMode(modeId)
    
    // 2. Validate mode
    if (!this.isSafe(mode)) {
      throw new Error('Mode failed security validation')
    }
    
    // 3. Install locally
    const modesManager = new CustomModesManager()
    await modesManager.createMode(mode)
    
    console.log(`Installed mode: ${mode.name}`)
  }
  
  async publishMode(mode: Mode): Promise<void> {
    // 1. Validate mode
    this.validateForPublishing(mode)
    
    // 2. Upload to marketplace
    const response = await fetch(`${this.apiUrl}/modes`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(mode)
    })
    
    if (!response.ok) {
      throw new Error('Failed to publish mode')
    }
    
    console.log(`Published mode: ${mode.id}`)
  }
  
  private isSafe(mode: Mode): boolean {
    // Check for suspicious tool combinations
    const dangerousTools = ['execute_command', 'write_file']
    const hasDangerousTools = mode.tools.some(t => dangerousTools.includes(t))
    
    // Check for malicious prompts
    const suspiciousPatterns = [
      /system\s*\(/i,
      /eval\s*\(/i,
      /exec\s*\(/i
    ]
    
    const hassSuspiciousPrompt = suspiciousPatterns.some(pattern => 
      pattern.test(mode.systemPrompt)
    )
    
    return !hassSuspiciousPrompt && (!hasDangerousTools || mode.author.verified)
  }
}
```

## Example Custom Modes

### 1. Documentation Writer
```json
{
  "id": "doc-writer",
  "name": "Documentation Writer",
  "tools": ["read_file", "write_file", "list_files"],
  "systemPrompt": "You are a technical writer. Create clear, comprehensive documentation. Use markdown format. Include code examples and diagrams.",
  "constraints": [
    "Only modify .md files in docs/ directory",
    "Follow the project's documentation style guide"
  ]
}
```

### 2. Test Generator
```json
{
  "id": "test-gen",
  "name": "Test Generator",
  "tools": ["read_file", "write_file", "execute_command"],
  "systemPrompt": "You generate comprehensive test suites. Focus on edge cases, error handling, and code coverage. Use the project's testing framework.",
  "constraints": [
    "Only create files in test/ or __tests__/ directories",
    "Run tests after creation to verify they work"
  ]
}
```

### 3. Refactoring Assistant
```json
{
  "id": "refactor",
  "name": "Refactoring Assistant",
  "tools": ["read_file", "write_file", "search_files", "replace_in_files"],
  "systemPrompt": "You refactor code for better maintainability. Focus on: reducing complexity, improving naming, extracting functions, removing duplication.",
  "constraints": [
    "Preserve existing functionality - no behavior changes",
    "Run tests after refactoring to ensure nothing broke",
    "Make incremental changes, not wholesale rewrites"
  ]
}
```

## Mode Switching

Users can switch modes during a task:

```typescript
// src/core/task/Task.ts
async switchMode(newModeId: string) {
  const modesManager = new CustomModesManager()
  const allModes = modesManager.getAllModes()
  
  const newMode = allModes.find(m => m.id === newModeId)
  if (!newMode) {
    throw new Error(`Mode not found: ${newModeId}`)
  }
  
  // Update task mode
  this.currentMode = newMode
  
  // Rebuild system prompt with new mode
  this.systemPrompt = this.buildSystemPrompt(newMode)
  
  // Update available tools
  this.availableTools = newMode.tools
  
  // Notify UI
  await this.notifyModeChange(newMode)
}
```

## VSCode Integration

Custom modes appear in VSCode UI:

```typescript
// src/core/webview/ClineProvider.ts
async getModeOptions(): Promise<QuickPickItem[]> {
  const modesManager = new CustomModesManager()
  await modesManager.loadCustomModes()
  
  const allModes = modesManager.getAllModes()
  
  return allModes.map(mode => ({
    label: mode.name,
    description: mode.description,
    detail: `${mode.tools.length} tools • ${mode.metadata?.author || 'Built-in'}`,
    iconPath: mode.metadata?.icon
  }))
}

async promptModeSelection() {
  const options = await this.getModeOptions()
  
  const selected = await vscode.window.showQuickPick(options, {
    placeHolder: 'Select a mode'
  })
  
  if (selected) {
    await this.currentTask?.switchMode(selected.id)
  }
}
```

## Source Code References

| File | Purpose |
|------|---------|
| `src/services/modes/CustomModesManager.ts` | Custom mode management |
| `src/services/marketplace/MarketplaceClient.ts` | Marketplace integration |
| `packages/types/src/mode.ts` | Mode type definitions |
| `src/core/task/Task.ts` | Mode switching logic |

## Key Insights

- **Custom modes** extend capabilities without code changes
- **JSON configuration** makes modes easy to create and share
- **Marketplace** enables community-contributed modes
- **Security validation** prevents malicious modes
- **Mode switching** allows changing behavior mid-task

**Version**: Roo-Code v3.39+ (January 2026)
