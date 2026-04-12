#!/bin/bash
set -eo pipefail

# Pull latest secrets from Bitwarden to ~/.secrets
# Run after editing dotfiles-secrets in Vaultwarden web UI

command -v bw &>/dev/null || { echo "Error: bw not found."; exit 1; }

source ~/.secrets 2>/dev/null
if [ -z "$BW_SERVER_URL" ]; then
  read -rp "Vaultwarden URL: " BW_SERVER_URL
fi
bw config server "$BW_SERVER_URL"

bw login --check &>/dev/null || bw login || { echo "Error: bw login failed."; exit 1; }
BW_SESSION=$(bw unlock --raw)
export BW_SESSION

bw sync

tmp=$(mktemp)
bw get notes dotfiles-secrets > "$tmp"
if [ -s "$tmp" ]; then
  mv "$tmp" ~/.secrets
  chmod 600 ~/.secrets
  echo "~/.secrets updated. Restart terminal or run: source ~/.secrets"
else
  rm -f "$tmp"
  echo "Error: dotfiles-secrets is empty or not found."
  exit 1
fi

unset BW_SESSION
