# jarvis — your local-first Jarvis, in git

This repository is the **personal, self-updating half** of the OpenJarvis
setup described in the implementation guide: the skills, recipes, config
templates, persona files, and scripts that make *your* Jarvis yours. The
engine itself (OpenJarvis + Ollama) lives outside git, under
`~/.openjarvis/` — this repo feeds and configures it.

> **Local-first by default.** With no cloud API keys exported, every model,
> memory store, voice buffer, and schedule in this repo runs on your own
> hardware. Cloud keys are an optional, explicit upgrade.

## What's inside

| Path | What it is | Goes to |
|---|---|---|
| [`SETUP.md`](SETUP.md) | The full 8-step implementation guide (verified against OpenJarvis 1.0.4) | read me first |
| [`config/config.toml`](config/config.toml) | Annotated config template: engines, memory, skills auto-sync, scheduler, channels, digest, voice, security | `~/.openjarvis/config.toml` |
| [`config/mcp-servers.json`](config/mcp-servers.json) | External MCP servers (filesystem, github) | `~/.openjarvis/mcp-servers.json` |
| [`persona/`](persona/) | `SOUL.md` (behavior), `USER.md` (who you are), `MEMORY.md` (persistent facts) | `~/.openjarvis/*.md` |
| [`skills/`](skills/) | Agent skills — instructions (`SKILL.md`) and pipelines (`skill.toml`) | `~/.openjarvis/skills/` (via auto-sync) |
| [`recipes/`](recipes/) | Zero-code agent compositions: briefing, inbox watch, self-improving loop | `~/.openjarvis/recipes/` (symlinked) |
| [`scripts/`](scripts/) | install · bootstrap · setup-connectors · verify | run from repo root |

## Quick start

```bash
./scripts/install.sh            # Step 1: official OpenJarvis installer + checks
jarvis init --full --engine ollama --no-download
./scripts/bootstrap.sh --force  # apply this repo's config, persona, recipes, skills
# edit ~/.openjarvis/config.toml  → set YOUR_USERNAME in [[skills.sources]]
ollama pull qwen3:8b            # Step 2: model sized to your RAM/VRAM
./scripts/verify.sh             # end-to-end sanity check
```

Full walkthrough (memory, MCP, channels, voice, scheduler, GitHub loop):
**[SETUP.md](SETUP.md)** — eight steps, each with its verification command.

## How the loop closes

```
┌────────────────────────────── git (this repo) ──────────────────────────────┐
│  skills/  ◄── PRs opened by the self-improving-loop recipe  ◄── reviewed by │
│     │                                                    you (or Telegram)  │
│     ▼  auto_sync / jarvis skill sync                                        │
│  ~/.openjarvis/skills/  ──►  orchestrator agent  ──►  new capability        │
│  recipes/ (symlinked)   ──►  jarvis compose deploy ──► scheduler daemon     │
│  config + persona       ──►  every session's behavior                      │
└─────────────────────────────────────────────────────────────────────────────┘
```

1. Merge a skill PR → `auto_sync = true` pulls it into `~/.openjarvis/skills/`
   on the next session start.
2. The `self-improving-loop` recipe (weekly) drafts the *next* skill as a
   branch + PR — it never pushes to `main` and never self-merges.
3. Scheduler jobs (`jarvis scheduler start`) and operators
   (`jarvis compose deploy`) run 24/7 and report to your channel.

## Safety rules baked in

- **No secrets in git.** `connectors/`, `*.token`, and `.env*` are
  ignored; `scripts/setup-connectors.sh` writes `github.json` with mode 600
  from a hidden prompt or `$GITHUB_TOKEN` — never from shell history.
- **`sandbox_dangerous = true`** — OpenJarvis warns whenever any skill asks
  for `shell:execute`, `network:listen`, or `filesystem:write`.
- **Branch + PR only** — recipes and skills that touch GitHub are prompt-bound
  to open pull requests for human review; self-merge is forbidden.
- **Loopback server** — `jarvis serve` binds `127.0.0.1` unless you add an
  API key and deliberately open it up.

## References

- Project: [github.com/open-jarvis/OpenJarvis](https://github.com/open-jarvis/OpenJarvis)
- Install: `curl -fsSL https://open-jarvis.github.io/OpenJarvis/install.sh | bash`
- Skills spec: [agentskills.io](https://agentskills.io/specification)
- This repo as a skill source:
  `[[skills.sources]] source = "github"` + `url = "https://github.com/<you>/<repo>"`
