# MEMORY.md — persistent facts and preferences

> Installed to `~/.openjarvis/MEMORY.md` by `scripts/bootstrap.sh`.
> Jarvis appends durable, verified facts here over time (and can read them
> from `~/.openjarvis/memory_facts.jsonl` via the memory service).
> Structure it so facts are easy to find and easy to disprove.

## Hard facts

<!-- Things that are true and rarely change. Include the date learned. -->
-

## Preferences

<!-- How I like things done: formats, tools, meeting styles, code style. -->
-

## Learned the hard way

<!-- Mistakes/decisions we shouldn't repeat. One line each, with context. -->
-

## People & orgs

<!-- Who's who: colleagues, vendors, accounts, and how to address them. -->
-

## Superseded

<!-- Old facts that got overwritten — keep the date and the replacement. -->
-

---

### Maintenance rules (for Jarvis)

1. Append facts with a date prefix: `2026-11-21 — …`.
2. Never store secrets, tokens, passwords, or full private file contents here.
3. When a fact changes, move the old one to **Superseded** and add the new one.
4. Prefer the smallest fact that answers future questions — not transcripts.
