# GenericAgent (pc-agent-loop) Learning

> GitHub: [lsdefine/pc-agent-loop](https://github.com/lsdefine/pc-agent-loop)
> 
> 一个极简的自主 Agent 框架，约 3,300 行 Python 代码，让任意 LLM 获得对 PC 的物理级控制能力。

---

## 目录

| 文档 | 内容 |
|------|------|
| [01: Architecture Overview](01_architecture_overview.md) | 系统架构、设计哲学、与其它框架对比 |
| [02: Tools & Execution](02_tools_and_execution.md) | 7 个原子工具、代码执行器、浏览器控制 |
| [03: Agent Loop & Memory](03_agent_loop_and_memory.md) | 核心循环、多层记忆系统、SOP 自举 |
| [04: Self-Bootstrapping Analysis](04_self_bootstrapping_analysis.md) | 深度分析：自举能力设计与实施 |

---

## 快速概览

### 核心特点

- **极简代码**：~3,300 行 Python
- **自举哲学**：5 个核心 SOP 为种子，Agent 自我进化
- **真实浏览器注入**：通过 Tampermonkey 保留登录态
- **全平台控制**：键鼠、终端、文件、屏幕、ADB

### 7 个原子工具

| 工具 | 功能 |
|------|------|
| `code_run` | 执行 Python/PowerShell |
| `file_read/write/patch` | 文件操作 |
| `web_scan` | 页面感知 |
| `web_execute_js` | 浏览器 DOM 控制 |
| `ask_user` | 人机协作 |

### 记忆层级

- **L0**: Meta-SOP（记忆管理宪法）
- **L2**: Global Facts（环境/凭证/路径）
- **L3**: Task SOPs（学会的流程）

---

## 对比参考

| 框架 | 代码量 | 特点 |
|------|--------|------|
| **GenericAgent** | ~3,300 行 | 自举进化、极简 |
| Letta | - | 分层记忆、长期对话 |
| OpenHands | ~530,000 行 | 软件工程、事件流 |
| OpenCode | - | 任务驱动、会话历史 |

---

## 相关笔记

- [Letta Learning](../letta_learning/) - 另一个 memory-centric agent 框架
- [OpenCode Learning](../opencode_learning/) - 任务驱动的编码 Agent
- [OpenClaw Learning](../openclaw_learning/) - 多平台消息机器人
