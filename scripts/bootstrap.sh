#!/usr/bin/env bash
# Step 3/4/5/7 — Apply this repository's templates into ~/.openjarvis/.
#
#   config/config.toml       -> ~/.openjarvis/config.toml      (backed up if present)
#   persona/*.md             -> ~/.openjarvis/{SOUL,USER,MEMORY}.md
#   config/mcp-servers.json  -> ~/.openjarvis/mcp-servers.json (chmod 600)
#   recipes/                 -> ~/.openjarvis/recipes          (symlink, edits go live)
#   skills/*/                -> ~/.openjarvis/skills/<name>    (copied if missing)
#
# Usage: scripts/bootstrap.sh [--force]
#   --force   overwrite existing config/persona files (they are backed up first)
set -euo pipefail

FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="${HOME}/.openjarvis"
STAMP="$(date +%Y%m%d-%H%M%S)"

command -v jarvis >/dev/null 2>&1 || {
  echo "jarvis not on PATH — run scripts/install.sh first" >&2
  exit 1
}
mkdir -p "${HOME_DIR}"

backup() {
  local f="$1"
  if [[ -f "${f}" ]]; then
    cp "${f}" "${f}.bak.${STAMP}"
    echo "    backed up: ${f}.bak.${STAMP}"
  fi
}

# ── config.toml ────────────────────────────────────────────────────
if [[ -f "${HOME_DIR}/config.toml" && ${FORCE} -eq 0 ]]; then
  echo "==> config.toml exists — skipping (use --force to replace; a backup is always made)"
else
  echo "==> Installing config.toml"
  backup "${HOME_DIR}/config.toml"
  cp "${REPO_DIR}/config/config.toml" "${HOME_DIR}/config.toml"
fi

# ── persona files ──────────────────────────────────────────────────
echo "==> Installing persona files (SOUL/USER/MEMORY)"
for f in SOUL.md USER.md MEMORY.md; do
  if [[ -f "${HOME_DIR}/${f}" && ${FORCE} -eq 0 && ! "${HOME_DIR}/${f}" -ot "${REPO_DIR}/persona/${f}" ]]; then
    echo "    kept: ${f} (newer or equal — use --force to overwrite)"
    continue
  fi
  backup "${HOME_DIR}/${f}"
  cp "${REPO_DIR}/persona/${f}" "${HOME_DIR}/${f}"
  echo "    installed: ${f}"
done

# ── MCP servers (may hold tokens later → lock down) ────────────────
echo "==> Installing mcp-servers.json"
cp "${REPO_DIR}/config/mcp-servers.json" "${HOME_DIR}/mcp-servers.json"
chmod 600 "${HOME_DIR}/mcp-servers.json"
echo "    chmod 600 applied"

# ── recipes: symlink so repo edits are live for `jarvis compose` ───
echo "==> Linking recipes/"
if [[ -L "${HOME_DIR}/recipes" ]]; then
  ln -sfn "${REPO_DIR}/recipes" "${HOME_DIR}/recipes"
  echo "    relinked -> ${REPO_DIR}/recipes"
elif [[ -d "${HOME_DIR}/recipes" ]]; then
  mv "${HOME_DIR}/recipes" "${HOME_DIR}/recipes.bak.${STAMP}"
  ln -s "${REPO_DIR}/recipes" "${HOME_DIR}/recipes"
  echo "    existing dir moved to recipes.bak.${STAMP}; linked -> ${REPO_DIR}/recipes"
else
  ln -s "${REPO_DIR}/recipes" "${HOME_DIR}/recipes"
  echo "    linked -> ${REPO_DIR}/recipes"
fi

# ── skills: copy each skill dir if not already installed ───────────
echo "==> Installing skills/ (missing ones only)"
mkdir -p "${HOME_DIR}/skills"
for d in "${REPO_DIR}"/skills/*/; do
  name="$(basename "${d}")"
  [[ "${name}" == "README.md" ]] && continue
  if [[ -d "${HOME_DIR}/skills/${name}" ]]; then
    if [[ ${FORCE} -eq 1 ]]; then
      rm -rf "${HOME_DIR}/skills/${name}"
      cp -R "${d}" "${HOME_DIR}/skills/${name}"
      echo "    replaced: ${name}"
    else
      echo "    kept: ${name} (use --force to replace)"
    fi
  else
    cp -R "${d}" "${HOME_DIR}/skills/${name}"
    echo "    installed: ${name}"
  fi
done

cat <<'NEXT'

Bootstrap complete. Remaining setup (see SETUP.md):
  1. Edit ~/.openjarvis/config.toml — set YOUR_USERNAME in [[skills.sources]],
     flip [channel] enabled = true + bot token, [digest] enabled = true as needed.
  2. export GITHUB_PERSONAL_ACCESS_TOKEN=...   # MCP github server reads env
  3. ./scripts/setup-connectors.sh             # ~/.openjarvis/connectors/github.json
  4. jarvis skill sync github && jarvis skill list
  5. uv pip install croniter                  # full 5-field cron support
  6. jarvis scheduler start                    # background automation daemon
  7. ./scripts/verify.sh
NEXT
