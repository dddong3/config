#!/bin/bash
set -eo pipefail

# Pull latest secrets from Bitwarden to ~/.secrets
# Run after editing dotfiles-secrets in Vaultwarden web UI

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/bw-auth.sh"

bw sync

tmp=$(mktemp)
trap 'rm -f "$tmp" "$tmp_json"' EXIT

bw get notes dotfiles-secrets > "$tmp"
if [ -s "$tmp" ]; then
  mv "$tmp" ~/.secrets
  chmod 600 ~/.secrets
  echo "~/.secrets updated."
else
  echo "Error: dotfiles-secrets is empty or not found."
  exit 1
fi

# Sync tokens to ~/.claude/settings.json (if it exists and has tokens)
source ~/.secrets
if [ -f ~/.claude/settings.json ] && [ -n "$ANTHROPIC_AUTH_TOKEN" ]; then
  tmp_json=$(mktemp)
  if jq --arg tok "$ANTHROPIC_AUTH_TOKEN" \
        --arg url "${ANTHROPIC_BASE_URL:-}" \
        '(.env.ANTHROPIC_AUTH_TOKEN) = $tok |
         if $url != "" then (.env.ANTHROPIC_BASE_URL) = $url else . end' \
        ~/.claude/settings.json > "$tmp_json" 2>/dev/null; then
    mv "$tmp_json" ~/.claude/settings.json
    chmod 600 ~/.claude/settings.json
    echo "~/.claude/settings.json synced."
  else
    rm -f "$tmp_json"
    echo "Warning: failed to update ~/.claude/settings.json (jq error)."
  fi
fi

echo "Restart terminal or run: source ~/.secrets"

unset BW_SESSION
