#!/bin/bash
set -eo pipefail

# Rotate Atuin encryption key
# 1. Logout + re-register
# 2. Update Bitwarden
# 3. Update local ~/.secrets

echo "=== Rotate Atuin Key ==="
echo ""

echo "[1] Re-registering Atuin..."
atuin account logout 2>/dev/null || true

read -rp "Atuin username: " ATUIN_USER
read -rp "Atuin email: " ATUIN_EMAIL
atuin account register -u "$ATUIN_USER" -e "$ATUIN_EMAIL"

echo ""
echo "[2] Syncing..."
atuin sync

# Update ~/.secrets
NEW_KEY=$(cat ~/.local/share/atuin/key)
echo ""
echo "[3] Updating ~/.secrets..."
if [ -f ~/.secrets ]; then
  if grep -q ATUIN_KEY ~/.secrets; then
    sed -i '' "s|^export ATUIN_KEY=.*|export ATUIN_KEY='$NEW_KEY'|" ~/.secrets
  else
    echo "export ATUIN_KEY='$NEW_KEY'" >> ~/.secrets
  fi
  echo "  ~/.secrets updated."
fi

# Update Bitwarden
echo ""
echo "[4] Updating Bitwarden..."
command -v bw &>/dev/null || { echo "Warning: bw not found, skip Bitwarden update."; exit 0; }
source ~/.secrets
export BW_SESSION=$(bw unlock --raw)
ITEM_ID=$(bw get item dotfiles-secrets | jq -r '.id')
CURRENT=$(bw get notes dotfiles-secrets)
if echo "$CURRENT" | grep -q ATUIN_KEY; then
  NEW=$(echo "$CURRENT" | sed "s|^export ATUIN_KEY=.*|export ATUIN_KEY='$NEW_KEY'|")
else
  NEW="$CURRENT
export ATUIN_KEY='$NEW_KEY'"
fi
ENCODED=$(bw get item dotfiles-secrets | jq --arg notes "$NEW" '.notes = $notes' | bw encode)
bw edit item "$ITEM_ID" "$ENCODED" > /dev/null
unset BW_SESSION
echo "  Bitwarden updated."

echo ""
echo "Done."
