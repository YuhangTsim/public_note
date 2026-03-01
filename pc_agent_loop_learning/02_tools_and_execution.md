# 02: Tool System & Execution

GenericAgent 的工具体系非常精简——只有 **7 个原子工具**，但通过 `code_run` 可以在运行时"制造"新工具。这种设计使其具有极强的扩展性。

---

## 1. 7 个原子工具

| 工具名 | 功能 | 核心能力 |
|--------|------|----------|
| `code_run` | 执行 Python/PowerShell/Bash | 安装依赖、运行脚本、系统操作 |
| `file_read` | 读取文件内容 | 支持行号、关键词搜索、截断 |
| `file_write` | 写入文件 | 支持 overwrite/append/prepend |
| `file_patch` | 精细修改文件 | 替换唯一匹配的文本块 |
| `web_scan` | 获取页面简化 HTML | 过滤边栏/浮动元素，可切换标签页 |
| `web_execute_js` | 完全控制浏览器 | 执行任意 JS，操作 DOM |
| `ask_user` | 人机协作 | 中断任务请求用户输入 |

### 工具设计特点

1. **原子性**：每个工具只做一件事
2. **可组合**：组合使用完成复杂任务
3. **可扩展**：通过 code_run 安装新包后可生成新工具

---

## 2. code_run - 代码执行器

```python
def code_run(code, code_type="python", timeout=60, cwd=None, code_cwd=None, stop_signal=[]):
```

**核心逻辑**：
- **Python 模式**：写入临时文件执行
- **PowerShell/Bash 模式**：直接执行单行命令
- **超时控制**：默认 60 秒，可配置
- **流式输出**：实时返回执行结果

### 使用示例

```python
# 安装依赖
code_run("pip install mootdx", type="powershell")

# 运行脚本
code_run("""
import mootdx
# 选股逻辑
""", type="python", timeout=120)
```

---

## 3. 文件操作工具

### file_read

```python
def file_read(path, start=1, keyword=None, count=200, show_linenos=True):
```

- 支持从指定行开始读取
- 支持关键词搜索（返回关键词上下文）
- 自动截断超长输出

### file_write

```python
def file_write(path, content, mode="overwrite")
```

- `overwrite`：覆盖写入
- `append`：追加
- `prepend`：前置

### file_patch - 精细修改

```python
def file_patch(path: str, old_content: str, new_content: str):
```

**关键约束**：
- 只能替换**唯一匹配**的文本块
- 如果找到多处匹配，返回错误
- 鼓励包含更多上下文以确保唯一性

---

## 4. 浏览器控制工具

### TMWebDriver - 浏览器注入桥接

**不是 Selenium**，而是通过 **Tampermonkey 注入真实浏览器**：

```
GenericAgent → TMWebDriver → Tampermonkey 插件 → 真实浏览器
```

**优势**：
- 保留浏览器登录状态
- 可以操作已打开的标签页
- 不需要每次重新登录

### web_scan

```python
def web_scan(tabs_only=False, switch_tab_id=None):
```

- 获取当前页面的**简化 HTML**（过滤边栏、浮动元素）
- 返回标签页列表
- 支持切换标签页

### web_execute_js

```python
def web_execute_js(script, switch_tab_id=None):
```

- 执行任意 JavaScript
- 完全控制浏览器 DOM
- 支持将结果保存到文件

---

## 5. 人机协作 - ask_user

```python
def ask_user(question: str, candidates: list = None):
```

**返回**：
```python
{
    "status": "INTERRUPT",
    "intent": "HUMAN_INTERVENTION",
    "data": {
        "question": "...",
        "candidates": [...]
    }
}
```

**触发条件**：
- 任务需要用户确认
- 需要用户额外输入
- 遇到无法自动解决的问题

---

## 6. 工具执行的 LLM 协议

### 响应格式要求

LLM 回复必须包含：
1. **代码块**（如需调用 code_run）
2. **`<summary>` 标签**：工具调用摘要
3. **工具调用**：JSON 格式的工具调用

### 二次确认机制

当检测到以下情况时触发：
- 回复仅包含 `<thinking>`/`<summary>` 和大段代码块
- 没有额外自然语言说明
- 未显式调用工具

```python
# 检测逻辑
code_block_pattern = r"```[a-zA-Z0-9_]*\n[\s\S]{100,}?```"
```

---

## 7. 工具的"自我进化"能力

通过 `code_run`，Agent 可以：

1. **安装任意 Python 包**
   ```python
   code_run("pip install some-package", type="powershell")
   ```

2. **编写并执行脚本**
   ```python
   code_run("""
   import some_package
   # 使用包完成任务
   """)
   ```

3. **对接硬件/API**
   - ADB 控制手机
   - OAuth 对接 Gmail
   - 股票数据接口

4. **保存为 SOP**
   - 下次直接调用，无需重新安装
