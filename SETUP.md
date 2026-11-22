# SETUP.md — build your local-first, offline-capable Jarvis in 8 steps

This is the complete implementation guide, **verified against OpenJarvis
1.0.4** (CLI `--help`, config schema, and official docs) with corrections
where the original instructions drifted from the shipped software. Follow it
top to bottom; every step ends with a verification command.

**What you end up with:** an OpenJarvis engine running on your hardware with
Ollama models, two layers of offline memory, this repository registered as a
self-updating skill source, MCP servers and messaging channels wired in, local
voice (STT + TTS), a 24/7 scheduler, and a safe GitHub loop where Jarvis
proposes new skills as pull requests that **you** review.

- **Engine & config:** `~/.openjarvis/` (machine-local, not in git)
- **Skills, recipes, persona, templates:** this repository (in git)
- **Glue:** `scripts/bootstrap.sh` copies/links this repo into `~/.openjarvis/`

---

## Prerequisites

| Requirement | Needed for | Check |
|---|---|---|
| macOS, Linux, or Windows WSL2 | everything | `uname -a` |
| `curl`, `bash` | installer | `curl --version` |
| Node.js ≥ 18 (`npx`) | MCP stdio servers | `npx --version` |
| Docker (optional) | Speaches voice container | `docker --version` |
| GitHub account + `gh` CLI | skill repo, PR loop | `gh auth status` |
| Telegram bot (optional) | channels & digests | token from @BotFather |

Ollama, Python (via `uv`), and the OpenJarvis venv are installed **by the
installer** — you don't need them beforehand.

---

## Step 1 — Install the core OpenJarvis engine

The official installer provisions `uv`, an isolated venv under
`~/.openjarvis/`, Ollama, a hardware-matched starter model, your config file,
and compiles the Rust extension (memory + security) in the background.

**macOS / Linux / WSL2** (inside Ubuntu for WSL2):

```bash
curl -fsSL https://open-jarvis.github.io/OpenJarvis/install.sh | bash
```

**Native Windows (PowerShell):**

```powershell
irm https://open-jarvis.github.io/OpenJarvis/install.ps1 | iex
```

Verify and generate the hardware-auto-detected config:

```bash
jarvis --version          # e.g. jarvis, version 1.0.4
jarvis init               # interactive: detects CPU/RAM/GPU → ~/.openjarvis/config.toml
```

For a non-interactive run that matches this repo's template flow:

```bash
jarvis init --full --engine ollama --no-download --no-scan
```

> **Note — scripted installs:** `jarvis init` writes a *default* config and
> persona files. Right after it, run `./scripts/bootstrap.sh --force` (Step 3)
> to replace them with this repository's templates — everything it overwrites
> is backed up with a timestamp.

> **Tip:** `jarvis self-update` upgrades the framework later while keeping
> your extras. `jarvis doctor` runs diagnostics any time something looks off.

**Fallback (no installer):** `python3 -m venv ~/.openjarvis/venv &&
~/.openjarvis/venv/bin/pip install openjarvis` — requires Python 3.10–3.13.
Heads-up: the PyPI wheel is pure-Python; document memory
(`jarvis memory index/search`) needs the compiled `openjarvis_rust`
extension, which the official installer builds in the background. To build it
by hand: `uv pip install maturin && uv run maturin develop -m
rust/crates/openjarvis-python/Cargo.toml` (rustc ≥ 1.88).

**Verify:**

```bash
jarvis --version && jarvis doctor
```

---

## Step 2 — Pull your offline models (with optional online fallback)

OpenJarvis stays **100% local-first** while no cloud API keys are set in your
environment. Pull a model sized to your RAM/VRAM via Ollama:

```bash
jarvis model list                 # what running engines currently serve

ollama pull qwen3.5:4b            # lighter laptops / CPU-heavy setups
ollama pull qwen3:8b              # standard 16GB RAM or 6GB+ VRAM GPU
ollama pull qwen3.5:9b            # stronger local reasoning on GPU
```

Test the offline agent with tools immediately:

```bash
jarvis ask --agent orchestrator --tools calculator,think "What is 15% of 340?"
```

(`--tools` is a one-off filter here; the persistent tool set lives in
`[agent]` in `config.toml`.)

**Optional online boost** — only when you *want* cloud fallback:

```bash
export OPENROUTER_API_KEY=…   # or ANTHROPIC_API_KEY / OPENAI_API_KEY / GOOGLE_API_KEY
```

Leave them unset to stay strictly offline.

**Verify:**

```bash
ollama list && jarvis ask --agent orchestrator "reply with exactly: offline ok"
```

---

## Step 3 — Persistent local memory & persona files

OpenJarvis gives you two offline memory layers.

### A. Persona markdown files

Three files loaded into every conversation's system prompt, living directly in
`~/.openjarvis/`:

| File | Purpose | In this repo |
|---|---|---|
| `SOUL.md` | tone, brevity, rules, where to push back | [`persona/SOUL.md`](persona/SOUL.md) |
| `USER.md` | your role, goals, active projects, context | [`persona/USER.md`](persona/USER.md) |
| `MEMORY.md` | durable facts/preferences learned over time | [`persona/MEMORY.md`](persona/MEMORY.md) |

`jarvis init` creates starter versions; install this repo's versions (and
re-apply later edits safely):

```bash
./scripts/bootstrap.sh            # first run installs; keeps newer local edits
./scripts/bootstrap.sh --force    # overwrite (timestamped backups are made)
```

Fill in `USER.md` right away — Jarvis reads it every turn. Keep secrets out
of all three files; tokens belong in env vars or `connectors/`.

### B. SQLite document memory

Index local folders so relevant context is injected into every query:

```bash
jarvis memory index ./docs/       # or any notes/knowledge folder
jarvis memory stats               # chunks, backend, size
jarvis memory list                # durable facts captured automatically
```

### C. Storage settings (`~/.openjarvis/config.toml`)

This repo's [`config/config.toml`](config/config.toml) already contains:

```toml
[agent]
context_from_memory = true        # ← retrieval injected each turn

[tools.storage]                   # document memory (SQLite)
default_backend = "sqlite"
context_top_k = 5
context_min_score = 0.1
context_max_tokens = 2048
chunk_size = 512
chunk_overlap = 64

[memory]                          # automatic fact extraction (alias → same store)
enabled = true
backend = "local"
max_facts = 1000
```

> **Note:** `[memory]` is a backward-compat alias that maps onto
> `[tools.storage]` — both blocks configure one object, so keep their key
> names disjoint (as above). Leave `db_path` unset to get
> `~/.openjarvis/memory.db`; db paths do **not** expand `~`, so overrides
> must be absolute.

**Verify:**

```bash
jarvis memory stats && jarvis config show -p ~/.openjarvis/config.toml loaded
```

---

## Step 4 — Your GitHub repo & auto-imported skills

This repository **is** your `my-jarvis-skills` repo. Layout:

```
skills/<name>/SKILL.md      # instructions the agent follows
skills/<name>/skill.toml    # deterministic tool pipeline (optional)
recipes/*.toml              # zero-code compositions (scheduled operators)
persona/                    # SOUL / USER / MEMORY templates
config/                     # config.toml + mcp-servers.json templates
scripts/                    # install · bootstrap · setup-connectors · verify
```

### A. GitHub connector (token — handled safely)

Never `echo '{"token": "ghp_…"}'` into a file: that lands in your shell
history. Use the repo script (reads `$GITHUB_TOKEN` or a **hidden prompt**,
writes mode 600, and `connectors/` is git-ignored):

```bash
./scripts/setup-connectors.sh
# → ~/.openjarvis/connectors/github.json   (chmod 600)
```

The MCP GitHub server additionally reads its token from the environment
(stdio servers inherit the `jarvis` process env):

```bash
export GITHUB_PERSONAL_ACCESS_TOKEN=…   # add to your shell profile
```

### B. Auto-discovery, auto-sync, skill sources

Already present in [`config/config.toml`](config/config.toml):

```toml
[skills]
enabled = true
skills_dir = "~/.openjarvis/skills/"
active = "*"
auto_discover = true
auto_sync = true
max_depth = 5
sandbox_dangerous = true        # warn on shell:execute / network:listen / filesystem:write

[[skills.sources]]              # your own self-automation repo (this repo, main branch)
source = "github"
url = "https://github.com/1jvaibhavreddy-del/jarvis"
auto_update = true

[[skills.sources]]              # Hermes Agent registry (186 skills, 26 categories)
source = "hermes"
auto_update = true

[[skills.sources]]              # OpenClaw official skills (via generic github source)
source = "github"
url = "https://github.com/openclaw/agent-skills"
auto_update = true
```

**Proven result (`jarvis skill sync`):** 56 skills installed total —
44 from **hermes** (creative 40, mlops 23, productivity 19, software-development
18, research 16, finance 9, security 6, …), 9 from **openclaw/agent-skills**
(autoreview, beam, handoff, crabbox, …), plus this repo's own 3.

**Note:** OpenJarvis 1.0.4's built-in `openclaw` source hardcodes
`github.com/openclaw/skills` (404 — repo was renamed), so it is wired through
the generic `github` source instead. Keep `sandbox_dangerous = true` — it
forces a warning whenever any external skill requests high-risk capabilities.

### C. Skill workflow

```bash
jarvis skill list                      # installed skills (incl. this repo's 3)
jarvis skill info github-skill-publisher
jarvis skill sync github               # pull from your GitHub source now
jarvis skill update                    # refresh all configured sources
jarvis skill search "briefing"         # search sources
jarvis skill discover --dry-run        # mine traces → candidate skills
```

Trust tiers: bundled → signed index → arbitrary GitHub URL (SHA256 + sandbox
warning) → this workspace `./skills/` (your code). Review merged skills like
code — after sync they become agent behavior.

**Verify:**

```bash
jarvis skill sources && jarvis skill list | grep morning-research-briefing
```

---

## Step 5 — Platforms, internet tools & external MCP servers

### A. External MCP servers (apps, databases, GitHub, Home Assistant)

[`config/mcp-servers.json`](config/mcp-servers.json):

```json
[
  { "name": "filesystem", "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/your/workspace"] },
  { "name": "github", "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-github"] }
]
```

Installed to `~/.openjarvis/mcp-servers.json` (mode 600) by bootstrap.
`servers` accepts a file path (relative to `config.toml`) **or** inline JSON;
HTTP servers use `{"name": "…", "url": "…", "token": "…"}` — lock the file
down with `chmod 600` when it holds tokens. Quick-add alternative:

```bash
jarvis add github --key "$GITHUB_TOKEN"      # writes a ready-made server entry
jarvis add filesystem
```

Enable in config (already set in the template):

```toml
[tools.mcp]
enabled = true
servers = "mcp-servers.json"
```

> **Notes (1.0.4):**
> - MCP tools are exposed **only to tool-capable agents** (`orchestrator`,
>   `native_react`) — never the default `simple`.
> - If you set `[agent] tools = "…"`, that list **also filters MCP tools** —
>   add their names, or leave `tools` unset to load everything.
> - Unreachable servers log a warning and are skipped; the rest still load.

### B. Personal services & internet search

```bash
jarvis connect gdrive     # Gmail, Calendar, Tasks, Contacts, Drive
jarvis connect spotify    # music control
jarvis connect --list     # connection + sync status
```

When online, tool-capable agents use the built-in `web_search` (and
optionally a self-hosted Firecrawl via `FIRECRAWL_API_URL`) to fetch live
pages. Offline, the same tools simply fail soft — the agent falls back to
local memory and says so.

### C. Control Jarvis from Telegram, Discord, or Slack

No external gateway required — channels connect directly:

```toml
[channel]
enabled = true
default_channel = "telegram"
default_agent = "orchestrator"

[channel.telegram]
bot_token = ""            # or export TELEGRAM_BOT_TOKEN (preferred)
```

```bash
jarvis channel list       # available channel types
jarvis channel status     # connection state of your configured channel
jarvis channel send "hi"  # smoke test
```

**Verify:**

```bash
jarvis channel status && jarvis connect --list
```

---

## Step 6 — Local offline voice (STT + TTS)

The speech subsystem ships local backends — **faster-whisper** (STT) and
**kokoro** (TTS) — alongside cloud options (deepgram, cartesia, elevenlabs,
openai). The template's `[speech]` block is already local-first:

```toml
[speech]
backend = "faster-whisper"
model = "base"            # CPU-friendly; tiny/base/small/medium/large-v3
device = "auto"
compute_type = "int8"
tts_backend = "kokoro"
voice_id = "bm_george"    # bf_emma, bm_lewis, af_*, am_* …
voice_speed = 1.0
```

### Plug-and-play container: Speaches

Faster-Whisper + Kokoro in one container, on port **8001** so it never
collides with `jarvis serve` on 8000:

```bash
# CPU-only machines:
docker run -d --name speaches -p 8001:8000 ghcr.io/speaches-ai/speaches:latest-cpu
# NVIDIA GPUs: use the GPU image + NVIDIA Container Toolkit.
```

Point OpenJarvis's OpenAI-compatible speech endpoints at
`http://localhost:8001/v1` (e.g. `OPENAI_BASE_URL`) if you prefer the
container over the in-process backends.

### Spoken morning digest

```toml
[digest]
enabled = true
schedule = "0 8 * * *"
timezone = "Asia/Kolkata"
tts_backend = "kokoro"    # keep aligned with [speech]
voice_id = "bm_george"
```

```bash
jarvis digest --fresh --text-only   # text first
jarvis digest --fresh               # generate + play spoken digest
```

Voice habits live in [`skills/local-voice-briefing/SKILL.md`](skills/local-voice-briefing/SKILL.md).

**Verify:**

```bash
jarvis digest --fresh --text-only
```

---

## Step 7 — 24/7 automation (scheduler daemon + API/UI)

### A. Full cron support

```bash
uv pip install croniter      # five-field cron; without it only "m h * * *" patterns parse
```

### B. Enable the scheduler

```toml
[scheduler]
enabled = true
poll_interval = 60           # seconds between due-task checks
db_path = ""                 # defaults to ~/.openjarvis/scheduler.db
```

> **Note:** there is **no** `default_agent` key under `[scheduler]` in 1.0.4
> (unknown keys are ignored silently). The agent is chosen **per task** with
> `--agent`.

### C. Register recurring jobs

```bash
# Morning research + inbox digest, every day at 08:00
jarvis scheduler create \
  "Check my tasks, calendar, and top tech news, then send a summary to Telegram" \
  --type cron --value "0 8 * * *" --agent orchestrator

# Hourly background check
jarvis scheduler create \
  "Check for new emails and summarize anything urgent" \
  --type interval --value "3600" --agent orchestrator

jarvis scheduler list                 # IDs, type, status, next run
jarvis scheduler logs <id>            # last 10 executions
jarvis scheduler pause|resume|cancel <id>
```

> **Note:** the prompt is a **positional argument** in 1.0.4
> (`jarvis scheduler create "…" --type …`). Newer docs show `--prompt "…"`;
> if your build rejects one form, use the other.

### D. Start the daemon and the OpenAI-compatible API

```bash
jarvis scheduler start                # foreground; run under systemd/launchd for 24/7

# separate terminal:
jarvis serve --port 8000 --engine ollama --model qwen3:8b
```

> **Note:** `jarvis serve` binds `127.0.0.1` by default. To serve other
> devices, set an API key first — `export OPENJARVIS_API_KEY=$(openssl rand -hex 32)`
> (there is no `jarvis auth` command in 1.0.4; secrets can also live in
> `jarvis vault set <name>`) — startup refuses a non-loopback bind without one.

For the full browser chat UI (energy monitoring, telemetry, trace debugging
at `http://localhost:5173`), run `./scripts/quickstart.sh` from an OpenJarvis
source checkout or install the desktop app from GitHub Releases (connects to
`http://localhost:8000`).

**Recipes as scheduled operators** (this repo's three ship ready to deploy):

```bash
jarvis compose list
jarvis compose show morning-briefing
jarvis compose deploy morning-briefing   # registers its [schedule] with the scheduler
jarvis compose status && jarvis compose stop morning-briefing
```

**Verify:**

```bash
jarvis scheduler list && jarvis status   # daemon state
```

---

## Step 8 — The self-automating GitHub loop (safely)

Tie everything together: Jarvis expands its own abilities **via pull
requests you merge**, never via silent local changes.

### 1. The recipe

[`recipes/self-improving-loop.toml`](recipes/self-improving-loop.toml) is a
zero-code operator that, weekly (Mondays 09:00):

1. `memory_search` for recent failures / "I can't do X yet" moments,
2. `web_search` for existing skills, MCP servers, or APIs that solve it,
3. drafts `skills/<name>/SKILL.md` (+ `skill.toml` when deterministic) on a
   **new branch**,
4. self-checks (secrets, capabilities, conventions in `skills/README.md`),
5. commits, opens a **PR** with test evidence, and
6. reports the PR number to Telegram — then `memory_store`s the decision.

Hard stop conditions are in the prompt: no token/connector → report and stop;
no gap clears the bar → say so; **never push to `main`, never self-merge.**

```bash
jarvis compose show self-improving-loop
jarvis compose deploy self-improving-loop     # needs scheduler daemon running
```

### 2. Review and merge

```bash
gh pr list
gh pr checks <n>
gh pr merge <n> --merge        # or approve via Telegram/CLI — your call
```

### 3. Auto-import closes the loop

With `auto_sync = true` + `auto_update = true` on your
`[[skills.sources]]` GitHub entry, OpenJarvis pulls the merged skill into
`~/.openjarvis/skills/` on its next sync cycle (or immediately:

```bash
jarvis skill sync github && jarvis skill list
```

).

**Verify:**

```bash
jarvis skill list | grep <new-skill> && jarvis skill info <new-skill>
```

---

## Run everything

```bash
./scripts/verify.sh        # OK/WARN/FAIL across core, config, skills, recipes,
                           # scheduler, MCP, channels, voice
```

Manual end-to-end checklist:

```bash
jarvis doctor                                   # environment diagnostics
jarvis ask --agent orchestrator "hello"         # offline agent + tools
jarvis memory stats                             # layer 1 & 2 alive
jarvis skill list && jarvis skill sources       # this repo synced
jarvis compose list                             # recipes discovered
jarvis scheduler list                           # jobs registered
jarvis channel status                           # Telegram connected
jarvis digest --fresh --text-only               # briefing generates
```

---

## Corrections vs. the original guide

| Original instruction | Verified reality (OpenJarvis 1.0.4) |
|---|---|
| `jarvis scheduler create --prompt "…"` | Prompt is positional: `jarvis scheduler create "…" --type … --value …` (newer docs use `--prompt`) |
| `[scheduler] default_agent = "orchestrator"` | Not a real key (silently ignored). Pass `--agent orchestrator` per task |
| `db_path = "~/.openjarvis/…"` in `[scheduler]`/`[tools.storage]` | db paths do **not** expand `~` — leave unset for defaults, or use absolute paths |
| `echo '{"token": "ghp_…"}' > connectors/github.json` | Lands in shell history. Use `scripts/setup-connectors.sh` (`$GITHUB_TOKEN` or hidden prompt, mode 600) |
| — | The GitHub **MCP** server reads `GITHUB_PERSONAL_ACCESS_TOKEN` from the process environment (stdio servers inherit env) |
| `[agent] tools = "…"` as a plain tool list | A list here also **filters MCP tools**; leave unset to load every tool |
| Memory keys under `[tools.storage]` | Correct — plus the `[memory]` alias maps onto the same object; keep key names disjoint |
| Persona files "Jarvis loads at start of every conversation" | They live at `~/.openjarvis/{SOUL,USER,MEMORY}.md`; `jarvis init` creates them; `--persona <name>` selects dirs under `~/.openjarvis/personas/` |
| Speaches on port 8001 | Confirmed as the right choice — `jarvis serve` defaults to 8000 |

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `jarvis: command not found` | Re-open the shell; or add the installer's venv `bin/` to `PATH` (`jarvis config path` shows the home dir) |
| "OpenAI client not available" though Ollama runs | Force engine: `jarvis ask -m ollama/qwen3:8b …`, and make sure `[intelligence]` names `preferred_engine = "ollama"` |
| Qwen coder streams die with `NoneType has no len()` | Downgrade Ollama &lt; 0.21.0, or switch to a non-thinking Qwen variant |
| MCP tools missing in `jarvis ask` | Agent must be tool-capable (`--agent orchestrator`); if `[agent] tools` is set, include the MCP tool names; check `mcp-servers.json` parses (`jarvis config show … toml`) |
| Cron job never fires at minute ≠ hour | Install `croniter` — the built-in parser only handles simple `m h * * *` |
| `channel list` says "No channel type specified" | Set `default_channel` under `[channel]` |
| Scheduler DB error mentioning `~/.openjarvis` | Your config has a `~` db_path — clear it (defaults apply) |
| Digest/port conflicts | Speaches on **8001**, `jarvis serve` on **8000** |
| Skill synced but not listed | `jarvis skill update`; check `skills_dir`, `active = "*"`, and name collisions (workspace beats user beats bundled) |

---

## Security checklist

- [ ] `~/.openjarvis/connectors/github.json` and `mcp-servers.json` are `chmod 600`
- [ ] No `ghp_…` / `sk-…` strings anywhere in this git history (`git log -p | grep -E 'ghp_|sk-'`)
- [ ] Cloud API keys only in env/profile files — never in TOML you commit
- [ ] `sandbox_dangerous = true` left enabled
- [ ] `jarvis serve` on loopback, or API key set before `0.0.0.0`
- [ ] Skill/recipe PRs reviewed before merge — they become agent behavior
- [ ] `jarvis scan` run periodically (data-boundary / secret audit)
