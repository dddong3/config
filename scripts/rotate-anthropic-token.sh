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

# Update ~/.secrets
if [ -f ~/.secrets ]; then
  sed -i '' "s|^export ANTHROPIC_AUTH_TOKEN=.*|export ANTHROPIC_AUTH_TOKEN='$NEW_TOKEN'|" ~/.secrets
  if [ -n "$NEW_URL" ]; then
    sed -i '' "s|^export ANTHROPIC_BASE_URL=.*|export ANTHROPIC_BASE_URL='$NEW_URL'|" ~/.secrets
  fi
  echo "  ~/.secrets updated."
fi

# Update ~/.claude/settings.json
if [ -f ~/.claude/settings.json ]; then
  OLD_TOKEN=$(python3 -c "import json; d=json.load(open('$HOME/.claude/settings.json')); print(d['env'].get('ANTHROPIC_AUTH_TOKEN',''))")
  [ -n "$OLD_TOKEN" ] && sed -i '' "s|$OLD_TOKEN|$NEW_TOKEN|" ~/.claude/settings.json
  if [ -n "$NEW_URL" ]; then
    OLD_URL=$(python3 -c "import json; d=json.load(open('$HOME/.claude/settings.json')); print(d['env'].get('ANTHROPIC_BASE_URL',''))")
    [ -n "$OLD_URL" ] && sed -i '' "s|$OLD_URL|$NEW_URL|" ~/.claude/settings.json
  fi
  echo "  ~/.claude/settings.json updated."
fi

# Update Bitwarden
echo ""
echo "Updating Bitwarden..."
command -v bw &>/dev/null || { echo "Warning: bw not found, skip Bitwarden update."; exit 0; }
source ~/.secrets
export BW_SESSION=$(bw unlock --raw)
ITEM_ID=$(bw get item dotfiles-secrets | jq -r '.id')
CURRENT=$(bw get notes dotfiles-secrets)
NEW=$(echo "$CURRENT" | sed "s|^export ANTHROPIC_AUTH_TOKEN=.*|export ANTHROPIC_AUTH_TOKEN='$NEW_TOKEN'|")
if [ -n "$NEW_URL" ]; then
  NEW=$(echo "$NEW" | sed "s|^export ANTHROPIC_BASE_URL=.*|export ANTHROPIC_BASE_URL='$NEW_URL'|")
fi
ENCODED=$(bw get item dotfiles-secrets | jq --arg notes "$NEW" '.notes = $notes' | bw encode)
bw edit item "$ITEM_ID" "$ENCODED" > /dev/null
unset BW_SESSION
echo "  Bitwarden updated."

echo ""
echo "Done. Restart Claude Code to apply."
