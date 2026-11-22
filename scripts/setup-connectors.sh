#!/usr/bin/env bash
# Step 4 — Create ~/.openjarvis/connectors/github.json with a GitHub token.
#
# Security:
#   * the token is read from $GITHUB_TOKEN or a hidden prompt — never from
#     argv or shell history (so don't `echo ghp_… > file`);
#   * the file is chmod 600 immediately;
#   * connectors/ is git-ignored in this repo.
set -euo pipefail

CONNECTORS_DIR="${HOME}/.openjarvis/connectors"
CONNECTOR="${CONNECTORS_DIR}/github.json"

mkdir -p "${CONNECTORS_DIR}"

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  TOKEN="${GITHUB_TOKEN}"
elif [[ -n "${GH_TOKEN:-}" ]]; then
  TOKEN="${GH_TOKEN}"
else
  echo -n "GitHub token (input hidden): "
  # Portable hidden read (bash)
  read -rs TOKEN
  echo
fi

if [[ -z "${TOKEN}" ]]; then
  echo "No token provided — aborting." >&2
  exit 1
fi

umask 077
printf '{"token": "%s"}\n' "${TOKEN}" > "${CONNECTOR}"
chmod 600 "${CONNECTOR}"
unset TOKEN GITHUB_TOKEN GH_TOKEN

echo "Wrote ${CONNECTOR} (mode 600)"
echo
echo "Also export the token for the MCP github server (it inherits env):"
echo "  export GITHUB_PERSONAL_ACCESS_TOKEN=...   # add to your shell profile"
echo
echo "Verify: jarvis skill sources && gh auth status"
