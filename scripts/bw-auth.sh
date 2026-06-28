#!/bin/bash
# Shared Bitwarden authentication helper
# Usage: source "$SCRIPT_DIR/bw-auth.sh"
# Provides: BW_SESSION (set, not exported — callers pass it explicitly)
#
# Logic:
#   1. BW_SESSION already set and valid → reuse
#   2. Logged in but locked → unlock
#   3. Not logged in → config server + login

command -v bw &>/dev/null || { echo "Error: bw not found."; return 1 2>/dev/null || exit 1; }

# Already have a valid session?
if [ -n "$BW_SESSION" ] && bw sync &>/dev/null; then
  return 0 2>/dev/null || exit 0
fi

# Logged in? Try unlock
if bw login --check &>/dev/null; then
  BW_SESSION=$(bw unlock --raw) || { echo "Error: bw unlock failed."; return 1 2>/dev/null || exit 1; }
else
  # Not logged in — need server URL + login
  if [ -z "$BW_SERVER_URL" ] && [ -f ~/.secrets ]; then
    source ~/.secrets
  fi
  if [ -z "$BW_SERVER_URL" ]; then
    read -rp "Vaultwarden URL: " BW_SERVER_URL
  fi
  bw config server "$BW_SERVER_URL" || { echo "Error: bw config server failed."; return 1 2>/dev/null || exit 1; }
  BW_SESSION=$(bw login --raw) || { echo "Error: bw login failed."; return 1 2>/dev/null || exit 1; }
fi

if [ -z "$BW_SESSION" ]; then
  echo "Error: Bitwarden authentication failed (empty session)."
  return 1 2>/dev/null || exit 1
fi
# BW_SESSION is now set in the caller's shell scope
