# OpenClaude — Portable AI Coding Agent

> **Run a full-featured AI coding agent from a USB drive or any folder on Windows — no installation required.**
> Plug in. Launch. Code. Take it anywhere.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows-lightgrey.svg)]()


**🎥 Watch the Setup & Demo Video:** [https://youtu.be/9Dh3kKWFFjg](https://youtu.be/9Dh3kKWFFjg)

[![OpenClaude Portable Demo](https://img.youtube.com/vi/9Dh3kKWFFjg/maxresdefault.jpg)](https://youtu.be/9Dh3kKWFFjg)

---

## What Is This?

**OpenClaude Multi-Platform** is a fully portable AI coding agent powered by the open-source [OpenClaude](https://github.com/gitlawb/openclaude) engine. It bundles a self-contained [Bun](https://bun.sh) runtime (v1.3.14), [Kilo CLI](https://kilo.ai), and [OpenCode CLI](https://opencode.ai) — plus a web-based dashboard — all configurable from `START.bat` (Windows).

Everything runs strictly inside the project folder. No files are written to the host machine.

Everything runs strictly inside the project folder. No files are written to the host machine.

---

## Key Features

| Feature | Details |
|---|---|
| **9 AI Providers** | NVIDIA NIM · DeepSeek · OpenRouter · Google Gemini · Anthropic Claude · OpenAI · Ollama (offline) · LM Studio · Custom OpenAI-compatible API |
| **Zero Footprint** | All data, keys, and logs stay inside `data/` — nothing touches the host system |
| **Web Dashboard** | ChatGPT-style browser UI with agent mode, tool cards, and thinking visualisation |
| **Auto-Update Cache** | Checks for engine updates once per day (skips the network call on repeat launches) |
| **Session Resume** | Resume any interrupted session with `RESUME.bat <session-id>` |
| **Web Dashboard** | ChatGPT-style browser UI with agent mode, tool cards, and thinking visualisation |
| **Limitless Mode** | Optional full-autonomy mode — the agent runs without asking for approval |
| **Cross-Platform** | Shared `data/` folder works across Windows, Linux, and macOS |

---

## Quick Start

```
.\START.bat
```
On first run it automatically downloads Bun (~25 MB) and the OpenClaude engine (~5 MB), then walks you through provider selection. Every subsequent launch skips setup and goes straight to the menu. Kilo CLI and OpenCode CLI are installed on-demand via `bun install` when selected from the menu.

> **First-time setup requires internet.** After that, only API calls need a connection (or none at all if you use Ollama offline mode).

---

## Project Structure

```
OpenClaude-Multi-Platform/
│
├── START.bat                  Windows entry point — handles everything
│
├── data/                      All persistent data
│   ├── ai_settings.env        Active provider, model, and API key
│   ├── openclaude/            Session history and agent memory
│   ├── ollama/                Local Ollama binary and model storage
│   └── config/                Redirected XDG config (Kilo/OpenCode)
│
├── engine/                    Bun runtime + AI engines
│   ├── bun-windows-x64/       Bundled Bun
│   └── node_modules/
│       ├── @gitlawb/openclaude/     OpenClaude engine
│       ├── @kilocode/cli/           Kilo CLI
│       ├── opencode-ai/             OpenCode CLI
│       └── .bin/                    CLI binaries
│
├── tools/                     Helper scripts
│   ├── install-openclaude-engine.ps1  Bun engine install script
│   ├── Change_Provider.bat    Switch AI provider or API key
│   └── Open_Dashboard.bat     Launch web dashboard
│
└── dashboard/                 Web dashboard UI
    ├── server.mjs             Dashboard server (runs on Bun)
    └── index.html             Chat interface
```

---

## Main Menu Options

When you run `START.bat`, you are presented with:

```
1) OpenClaude     — AI coding agent (Normal / Limitless)
2) Kilo CLI       — AI coding agent
3) OpenCode CLI   — AI coding agent
4) Open Dashboard — Web UI at http://localhost:3000
5) Change Provider — Switch model or API key
```
The menu auto-selects **Normal Mode** after 10 seconds if no key is pressed.




## Supported AI Providers

| Provider | Cost | API Key |
|---|---|---|
| **NVIDIA NIM** | Free tier (1 000 credits/month) | [build.nvidia.com](https://build.nvidia.com) |
| **DeepSeek** | Paid API | [platform.deepseek.com](https://platform.deepseek.com) |
| **OpenRouter** | Free + paid models | [openrouter.ai](https://openrouter.ai) |
| **Google Gemini** | Free tier available | [aistudio.google.com](https://aistudio.google.com) |
| **Anthropic Claude** | Paid | [console.anthropic.com](https://console.anthropic.com) |
| **OpenAI** | Paid | [platform.openai.com](https://platform.openai.com) |
| **Ollama** | Free, fully offline | [ollama.com](https://ollama.com) |
| **LM Studio** | Free, local server | [lmstudio.ai](https://lmstudio.ai) |
| **Custom OpenAI-compatible API** | Depends on provider | Provider base URL + optional API key |

---

## LM Studio Setup

LM Studio works through its OpenAI-compatible local server. In LM Studio:

1. Download or select a model.
2. Load the model.
3. Open **Developer > Local Server**.
4. Start the server.
5. Keep the default base URL unless you changed it: `http://localhost:1234/v1`.

Then select **LM Studio** in `START.bat` or the dashboard setup wizard. The setup will check `GET /v1/models` and list the loaded model identifiers. If the check fails, confirm the LM Studio server is running and a model is loaded.

## Custom OpenAI-Compatible Provider

Use **Custom API** for any provider that exposes OpenAI-style endpoints. The setup asks for:

- Base URL, usually ending in `/v1`
- API key, or blank for local providers that do not require one
- Model name, fetched from `/models` when available or entered manually

The saved config uses `AI_PROVIDER=openai`, `CLAUDE_CODE_USE_OPENAI=1`, `OPENAI_BASE_URL`, `OPENAI_API_FORMAT=chat_completions`, `OPENAI_API_KEY`, and `OPENAI_MODEL`. The launcher does not pass `--provider openai` for these providers; it lets the endpoint and model environment variables select the OpenAI-compatible backend so saved Codex/OpenAI profiles do not take over.

---

## Security & Privacy

- **Zero Footprint** — `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, and `CLAUDE_CONFIG_DIR` are all redirected to `data/`, keeping the host system clean.
- **No Telemetry** — Nothing is sent anywhere except your chosen AI provider.
- **API Key Safety** — Keys are stored only in `data/ai_settings.env` on your drive.
- **Approval Mode** — In Normal Mode the agent asks before any file write or shell command.

---

## System Requirements

| Platform | Requirement |
|---|---|
| **Windows** | Windows 10 or later — Bun is bundled, nothing else needed |

**Disk space:** ~25 MB for Bun + ~5 MB for OpenClaude engine. Kilo/OpenCode CLI packages are ~10-30 MB each. Local Ollama models require additional space (800 MB–8 GB depending on model).

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Bun not found` | Run `START.bat` first — it downloads Bun automatically |
| `Automatic Bun download failed` | Check `engine/bun-download.log`, allow `curl` through antivirus/firewall, or download Bun manually from [bun.sh](https://bun.sh) and restart OpenClaude Portable |
| Stuck at `Installing OpenClaude Engine` on USB | Wait at least 10-15 minutes on slow USB media and check `engine/openclaude-engine-install.log`. For first-time setup, a USB 3.x port/drive or running the first install on internal storage and copying the completed folder back to USB is much faster |
| `openclaude: dist/cli.mjs not found` | The engine install was interrupted. Pull the latest launcher and run `START.bat` again; it will repair incomplete installs automatically |
| `npm error could not determine executable to run` | Pull the latest launcher. The app now runs the verified bundled OpenClaude binary instead of falling back to `npx` |
| `Claude Code on Windows requires git-bash` | Install Git for Windows manually from [git-scm.com](https://git-scm.com) and ensure `git` is in your PATH |
| `'D_ARGS' is not recognized` | Old version of START.bat with nested if-blocks. Pull the latest version |
| Ollama response is very slow | Use a smaller model (`gemma3:1b`), or copy models to a local SSD |
| API key rejected | Verify your key at the provider's website; re-run option 4 to update it |
| Port 3000 already in use | The dashboard is already running — open `http://localhost:3000` directly |
| `openclaude` not found in PowerShell | Use `.\RESUME.bat <session-id>` instead of calling `openclaude` directly |

---

## License

MIT — use it, fork it, ship it.
