#!/data/data/com.termux/files/usr/bin/bash
# ──────────────────────────────────────────────────────────────────────
# Jarvis on a tablet/phone with NO computer — runs entirely on the device
# via Termux (Android) or a Linux terminal.
#
# Robust, self-repairing installer:
#   - Fixes broken packages automatically (pkg full-upgrade) before anything.
#   - Does NOT require clang (only needed for a rare fallback build).
#   - Shows all output — no silent failures.
#   - Stops with a clear message on the first error.
#
# Usage:
#   bash termux-install.sh            # full install + start
#   bash termux-install.sh --no-start # install only
# ──────────────────────────────────────────────────────────────────────
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
OJ_HOME="${OPENJARVIS_HOME:-$HOME/.openjarvis}"
VENV="$HOME/jarvis-venv"
MODEL_DIR="$HOME/models"
MODEL_NAME="qwen2.5-3b-instruct-q4_k_m.gguf"   # ~2 GB, runs on most tablets
MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf"
LLAMA_PORT=8080
JARVIS_PORT=8000

is_termux=0
[ -d "/data/data/com.termux/files/usr" ] && is_termux=1

say()  { printf "\033[1;36m[jarvis]\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m[ok]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[warn]\033[0m %s\n" "$*"; }
die()  { printf "\033[1;31m[error]\033[0m %s\n" "$*" >&2; exit 1; }

# ── 1. System packages (self-repair first) ────────────────────────────
if [ "$is_termux" -eq 1 ]; then
  say "Termux detected — repairing and installing packages"
  say "Step 1a: updating package lists"
  pkg update -y || die "'pkg update' failed — check your internet connection and re-run."

  say "Step 1b: full-upgrade (fixes broken packages like curl)"
  # full-upgrade repairs a broken curl/libcurl before we install anything else.
  pkg full-upgrade -y || warn "full-upgrade had issues — continuing, but if a later step fails, re-run 'pkg full-upgrade'."

  say "Step 1c: installing core packages (python, git, curl, termux-tools)"
  pkg install -y python git curl termux-tools || die "core package install failed — run 'pkg install -y python git curl termux-tools' yourself and show the error."

  # Keep the engine alive when the screen turns off.
  termux-wake-lock 2>/dev/null || true
else
  say "Desktop Linux detected — using system tools"
  command -v python3 >/dev/null || die "python3 not found"
  command -v curl  >/dev/null || die "curl not found"
  command -v git   >/dev/null || die "git not found"
fi

# ── 2. Python venv + OpenJarvis ───────────────────────────────────────
if [ ! -x "$VENV/bin/jarvis" ]; then
  say "Step 2: creating venv and installing OpenJarvis (downloads ~100 MB)"
  if [ "$is_termux" -eq 1 ]; then
    python -m venv "$VENV" 2>/dev/null || { pip install --user virtualenv >/dev/null 2>&1; python -m venv "$VENV"; }
  else
    python3 -m venv "$VENV"
  fi
  "$VENV/bin/pip" install --upgrade pip
  "$VENV/bin/pip" install "openjarvis[server]" || die "OpenJarvis install failed — check your internet and re-run."
  [ -x "$VENV/bin/jarvis" ] || die "openjarvis install failed — the 'jarvis' binary was not created."
  ok "OpenJarvis installed at $VENV"
else
  ok "OpenJarvis venv already present at $VENV — skipping"
fi

# ── 3. Local model server (llama.cpp) ────────────────────────────────
# Prefer the Termux package; only build from source if it's unavailable.
LLAMA_BIN="$(command -v llama-server 2>/dev/null || command -v llama.cpp 2>/dev/null || true)"

if [ -z "$LLAMA_BIN" ]; then
  say "Step 3: installing llama.cpp model server"
  if [ "$is_termux" -eq 1 ]; then
    pkg install -y llama.cpp || warn "llama.cpp package install failed — will try building from source."
  fi
  LLAMA_BIN="$(command -v llama-server 2>/dev/null || command -v llama.cpp 2>/dev/null || true)"
fi

if [ -z "$LLAMA_BIN" ] && [ "$is_termux" -eq 1 ]; then
  say "llama.cpp not available as a package — building from source (one-time, several minutes)"
  pkg install -y cmake make git >/dev/null 2>&1 || die "need cmake/make/git to build llama.cpp — run 'pkg install -y cmake make git' and retry."
  [ -d "$HOME/llama.cpp" ] || git clone --depth 1 https://github.com/ggml-org/llama.cpp "$HOME/llama.cpp" \
    || die "could not clone llama.cpp — check your internet."
  mkdir -p "$HOME/llama.cpp/build"
  ( cd "$HOME/llama.cpp/build" && cmake .. -DLLAMA_INSTALL_BIN=ON >/dev/null && cmake --build . --config Release -j"$(nproc)" >/dev/null ) \
    || die "llama.cpp build failed — run the build commands manually and show the error."
  LLAMA_BIN="$HOME/llama.cpp/build/bin/llama-server"
  [ -x "$LLAMA_BIN" ] || die "llama.cpp built but binary not found at $LLAMA_BIN."
fi

if [ -n "$LLAMA_BIN" ]; then
  if [ ! -f "$MODEL_DIR/$MODEL_NAME" ]; then
    say "Step 4: downloading model $MODEL_NAME (~2 GB, one-time)"
    mkdir -p "$MODEL_DIR"
    curl -L --progress-bar -o "$MODEL_DIR/$MODEL_NAME" "$MODEL_URL" \
      || die "model download failed — check your internet and re-run (it resumes/restarts the download)."
  else
    ok "Model already downloaded — skipping"
  fi

  # ── 5. Jarvis config pointing at the on-device model ────────────────
  say "Step 5: writing Jarvis config (engine = llama.cpp on :$LLAMA_PORT)"
  mkdir -p "$OJ_HOME"
  cp -n "$REPO_ROOT/config/config.toml" "$OJ_HOME/config.toml" 2>/dev/null || \
    cp "$REPO_ROOT/config/config.toml" "$OJ_HOME/config.toml"

  LLAMA_PORT="$LLAMA_PORT" python3 - "$OJ_HOME/config.toml" <<'PY'
import sys, re, os
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
s = re.sub(r'(?m)^\[engine\]', '[engine]\ndefault = "llamacpp"', s, count=1) if 'default = "llamacpp"' not in s else s
s = re.sub(r'(?m)^\[engine\.llamacpp\][^\[]*',
           '[engine.llamacpp]\nhost = "http://localhost:' + os.environ.get("LLAMA_PORT", "8080") + '"\n', s, count=1)
s = re.sub(r'(?m)^default_model = .*', 'default_model = "local"', s, count=1)
open(p, "w", encoding="utf-8").write(s)
PY

  # ── 6. Start the model server + jarvis serve (background) ──────────
  say "Step 6: starting llama.cpp on :$LLAMA_PORT and jarvis serve on :$JARVIS_PORT"
  LLAMA_PORT="$LLAMA_PORT" JARVIS_PORT="$JARVIS_PORT" VENV="$VENV" \
  MODEL="$MODEL_DIR/$MODEL_NAME" LLAMA_BIN="$LLAMA_BIN" \
  nohup bash -c '
    "'"$LLAMA_BIN"'" -m "'"$MODEL"'" --host 0.0.0.0 --port '"$LLAMA_PORT"' \
      -ngl 99 -c 4096 > '"$HOME"'/llama.log 2>&1 &
    sleep 3
    export PATH="'"$VENV"'/bin:$PATH"
    exec "'"$VENV"'/bin/jarvis" serve --host 0.0.0.0 --port '"$JARVIS_PORT"' --agent orchestrator
  ' > "$HOME/jarvis.log" 2>&1 &

  ok "Started. Logs: $HOME/llama.log  and  $HOME/jarvis.log"
else
  warn "llama.cpp unavailable — skipping on-device model. Jarvis will use whatever engine is configured."
fi

# ── 7. Persona files (optional) ────────────────────────────────────────
if [ -d "$REPO_ROOT/persona" ]; then
  mkdir -p "$OJ_HOME"
  for f in SOUL USER MEMORY; do
    [ -f "$OJ_HOME/$f.md" ] || cp -n "$REPO_ROOT/persona/$f.md" "$OJ_HOME/$f.md" 2>/dev/null || true
  done
  ok "Persona files installed to $OJ_HOME"
fi

say "Done."
if [ "${1:-}" != "--no-start" ]; then
  say "Open the Jarvis app and point it at http://localhost:$JARVIS_PORT (Settings ⚙)."
  say "To check it's alive later, run: curl http://localhost:$JARVIS_PORT/health"
fi
