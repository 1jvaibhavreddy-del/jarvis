---
name: github-skill-publisher
description: Research a missing capability, draft a new skill for this repository, and open a pull request for human review — the safe half of the self-improving loop
license: MIT
metadata:
  openjarvis:
    version: "0.1.0"
    author: jarvis
    tags: [github, automation, self-improvement, skills]
---

# github-skill-publisher

Purpose: turn "Jarvis can't do X yet" into a reviewed, merged skill in this
repository — **never** into a silent local change.

## Workflow

1. **Identify the gap** — from the request or from `jarvis skill discover`
   candidates. State the capability in one sentence.
2. **Research** (run the `github-skill-publisher` pipeline, or step manually):
   - `memory_search` for prior attempts and preferences.
   - `web_search` for existing skills, APIs, or MCP tools that already do it.
   - `think` to decide: compose an existing skill, or author a new one?
3. **Draft** the skill in a worktree:
   - Create a branch: `git checkout -b skill/<skill-name>`.
   - Write `skills/<skill-name>/SKILL.md` (frontmatter: `name`,
     `description`, `metadata.openjarvis.*`) and, if the workflow is
     deterministic, `skills/<skill-name>/skill.toml` with explicit
     `required_capabilities`.
   - Follow `skills/README.md` conventions exactly.
4. **Self-check**
   - `jarvis skill info <skill-name>` from the repo root (workspace
     precedence picks it up).
   - Validate: no secrets, no `shell:execute` unless unavoidable, no network
     listen, description under ~1024 chars.
5. **Open a PR — never merge your own**
   - `git push -u origin skill/<skill-name>`
   - `gh pr create --title "skill: <name> — <capability>" --body <summary>`
   - PR body must include: the gap, why a skill is the right fix, declared
     capabilities, and test evidence (`jarvis skill run` output).
6. **After merge** — with `auto_sync = true` the skill appears in
   `~/.openjarvis/skills/` on the next session start; verify with
   `jarvis skill list`.

## Hard rules

- Branch + PR only. Never push directly to `main`; never approve or merge
  your own PR.
- Never commit tokens, connector files, or personal data.
- If the gap is better solved by config or an existing skill, say so and
  stop — don't force a new skill.
