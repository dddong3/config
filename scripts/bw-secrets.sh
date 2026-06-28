#!/bin/bash
set -eo pipefail

# Create or update dotfiles-secrets-{home,work} in Bitwarden
# Usage:
#   ./bw-secrets.sh home    # edit home secrets
#   ./bw-secrets.sh work    # edit work secrets

PROFILE="${1:-home}"
ITEM_NAME="dotfiles-secrets-${PROFILE}"

echo "=== Bitwarden Secrets ($PROFILE) ==="
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/bw-auth.sh"
export BW_SESSION
bw sync

EXISTING=$(bw get item "$ITEM_NAME" 2>/dev/null || echo "")

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

if [ -n "$EXISTING" ]; then
  echo "Editing existing item: $ITEM_NAME"
  echo "$EXISTING" | jq -r '.notes // ""' > "$tmp"
else
  echo "Creating new item: $ITEM_NAME"
  cat > "$tmp" << 'EOF'
# One KEY='value' per line, sourced by .zshrc
#
# ── Bitwarden ──
# BW_SERVER_URL='https://...'
#
# ── DeepSeek (claude-ds) ──
# DEEPSEEK_BASE_URL='https://api.deepseek.com'
# DEEPSEEK_API_KEY='sk-...'
#
# ── Atuin ──
# ATUIN_KEY='...'
EOF
fi

${EDITOR:-vim} "$tmp"

NOTES=$(cat "$tmp")

if [ -n "$EXISTING" ]; then
  ITEM_ID=$(echo "$EXISTING" | jq -r '.id')
  ENCODED=$(NOTES="$NOTES" jq '.notes = env.NOTES' <<< "$EXISTING" | bw encode)
  bw edit item "$ITEM_ID" "$ENCODED" > /dev/null
else
  bw get template item | NOTES="$NOTES" jq \
    --arg name "$ITEM_NAME" \
    '.name = $name | .type = 2 | .secureNote = {"type": 0} | .notes = env.NOTES' \
    | bw encode | bw create item > /dev/null
fi

echo "  $ITEM_NAME saved to Bitwarden."
echo ""
echo "Run 'chezmoi apply' to deploy ~/.secrets"

unset BW_SESSION
