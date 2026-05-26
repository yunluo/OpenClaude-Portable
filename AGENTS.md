# OpenClaude-Portable 项目说明

## 项目概述
便携式 AI 编程环境，从 U 盘或任意文件夹直接运行，无需安装。集成了三种 AI 引擎：
- **OpenClaude** (`@gitlawb/openclaude`) — 通过 Bun 1.3.14 安装，功能最全
- **Kilo CLI** (`@kilocode/cli`) — 通过 `bun install @kilocode/cli` 安装
~~- **OpenCode CLI** (`opencode-ai`) — 通过 `bun install opencode-ai` 安装（已移除）~~

## 入口点
- **Windows (CMD)**: `START.bat`
- **Windows (PowerShell 7)**: `start.ps1` — 纯 PowerShell 实现，无需 CMD 兼容层
- **命令行直达**: `bin/openclaude.ps1` / `bin/kilo.ps1` — 跳过菜单，直接启动

启动后显示 4 选项菜单，自动超时默认为 Normal Mode（10 秒）。

## 运行环境
- **Bun v1.3.14** — 替代原有的 Node.js，单二进制运行
- **引擎安装**: `bun install @gitlawb/openclaude@latest --cache <dir>`
- **引擎启动**: `bun bin/openclaude --setting-sources local --provider <provider> --model <model>`
- **仪表盘启动**: `bun dashboard/server.mjs`
- **本地代理**: `bun tools/local-proxy.js`（Ollama 加速，端口 11435→11434）

## 项目结构
```
├── bin/                       命令行直达入口
│   ├── openclaude.cmd          直接启动 OpenClaude
│   ├── openclaude.ps1          PowerShell 版本
│   ├── kilo.cmd                直接启动 Kilo CLI
│   └── kilo.ps1                PowerShell 版本
├── START.bat                  启动入口 (CMD)
├── start.ps1                  启动入口 (PowerShell 7)
├── engine/                    Bun + Kilo/OpenCode 二进制 + node_modules/
├── data/                      运行时数据（gitignored）
│   ├── ai_settings.env        主配置文件（提供商、API Key、模型）
│   ├── openclaude/            OpenClaude 会话记录
│   ├── ollama/                本地 Ollama 模型
│   ├── config/                重定向的 XDG 配置（Kilo/OpenCode 共享）
│   ├── app_data/              应用数据
│   └── bun-cache/             Bun 缓存
├── tools/                     辅助脚本
│   ├── install-openclaude-engine.ps1  Bun 引擎安装脚本
│   ├── Change_Provider.bat     切换 AI 提供商
│   └── Open_Dashboard.bat      启动 Web 仪表盘
├── dashboard/                 Web 仪表盘（server.mjs + index.html）
├── opencode.json              被 Kilo/OpenCode 读取的项目配置
└── AGENTS.md                  本文件
```

## 配置
主配置文件 `data/ai_settings.env`（环境变量格式）：

| 变量 | 说明 |
|------|------|
| `AI_PROVIDER` | 提供商类型: `openai`/`anthropic`/`gemini`/`ollama` |
| `CLAUDE_CODE_USE_OPENAI` | OpenAI 兼容模式标识 |
| `OPENAI_API_KEY` | API 密钥 |
| `OPENAI_BASE_URL` | OpenAI 兼容 API 端点 |
| `OPENAI_MODEL` | 模型名称 |
| `AI_DISPLAY_MODEL` | 显示用模型名称 |

Kilo 和 OpenCode 共享 `opencode.json` 项目配置，全局配置通过 `XDG_CONFIG_HOME` 重定向到 `data/config/`。

## 仪表盘
- 地址: `http://localhost:3000`
- 基于 SSE 流式聊天 + 内置 agent 循环（支持工具调用）
- 支持 3 种 AI 后端的非流式 agent 调用（OpenAI/Anthropic/Gemini 协议）

## 重要约束
- `data/` 和 `engine/` 目录被 `.gitignore` 排除（下载内容不提交）
- `XDG_CONFIG_HOME`、`HOME`、`APPDATA` 等环境变量重定向到 `data/`，不污染宿主系统
- 所有 AI API 密钥仅存储在 `data/ai_settings.env`
- 无 package.json、无测试框架、无 lint/typecheck 配置

## 开发命令
此项目不包含标准开发工具。修改启动脚本后验证：
- 确保 `START.bat` 语法正确（CMD 入口点）
- 确保 `start.ps1` 语法正确：`pwsh -NoProfile -Command "Invoke-ScriptAnalyzer start.ps1"` 或 `pwsh -NoProfile -File start.ps1 --Quick --Offline` 进行烟雾测试
- 手动测试：运行脚本，验证菜单正常、Bun 下载、引擎安装
