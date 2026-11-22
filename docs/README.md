# docs/ — your local knowledge base

Put plain Markdown notes here (meeting notes, project specs, references,
exported wikis), then index them once:

```bash
jarvis memory index ./docs/
jarvis memory stats
```

Indexed chunks are stored in `~/.openjarvis/memory.db` (SQLite, fully
offline) and retrieved with `context_top_k = 5` /
`context_min_score = 0.1` on every turn where `context_from_memory = true`.

Tips:

- One topic per file; descriptive filenames beat folders.
- Re-run `jarvis memory index ./docs/` after adding or editing files.
- Nothing secret belongs here unless you're comfortable with it being
  injected into prompts — see the security checklist in SETUP.md.

This README is itself indexable, so the command above works out of the box.
