#!/usr/bin/env bash
# Post-setup sanity checks — run any time something feels off.
# Every check prints OK / WARN / FAIL; the exit code is non-zero on FAIL.
set -uo pipefail

OK=0; WARN=0; FAIL=0
ok()   { printf '  \033[32mOK  \033[0m %s\n' "$1"; OK=$((OK+1)); }
warn() { printf '  \033[33mWARN\033[0m %s\n' "$1"; WARN=$((WARN+1)); }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

echo "── OpenJarvis core ─────────────────────────────────"
if command -v jarvis >/dev/null 2>&1; then
  ok "jarvis on PATH: $(jarvis --version 2>&1 | head -1)"
else
  fail "jarvis not on PATH (installer output or ~/.openjarvis venv)"
fi

echo "── Config ──────────────────────────────────────────"
CFG="${HOME}/.openjarvis/config.toml"
if [[ -f "${CFG}" ]]; then
  if jarvis config show -p "${CFG}" toml >/dev/null 2>&1; then
    ok "config.toml parses ($(jarvis config show -p "${CFG}" loaded >/dev/null 2>&1 && echo 'loads cleanly' || echo 'syntax ok, load warning'))"
  else
    fail "config.toml has syntax errors — jarvis config show -p ${CFG} toml"
  fi
else
  fail "missing ${CFG} — run scripts/bootstrap.sh"
fi

echo "── Persona files ───────────────────────────────────"
for f in SOUL.md USER.md MEMORY.md; do
  [[ -s "${HOME}/.openjarvis/${f}" ]] && ok "${f}" || warn "${f} missing/empty"
done

echo "── Engines & models ────────────────────────────────"
if command -v ollama >/dev/null 2>&1; then
  ok "ollama installed"
  if curl -sf --max-time 2 http://localhost:11434/api/tags >/dev/null 2>&1; then
    ok "ollama daemon responding"
    MODELS="$(ollama list 2>/dev/null | awk 'NR>1 {print $1}' | tr '\n' ' ')"
    [[ -n "${MODELS// /}" ]] && ok "models: ${MODELS}" || warn "no models pulled — ollama pull qwen3:8b"
  else
    warn "ollama daemon not responding (ollama serve)"
  fi
else
  warn "ollama not found (required for local inference)"
fi

echo "── Document memory ─────────────────────────────────"
if command -v jarvis >/dev/null 2>&1; then
  jarvis memory stats >/dev/null 2>&1 \
    && ok "memory backend available (jarvis memory stats)" \
    || warn "memory backend unavailable — Rust extension not built (installer does this; see SETUP.md)"
fi

echo "── Skills ──────────────────────────────────────────"
if command -v jarvis >/dev/null 2>&1; then
  jarvis skill list >/dev/null 2>&1 && ok "skill list works" || warn "skill list failed"
  for s in morning-research-briefing github-skill-publisher local-voice-briefing; do
    if jarvis skill info "${s}" >/dev/null 2>&1; then ok "skill: ${s}"; else warn "skill not discovered: ${s}"; fi
  done
fi

echo "── Recipes ─────────────────────────────────────────"
if command -v jarvis >/dev/null 2>&1; then
  if jarvis compose list 2>&1 | grep -q morning-briefing; then
    ok "compose discovers repo recipes (morning-briefing)"
  else
    warn "recipes not discovered — check ~/.openjarvis/recipes symlink"
  fi
fi

echo "── Scheduler ───────────────────────────────────────"
if command -v jarvis >/dev/null 2>&1; then
  jarvis scheduler list >/dev/null 2>&1 && ok "scheduler list works" || warn "scheduler list failed"
  python3 -c "import croniter" >/dev/null 2>&1 \
    && ok "croniter available (full 5-field cron)" \
    || warn "croniter missing — uv pip install croniter"
fi

echo "── MCP & channels ──────────────────────────────────"
[[ -f "${HOME}/.openjarvis/mcp-servers.json" ]] && ok "mcp-servers.json present" || warn "mcp-servers.json missing"
if command -v npx >/dev/null 2>&1; then ok "npx available (stdio MCP servers)"; else warn "npx missing — MCP stdio servers won't start"; fi
if command -v jarvis >/dev/null 2>&1; then
  jarvis channel status >/dev/null 2>&1 && ok "channel status ok" || warn "no channel connected (set [channel] + bot token)"
fi

echo "── Voice (optional) ────────────────────────────────"
if command -v docker >/dev/null 2>&1; then
  docker ps --format '{{.Names}}' 2>/dev/null | grep -q speaches \
    && ok "speaches container running" \
    || warn "speaches not running (optional — see SETUP.md Step 6)"
else
  warn "docker not found (only needed for the Speaches container)"
fi

echo
echo "Summary: ${OK} ok, ${WARN} warnings, ${FAIL} failures"
[[ ${FAIL} -eq 0 ]]
