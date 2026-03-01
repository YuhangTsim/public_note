# 04: Self-Bootstrapping 深度分析

> 本文档深入分析 GenericAgent 的**自举能力**（Self-Bootstrapping）设计与实现。

---

## 1. 核心机制总览

```
┌─────────────────────────────────────────────────────────────────┐
│                      自举循环流程                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   用户任务 ──▶  Agent 推理 ──▶ code_run 安装依赖/写脚本        │
│       │              │                    │                    │
│       │              │                    ▼                    │
│       │              │            执行并验证结果                │
│       │              │                    │                    │
│       ▼              ▼                    ▼                    │
│   任务完成    ──▶  start_long_term_update  ──▶  保存为 SOP    │
│                                                             │
│   下次相同任务 ──▶  直接调用 SOP ──▶  秒级响应                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. 关键技术实现

### 2.1 任务完成触发器

**`start_long_term_update` 工具**：

```python
def do_start_long_term_update(self, args, response):
    '''Agent觉得当前任务完成后有重要信息需要记忆时调用此工具。'''
    
    prompt = '''### [总结提炼经验] 
    既然你觉得当前任务有重要信息需要记忆，
    请提取最近一次任务中【事实验证成功且长期有效】的：
    - 环境事实（路径/凭证/配置）→ file_patch 更新 L2
    - 复杂任务经验（关键坑点/前置条件/重要步骤）→ L3 精简 SOP
    '''
    
    # 触发 LLM 主动提炼记忆
    return StepOutcome(result, next_prompt=prompt)
```

**触发条件**：
- Agent 认为任务完成
- 任务中有值得记忆的信息（路径、凭证、流程）
- Agent 主动调用此工具

### 2.2 SOP 存储结构

```
memory/
├── memory_management_sop.md    # L0: 记忆管理宪法
├── global_mem_insight.txt     # L2: 全局事实
├── ljqCtrl_sop.md             # L3: 桌面控制 SOP
├── wechat_reader_sop.md        # L3: 微信读取 SOP
├── gmail_send_sop.md           # L3: Gmail 发送 SOP
└── ...
```

**SOP 文件格式**（示例）：
```markdown
# SOP: 微信消息读取

## 适用场景
用户要求读取微信消息

## 前置依赖
- Python 3.x
- requests 包
- pycryptodome 包（用于解密微信数据库）

## 操作步骤
1. 安装依赖: pip install requests pycryptodome
2. 定位微信数据库: %APPDATA%/Tencent/WeChat/...
3. 使用脚本解密数据库
4. 读取消息并返回

## 注意事项
- 微信版本号影响数据库路径
- 部分手机需要 root 权限
```

### 2.3 记忆层级与更新规则

| 层级 | 存储内容 | 更新方式 | 检索方式 |
|------|----------|----------|----------|
| **L0** | 记忆管理宪法 | 极少变更 | 初始加载 |
| **L2** | 环境事实（路径/凭证/配置）| `file_patch` 精确修改 | 每次工具调用注入 |
| **L3** | 学会的流程（SOP）| 任务完成后追加 | 关键词匹配检索 |

**L2 更新约束**（来自代码）：
```python
# 禁止记录的内容
- 临时变量
- 具体推理过程
- 未验证信息
- 通用常识

# 只记录
- 验证成功的环境事实
- 被坑过多次的核心要点
- 路径/凭证/配置
```

### 2.4 SOP 检索机制

**锚点提示注入**：
```python
def _get_anchor_prompt(self):
    h_str = "\n".join(self.history_info[-20:])
    prompt = f"""
### [WORKING MEMORY]
<history>{h_str}</history>
"""
    if self.key_info:
        prompt += f"\n<key_info>{self.key_info}</key_info>"
    if self.related_sop:
        prompt += f"\n有不清晰的地方请再次读取{self.related_sop}"
    return prompt
```

**触发条件**：
- 读取 memory/ 或 sop/ 路径时
- Agent 决定按 SOP 执行时
- 自动提取 SOP 中的关键点

---

## 3. 与传统 Plugin 系统的本质区别

### 传统 Plugin 架构

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   框架作者   │     │  Plugin     │     │    用户     │
│  预先设计    │────▶│  开发者     │────▶│   安装使用   │
│   工具集     │     │  编写代码    │     │             │
└─────────────┘     └─────────────┘     └─────────────┘
                              │
                              ▼
                     ┌─────────────┐
                     │  版本管理    │
                     │  发布流程    │
                     └─────────────┘
```

**特点**：
- 工具由**开发者**预先定义
- 静态的函数/命令注册
- 需要版本发布流程
- 用户被动接受功能

### GenericAgent SOP 架构

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   框架作者   │     │    Agent    │     │    用户    │
│  提供种子   │────▶│  自我学习    │────▶│  教会任务   │
│   7工具+SOP │     │  记录 SOP    │     │             │
└─────────────┘     └─────────────┘     └─────────────┘
        │                   │
        ▼                   ▼
   5 核心 SOP         文件系统存储
   (宪法)            (纯文本 SOP)
```

**特点**：
- 工具由 **Agent 动态生成**
- SOP 存储为纯文本文件
- 无需版本发布，用户即创作者
- 能力随使用增长

---

## 4. 自举能力的优势

### 4.1 用户定制化

```python
# 传统框架：等待作者开发功能
# GenericAgent：自己教会 Agent

用户: "帮我自动化股票提醒"
Agent: 
  1. 安装 mootdx 包
  2. 编写选股逻辑脚本
  3. 设置定时任务
  4. 保存为「股票提醒 SOP」
  
下次: 用户说一句，Agent 直接执行
```

### 4.2 极小的初始代码量

| 框架 | 初始代码 | 出厂能力 |
|------|----------|----------|
| GenericAgent | ~3,300 行 | 7 原子工具 + 5 SOP |
| OpenHands | ~530,000 行 | 完整工具集 |
| Roo-Code | 大型扩展 | 完整工具集 |

### 4.3 上下文感知

SOP 包含**真实使用环境**的信息：
- 用户的实际文件路径
- 用户的 API 密钥配置
- 用户的偏好设置

---

## 5. 潜在风险与局限

### 5.1 错误传播风险

```
问题 SOP 一旦写入 → 下次直接调用 → 错误重复执行
```

**缓解机制**：
- L0 宪法要求"验证成功"才能记录
- `file_patch` 要求唯一匹配（防止误修改）
- Agent 被要求"精简"要点（减少错误概率）

### 5.2 质量不可控

**问题**：
- SOP 可能包含冗余信息
- 步骤可能不准确
- 缺乏测试验证

**当前缓解**：
- 约束"只记被坑过多次的核心要点"
- 用户可以手动编辑 SOP 文件

### 5.3 记忆膨胀

**问题**：SOP 越来越多，检索效率降低

**当前设计**：
- L3 按需加载（读取时注入）
- Working Memory 只保留最近 20 条历史
- `update_working_checkpoint` 定期清理

---

## 6. 架构启发

### 6.1 "最小可进化"设计

GenericAgent 证明了一个观点：**不需要预装完整工具集**。

**关键洞察**：
- `code_run` 可以安装任何包 → 相当于"万能工具制造机"
- 只需要原子工具，不需要预定义所有功能

**可借鉴点**：
```
┌──────────────────────────────────────────────┐
│           OpenCode/OpenClaw 可能的改进       │
├──────────────────────────────────────────────┤
│                                              │
│  当前：预定义所有 skill/tool                  │
│  改进：提供 "learning skill" 能力            │
│       → Agent 可以自创 skill                 │
│       → 存储为 ~/.opencode/skills/xxx.md    │
│                                              │
└──────────────────────────────────────────────┘
```

### 6.2 动态 Skill 加载

```python
# 传统：启动时加载所有 skills
skills = load_all_skills()

# GenericAgent 风格：按需加载
def get_relevant_sop(task_description):
    # 读取 memory/ 目录
    # 匹配关键词
    # 返回相关 SOP
    return load_matching_sops(task_description)
```

### 6.3 记忆分层设计

| 层级 | 类似 | 用途 |
|------|------|------|
| L0 | BIOS | 元认知、记忆管理原则 |
| L2 | ENV | 环境变量、配置 |
| L3 | Scripts | 业务流程 |

这种分层可以借鉴到其他 Agent 框架。

---

## 7. 核心代码片段

### 7.1 核心循环（92行）

```python
def agent_runner_loop(client, system_prompt, user_input, handler, tools_schema, max_turns=15):
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_input}
    ]
    
    for turn in range(max_turns):
        # 每 10 轮重置工具描述，避免上下文膨胀
        if (turn+1) % 10 == 0: 
            client.last_tools = ''
            
        response = client.chat(messages=messages, tools=tools_schema)
        
        # 解析并执行工具
        outcome = handler.dispatch(tool_name, args, response)
        
        # 检查是否需要退出
        if outcome.should_exit: return {'result': 'EXITED'}
        if outcome.next_prompt is None: return {'result': 'CURRENT_TASK_DONE'}
        
        # 注入工作记忆
        next_prompt = handler.next_prompt_patcher(next_prompt, outcome, turn+1)
        messages = [{"role": "user", "content": next_prompt}]
    
    return {'result': 'MAX_TURNS_EXCEEDED'}
```

### 7.2 记忆更新提示

```python
def next_prompt_patcher(self, next_prompt, outcome, turn):
    # 第 7 轮：警告无效重试
    if turn % 7 == 0:
        next_prompt += "\n\n[DANGER] 已连续执行第 7 轮..."
    
    # 第 10 轮：注入全局记忆
    elif turn % 10 == 0: 
        next_prompt += get_global_memory()
        
    # 第 30 轮：强制 ask_user
    elif turn % 30 == 0:
        next_prompt += "\n\n[DANGER] 已连续执行第 30 轮。你必须 ask_user"
        
    return next_prompt
```

---

## 8. 总结

| 维度 | GenericAgent 自举 | 传统 Plugin |
|------|-------------------|-------------|
| **能力来源** | Agent 自我学习 | 开发者预定义 |
| **存储形式** | 纯文本 SOP | 代码/配置文件 |
| **增长方式** | 使用即增长 | 版本发布 |
| **初始化规模** | ~3,300 行 | 大型框架 |
| **灵活性** | 高（用户定制）| 低（依赖作者）|
| **质量风险** | 可能累积错误 | 通常经过测试 |

**核心哲学**：与其提供一个"完整"的工具集，不如提供"学习"的能力。让每个用户拥有**独一无二的、随使用成长的**Agent。
