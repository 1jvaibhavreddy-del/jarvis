# recipes/ — zero-code agent pipelines

A **recipe** is a TOML file that wires all five OpenJarvis primitives —
Intelligence, Engine, Agent, Tools, Learning — into one runnable
composition. Two kinds:

| Kind | `[recipe].kind` | Lifecycle |
|---|---|---|
| **discrete** | omitted | one-shot: `jarvis compose run <name> "<query>"` |
| **operator** | `"operator"` | persistent + scheduled: `jarvis compose deploy <name>` |

## Discovery

`jarvis compose` discovers TOML recipes from:

1. the bundled `recipes/data/` directory inside the OpenJarvis package, and
2. **`~/.openjarvis/recipes/`** — this repo's `recipes/` folder is symlinked
   there by `scripts/bootstrap.sh`, so edits here go live immediately.

```bash
jarvis compose list                 # everything discovered
jarvis compose show morning-briefing
jarvis compose run <name> "<query>" # single query (discrete recipes)
jarvis compose deploy <name>        # activate an operator's schedule
jarvis compose status               # running operators
jarvis compose stop <name>          # deactivate
```

`deploy` registers the recipe's `[schedule]` with the task scheduler, so the
scheduler daemon (`jarvis scheduler start`) must be running.

## File conventions

```toml
[recipe]
name = "my-operator"          # == filename stem, kebab-case
kind = "operator"             # omit for discrete recipes
description = "One line — what and why"
version = "0.1.0"

[intelligence]
model = "qwen3:8b"            # any model your engines can serve

[engine]
key = "ollama"                # engine from [engine] in config.toml

[agent]
type = "orchestrator"         # tool-capable agent (MCP tools only load here)
max_turns = 20
temperature = 0.4
tools = ["web_search", "think", "memory_search", "memory_store", "channel_send"]
system_prompt = """…"""       # the whole workflow, step by step

[schedule]                    # operators only
type = "cron"                 # cron | interval | once
value = "0 8 * * *"           # 5-field cron | seconds | ISO-8601 UTC

[channels]                    # operators only — where output is delivered
output = ["telegram"]
```

## Safety rules (this repo)

- Prefer listed tools over broad grants; leave `shell_exec` out unless the
  recipe genuinely needs a shell, and keep `sandbox_dangerous = true`.
- System prompts must state the stop condition: if a connector, token, or
  MCP server is missing, report it instead of improvising.
- Anything that pushes to GitHub must branch + open a PR — never push to
  `main`, never self-merge (see `self-improving-loop.toml`).
