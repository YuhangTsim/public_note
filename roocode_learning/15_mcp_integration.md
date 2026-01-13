# 15: MCP Integration & McpHub

## Overview

Roo-Code integrates with **Model Context Protocol (MCP)** servers to extend capabilities. MCP servers provide tools, resources, and prompts that Roo can use.

**Key Files**:
- `src/services/mcp/McpHub.ts` - MCP server manager
- `src/services/mcp/McpServer.ts` - Individual server connection
- `packages/mcp/` - MCP protocol implementation

## What is MCP?

MCP (Model Context Protocol) is a standard protocol for AI assistants to connect to external tools and data sources:

- **Tools** - Functions the AI can call (e.g., database queries, API calls)
- **Resources** - Data the AI can read (e.g., files, documentation)
- **Prompts** - Pre-configured prompts with templates

## McpHub - Server Manager

Manages multiple MCP server connections:

```typescript
// src/services/mcp/McpHub.ts
export class McpHub {
  private servers: Map<string, McpServer> = new Map()
  
  async initialize() {
    // Load MCP servers from config
    const config = await this.loadConfig()
    
    for (const serverConfig of config.mcpServers) {
      await this.connectServer(serverConfig)
    }
  }
  
  async connectServer(config: McpServerConfig) {
    const server = new McpServer({
      name: config.name,
      command: config.command,
      args: config.args,
      env: config.env
    })
    
    await server.connect()
    this.servers.set(config.name, server)
    
    // Fetch available capabilities
    const capabilities = await server.getCapabilities()
    console.log(`Connected to ${config.name}: ${capabilities.tools.length} tools`)
  }
  
  // Get all available tools from all servers
  async getAllTools(): Promise<Tool[]> {
    const allTools: Tool[] = []
    
    for (const [serverName, server] of this.servers) {
      const tools = await server.listTools()
      
      // Prefix tool names with server name
      allTools.push(...tools.map(tool => ({
        ...tool,
        name: `${serverName}/${tool.name}`
      })))
    }
    
    return allTools
  }
  
  // Execute tool on appropriate server
  async callTool(toolName: string, input: any): Promise<any> {
    const [serverName, actualToolName] = toolName.split('/')
    const server = this.servers.get(serverName)
    
    if (!server) {
      throw new Error(`MCP server not found: ${serverName}`)
    }
    
    return await server.callTool(actualToolName, input)
  }
}
```

## McpServer - Individual Connection

Handles connection to a single MCP server:

```typescript
// src/services/mcp/McpServer.ts
export class McpServer {
  private process: ChildProcess
  private rpcClient: JsonRpcClient
  
  async connect() {
    // 1. Spawn server process
    this.process = spawn(this.config.command, this.config.args, {
      env: { ...process.env, ...this.config.env },
      stdio: ['pipe', 'pipe', 'pipe']
    })
    
    // 2. Set up JSON-RPC communication
    this.rpcClient = new JsonRpcClient({
      input: this.process.stdout,
      output: this.process.stdin
    })
    
    // 3. Initialize connection
    await this.rpcClient.request('initialize', {
      protocolVersion: '2024-11-05',
      capabilities: {
        tools: {},
        resources: {},
        prompts: {}
      }
    })
  }
  
  async listTools(): Promise<Tool[]> {
    const response = await this.rpcClient.request('tools/list', {})
    return response.tools
  }
  
  async callTool(name: string, input: any): Promise<any> {
    return await this.rpcClient.request('tools/call', {
      name: name,
      arguments: input
    })
  }
  
  async getResource(uri: string): Promise<string> {
    const response = await this.rpcClient.request('resources/read', {
      uri: uri
    })
    return response.contents[0].text
  }
}
```

## MCP Server Configuration

Users configure MCP servers in settings:

```json
// .vscode/settings.json or ~/.roo/mcp-config.json
{
  "roo-cline.mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/Users/username/projects"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${env:GITHUB_TOKEN}"
      }
    },
    "postgres": {
      "command": "docker",
      "args": ["run", "-i", "mcp-postgres"],
      "env": {
        "DATABASE_URL": "postgresql://localhost/mydb"
      }
    }
  }
}
```

## Tool Integration

MCP tools become available to the assistant:

```typescript
// src/core/task/Task.ts
async getAvailableTools(): Promise<Tool[]> {
  // 1. Get built-in tools
  const builtinTools = this.mode.tools
  
  // 2. Get MCP tools
  const mcpTools = await this.mcpHub.getAllTools()
  
  // 3. Combine and deduplicate
  return [...builtinTools, ...mcpTools]
}

async executeToolCall(toolCall: ToolCall): Promise<any> {
  // Check if it's an MCP tool
  if (toolCall.name.includes('/')) {
    // MCP tool (format: serverName/toolName)
    return await this.mcpHub.callTool(toolCall.name, toolCall.input)
  } else {
    // Built-in tool
    return await this.executeBuiltinTool(toolCall)
  }
}
```

## Common MCP Servers

### 1. Filesystem Server
```typescript
// Provides file operations
{
  "tools": [
    {
      "name": "read_file",
      "description": "Read a file from the filesystem",
      "input_schema": {
        "type": "object",
        "properties": {
          "path": { "type": "string" }
        }
      }
    },
    {
      "name": "write_file",
      "description": "Write content to a file"
    }
  ]
}
```

### 2. GitHub Server
```typescript
// Provides GitHub API access
{
  "tools": [
    {
      "name": "create_issue",
      "description": "Create a GitHub issue"
    },
    {
      "name": "create_pull_request",
      "description": "Create a pull request"
    }
  ]
}
```

### 3. Database Servers
```typescript
// Postgres, MySQL, etc.
{
  "tools": [
    {
      "name": "query",
      "description": "Execute SQL query",
      "input_schema": {
        "properties": {
          "sql": { "type": "string" }
        }
      }
    }
  ]
}
```

## Resource Access

MCP resources provide read-only data:

```typescript
// Assistant can access resources
const schema = await mcpHub.getResource('postgres://localhost/schema')
const docs = await mcpHub.getResource('github://owner/repo/README.md')

// Used in context
const response = await llm.complete({
  systemPrompt: `Here is the database schema:\n${schema}`,
  messages: conversationHistory
})
```

## Error Handling

MCP servers can fail or disconnect:

```typescript
// src/services/mcp/McpHub.ts
async callTool(toolName: string, input: any): Promise<any> {
  const [serverName, actualToolName] = toolName.split('/')
  const server = this.servers.get(serverName)
  
  if (!server) {
    throw new Error(`MCP server '${serverName}' not connected`)
  }
  
  try {
    return await server.callTool(actualToolName, input)
  } catch (error) {
    // Try to reconnect
    console.log(`MCP server error, attempting reconnect: ${error}`)
    
    await this.reconnectServer(serverName)
    
    // Retry once
    return await server.callTool(actualToolName, input)
  }
}

async reconnectServer(serverName: string) {
  const config = this.serverConfigs.get(serverName)
  if (!config) throw new Error(`Config not found for ${serverName}`)
  
  await this.disconnectServer(serverName)
  await this.connectServer(config)
}
```

## Custom MCP Servers

Users can create custom servers:

```typescript
// my-custom-mcp/server.ts
import { McpServer } from '@modelcontextprotocol/sdk'

const server = new McpServer({
  name: 'my-custom-tools',
  version: '1.0.0'
})

// Register tools
server.tool('analyze_code', 
  { path: { type: 'string' } },
  async (input) => {
    // Custom analysis logic
    const analysis = await analyzeCodeFile(input.path)
    return { result: analysis }
  }
)

// Start server
await server.start()
```

## Source Code References

| File | Purpose |
|------|---------|
| `src/services/mcp/McpHub.ts` | MCP server manager |
| `src/services/mcp/McpServer.ts` | Individual server connection |
| `packages/mcp/` | MCP protocol implementation |
| `src/core/task/Task.ts` | MCP tool integration |

## Key Insights

- **MCP extends capabilities** without modifying core code
- **Multiple servers** can run simultaneously
- **Tools prefixed** with server name to avoid conflicts
- **Automatic reconnection** on failures
- **Custom servers** let users add domain-specific tools

**Version**: Roo-Code v3.39+ (January 2026)
