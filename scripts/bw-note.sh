#!/bin/bash
set -eo pipefail

# Create or edit a Bitwarden Secure Note
# Usage:
#   ./bw-note.sh <note-name>                # edit interactively
#   ./bw-note.sh <note-name> <file>         # import from file

NOTE_NAME="${1:-}"
SOURCE_FILE="${2:-}"

if [ -z "$NOTE_NAME" ]; then
  echo "Usage: ./bw-note.sh <note-name> [file]"
  echo ""
  echo "Examples:"
  echo "  ./bw-note.sh claude-settings-local-work              # edit interactively"
  echo "  ./bw-note.sh claude-hook-jenkins-work hook.sh         # import from file"
  exit 1
fi

echo "=== Bitwarden Note: $NOTE_NAME ==="
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/bw-auth.sh"
export BW_SESSION
bw sync

EXISTING=$(bw get item "$NOTE_NAME" 2>/dev/null || echo "")

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

if [ -n "$EXISTING" ]; then
  echo "Editing existing note: $NOTE_NAME"
  echo "$EXISTING" | jq -r '.notes // ""' > "$tmp"
else
  echo "Creating new note: $NOTE_NAME"
  : > "$tmp"
fi

if [ -n "$SOURCE_FILE" ]; then
  cp "$SOURCE_FILE" "$tmp"
  echo "  Imported from: $SOURCE_FILE"
else
  ${EDITOR:-vim} "$tmp"
fi

NOTES=$(cat "$tmp")

if [ -z "$NOTES" ]; then
  echo "Empty content, aborting."
  exit 1
fi

if [ -n "$EXISTING" ]; then
  ITEM_ID=$(echo "$EXISTING" | jq -r '.id')
  ENCODED=$(NOTES="$NOTES" jq '.notes = env.NOTES' <<< "$EXISTING" | bw encode)
  echo "$ENCODED" | bw edit item "$ITEM_ID" > /dev/null
else
  ENCODED=$(bw get template item | NOTES="$NOTES" jq \
    --arg name "$NOTE_NAME" \
    '.name = $name | .type = 2 | .secureNote = {"type": 0} | .notes = env.NOTES' \
    | bw encode)
  echo "$ENCODED" | bw create item > /dev/null
fi

echo ""
echo "  ✓ $NOTE_NAME saved to Bitwarden."
echo "  Run 'chezmoi apply' to deploy."

unset BW_SESSION
