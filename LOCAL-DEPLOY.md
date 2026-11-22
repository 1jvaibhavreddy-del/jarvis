# LOCAL-DEPLOY.md — Run Jarvis on your own machine, offline, with full device + platform access

Companion to [`SETUP.md`](SETUP.md) (8-step install) and [`config/config.toml`](config/config.toml).
This document answers three questions end-to-end:

1. **How do I get Jarvis on my local machine and keep it offline?**
2. **How do I give it access to my device and my platforms?**
3. **How does it develop itself and stay complete on skills?**

Everything below is verified against OpenJarvis **1.0.4**. Commands are run on
**your machine** (the sandbox where this repo was scaffolded has no Docker,
Ollama, or Rust toolchain — that's expected; this guide is for your real
device).

---

## Part 1 — Jarvis on your machine, fully offline

### 1.1 One-shot install (recommended)

On macOS / Linux / WSL2:

```bash
curl -fsSL https://open-jarvis.github.io/OpenJarvis/install.sh | bash
```

The installer provisions `uv`, an isolated venv under `~/.openjarvis/`,
Ollama, a hardware-matched starter model, your config file, and compiles the
Rust extension (memory + security) in the background.

Verify:

```bash
jarvis --version          # jarvis, version 1.0.4
jarvis init               # interactive hardware detection → ~/.openjarvis/config.toml
```

### 1.2 Pure-offline operation

Jarvis is **offline by default** — it runs against local Ollama models and
never calls a cloud API unless you explicitly export a key:

```bash
# Offline: no keys exported. Everything (model, memory, skills) is local.
jarvis serve                 # local API server on 127.0.0.1:8000

# Optional online boost (only when you want it):
export OPENROUTER_API_KEY=...   # or ANTHROPIC_API_KEY / OPENAI_API_KEY / GOOGLE_API_KEY
```

`provider = "local"` + `preferred_engine = "ollama"` in
[`config/config.toml`](config/config.toml) is what keeps it offline. The
installer pulls the model once; after that, inference is fully local.

### 1.3 Model sizing (pick by your RAM/VRAM)

| Model | VRAM | RAM | Good for |
|---|---|---|---|
| `qwen3.5:4b` | none (CPU) | 4 GB | everyday tasks, battery-friendly |
| `qwen3:8b` (default) | 6–8 GB | 16 GB | balanced — recommended |
| `qwen3.5:9b` | 10–12 GB | 24 GB | heavier reasoning |

```bash
ollama pull qwen3:8b      # pull once; runs offline afterwards
```

### 1.4 Verify the offline core

```bash
jarvis config show loaded          # config parses, engine = ollama, model = qwen3:8b
./scripts/verify.sh                # 15 OK / 3 WARN / 0 FAIL (WARNs = optional infra)
```

`verify.sh` checks: jarvis core, config, persona, Ollama, memory, skills,
recipes, scheduler, MCP, channels, voice. Run it after every change.

---

## Part 2 — Device & platform access

Jarvis reaches your device and platforms through **three layers**:
**skills** (agent workflows), **MCP servers** (tool bridges to apps), and
**channels** (messaging in/out). All three are configured in
[`config/config.toml`](config/config.toml).

### 2.1 Local device skills (already installed)

The synced registry includes device-native skills — no extra setup beyond
their platform dependencies:

| Skill | What it gives Jarvis | Needs |
|---|---|---|
| `computer-use` | Drives your desktop: click, type, screenshots, background-first | macOS/Linux desktop |
| `apple-notes` | Create / search / edit Apple Notes via `memo` CLI | macOS + `memo` CLI |
| `apple-reminders` | Add / list / complete reminders via `remindctl` | macOS + `remindctl` CLI |
| `findmy` | Locate your Apple devices | macOS |
| `google-workspace` | Gmail, Calendar, Docs, Sheets, Drive | Google account + OAuth |
| `obsidian` | Read/write your Obsidian vault | Obsidian vault on disk |
| `browser` / `web-*` | Web browsing, scraping, research | network (optional) |

> These are installed by the sync in Part 3. Platform-specific ones only
> activate on the matching OS.

### 2.2 MCP servers — bridges to your platforms

MCP servers expose external tools (GitHub, Home Assistant, databases,
browsers) to Jarvis. Config lives in
[`config/mcp-servers.json`](config/mcp-servers.json); `[tools.mcp] servers`
accepts a file path or inline JSON.

**Canonical server schema** (verified against the official docs):

```json
{
  "servers": {
    "github": {
      "name": "github",
      "url": "https://api.github.com/mcp",
      "token": "<your-token>",
      "include_tools": ["*"]
    }
  }
}
```

Key facts:
- **No `env` field** — stdio servers inherit Jarvis's environment, so pass
  tokens via env vars (`GITHUB_PERSONAL_ACCESS_TOKEN`) instead.
- **Token-bearing servers**: `jarvis add github --key "$GITHUB_TOKEN"`
  writes a mode-600 file under `~/.openjarvis/mcp/`.
- **One broken server doesn't block others** — safe to add incrementally.
- **MCP tools only reach tool-capable agents** — the default `orchestrator`
  agent has them; leave `[agent] tools` unset so MCP isn't filtered out.
- stdio servers (e.g. `npx -y @modelcontextprotocol/server-...`) need
  Node.js ≥ 18.

**Recommended starter set** (add as you go):

| Server | Access to | Install |
|---|---|---|
| GitHub | repos, PRs, issues, releases | `jarvis add github --key "$GITHUB_TOKEN"` |
| Home Assistant | smart-home devices & automations | stdio `ha-mcp` via npx |
| Postgres / SQLite | your databases | stdio MCP servers |
| Obsidian | vault files | already a skill; MCP optional |
| Browser | web automation | `browser-use` MCP |

### 2.3 Messaging channels — talk to Jarvis from anywhere

[`channel`] config + `setup-connectors.sh` wire Telegram/Slack/etc.:

```bash
# Telegram (from @BotFather):
export TELEGRAM_BOT_TOKEN=123456:ABC-DEF
./scripts/setup-connectors.sh        # writes ~/.openjarvis/connectors/*.json (mode 600)

# Flip on in config:
# [channel] enabled = true
```

With channels on, your **morning-briefing** and **inbox-watch** recipes can
push results to Telegram, and Jarvis can receive commands from it.

### 2.4 Voice (offline)

`[speech]` in config: faster-whisper STT (local) + kokoro TTS (local).
Faster alternative: Speaches container on port **8001** (Jarvis serve runs on
**8000** — don't collide). Details in SETUP.md Step 6.

---

## Part 3 — Self-development: how Jarvis grows and stays complete

### 3.1 All skills, always current

[`config/config.toml`](config/config.toml) registers **4 sources**;
`jarvis skill sync` pulls everything:

| Source | URL | Skills |
|---|---|---|
| Your repo | `github.com/1jvaibhavreddy-del/jarvis` | 3 (your own) |
| Hermes Agent (full) | `NousResearch/hermes-agent` | 186 |
| OpenClaw agent-skills | `openclaw/agent-skills` | 9 |
| OpenClaw clawhub | `openclaw/clawhub` | 69 |

```bash
jarvis skill sync                 # bulk install/update from all sources
jarvis skill list                 # everything installed (262+ skills)
jarvis skill update                # refresh all sources
jarvis skill search "meeting"     # find skills by name/description
jarvis skill info <name>          # inspect one skill
```

**Current state: 262 skills installed** (185 hermes + 68 clawhub + 9
agent-skills + 3 local). 1 skipped: `google_meet` (upstream naming bug —
underscore in skill name, rejected by the spec parser; 99.6% coverage).
`auto_update = true` on every source means a new `jarvis` session pulls
fresh skills automatically.

> **Why the generic `github` source, not the built-in `hermes`/`openclaw`
> sources?** The built-in `hermes` resolver only walks `skills/<category>/`
> (44 skills) and ignores `optional-skills/` (142 more); the built-in
> `openclaw` source points at a repo that no longer exists (404). The
> generic `github` source recursively finds every `SKILL.md`, so it gets
> the complete catalog.

### 3.2 The self-improving loop (Jarvis writing its own skills)

`recipes/self-improving-loop.toml` runs on a schedule:

1. `memory_search` for recent failures / "I can't do X yet" moments.
2. Drafts a new skill from the failure pattern.
3. Writes it into this repo's `skills/` as a draft.
4. Opens a **pull request** via `github-skill-publisher` (Skill 3).
5. Reports the PR number to Telegram.
6. `memory_store`s the decision.

**You review and merge** — Jarvis never self-installs unreviewed code.
Trust tiers: bundled → signed index → arbitrary GitHub URL (SHA256 +
sandbox warning) → your workspace `./skills/` (your code).
`sandbox_dangerous = true` forces a warning on any skill requesting
`shell:execute`, `network:listen`, or `filesystem:write`.

### 3.3 Memory — Jarvis remembers you

Two layers (STEP 3 in SETUP.md):

- **Facts** (`[memory]`): durable facts extracted from conversations, stored
  in `~/.openjarvis/memory_facts.jsonl` — works with no Rust extension.
  `jarvis memory list` to inspect; seeded with 4 facts already.
- **Documents** (`[tools.storage]`): `jarvis memory index ./docs/` indexes
  your notes into SQLite; `context_from_memory = true` injects the right
  context each turn. Needs the compiled `openjarvis_rust` extension — the
  installer builds it automatically.

### 3.4 Scheduled automations

```bash
jarvis scheduler create "Morning research briefing" --type cron --value "0 8 * * *" --agent orchestrator
jarvis scheduler list
jarvis scheduler start          # background daemon
```

Recipes in [`recipes/`](recipes/) (`morning-briefing`, `inbox-watch`,
`self-improving-loop`) are ready-made operators. Full 5-field cron needs
`uv pip install croniter`.

---

## Part 4 — Your completion checklist

Run these on your machine, in order. Every step has a verification command.

```bash
# 1. Engine + models
curl -fsSL https://open-jarvis.github.io/OpenJarvis/install.sh | bash
jarvis --version && jarvis init && ollama pull qwen3:8b
# The installer includes the server extra; if you installed via pip instead:
#   pip install "openjarvis[server]"      # required for `jarvis serve`
```

# 2. This repo onto the machine
git clone https://github.com/1jvaibhavreddy-del/jarvis.git
cd jarvis && ./scripts/bootstrap.sh --force

# 3. Skills (all of them)
jarvis skill sync && jarvis skill list | wc -l      # expect 262+

# 4. Memory
jarvis memory index ./docs/ && jarvis memory stats
jarvis memory list                                    # durable facts

# 5. Platform access
jarvis add github --key "$GITHUB_TOKEN"             # or edit mcp-servers.json
export TELEGRAM_BOT_TOKEN=... && ./scripts/setup-connectors.sh

# 6. Automation
uv pip install croniter
jarvis scheduler create "Morning briefing" --type cron --value "0 8 * * *" --agent orchestrator
jarvis scheduler start

# 7. Voice
docker run -p 8001:8001 ghcr.io/speaches/speaches:latest-cpu   # or local faster-whisper

# 8. Everything checks out
./scripts/verify.sh                                  # target: 0 FAIL
```

**Result:** Jarvis running offline on your hardware, with 262 skills,
two-layer memory, device/platform access through MCP + channels, a 24/7
scheduler, and a safe self-improving loop where new skills arrive as
reviewed pull requests.

---

## Troubleshooting quick reference

| Symptom | Fix |
|---|---|
| `MemoryBackendUnavailable: openjarvis_rust` | Rust extension missing — re-run the installer (builds it) or `uv run maturin develop -m rust/crates/openjarvis-python/Cargo.toml` (needs rustc ≥ 1.88) |
| `No such option '--prompt'` | Scheduler is 1.0.4: prompt is **positional**, not a flag |
| MCP tools not reaching the agent | Agent must be tool-capable (`orchestrator`); leave `[agent] tools` unset |
| Skill not found after sync | Check `jarvis skill sources`; github source resolves only the **default branch** — push + merge first |
| `db_path` ignored | `~` is not expanded — use absolute paths |
| Ollama not found | `ollama serve` in another terminal; model pulled via `ollama pull` |
| Cron jobs don't fire | `uv pip install croniter` for 5-field cron |

Full walkthrough and corrections table: [`SETUP.md`](SETUP.md).
