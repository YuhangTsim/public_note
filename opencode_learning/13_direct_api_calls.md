# Direct API Calls: OpenAI, Anthropic, and Gemini

## Overview

This document shows what the equivalent API calls would look like if you were using the raw Python SDKs for OpenAI, Anthropic, or Google Gemini directly, instead of OpenCode's abstraction layer.

**Key Differences**:

- OpenCode uses the **Vercel AI SDK** (TypeScript) which normalizes across providers
- Direct SDKs have **provider-specific formats** for tools and messages
- OpenCode's **part-based architecture** is internal; providers use simpler message arrays

## Table of Contents

1. [OpenAI Python SDK](#openai-python-sdk)
2. [Anthropic Python SDK](#anthropic-python-sdk)
3. [Google Gemini API](#google-gemini-api)
4. [Side-by-Side Comparison](#side-by-side-comparison)

---

## OpenAI Python SDK

### Installation

```bash
pip install openai
```

### Tool Definition

```python
from openai import OpenAI

client = OpenAI(api_key="sk-...")

# Define tools
tools = [
    {
        "type": "function",
        "function": {
            "name": "bash",
            "description": "Execute bash commands",
            "parameters": {
                "type": "object",
                "properties": {
                    "command": {
                        "type": "string",
                        "description": "The command to execute"
                    },
                    "workdir": {
                        "type": "string",
                        "description": "Working directory (optional)"
                    },
                    "timeout": {
                        "type": "number",
                        "description": "Timeout in milliseconds (optional)"
                    },
                    "description": {
                        "type": "string",
                        "description": "Clear description of what this command does"
                    }
                },
                "required": ["command", "description"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "read",
            "description": "Read file contents from the filesystem",
            "parameters": {
                "type": "object",
                "properties": {
                    "filePath": {
                        "type": "string",
                        "description": "Absolute path to the file"
                    },
                    "offset": {
                        "type": "number",
                        "description": "Line number to start reading from (0-based)"
                    },
                    "limit": {
                        "type": "number",
                        "description": "Maximum number of lines to read"
                    }
                },
                "required": ["filePath"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "write",
            "description": "Write content to a file",
            "parameters": {
                "type": "object",
                "properties": {
                    "filePath": {
                        "type": "string",
                        "description": "Absolute path to the file"
                    },
                    "content": {
                        "type": "string",
                        "description": "Content to write to the file"
                    }
                },
                "required": ["filePath", "content"]
            }
        }
    }
]
```

### Complete Conversation Flow

```python
import json
import subprocess
from pathlib import Path

# ============================================================
# Understanding finish_reason / stop_reason
# ============================================================
# The API returns different reasons why generation stopped:
#
# OpenAI finish_reason:
#   - "stop": Model completed response naturally (DONE!)
#   - "tool_calls": Model wants to call tools (CONTINUE LOOP)
#   - "length": Hit max_tokens limit
#   - "content_filter": Content filtered
#
# Anthropic stop_reason:
#   - "end_turn": Model completed response (DONE!)
#   - "tool_use": Model wants to use tools (CONTINUE LOOP)
#   - "max_tokens": Hit max token limit
#
# Gemini finish_reason (numeric):
#   - 1 (STOP): Natural completion (DONE!)
#   - 2 (MAX_TOKENS): Hit token limit
#   - 3 (SAFETY): Safety filter triggered
#   - (With function_calls present: CONTINUE LOOP)
# ============================================================

# Helper functions to execute tools
def execute_bash(command, workdir=None, timeout=None, description=""):
    """Execute bash command"""
    result = subprocess.run(
        command,
        shell=True,
        cwd=workdir,
        capture_output=True,
        text=True,
        timeout=timeout/1000 if timeout else None
    )
    return f"{result.stdout}{result.stderr}"

def execute_read(filePath, offset=0, limit=2000):
    """Read file contents"""
    with open(filePath, 'r') as f:
        lines = f.readlines()
        selected = lines[offset:offset+limit]
        return ''.join(f"{i+offset+1:5d}| {line}" for i, line in enumerate(selected))

def execute_write(filePath, content):
    """Write file"""
    Path(filePath).parent.mkdir(parents=True, exist_ok=True)
    with open(filePath, 'w') as f:
        f.write(content)
    return "File written successfully"

# Tool execution dispatcher
def execute_tool(tool_name, arguments):
    if tool_name == "bash":
        return execute_bash(**arguments)
    elif tool_name == "read":
        return execute_read(**arguments)
    elif tool_name == "write":
        return execute_write(**arguments)
    else:
        return f"Unknown tool: {tool_name}"

# Initialize conversation
messages = [
    {
        "role": "system",
        "content": """You are Claude Code, Anthropic's official CLI for Claude.

You are a coding agent running in the opencode, a terminal-based coding assistant. opencode is an open source project. You are expected to be precise, safe, and helpful.

Instructions from: ~/.config/opencode/AGENTS.md
<Role>
You are "Sisyphus" - Powerful AI Agent with orchestration capabilities from OhMyOpenCode.
</Role>

Here is some useful information about the environment you are running in:
<env>
  Working directory: /Users/yuhangzhan/Codebase/research_workspace/opencode
  Is directory a git repo: yes
  Platform: darwin
  Today's date: Mon Jan 13 2026
</env>"""
    },
    {
        "role": "user",
        "content": "help me understand how opencode is designed, put your learning under a new folder under root, named `opencode_learning`"
    }
]

# Initial API call
response = client.chat.completions.create(
    model="gpt-4-turbo",
    messages=messages,
    tools=tools,
    tool_choice="auto"  # Let model decide when to use tools
)

print("=== Initial Response ===")
print(f"Finish reason: {response.choices[0].finish_reason}")
print(f"Message: {response.choices[0].message}")

# ============================================================
# THE LOOP LOGIC EXPLAINED
# ============================================================
# Loop continues while finish_reason == "tool_calls"
#
# Iteration 1: Model says "I'll use bash tool" → finish_reason = "tool_calls"
#   → We execute bash → Add results to messages → Call API again
#
# Iteration 2: Model says "I'll use write tool" → finish_reason = "tool_calls"
#   → We execute write → Add results to messages → Call API again
#
# Iteration 3: Model says "Done! I created files." → finish_reason = "stop"
#   → Loop exits, we have final response
# ============================================================

# Process tool calls in a loop
while response.choices[0].finish_reason == "tool_calls":
    assistant_message = response.choices[0].message
    messages.append(assistant_message)

    print(f"\n=== Tool Calls ({len(assistant_message.tool_calls)}) ===")

    # Execute each tool call
    for tool_call in assistant_message.tool_calls:
        tool_name = tool_call.function.name
        tool_args = json.loads(tool_call.function.arguments)

        print(f"\nTool: {tool_name}")
        print(f"Arguments: {json.dumps(tool_args, indent=2)}")

        # Execute the tool
        tool_output = execute_tool(tool_name, tool_args)

        print(f"Output: {tool_output[:200]}...")  # Truncated for display

        # Add tool result to messages
        messages.append({
            "role": "tool",
            "tool_call_id": tool_call.id,
            "name": tool_name,
            "content": tool_output
        })

    # Continue conversation with tool results
    response = client.chat.completions.create(
        model="gpt-4-turbo",
        messages=messages,
        tools=tools,
        tool_choice="auto"
    )

    print(f"\n=== Next Response ===")
    print(f"Finish reason: {response.choices[0].finish_reason}")

    # If finish_reason is still "tool_calls", loop continues
    # If finish_reason is "stop", loop exits

# ============================================================
# LOOP EXITED - finish_reason must be "stop" (or other non-tool reason)
# ============================================================
# At this point, the model has finished and given us a final text response
# No more tools to call - conversation complete
# ============================================================

# Final response
final_message = response.choices[0].message
messages.append(final_message)

print("\n=== Final Response ===")
print(f"Finish reason: {response.choices[0].finish_reason}")  # Should be "stop"
print(final_message.content)

# Print final message history
print("\n=== Complete Message History ===")
for i, msg in enumerate(messages):
    print(f"\n[{i}] Role: {msg.get('role', 'unknown')}")
    if msg.get('role') == 'tool':
        print(f"    Tool: {msg.get('name')}")
        print(f"    Tool Call ID: {msg.get('tool_call_id')}")
        print(f"    Content: {msg.get('content', '')[:100]}...")
    elif hasattr(msg, 'tool_calls') and msg.tool_calls:
        print(f"    Tool Calls: {len(msg.tool_calls)}")
        for tc in msg.tool_calls:
            print(f"      - {tc.function.name}: {tc.function.arguments[:80]}...")
    else:
        content = msg.get('content') or (msg.content if hasattr(msg, 'content') else '')
        print(f"    Content: {content[:100]}...")
```

### Example Message Array (OpenAI Format)

```python
[
    # System prompt
    {
        "role": "system",
        "content": "You are Claude Code, Anthropic's official CLI for Claude..."
    },

    # User message
    {
        "role": "user",
        "content": "help me understand how opencode is designed..."
    },

    # Assistant response with tool calls
    {
        "role": "assistant",
        "content": "I'll gather context about opencode's design using parallel exploration.",
        "tool_calls": [
            {
                "id": "call_abc123",
                "type": "function",
                "function": {
                    "name": "bash",
                    "arguments": '{"command": "find . -name \\"package.json\\" -not -path \\"*/node_modules/*\\" | head -20", "description": "Find package.json files"}'
                }
            },
            {
                "id": "call_def456",
                "type": "function",
                "function": {
                    "name": "bash",
                    "arguments": '{"command": "ls -la", "description": "List root directory"}'
                }
            },
            {
                "id": "call_ghi789",
                "type": "function",
                "function": {
                    "name": "read",
                    "arguments": '{"filePath": "/Users/yuhangzhan/Codebase/cc_workspace/opencode/README.md"}'
                }
            }
        ]
    },

    # Tool results
    {
        "role": "tool",
        "tool_call_id": "call_abc123",
        "name": "bash",
        "content": "./sdks/vscode/package.json\n./.opencode/package.json\n..."
    },
    {
        "role": "tool",
        "tool_call_id": "call_def456",
        "name": "bash",
        "content": "total 1472\ndrwxr-xr-x  37 yuhangzhan  staff..."
    },
    {
        "role": "tool",
        "tool_call_id": "call_ghi789",
        "name": "read",
        "content": "<file>\n00001| <p align=\"center\">..."
    },

    # Assistant continues after receiving tool results
    {
        "role": "assistant",
        "content": None,
        "tool_calls": [
            {
                "id": "call_write1",
                "type": "function",
                "function": {
                    "name": "write",
                    "arguments": '{"filePath": "/Users/yuhangzhan/Codebase/cc_workspace/opencode/opencode_learning/01_overview.md", "content": "# OpenCode Architecture Overview..."}'
                }
            }
        ]
    },

    # Write tool result
    {
        "role": "tool",
        "tool_call_id": "call_write1",
        "name": "write",
        "content": "File written successfully"
    },

    # Final assistant response
    {
        "role": "assistant",
        "content": "Perfect! I've created comprehensive documentation..."
    }
]
```

---

## Anthropic Python SDK

### Installation

```bash
pip install anthropic
```

### Tool Definition

```python
from anthropic import Anthropic

client = Anthropic(api_key="sk-ant-...")

# Define tools (Anthropic format)
tools = [
    {
        "name": "bash",
        "description": "Execute bash commands",
        "input_schema": {
            "type": "object",
            "properties": {
                "command": {
                    "type": "string",
                    "description": "The command to execute"
                },
                "workdir": {
                    "type": "string",
                    "description": "Working directory (optional)"
                },
                "timeout": {
                    "type": "number",
                    "description": "Timeout in milliseconds (optional)"
                },
                "description": {
                    "type": "string",
                    "description": "Clear description of what this command does"
                }
            },
            "required": ["command", "description"]
        }
    },
    {
        "name": "read",
        "description": "Read file contents from the filesystem",
        "input_schema": {
            "type": "object",
            "properties": {
                "filePath": {
                    "type": "string",
                    "description": "Absolute path to the file"
                },
                "offset": {
                    "type": "number",
                    "description": "Line number to start reading from (0-based)"
                },
                "limit": {
                    "type": "number",
                    "description": "Maximum number of lines to read"
                }
            },
            "required": ["filePath"]
        }
    },
    {
        "name": "write",
        "description": "Write content to a file",
        "input_schema": {
            "type": "object",
            "properties": {
                "filePath": {
                    "type": "string",
                    "description": "Absolute path to the file"
                },
                "content": {
                    "type": "string",
                    "description": "Content to write to the file"
                }
            },
            "required": ["filePath", "content"]
        }
    }
]
```

### Complete Conversation Flow

```python
import json

# Same tool execution functions as OpenAI example above

# Initialize conversation (Anthropic uses separate system parameter)
system_prompt = """You are Claude Code, Anthropic's official CLI for Claude.

You are a coding agent running in the opencode, a terminal-based coding assistant...

Here is some useful information about the environment you are running in:
<env>
  Working directory: /Users/yuhangzhan/Codebase/research_workspace/opencode
  Is directory a git repo: yes
  Platform: darwin
  Today's date: Mon Jan 13 2026
</env>"""

messages = [
    {
        "role": "user",
        "content": "help me understand how opencode is designed, put your learning under a new folder under root, named `opencode_learning`"
    }
]

# Initial API call
response = client.messages.create(
    model="claude-3-5-sonnet-20241022",
    system=system_prompt,  # Anthropic uses separate system parameter
    messages=messages,
    tools=tools,
    max_tokens=4096
)

print("=== Initial Response ===")
print(f"Stop reason: {response.stop_reason}")
print(f"Content blocks: {len(response.content)}")

# Process tool calls in a loop
while response.stop_reason == "tool_use":
    # Add assistant's response to messages
    messages.append({
        "role": "assistant",
        "content": response.content
    })

    print(f"\n=== Tool Calls ===")

    # Build tool results
    tool_results = []
    for block in response.content:
        if block.type == "tool_use":
            print(f"\nTool: {block.name}")
            print(f"Tool Use ID: {block.id}")
            print(f"Input: {json.dumps(block.input, indent=2)}")

            # Execute the tool
            tool_output = execute_tool(block.name, block.input)

            print(f"Output: {tool_output[:200]}...")

            tool_results.append({
                "type": "tool_result",
                "tool_use_id": block.id,
                "content": tool_output
            })

    # Add tool results as user message
    messages.append({
        "role": "user",
        "content": tool_results
    })

    # Continue conversation
    response = client.messages.create(
        model="claude-3-5-sonnet-20241022",
        system=system_prompt,
        messages=messages,
        tools=tools,
        max_tokens=4096
    )

    print(f"\n=== Next Response ===")
    print(f"Stop reason: {response.stop_reason}")

# Final response
messages.append({
    "role": "assistant",
    "content": response.content
})

print("\n=== Final Response ===")
for block in response.content:
    if block.type == "text":
        print(block.text)

# Print final message history
print("\n=== Complete Message History ===")
for i, msg in enumerate(messages):
    print(f"\n[{i}] Role: {msg['role']}")
    if isinstance(msg['content'], str):
        print(f"    Content: {msg['content'][:100]}...")
    elif isinstance(msg['content'], list):
        for j, block in enumerate(msg['content']):
            if hasattr(block, 'type'):
                print(f"    Block {j}: {block.type}")
                if block.type == "text":
                    print(f"      Text: {block.text[:80]}...")
                elif block.type == "tool_use":
                    print(f"      Tool: {block.name}")
                    print(f"      ID: {block.id}")
                elif block.type == "tool_result":
                    print(f"      Tool Use ID: {block.tool_use_id}")
            else:
                print(f"    Block {j}: {block.get('type', 'unknown')}")
```

### Example Message Array (Anthropic Format)

```python
[
    # User message
    {
        "role": "user",
        "content": "help me understand how opencode is designed..."
    },

    # Assistant response with tool calls
    {
        "role": "assistant",
        "content": [
            {
                "type": "text",
                "text": "I'll gather context about opencode's design using parallel exploration."
            },
            {
                "type": "tool_use",
                "id": "toolu_01abc123",
                "name": "bash",
                "input": {
                    "command": "find . -name \"package.json\" -not -path \"*/node_modules/*\" | head -20",
                    "description": "Find package.json files"
                }
            },
            {
                "type": "tool_use",
                "id": "toolu_02def456",
                "name": "bash",
                "input": {
                    "command": "ls -la",
                    "description": "List root directory"
                }
            },
            {
                "type": "tool_use",
                "id": "toolu_03ghi789",
                "name": "read",
                "input": {
                    "filePath": "/Users/yuhangzhan/Codebase/cc_workspace/opencode/README.md"
                }
            }
        ]
    },

    # Tool results (sent as user message!)
    {
        "role": "user",
        "content": [
            {
                "type": "tool_result",
                "tool_use_id": "toolu_01abc123",
                "content": "./sdks/vscode/package.json\n./.opencode/package.json\n..."
            },
            {
                "type": "tool_result",
                "tool_use_id": "toolu_02def456",
                "content": "total 1472\ndrwxr-xr-x  37 yuhangzhan  staff..."
            },
            {
                "type": "tool_result",
                "tool_use_id": "toolu_03ghi789",
                "content": "<file>\n00001| <p align=\"center\">..."
            }
        ]
    },

    # Assistant continues
    {
        "role": "assistant",
        "content": [
            {
                "type": "tool_use",
                "id": "toolu_04write1",
                "name": "write",
                "input": {
                    "filePath": "/Users/yuhangzhan/Codebase/cc_workspace/opencode/opencode_learning/01_overview.md",
                    "content": "# OpenCode Architecture Overview..."
                }
            }
        ]
    },

    # Write tool result
    {
        "role": "user",
        "content": [
            {
                "type": "tool_result",
                "tool_use_id": "toolu_04write1",
                "content": "File written successfully"
            }
        ]
    },

    # Final response
    {
        "role": "assistant",
        "content": [
            {
                "type": "text",
                "text": "Perfect! I've created comprehensive documentation..."
            }
        ]
    }
]
```

---

## Google Gemini API

### Installation

```bash
pip install google-generativeai
```

### Tool Definition

```python
import google.generativeai as genai

genai.configure(api_key="AIza...")

# Define tools (Gemini format)
tools = [
    {
        "function_declarations": [
            {
                "name": "bash",
                "description": "Execute bash commands",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "command": {
                            "type": "string",
                            "description": "The command to execute"
                        },
                        "workdir": {
                            "type": "string",
                            "description": "Working directory (optional)"
                        },
                        "timeout": {
                            "type": "number",
                            "description": "Timeout in milliseconds (optional)"
                        },
                        "description": {
                            "type": "string",
                            "description": "Clear description of what this command does"
                        }
                    },
                    "required": ["command", "description"]
                }
            },
            {
                "name": "read",
                "description": "Read file contents from the filesystem",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "filePath": {
                            "type": "string",
                            "description": "Absolute path to the file"
                        },
                        "offset": {
                            "type": "number",
                            "description": "Line number to start reading from (0-based)"
                        },
                        "limit": {
                            "type": "number",
                            "description": "Maximum number of lines to read"
                        }
                    },
                    "required": ["filePath"]
                }
            },
            {
                "name": "write",
                "description": "Write content to a file",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "filePath": {
                            "type": "string",
                            "description": "Absolute path to the file"
                        },
                        "content": {
                            "type": "string",
                            "description": "Content to write to the file"
                        }
                    },
                    "required": ["filePath", "content"]
                }
            }
        ]
    }
]
```

### Complete Conversation Flow

```python
import json

# Same tool execution functions as previous examples

# Initialize model with tools
model = genai.GenerativeModel(
    model_name="gemini-1.5-pro",
    tools=tools,
    system_instruction="""You are opencode, an interactive CLI agent specializing in software engineering tasks.

Here is some useful information about the environment you are running in:
<env>
  Working directory: /Users/yuhangzhan/Codebase/research_workspace/opencode
  Is directory a git repo: yes
  Platform: darwin
  Today's date: Mon Jan 13 2026
</env>"""
)

# Start chat
chat = model.start_chat(history=[])

# Send user message
response = chat.send_message(
    "help me understand how opencode is designed, put your learning under a new folder under root, named `opencode_learning`"
)

print("=== Initial Response ===")
print(f"Finish reason: {response.candidates[0].finish_reason}")

# Process function calls in a loop
while response.candidates[0].finish_reason == 1:  # 1 = STOP (but with function calls)
    function_calls = []

    for part in response.parts:
        if hasattr(part, 'function_call') and part.function_call:
            function_calls.append(part.function_call)

    if not function_calls:
        break

    print(f"\n=== Function Calls ({len(function_calls)}) ===")

    # Execute function calls and build responses
    function_responses = []
    for fc in function_calls:
        print(f"\nFunction: {fc.name}")
        print(f"Args: {dict(fc.args)}")

        # Execute the tool
        tool_output = execute_tool(fc.name, dict(fc.args))

        print(f"Output: {tool_output[:200]}...")

        function_responses.append({
            "function_call": fc,
            "function_response": {
                "name": fc.name,
                "response": {"result": tool_output}
            }
        })

    # Send function responses back
    response = chat.send_message(
        [genai.protos.Part(function_response=fr["function_response"])
         for fr in function_responses]
    )

    print(f"\n=== Next Response ===")
    print(f"Finish reason: {response.candidates[0].finish_reason}")

# Final response
print("\n=== Final Response ===")
print(response.text)

# Print chat history
print("\n=== Complete Chat History ===")
for i, msg in enumerate(chat.history):
    print(f"\n[{i}] Role: {msg.role}")
    for j, part in enumerate(msg.parts):
        if part.text:
            print(f"    Part {j} (text): {part.text[:80]}...")
        elif hasattr(part, 'function_call') and part.function_call:
            print(f"    Part {j} (function_call):")
            print(f"      Name: {part.function_call.name}")
            print(f"      Args: {dict(part.function_call.args)}")
        elif hasattr(part, 'function_response') and part.function_response:
            print(f"    Part {j} (function_response):")
            print(f"      Name: {part.function_response.name}")
```

### Example Message Array (Gemini Format)

```python
[
    # User message
    {
        "role": "user",
        "parts": [
            {"text": "help me understand how opencode is designed..."}
        ]
    },

    # Model response with function calls
    {
        "role": "model",
        "parts": [
            {"text": "I'll gather context about opencode's design."},
            {
                "function_call": {
                    "name": "bash",
                    "args": {
                        "command": "find . -name \"package.json\" -not -path \"*/node_modules/*\" | head -20",
                        "description": "Find package.json files"
                    }
                }
            },
            {
                "function_call": {
                    "name": "bash",
                    "args": {
                        "command": "ls -la",
                        "description": "List root directory"
                    }
                }
            },
            {
                "function_call": {
                    "name": "read",
                    "args": {
                        "filePath": "/Users/yuhangzhan/Codebase/cc_workspace/opencode/README.md"
                    }
                }
            }
        ]
    },

    # Function responses (sent back as user message)
    {
        "role": "user",
        "parts": [
            {
                "function_response": {
                    "name": "bash",
                    "response": {
                        "result": "./sdks/vscode/package.json\n./.opencode/package.json\n..."
                    }
                }
            },
            {
                "function_response": {
                    "name": "bash",
                    "response": {
                        "result": "total 1472\ndrwxr-xr-x  37 yuhangzhan  staff..."
                    }
                }
            },
            {
                "function_response": {
                    "name": "read",
                    "response": {
                        "result": "<file>\n00001| <p align=\"center\">..."
                    }
                }
            }
        ]
    },

    # Model continues with more function calls
    {
        "role": "model",
        "parts": [
            {
                "function_call": {
                    "name": "write",
                    "args": {
                        "filePath": "/Users/yuhangzhan/Codebase/cc_workspace/opencode/opencode_learning/01_overview.md",
                        "content": "# OpenCode Architecture Overview..."
                    }
                }
            }
        ]
    },

    # Write function response
    {
        "role": "user",
        "parts": [
            {
                "function_response": {
                    "name": "write",
                    "response": {
                        "result": "File written successfully"
                    }
                }
            }
        ]
    },

    # Final model response
    {
        "role": "model",
        "parts": [
            {"text": "Perfect! I've created comprehensive documentation..."}
        ]
    }
]
```

---

## Side-by-Side Comparison

### Tool Definition Format

| Feature             | OpenAI                | Anthropic          | Gemini                            |
| ------------------- | --------------------- | ------------------ | --------------------------------- |
| **Top Level**       | `tools[]`             | `tools[]`          | `tools[].function_declarations[]` |
| **Tool Wrapper**    | `type: "function"`    | None               | None                              |
| **Schema Key**      | `function.parameters` | `input_schema`     | `parameters`                      |
| **Required Fields** | `required[]` array    | `required[]` array | `required[]` array                |

### Message Format

| Feature              | OpenAI           | Anthropic                          | Gemini                              |
| -------------------- | ---------------- | ---------------------------------- | ----------------------------------- |
| **System Prompt**    | `role: "system"` | Separate `system` parameter        | `system_instruction` parameter      |
| **User Role**        | `"user"`         | `"user"`                           | `"user"`                            |
| **Assistant Role**   | `"assistant"`    | `"assistant"`                      | `"model"`                           |
| **Content Format**   | String or array  | Array of blocks                    | Array of parts                      |
| **Tool Call Key**    | `tool_calls[]`   | `content[].type: "tool_use"`       | `parts[].function_call`             |
| **Tool Result Role** | `"tool"`         | `"user"` (with `tool_result` type) | `"user"` (with `function_response`) |

### Tool Call Format

```python
# OpenAI
{
    "tool_calls": [
        {
            "id": "call_abc123",
            "type": "function",
            "function": {
                "name": "bash",
                "arguments": '{"command": "ls"}'  # JSON string!
            }
        }
    ]
}

# Anthropic
{
    "content": [
        {
            "type": "tool_use",
            "id": "toolu_abc123",
            "name": "bash",
            "input": {"command": "ls"}  # Already parsed object
        }
    ]
}

# Gemini
{
    "parts": [
        {
            "function_call": {
                "name": "bash",
                "args": {"command": "ls"}  # Already parsed object
            }
        }
    ]
}
```

### Tool Result Format

```python
# OpenAI
{
    "role": "tool",
    "tool_call_id": "call_abc123",
    "name": "bash",
    "content": "file1.txt\nfile2.txt"
}

# Anthropic
{
    "role": "user",  # Tool results sent as user message!
    "content": [
        {
            "type": "tool_result",
            "tool_use_id": "toolu_abc123",
            "content": "file1.txt\nfile2.txt"
        }
    ]
}

# Gemini
{
    "role": "user",  # Function responses sent as user message!
    "parts": [
        {
            "function_response": {
                "name": "bash",
                "response": {
                    "result": "file1.txt\nfile2.txt"
                }
            }
        }
    ]
}
```

## Key Differences from OpenCode

### 1. Message Storage

**OpenCode**:

- Stores messages in **part-based format** on filesystem
- Each tool call is a separate `ToolPart` with state tracking
- Messages have metadata (tokens, cost, timestamps)

**Direct SDKs**:

- Keep messages in memory as simple arrays
- No automatic persistence
- Tool calls embedded in assistant messages

### 2. Tool Execution

**OpenCode**:

- **Automatic execution** via `SessionProcessor`
- **Permission checks** before running tools
- **State tracking** (pending → running → completed)
- **Output truncation** for large results

**Direct SDKs**:

- **Manual execution** required (you write the loop)
- **No permission system** (you implement it)
- **No state tracking** (tool either succeeds or fails)
- **Raw output** returned as-is

### 3. Streaming

**OpenCode**:

- Real-time UI updates via `Bus.publish()`
- Tool state changes visible immediately
- Progress bars and live output

**Direct SDKs**:

- OpenAI: Streaming via `stream=True`
- Anthropic: Streaming via `.stream()`
- Gemini: Streaming via `.stream_generate_content()`
- Tool calls only appear after completion

### 4. Error Handling

**OpenCode**:

- Structured error types (`MessageV2.APIError`, `AuthError`, etc.)
- Automatic retry with exponential backoff
- Error details stored in message metadata

**Direct SDKs**:

- Provider-specific exceptions
- Manual retry logic required
- Errors not persisted

## Understanding finish_reason / stop_reason

### Where is finish_reason Located?

**IMPORTANT**: `finish_reason` is **NOT** part of the model's text output or tool calls. It's a **separate metadata field** in the API response object.

#### OpenAI Response Structure

```python
response = client.chat.completions.create(...)

# The complete response object structure:
{
  "id": "chatcmpl-abc123",
  "object": "chat.completion",
  "created": 1736708258,
  "model": "gpt-4-turbo-2024-04-09",
  "choices": [                           # ← Array of choices
    {
      "index": 0,
      "message": {                       # ← The model's message
        "role": "assistant",
        "content": "I'll help you...",   # ← Text content (can be None!)
        "tool_calls": [...]              # ← Tool calls (can be None!)
      },
      "finish_reason": "tool_calls"      # ← HERE! Separate metadata field
    }
  ],
  "usage": {
    "prompt_tokens": 1234,
    "completion_tokens": 567,
    "total_tokens": 1801
  }
}

# Accessing finish_reason:
finish_reason = response.choices[0].finish_reason  # ← It's at this level
content = response.choices[0].message.content      # ← Text is separate
tool_calls = response.choices[0].message.tool_calls # ← Tools are separate
```

**Visual Structure:**

```
response
  └─ choices[0]
       ├─ message
       │    ├─ role: "assistant"
       │    ├─ content: "text here" (or None)
       │    └─ tool_calls: [...] (or None)
       │
       └─ finish_reason: "tool_calls" ← METADATA, not part of message!
```

#### Anthropic Response Structure

```python
response = client.messages.create(...)

# The complete response object structure:
{
  "id": "msg_abc123",
  "type": "message",
  "role": "assistant",
  "content": [                            # ← Array of content blocks
    {
      "type": "text",
      "text": "I'll help you..."
    },
    {
      "type": "tool_use",
      "id": "toolu_xyz",
      "name": "bash",
      "input": {...}
    }
  ],
  "model": "claude-3-5-sonnet-20241022",
  "stop_reason": "tool_use",             # ← HERE! Top-level metadata
  "usage": {
    "input_tokens": 1234,
    "output_tokens": 567
  }
}

# Accessing stop_reason:
stop_reason = response.stop_reason  # ← Top level field
content = response.content          # ← Content blocks are separate
```

**Visual Structure:**

```
response
  ├─ id: "msg_abc123"
  ├─ role: "assistant"
  ├─ content: [...]               ← Message content (text, tool_use blocks)
  ├─ model: "claude-3-5-sonnet"
  └─ stop_reason: "tool_use"      ← METADATA, not inside content!
```

#### Gemini Response Structure

```python
response = chat.send_message(...)

# The complete response object structure:
{
  "candidates": [                        # ← Array of candidates
    {
      "content": {
        "parts": [                       # ← Message parts
          {
            "text": "I'll help you..."
          },
          {
            "function_call": {
              "name": "bash",
              "args": {...}
            }
          }
        ],
        "role": "model"
      },
      "finish_reason": 1,                # ← HERE! Numeric code
      "safety_ratings": [...]
    }
  ],
  "usage_metadata": {
    "prompt_token_count": 1234,
    "candidates_token_count": 567
  }
}

# Accessing finish_reason:
finish_reason = response.candidates[0].finish_reason  # ← Numeric: 1, 2, 3, etc.
parts = response.candidates[0].content.parts          # ← Content is separate
```

**Visual Structure:**

```
response
  └─ candidates[0]
       ├─ content
       │    └─ parts: [...]        ← Message content (text, function_call)
       │
       └─ finish_reason: 1          ← METADATA (numeric), not in content!
```

### Real Example: Tool Call Response

Here's what an actual API response looks like when the model wants to call a tool:

#### OpenAI Real Response

```python
response = client.chat.completions.create(
    model="gpt-4-turbo",
    messages=[{"role": "user", "content": "List files in current directory"}],
    tools=[bash_tool_definition]
)

# What you actually get back:
ChatCompletion(
    id='chatcmpl-abc123',
    choices=[
        Choice(
            finish_reason='tool_calls',  # ← Says "I want to call tools"
            index=0,
            message=ChatCompletionMessage(
                content=None,            # ← No text! Model wants to call tool instead
                role='assistant',
                tool_calls=[             # ← The tool it wants to call
                    ChatCompletionMessageToolCall(
                        id='call_xyz789',
                        function=Function(
                            arguments='{"command":"ls -la","description":"List files"}',
                            name='bash'
                        ),
                        type='function'
                    )
                ]
            )
        )
    ],
    created=1736708258,
    model='gpt-4-turbo-2024-04-09',
    usage=CompletionUsage(
        completion_tokens=25,
        prompt_tokens=150,
        total_tokens=175
    )
)

# How to check:
if response.choices[0].finish_reason == "tool_calls":  # ← Check THIS field
    # Execute tools from response.choices[0].message.tool_calls
    for tool_call in response.choices[0].message.tool_calls:
        execute_tool(tool_call.function.name, tool_call.function.arguments)
```

#### OpenAI Final Response (After Tools)

```python
# After executing tools and sending results back:
response = client.chat.completions.create(
    model="gpt-4-turbo",
    messages=[
        {"role": "user", "content": "List files"},
        {"role": "assistant", "tool_calls": [...]},
        {"role": "tool", "content": "file1.txt\nfile2.txt"}  # Tool result
    ],
    tools=[bash_tool_definition]
)

# What you get back:
ChatCompletion(
    id='chatcmpl-def456',
    choices=[
        Choice(
            finish_reason='stop',        # ← Says "I'm done!"
            index=0,
            message=ChatCompletionMessage(
                content='Here are the files in the current directory:\n- file1.txt\n- file2.txt',  # ← NOW has text
                role='assistant',
                tool_calls=None          # ← No more tool calls
            )
        )
    ],
    created=1736708260,
    model='gpt-4-turbo-2024-04-09',
    usage=CompletionUsage(
        completion_tokens=45,
        prompt_tokens=200,
        total_tokens=245
    )
)

# How to check:
if response.choices[0].finish_reason == "stop":  # ← Check THIS field
    # We're done! Print final response
    print(response.choices[0].message.content)
```

### Key Insight: Three Separate Things

When you get a response, there are **three separate pieces of information**:

```python
response = client.chat.completions.create(...)

# 1. METADATA: Why did generation stop?
finish_reason = response.choices[0].finish_reason
# Possible values: "stop", "tool_calls", "length", "content_filter"

# 2. TEXT CONTENT: What did the model say?
text = response.choices[0].message.content
# Can be: "Here's the answer..." or None (if tool_calls present)

# 3. TOOL CALLS: What tools does the model want to use?
tools = response.choices[0].message.tool_calls
# Can be: [{name: "bash", arguments: {...}}] or None (if no tools)
```

**The relationship:**

| finish_reason      | content           | tool_calls      | What it means                |
| ------------------ | ----------------- | --------------- | ---------------------------- |
| `"stop"`           | Text              | `None`          | ✅ Model gave final answer   |
| `"tool_calls"`     | `None`            | Array           | ⚠️ Model wants to call tools |
| `"length"`         | Text (incomplete) | Could be either | ⚠️ Hit token limit           |
| `"content_filter"` | `None`            | `None`          | ❌ Response blocked          |

### Why This Matters

**Without checking finish_reason:**

```python
response = client.chat.completions.create(...)

# WRONG - This might print "None"!
print(response.choices[0].message.content)
# → Output: None (because finish_reason was "tool_calls"!)
```

**With finish_reason check:**

```python
response = client.chat.completions.create(...)

if response.choices[0].finish_reason == "tool_calls":
    print("Model wants to call tools:")
    for tool in response.choices[0].message.tool_calls:
        print(f"  - {tool.function.name}")
    # Execute tools and call API again...

elif response.choices[0].finish_reason == "stop":
    print("Model's response:")
    print(response.choices[0].message.content)
    # Safe to print - we know content exists
```

### The Loop Termination Logic

The key to understanding when a conversation ends is the **finish_reason** (OpenAI) or **stop_reason** (Anthropic/Gemini) field.

```
┌─────────────────────────────────────────────────────────┐
│ User sends message                                      │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│ API Call                                                │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
        ┌────────────────┐
        │ Model Response │
        └────────┬───────┘
                 │
      ┌──────────▼──────────┐
      │ Check finish_reason │
      └──────────┬──────────┘
                 │
     ┌───────────┴───────────┐
     │                       │
     ▼                       ▼
┌─────────┐            ┌─────────┐
│ "stop"  │            │"tool_   │
│         │            │calls"   │
└────┬────┘            └────┬────┘
     │                      │
     │                      ▼
     │              ┌───────────────┐
     │              │ Execute Tools │
     │              └───────┬───────┘
     │                      │
     │                      ▼
     │              ┌───────────────┐
     │              │ Add Results   │
     │              │ to Messages   │
     │              └───────┬───────┘
     │                      │
     │                      └──────┐
     │                             │
     ▼                             ▼
┌────────────┐           ┌─────────────────┐
│   DONE!    │           │ Call API Again  │
│ Exit Loop  │           │ (Loop Back)     │
└────────────┘           └─────────────────┘
```

### Detailed Example Trace

Let's trace through the exact sequence:

**Request 1:**

```python
response = client.chat.completions.create(
    model="gpt-4-turbo",
    messages=[
        {"role": "system", "content": "..."},
        {"role": "user", "content": "help me understand opencode"}
    ],
    tools=[...]
)

# Response:
response.choices[0].finish_reason = "tool_calls"  # ← NOT "stop", so continue!
response.choices[0].message.tool_calls = [
    { name: "bash", arguments: '{"command": "ls -la"}' },
    { name: "read", arguments: '{"filePath": "README.md"}' }
]
```

**What happens:**

- `finish_reason == "tool_calls"` → Loop continues
- We execute `bash` and `read` tools
- Add tool results to messages
- Make another API call

**Request 2:**

```python
messages.append(assistant_message)  # The message with tool_calls
messages.append({"role": "tool", "name": "bash", "content": "..."})
messages.append({"role": "tool", "name": "read", "content": "..."})

response = client.chat.completions.create(
    model="gpt-4-turbo",
    messages=messages,  # Now includes tool results
    tools=[...]
)

# Response:
response.choices[0].finish_reason = "tool_calls"  # ← STILL not "stop"!
response.choices[0].message.tool_calls = [
    { name: "write", arguments: '{"filePath": "...", "content": "..."}' }
]
```

**What happens:**

- `finish_reason == "tool_calls"` → Loop continues again
- We execute `write` tool
- Add tool result to messages
- Make another API call

**Request 3:**

```python
messages.append(assistant_message)  # The message with write tool_call
messages.append({"role": "tool", "name": "write", "content": "File written"})

response = client.chat.completions.create(
    model="gpt-4-turbo",
    messages=messages,  # Now includes write result
    tools=[...]
)

# Response:
response.choices[0].finish_reason = "stop"  # ← NOW it's "stop"!
response.choices[0].message.content = "Perfect! I've created comprehensive documentation..."
response.choices[0].message.tool_calls = None  # No more tools
```

**What happens:**

- `finish_reason == "stop"` → Loop exits
- We have the final text response
- Conversation complete

### All Possible finish_reason Values

#### OpenAI

```python
if finish_reason == "stop":
    # Natural completion - model is done
    # This is the normal end of conversation
    print("Conversation complete!")
    break

elif finish_reason == "tool_calls":
    # Model wants to call tools
    # MUST execute tools and continue loop
    execute_and_continue()

elif finish_reason == "length":
    # Hit max_tokens limit
    # Response is incomplete - may need to continue
    print("Warning: Response truncated due to length")
    break

elif finish_reason == "content_filter":
    # Response blocked by content filter
    print("Error: Content filtered")
    break
```

#### Anthropic

```python
if stop_reason == "end_turn":
    # Natural completion - model is done
    print("Conversation complete!")
    break

elif stop_reason == "tool_use":
    # Model wants to use tools
    execute_and_continue()

elif stop_reason == "max_tokens":
    # Hit token limit
    print("Warning: Response truncated")
    break

elif stop_reason == "stop_sequence":
    # Hit a stop sequence
    break
```

#### Gemini

```python
if finish_reason == 1:  # STOP
    # Check if there are function calls
    has_function_calls = any(
        hasattr(part, 'function_call') and part.function_call
        for part in response.parts
    )

    if has_function_calls:
        # Model wants to call functions
        execute_and_continue()
    else:
        # Natural completion
        print("Conversation complete!")
        break

elif finish_reason == 2:  # MAX_TOKENS
    print("Warning: Response truncated")
    break

elif finish_reason == 3:  # SAFETY
    print("Error: Safety filter triggered")
    break
```

### Why This Matters

**Without checking finish_reason:**

```python
# WRONG - This will miss tool calls!
response = client.chat.completions.create(...)
print(response.choices[0].message.content)  # Might be None if tool_calls present!
```

**Correct approach:**

```python
# RIGHT - Loop until finish_reason is "stop"
while response.choices[0].finish_reason == "tool_calls":
    # Execute tools, add results, call API again
    ...

# Now we know we have final text response
print(response.choices[0].message.content)  # Safe to print
```

### What OpenCode Does Differently

OpenCode handles this automatically:

```typescript
// packages/opencode/src/session/processor.ts
for await (const value of stream.fullStream) {
  switch (value.type) {
    case "tool-call":
      // Auto-execute tool
      await executeTool(value)
      break

    case "finish":
      // Stream ended
      if (value.finishReason === "tool_use") {
        // Model will automatically continue after tools complete
        // No manual loop needed!
      } else if (value.finishReason === "stop") {
        // Done
      }
      break
  }
}
```

**Key differences:**

1. **Automatic tool execution** - No manual loop required
2. **Streaming support** - See tool calls as they arrive
3. **State management** - Track pending/running/completed states
4. **Error recovery** - Automatic retry on transient failures

### Common Mistakes

❌ **Mistake 1: Only calling API once**

```python
response = client.chat.completions.create(...)
print(response.choices[0].message.content)  # ERROR: content is None!
```

❌ **Mistake 2: Not checking finish_reason**

```python
while True:  # Infinite loop!
    response = client.chat.completions.create(...)
    if response.choices[0].message.tool_calls:
        execute_tools()
    else:
        break  # This works but doesn't handle edge cases
```

✅ **Correct: Loop on finish_reason**

```python
while response.choices[0].finish_reason == "tool_calls":
    execute_tools()
    response = client.chat.completions.create(...)

# Now guaranteed to have final response
print(response.choices[0].message.content)
```

## Conclusion

OpenCode's abstraction provides:

- **Unified API** across providers (via Vercel AI SDK)
- **Automatic tool execution** with permission controls
- **Persistent storage** of conversation history
- **State management** for long-running operations
- **Error recovery** and retry logic

Direct SDK usage gives you:

- **Full control** over execution flow
- **Provider-specific features** (e.g., Claude's prompt caching)
- **Lower abstraction overhead**
- **Custom persistence** strategies

Choose based on your needs:

- **Building an agent**: Use OpenCode's abstractions
- **Simple chatbot**: Direct SDKs are sufficient
- **Research/experimentation**: Direct SDKs for flexibility
