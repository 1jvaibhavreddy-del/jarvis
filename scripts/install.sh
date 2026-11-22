#!/usr/bin/env bash
# Step 1 — Install the core OpenJarvis engine (official installer).
# macOS / Linux / WSL2. Native Windows: use install.ps1 (see SETUP.md).
set -euo pipefail

echo "==> Checking prerequisites"
command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }

if [[ "${OS:-}" == "Windows_NT" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
  DETECTED="WSL2/Windows"
elif [[ "$(uname)" == "Darwin" ]]; then
  DETECTED="macOS"
else
  DETECTED="Linux"
fi
echo "    detected: ${DETECTED}"

echo "==> Running the official OpenJarvis installer"
echo "    (provisions ~/.openjarvis/, uv + venv, Ollama, starter model, Rust extension)"
curl -fsSL https://open-jarvis.github.io/OpenJarvis/install.sh | bash

echo "==> Verifying"
if command -v jarvis >/dev/null 2>&1; then
  jarvis --version
else
  # Installer may leave the binary inside ~/.openjarvis — fall back to that.
  JARVIS_BIN="$(find "$HOME/.openjarvis" -maxdepth 3 -type f -name jarvis 2>/dev/null | head -1 || true)"
  if [[ -n "${JARVIS_BIN}" ]]; then
    echo "    jarvis found at ${JARVIS_BIN} — add it to PATH:"
    echo "      export PATH=\"$(dirname "${JARVIS_BIN}"):\$PATH\""
    "${JARVIS_BIN}" --version
  else
    echo "jarvis not found on PATH — re-run the installer or check ~/.openjarvis/" >&2
    exit 1
  fi
fi

cat <<'NEXT'

Next steps:
  1. jarvis init --full --engine ollama --no-download   # hardware-matched config
  2. ollama pull qwen3:8b                               # model sized to your RAM/VRAM
  3. ./scripts/bootstrap.sh --force                       # apply this repo's config/persona/recipes
  4. ./scripts/verify.sh                                # end-to-end sanity checks
NEXT
