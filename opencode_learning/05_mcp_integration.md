# Model Context Protocol (MCP) Integration

## Overview

OpenCode implements the **Model Context Protocol (MCP)** as a client, enabling integration with external MCP servers that provide additional tools, resources, and prompts.

**Location**: `packages/opencode/src/mcp/index.ts`

**Specification**: https://modelcontextprotocol.io

## What is MCP?

MCP is a standard protocol for AI applications to access external context and capabilities:

- **Tools**: External functions the AI can call
- **Resources**: Structured data sources (files, APIs, databases)
- **Prompts**: Templated prompt snippets

**Benefits**:

- Vendor-neutral integration
- Standardized capability discovery
- Secure authentication (OAuth, API keys)
- Hot-reload when capabilities change

## MCP Architecture in OpenCode

```
┌─────────────────────────────────────────────────────┐
│               OpenCode Core                         │
│                                                     │
│  ┌──────────┐         ┌──────────┐                │
│  │  Agent   │───────> │   MCP    │                │
│  │  System  │  uses   │  Client  │                │
│  └──────────┘         └────┬─────┘                │
│                            │                        │
└────────────────────────────┼────────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
┌─────────────┐      ┌─────────────┐     ┌─────────────┐
│ MCP Server  │      │ MCP Server  │     │ MCP Server  │
│   (stdio)   │      │   (SSE)     │     │   (HTTP)    │
│             │      │             │     │             │
│  filesystem │      │  database   │     │  web APIs   │
│  git        │      │  slack      │     │  browser    │
└─────────────┘      └─────────────┘     └─────────────┘
```

## MCP Configuration

### Config File (`.opencode/config.toml`)

```toml
# Stdio transport (local process)
[mcp.filesystem]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/project"]

# SSE transport (HTTP Server-Sent Events)
[mcp.database]
url = "http://localhost:3000/sse"
headers = { "Authorization" = "Bearer token123" }

# HTTP transport (Streamable HTTP)
[mcp.web_api]
url = "http://localhost:8080"
headers = { "X-API-Key" = "key123" }

# OAuth-enabled server
[mcp.github]
url = "https://mcp-github.example.com"
oauth = true
```

### Transport Types

#### 1. Stdio Transport

```typescript
// Spawns local process, communicates via stdin/stdout
const transport = new StdioClientTransport({
  command: "npx",
  args: ["-y", "@modelcontextprotocol/server-filesystem", "/path"],
})
```

**Use Case**: Local tools (filesystem, git, system utilities)
**Pros**: Simple, no network, fast
**Cons**: Platform-specific, harder to share

#### 2. SSE Transport

```typescript
// Server-Sent Events over HTTP
const transport = new SSEClientTransport(new URL("http://localhost:3000/sse"))
```

**Use Case**: Web services, remote databases, APIs
**Pros**: Works over HTTP, firewall-friendly
**Cons**: One-directional (server → client events only)

#### 3. Streamable HTTP Transport

```typescript
// Bidirectional HTTP streaming
const transport = new StreamableHTTPClientTransport(new URL("http://localhost:8080"))
```

**Use Case**: Full-duplex communication needed
**Pros**: Bidirectional, modern
**Cons**: Requires HTTP/2 or special server support

## MCP Client Lifecycle

### 1. Initialization

```typescript
async function initMCPServer(name: string, config: MCPConfig) {
  // Create transport
  const transport = createTransport(config)

  // Create client
  const client = new Client(
    {
      name: "opencode",
      version: Installation.VERSION,
    },
    {
      capabilities: {
        tools: {}, // Support tools
        resources: {}, // Support resources
        prompts: {}, // Support prompts
      },
    },
  )

  // Connect
  await client.connect(transport)

  // Register notification handlers
  client.setNotificationHandler(ToolListChangedNotificationSchema, async () => {
    // Reload tools when server updates them
    Bus.publish(MCP.ToolsChanged, { server: name })
  })

  return client
}
```

### 2. Capability Discovery

```typescript
// List available tools
const { tools } =
  await client.listTools()[
    // Example tools:
    ({
      name: "read_file",
      description: "Read file from filesystem",
      inputSchema: {
        type: "object",
        properties: {
          path: { type: "string" },
        },
      },
    },
    {
      name: "search_slack",
      description: "Search Slack messages",
      inputSchema: {
        /* ... */
      },
    })
  ]

// List resources
const { resources } =
  await client.listResources()[
    // Example resources:
    {
      uri: "file:///path/to/project",
      name: "Project Files",
      description: "Access to project filesystem",
    }
  ]

// List prompts
const { prompts } =
  await client.listPrompts()[
    // Example prompts:
    {
      name: "code_review",
      description: "Structured code review prompt",
      arguments: [{ name: "file_path", required: true }],
    }
  ]
```

### 3. Tool Execution

```typescript
// Convert MCP tool to OpenCode tool
function convertMcpTool(mcpTool: MCPToolDef, client: Client): Tool {
  return dynamicTool({
    description: mcpTool.description ?? "",
    inputSchema: jsonSchema(mcpTool.inputSchema),
    execute: async (args: unknown) => {
      // Call MCP server
      const result = await client.callTool(
        {
          name: mcpTool.name,
          arguments: args as Record<string, unknown>,
        },
        CallToolResultSchema,
        {
          timeout: 30000,
          resetTimeoutOnProgress: true, // Reset on streaming updates
        },
      )

      return result
    },
  })
}

// Now available to agents as regular tool
```

### 4. Resource Access

```typescript
// Read resource content
const resource = await client.readResource({
  uri: "file:///path/to/config.json"
})

// Returns:
{
  uri: "file:///path/to/config.json",
  mimeType: "application/json",
  contents: [
    {
      type: "text",
      text: "{ /* config */ }"
    }
  ]
}
```

### 5. Prompt Templates

```typescript
// Get prompt template
const prompt = await client.getPrompt({
  name: "code_review",
  arguments: {
    file_path: "src/auth.ts",
  },
})

// Returns:
{
  messages: [
    {
      role: "user",
      content: {
        type: "text",
        text: "Review this file for security issues: src/auth.ts",
      },
    },
  ]
}

// Can inject into session messages
```

## OAuth Integration

### OAuth Flow

```typescript
// 1. Server requests authentication
client.on("unauthorized", async (error: UnauthorizedError) => {
  // Start OAuth flow
  const authUrl = await McpOAuthProvider.startAuth({
    serverName: "github",
    authEndpoint: error.authEndpoint,
  })

  // Open browser
  await open(authUrl)

  // Wait for callback
  const code = await McpOAuthCallback.waitForCode()

  // Exchange code for token
  const token = await exchangeCodeForToken(code)

  // Retry with token
  transport.setAuth(token)
  await client.connect(transport)
})
```

### OAuth Server Setup

```typescript
// Start OAuth callback server
const server = await McpOAuthCallback.start({
  port: 3000,
  callback: async (code, state) => {
    // Handle OAuth callback
    return { success: true }
  },
})

// Register OAuth provider
await McpOAuthProvider.register({
  name: "github",
  clientId: "...",
  clientSecret: "...",
  authUrl: "https://github.com/login/oauth/authorize",
  tokenUrl: "https://github.com/login/oauth/access_token",
})
```

## Status Management

```typescript
// MCP server status
type MCPStatus =
  | { status: "connected" }
  | { status: "disabled" }
  | { status: "failed"; error: string }
  | { status: "needs_auth" }
  | { status: "needs_client_registration"; error: string }

// Track status per server
const statusMap = new Map<string, MCPStatus>()

// Update on events
client.on("connect", () => {
  statusMap.set(serverName, { status: "connected" })
})

client.on("error", (error) => {
  statusMap.set(serverName, {
    status: "failed",
    error: error.message,
  })
})
```

## Notification Handling

### Tool List Changes

```typescript
// Server notifies when tools change
client.setNotificationHandler(ToolListChangedNotificationSchema, async () => {
  // Reload tools
  const { tools } = await client.listTools()

  // Update tool registry
  await ToolRegistry.updateMcpTools(serverName, tools)

  // Notify system
  Bus.publish(MCP.ToolsChanged, { server: serverName })
})
```

### Resource Updates

```typescript
// Server notifies when resources change
client.setNotificationHandler(ResourceListChangedNotificationSchema, async () => {
  // Reload resources
  const { resources } = await client.listResources()

  // Update cache
  await MCP.updateResourceCache(serverName, resources)
})
```

## Error Handling

### Connection Errors

```typescript
try {
  await client.connect(transport)
} catch (error) {
  if (error instanceof UnauthorizedError) {
    // OAuth required
    await handleOAuth(serverName, error)
  } else if (error instanceof TimeoutError) {
    // Server not responding
    Log.error("MCP server timeout", { server: serverName })
  } else {
    // Other connection issues
    Log.error("MCP connection failed", {
      server: serverName,
      error: error.message,
    })
  }
}
```

### Tool Execution Errors

```typescript
try {
  const result = await client.callTool({
    name: "read_file",
    arguments: { path: "/nonexistent" },
  })
} catch (error) {
  // Return error to LLM
  return {
    isError: true,
    content: [
      {
        type: "text",
        text: `Tool execution failed: ${error.message}`,
      },
    ],
  }
}
```

## Built-in MCP Servers

### Filesystem Server

```toml
[mcp.filesystem]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-filesystem", "/path"]
```

**Tools**:

- `read_file` - Read file contents
- `write_file` - Write file
- `list_directory` - List directory contents
- `search_files` - Search files by pattern

### Git Server

```toml
[mcp.git]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-git"]
```

**Tools**:

- `git_status` - Get repo status
- `git_diff` - Show changes
- `git_commit` - Create commit
- `git_log` - View history

### Brave Search Server

```toml
[mcp.brave_search]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-brave-search"]
env = { "BRAVE_API_KEY" = "your-key" }
```

**Tools**:

- `brave_web_search` - Search the web
- `brave_local_search` - Local business search

## Custom MCP Server Development

### Server Implementation (Node.js)

```typescript
import { Server } from "@modelcontextprotocol/sdk/server/index.js"
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js"

const server = new Server(
  {
    name: "my-custom-server",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  },
)

// Register tool
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "custom_tool",
      description: "My custom tool",
      inputSchema: {
        type: "object",
        properties: {
          input: { type: "string" },
        },
      },
    },
  ],
}))

// Handle tool execution
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  if (request.params.name === "custom_tool") {
    const result = await doCustomOperation(request.params.arguments)

    return {
      content: [
        {
          type: "text",
          text: result,
        },
      ],
    }
  }
})

// Start server
const transport = new StdioServerTransport()
await server.connect(transport)
```

### Testing Custom Server

```bash
# Test with OpenCode
opencode mcp add my-server \
  --command "node" \
  --args "path/to/server.js"

# Verify connection
opencode mcp list

# Test tool
opencode
> Use custom_tool with input "test"
```

## MCP vs Native Tools

| Aspect           | MCP Tools                   | Native Tools          |
| ---------------- | --------------------------- | --------------------- |
| **Location**     | External process/server     | Built into OpenCode   |
| **Language**     | Any (stdio/HTTP)            | TypeScript            |
| **Distribution** | npm, docker, binary         | Bundled with OpenCode |
| **Development**  | Separate project            | OpenCode codebase     |
| **Hot Reload**   | Supported via notifications | Requires restart      |
| **Latency**      | Higher (IPC/network)        | Lower (same process)  |
| **Isolation**    | Process boundary            | Shared runtime        |
| **Best For**     | External integrations       | Core functionality    |

## Performance Considerations

### Caching

```typescript
// Cache tool definitions (1 hour TTL)
const toolCache = new Map<
  string,
  {
    tools: Tool[]
    timestamp: number
  }
>()

async function getMcpTools(serverName: string) {
  const cached = toolCache.get(serverName)
  if (cached && Date.now() - cached.timestamp < 3600000) {
    return cached.tools
  }

  const client = await getMcpClient(serverName)
  const { tools } = await client.listTools()

  toolCache.set(serverName, {
    tools: tools.map(convertMcpTool),
    timestamp: Date.now(),
  })

  return toolCache.get(serverName)!.tools
}
```

### Connection Pooling

```typescript
// Reuse MCP clients
const clientPool = new Map<string, Client>()

async function getMcpClient(serverName: string) {
  if (clientPool.has(serverName)) {
    return clientPool.get(serverName)!
  }

  const client = await initMCPServer(serverName, config)
  clientPool.set(serverName, client)
  return client
}
```

### Timeout Configuration

```typescript
// Configure per server
[mcp.slow_server]
command = "python"
args = ["server.py"]

[experimental]
mcp_timeout = 60000  # 60 seconds (default 30s)
```

## CLI Commands

```bash
# List configured MCP servers
opencode mcp list

# Add MCP server
opencode mcp add github \
  --url "https://mcp.github.com" \
  --oauth

# Remove MCP server
opencode mcp remove github

# Test MCP server
opencode mcp test filesystem

# Show server status
opencode mcp status

# Reload servers
opencode mcp reload
```

## Security Best Practices

1. **Validate Tool Inputs**: Always validate arguments server-side
2. **Sandbox Execution**: Run MCP servers in containers if possible
3. **Limit Permissions**: Grant minimal filesystem/network access
4. **Secure Credentials**: Never log OAuth tokens or API keys
5. **Timeout Protection**: Set reasonable timeouts to prevent hangs
6. **Audit Tools**: Review tools provided by third-party servers
7. **Update Regularly**: Keep MCP SDK and servers updated

## Next Steps

- [04_tool_system.md](./04_tool_system.md) - How MCP tools integrate with native tools
- [06_provider_layer.md](./06_provider_layer.md) - How providers use MCP context
- [01_overview.md](./01_overview.md) - Overall architecture
