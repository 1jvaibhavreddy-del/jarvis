---
name: morning-research-briefing
description: Assemble a concise morning briefing from tasks, calendar, and top tech news, then deliver it to the configured channel
license: MIT
metadata:
  openjarvis:
    version: "0.1.0"
    author: jarvis
    tags: [research, productivity, briefing]
---

# Morning research briefing

When asked for a morning briefing (or when triggered by the scheduler /
digest job), follow this workflow:

1. **Gather**
   - Tasks: pull open tasks and due-today items (Google Tasks / `jarvis connect gdrive`).
   - Calendar: list today's and tomorrow's events; note conflicts and buffers.
   - News: `web_search` for the top stories in my configured topics
     (default: AI/ML, developer tooling, Indian tech business).

2. **Cross-reference**
   - Verify any single-source claim against a second source; mark it
     "unconfirmed" otherwise.
   - Check `memory_search` for yesterday's briefing — carry forward
     unresolved threads and note what changed.

3. **Synthesize** into this shape (≤ 300 words):

   ```
   BRIEFING — <date>
   1. Today's priorities   (max 3 items, mapped to calendar/tasks)
   2. Top stories          (3–5 bullets, each with source + why it matters)
   3. Watch-outs           (conflicts, deadlines, unconfirmed items)
   4. From yesterday       (follow-ups only)
   ```

4. **Deliver**
   - Chat: print the briefing.
   - Channel: send via the configured output channel (e.g. Telegram) using
     the channel's send path — never invent a destination.
   - Voice: if `[speech]` is configured, offer a spoken version via the
     local TTS backend (see the `local-voice-briefing` skill).

5. **Remember**
   - `memory_store` the date + top 3 priorities so tomorrow's run can
     compare and follow up.

Rules: no filler, no full articles — headlines and implications only.
If a connector is missing, say which one and skip that section rather than
guessing.
