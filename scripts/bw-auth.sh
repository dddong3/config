#!/bin/bash
# Shared Bitwarden authentication helper
# Usage: source "$SCRIPT_DIR/bw-auth.sh"
# Provides: BW_SESSION (exported)

command -v bw &>/dev/null || { echo "Error: bw not found."; return 1 2>/dev/null || exit 1; }

if [ -z "$BW_SERVER_URL" ] && [ -f ~/.secrets ]; then
  source ~/.secrets
fi

if [ -z "$BW_SERVER_URL" ]; then
  read -rp "Vaultwarden URL: " BW_SERVER_URL
fi
bw logout 2>/dev/null || true
bw config server "$BW_SERVER_URL"

if bw login --check &>/dev/null; then
  BW_SESSION=$(bw unlock --raw) || { echo "Error: bw unlock failed."; return 1 2>/dev/null || exit 1; }
else
  BW_SESSION=$(bw login --raw) || { echo "Error: bw login failed."; return 1 2>/dev/null || exit 1; }
fi

if [ -z "$BW_SESSION" ]; then
  echo "Error: Bitwarden authentication failed (empty session)."
  return 1 2>/dev/null || exit 1
fi
export BW_SESSION
