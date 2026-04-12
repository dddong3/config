#!/bin/bash
set -eo pipefail

# Rotate ANTHROPIC_AUTH_TOKEN
# 1. Paste new token
# 2. Update Bitwarden
# 3. Update local ~/.secrets and ~/.claude/settings.json

echo "=== Rotate ANTHROPIC_AUTH_TOKEN ==="
echo ""
read -rp "Paste new ANTHROPIC_AUTH_TOKEN: " NEW_TOKEN
[ -z "$NEW_TOKEN" ] && { echo "Error: empty token."; exit 1; }

read -rp "Paste new ANTHROPIC_BASE_URL (leave empty to keep current): " NEW_URL

# Update ~/.secrets (awk avoids sed metacharacter issues with tokens)
if [ -f ~/.secrets ]; then
  awk -v val="$NEW_TOKEN" '/^export ANTHROPIC_AUTH_TOKEN=/{$0="export ANTHROPIC_AUTH_TOKEN='"'"'" val "'"'"'"} 1' ~/.secrets > ~/.secrets.tmp && mv ~/.secrets.tmp ~/.secrets
  if [ -n "$NEW_URL" ]; then
    awk -v val="$NEW_URL" '/^export ANTHROPIC_BASE_URL=/{$0="export ANTHROPIC_BASE_URL='"'"'" val "'"'"'"} 1' ~/.secrets > ~/.secrets.tmp && mv ~/.secrets.tmp ~/.secrets
  fi
  chmod 600 ~/.secrets
  echo "  ~/.secrets updated."
fi

# Update ~/.claude/settings.json
if [ -f ~/.claude/settings.json ]; then
  tmp_json=$(mktemp)
  trap 'rm -f "$tmp_json"' EXIT
  if [ -n "$NEW_URL" ]; then
    jq --arg tok "$NEW_TOKEN" --arg url "$NEW_URL" \
       '.env.ANTHROPIC_AUTH_TOKEN = $tok | .env.ANTHROPIC_BASE_URL = $url' \
       ~/.claude/settings.json > "$tmp_json"
  else
    jq --arg tok "$NEW_TOKEN" \
       '.env.ANTHROPIC_AUTH_TOKEN = $tok' \
       ~/.claude/settings.json > "$tmp_json"
  fi
  mv "$tmp_json" ~/.claude/settings.json
  chmod 600 ~/.claude/settings.json
  echo "  ~/.claude/settings.json updated."
fi

# Update Bitwarden
echo ""
echo "Updating Bitwarden..."
command -v bw &>/dev/null || { echo "Warning: bw not found, skip Bitwarden update."; exit 0; }
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/bw-auth.sh"
ITEM=$(bw get item dotfiles-secrets)
ITEM_ID=$(echo "$ITEM" | jq -r '.id')
CURRENT=$(echo "$ITEM" | jq -r '.notes')
NEW=$(echo "$CURRENT" | awk -v val="$NEW_TOKEN" '/^export ANTHROPIC_AUTH_TOKEN=/{$0="export ANTHROPIC_AUTH_TOKEN='"'"'" val "'"'"'"} 1')
if [ -n "$NEW_URL" ]; then
  NEW=$(echo "$NEW" | awk -v val="$NEW_URL" '/^export ANTHROPIC_BASE_URL=/{$0="export ANTHROPIC_BASE_URL='"'"'" val "'"'"'"} 1')
fi
ENCODED=$(echo "$ITEM" | jq --arg notes "$NEW" '.notes = $notes' | bw encode)
bw edit item "$ITEM_ID" "$ENCODED" > /dev/null
unset BW_SESSION
echo "  Bitwarden updated."

echo ""
echo "Done. Restart Claude Code to apply."
