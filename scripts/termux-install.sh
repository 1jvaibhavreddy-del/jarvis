#!/data/data/com.termux/files/usr/bin/bash
# ──────────────────────────────────────────────────────────────────────
# Jarvis on a tablet/phone with NO computer — runs entirely on the device
# via Termux (Android) or a Linux terminal.
#
# What this does:
#   1. Installs Termux packages (python, git, llama.cpp server, curl).
#   2. Creates a Python venv and installs OpenJarvis.
#   3. Downloads a small local GGUF model (llama.cpp server speaks the
#      OpenAI-compatible API that Jarvis uses as its engine).
#   4. Configures Jarvis to talk to the on-device model.
#   5. Starts the model server + `jarvis serve` (API on :8000).
#
# The Jarvis Android app (android/) then points at http://localhost:8000.
#
# Usage:
#   bash termux-install.sh            # full install + start
#   bash termux-install.sh --no-start # install only
# ──────────────────────────────────────────────────────────────────────
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
OJ_HOME="${OPENJARVIS_HOME:-$HOME/.openjarvis}"
VENV="$HOME/jarvis-venv"
MODEL_DIR="$HOME/models"
MODEL_NAME="qwen2.5:3b-instruct-q4_k_m.gguf"   # ~2 GB, runs on most tablets
MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf"
LLAMA_PORT=8080
JARVIS_PORT=8000

is_termux=0
[ -d "/data/data/com.termux/files/usr" ] && is_termux=1

say()  { printf "\033[1;36m[jarvis]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[warn]\033[0m %s\n" "$*"; }
die()  { printf "\033[1;31m[error]\033[0m %s\n" "$*" >&2; exit 1; }

# ── 1. System packages ────────────────────────────────────────────────
if [ "$is_termux" -eq 1 ]; then
  say "Termux detected — installing packages"
  pkg update -y >/dev/null 2>&1
  pkg install -y python git curl clang termux-tools >/dev/null 2>&1
  # Keep the engine alive when the screen turns off.
  termux-wake-lock 2>/dev/null || true
  # llama.cpp server (provides the OpenAI-compatible API)
  if pkg list-installed 2>/dev/null | grep -q "^llama.cpp"; then
    say "llama.cpp already installed"
  else
    pkg install -y llama.cpp >/dev/null 2>&1 || {
      warn "llama.cpp package not found — building from source (takes a few minutes)"
      pkg install -y cmake make >/dev/null 2>&1
      git clone --depth 1 https://github.com/ggml-org/llama.cpp "$HOME/llama.cpp"
      mkdir -p "$HOME/llama.cpp/build" && cd "$HOME/llama.cpp/build"
      cmake .. -DLLAMA_INSTALL_BIN=ON >/dev/null
      cmake --build . --config Release -j"$(nproc)" >/dev/null
      cd "$REPO_ROOT"
    }
  fi
else
  say "Desktop Linux detected — using system tools"
  command -v python3 >/dev/null || die "python3 not found"
  command -v curl  >/dev/null || die "curl not found"
  command -v git   >/dev/null || die "git not found"
  if ! command -v llama-server >/dev/null 2>&1 && ! command -v llama.cpp >/dev/null 2>&1; then
    warn "llama.cpp not found — install it (https://github.com/ggml-org/llama.cpp) or let step 3 skip the model"
  fi
fi

# ── 2. Python venv + OpenJarvis ───────────────────────────────────────
if [ ! -x "$VENV/bin/jarvis" ]; then
  say "Creating venv and installing OpenJarvis (first run downloads ~100 MB)"
  if [ "$is_termux" -eq 1 ]; then
    python -m venv "$VENV" || { pip install --user virtualenv >/dev/null 2>&1; python -m venv "$VENV"; }
  else
    python3 -m venv "$VENV"
  fi
  "$VENV/bin/pip" install --quiet --upgrade pip
  "$VENV/bin/pip" install --quiet "openjarvis[server]"
  [ -x "$VENV/bin/jarvis" ] || die "openjarvis install failed"
else
  say "OpenJarvis venv already present at $VENV"
fi

# ── 3. Local model (llama.cpp server) ─────────────────────────────────
LLAMA_BIN="$(command -v llama-server 2>/dev/null || command -v llama.cpp 2>/dev/null || true)"
if [ -z "$LLAMA_BIN" ] && [ -x "$HOME/llama.cpp/build/bin/llama-server" ]; then
  LLAMA_BIN="$HOME/llama.cpp/build/bin/llama-server"
fi

if [ -n "$LLAMA_BIN" ]; then
  if [ ! -f "$MODEL_DIR/$MODEL_NAME" ]; then
    say "Downloading model $MODEL_NAME (~2 GB, one-time)"
    mkdir -p "$MODEL_DIR"
    curl -L --progress-bar -o "$MODEL_DIR/$MODEL_NAME" "$MODEL_URL" \
      || warn "model download failed — set MODEL_URL in this script and re-run"
  else
    say "Model already downloaded"
  fi

  # ── 4. Jarvis config pointing at the on-device model ──────────────
  say "Writing Jarvis config (engine = llama.cpp on :$LLAMA_PORT)"
  mkdir -p "$OJ_HOME"
  cp -n "$REPO_ROOT/config/config.toml" "$OJ_HOME/config.toml" 2>/dev/null || \
    cp "$REPO_ROOT/config/config.toml" "$OJ_HOME/config.toml"

  python3 - "$OJ_HOME/config.toml" <<'PY'
import sys, re
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
# Engine: use llama.cpp as the OpenAI-compatible backend.
s = re.sub(r'(?m)^\[engine\]', '[engine]\ndefault = "llamacpp"', s, count=1) if 'default = "llamacpp"' not in s else s
s = re.sub(r'(?m)^\[engine\.llamacpp\][^\[]*',
           '[engine.llamacpp]\nhost = "http://localhost:' + __import__("os").environ.get("LLAMA_PORT","8080") + '"\n', s, count=1)
s = re.sub(r'(?m)^default_model = .*', 'default_model = "local"', s, count=1)
open(p, "w", encoding="utf-8").write(s)
PY

  LLAMA_PORT="$LLAMA_PORT" JARVIS_PORT="$JARVIS_PORT" VENV="$VENV" \
  MODEL="$MODEL_DIR/$MODEL_NAME" LLAMA_BIN="$LLAMA_BIN" \
  nohup bash -c '
    "'"$LLAMA_BIN"'" -m "'"$MODEL"'" --host 0.0.0.0 --port '"$LLAMA_PORT"' \
      -ngl 99 -c 4096 > '"$HOME"'/llama.log 2>&1 &
    sleep 3
    export PATH="'"$VENV"'/bin:$PATH"
    exec "'"$VENV"'/bin/jarvis" serve --host 0.0.0.0 --port '"$JARVIS_PORT"' --agent orchestrator
  ' > "$HOME/jarvis.log" 2>&1 &
  say "Started: llama.cpp on :$LLAMA_PORT, jarvis serve on :$JARVIS_PORT"
  say "Logs: $HOME/llama.log  and  $HOME/jarvis.log"
else
  warn "llama.cpp not available — skipping on-device model. Jarvis will use whatever engine is configured."
fi

# ── 5. Persona + skills (optional, from this repo) ────────────────────
if [ -d "$REPO_ROOT/persona" ]; then
  mkdir -p "$OJ_HOME"
  for f in SOUL USER MEMORY; do
    [ -f "$OJ_HOME/$f.md" ] || cp -n "$REPO_ROOT/persona/$f.md" "$OJ_HOME/$f.md" 2>/dev/null || true
  done
  say "Persona files installed to $OJ_HOME"
fi

say "Done."
if [ "${1:-}" != "--no-start" ]; then
  say "Open the Jarvis app and point it at http://localhost:$JARVIS_PORT (Settings ⚙)."
fi
