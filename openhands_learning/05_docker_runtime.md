# 05: Docker Runtime & Sandbox

**Container Lifecycle and Action Execution**

OpenHands relies on **Docker** for secure, isolated execution environments. The `DockerRuntime` (`openhands/runtime/impl/docker/`) manages this layer.

---

## 1. Architecture

```
[ Agent Controller ]
       | (Action)
       v
[ DockerRuntime ]
       | (HTTP Request)
       v
[ Docker Container ]
    [ Action Execution Server ] (Python HTTP Server)
           |
           +--> Bash Command
           +--> File Read/Write
           +--> Plugin Init
```

## 2. Container Management

*   **Lifecycle**: The runtime starts a dedicated container for each session.
*   **Image**: Uses a base image (configurable in `sandbox_config.py`). It builds a custom runtime image on top if needed.
*   **Identification**: Containers are named with a specific prefix (`openhands-session-...`) to allow cleanup of orphaned containers.
*   **Port Locking**: Uses file-based locking to assign unique ports for the execution server.

## 3. Action Execution

Unlike simple `docker exec`, OpenHands runs a persistent **HTTP Server** inside the container.

*   **Mechanism**: The `DockerRuntime` sends HTTP requests to this internal server.
*   **Endpoints**:
    *   `/execute_action`: Run a command or file op.
    *   `/upload_file`: Upload files.
    *   `/alive`: Health check.
*   **Benefit**: This maintains state (like current working directory, environment variables) better than repeated `docker exec` calls.

## 4. Plugin System

Plugins inject capabilities into the sandbox.

*   **Loading**: Plugins (e.g., Jupyter, AgentSkills) are loaded by the **Action Execution Server** inside the container during startup.
*   **Config**: Defined in `sandbox_config.py`.
*   **Example**: The `JupyterPlugin` starts a Jupyter kernel inside the container, allowing the agent to execute Python cells and get rich output (plots, tables).
