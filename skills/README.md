# skills/ — reusable agent skills

A **skill** is a directory containing `skill.toml` (a deterministic tool
pipeline), `SKILL.md` (instructions the agent follows), or both.

```
my-skill/
├── SKILL.md          # markdown instructions (agentskills.io frontmatter)
├── skill.toml        # structured pipeline steps
├── scripts/          # optional helpers — skipped on import unless --with-scripts
├── references/       # optional deep docs
└── examples/         # optional usage examples
```

## How these skills reach Jarvis

1. **Auto-sync (preferred):** `config/config.toml` registers this repository as a
   `[[skills.sources]]` GitHub source with `auto_update = true`. With
   `auto_sync = true`, OpenJarvis pulls merged skills into
   `~/.openjarvis/skills/` on the next session start — or run
   `jarvis skill sync github` / `jarvis skill update` manually.
2. **Workspace precedence:** running `jarvis` from this repository root loads
   `./skills/` directly at the highest priority (over user and bundled skills).
3. **Manual install:** `jarvis skill install github:USER/REPO/skills/<name> --url https://github.com/USER/REPO`

## Conventions in this repo

- One capability per directory; directory name == skill name (kebab-case).
- Every skill has a `SKILL.md` with YAML frontmatter (`name`, `description`
  required) following the [agentskills.io](https://agentskills.io/specification)
  open standard; OpenJarvis metadata goes under `metadata.openjarvis`.
- Pipelines (`skill.toml`) may only call well-known tools
  (`web_search`, `http_request`, `think`, `memory_search`, `memory_store`,
  `calculator`, …) and other skills (`skill_name = "…"`).
- Declare `required_capabilities` honestly — `network:fetch`,
  `filesystem:read`, `filesystem:write`, `memory:read`, `memory:write`,
  `shell:execute`. Anything dangerous (`shell:execute`, `network:listen`,
  `filesystem:write`) triggers a sandbox warning when `sandbox_dangerous = true`.
- No `scripts/` folders unless the code has been reviewed; imported scripts are
  skipped by default (`--with-scripts` opts in).

## Useful commands

```bash
jarvis skill list                    # installed skills
jarvis skill info <name>             # details for one skill
jarvis skill run <name> -a k=v       # execute a pipeline directly
jarvis skill search <query>          # search configured sources
jarvis skill discover --dry-run      # mine traces for new skill candidates
jarvis skill show-overlay <name>     # optimized description/few-shot overlay
```

## Security tiers

| Source | Trust | Runtime |
|---|---|---|
| Bundled with OpenJarvis | implicit | full within declared capabilities |
| Official signed index | SHA256 + Ed25519 | capability-gated |
| Arbitrary GitHub URL | SHA256 only | capability-gated + sandbox warning |
| This workspace `./skills/` | you (local code) | trusted |

Review any PR that adds skills exactly like code — it becomes agent behavior
after merge.
