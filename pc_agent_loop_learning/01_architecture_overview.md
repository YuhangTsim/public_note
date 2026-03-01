# 01: High-Level Architecture & Design

**GenericAgent (pc-agent-loop)** 是一个极简的自主 Agent 框架，约 **3,300 行 Python 代码**，让任意 LLM 获得对 PC 的物理级控制能力。其核心哲学是 **"Seed Philosophy"（种子哲学）**——以极简的 5 个核心 SOP 为种子，Agent 在使用中自主发现、学习并记录新能力。

---

## 1. 系统架构

```mermaid
graph TD
    User[用户] -->|Streamlit/Telegram/CLI| Launch[launch.pyw]
    
    subgraph "GenericAgent Core"
        Launch -->|Web UI| stapp[stapp.py - Streamlit]
        Launch -->|Bot| tgapp[tgapp.py - Telegram]
        Launch -->|CLI| agentmain[agentmain.py]
        
        agentmain --> Loop[agent_loop.py - 核心循环 92行]
        Loop --> Handler[ga.py - Tool Handler]
        
        Handler -->|7 Atomic Tools| Tools
        Tools -->|"code_run"| CodeExec[Python/PowerShell执行]
        Tools -->|"file_xxx"| FileOps[文件操作]
        Tools -->|"web_xxx"| Browser[浏览器控制]
        Tools -->|"ask_user"| Human[人机协作]
        
        Loop --> Memory[Memory System]
        
        subgraph "Memory"
            Memory --> L0[L0: Meta-SOP - 记忆管理宪法]
            Memory --> L2[L2: Global Facts - 环境/凭证/路径]
            Memory --> L3[L3: Task SOPs - 学会的流程]
        end
    end
    
    Browser -->|"TMWebDriver"| RealBrowser[真实浏览器注入]
    CodeExec -->|"ADB"| Mobile[移动设备控制]
```

### 核心组件

| 文件 | 行数 | 职责 |
|------|------|------|
| `agent_loop.py` | ~92 | 感知-思考-行动循环 (Sense-Think-Act) |
| `ga.py` | ~600+ | 工具定义与执行Handler |
| `sidercall.py` | - | LLM 通信（多后端支持）|
| `agentmain.py` | - | 会话编排 |
| `TMWebDriver.py` | - | 浏览器注入桥接（非 Selenium，通过 Tampermonkey）|
| `simphtml.py` | - | HTML→文本清洗 |

### 界面层

| 文件 | 类型 | 说明 |
|------|------|------|
| `stapp.py` | Streamlit Web UI | 网页交互界面 |
| `tgapp.py` | Telegram Bot | 消息机器人 |
| `launch.pyw` | 桌面启动器 | 一键启动 + 悬浮窗 |

---

## 2. 设计哲学：自举 (Seed Philosophy)

多数 Agent 框架以**成品**形态发布。GenericAgent 以**种子**形态发布。

```
用户让 Agent 做新事
        ↓
Agent 自己摸索方法（安装依赖、写脚本、测试）
        ↓
把流程保存为新 SOP
        ↓
下次直接调用
```

**关键差异**：
- **传统框架**：出厂即有完整工具集
- **GenericAgent**：出厂只有 7 个原子工具 + 5 个核心 SOP，剩余能力由 Agent 自主构建

---

## 3. 与其他框架对比

| 特性 | GenericAgent | OpenClaw | Claude Code |
|------|--------------|----------|-------------|
| **代码量** | ~3,300 行 | ~530,000 行 | 开源（大）|
| **部署方式** | `pip install` + API key | 多服务编排 | CLI + 订阅 |
| **浏览器** | 注入真实浏览器（保留登录态）| 沙箱/无头 | MCP 插件 |
| **OS 控制** | 键鼠、视觉、ADB | 多 Agent 委派 | 文件 + 终端 |
| **自我进化** | 自主生长 SOP & 工具 | 插件生态 | 会话间无状态 |
| **出厂配置** | 10 .py + 5 SOP | 数百模块 | 丰富 CLI 工具 |

### 核心优势

1. **极简**：无需 Electron、Docker、Mac Mini
2. **真实浏览器注入**：通过 Tampermonkey 注入，保留登录状态
3. **自我进化**：每个任务解决后变成永久技能
4. **移动端支持**：可在 Android Termux 上运行

---

## 4. 关键特性

- **7 个原子工具**可以"制造"新工具（通过 code_run 安装任意包）
- **5 个核心 SOP** 定义了 Agent 的思考、记忆和行动方式
- **多层记忆系统**：L0（宪法）、L2（事实）、L3（流程）
- **人机协作**：ask_user 支持任务中断和用户确认
