#!/bin/bash
set -eo pipefail

# Stage 2: Restore secrets and SSH keys from Bitwarden
# Run on a new machine after Stage 1 (setup.sh / chezmoi apply)
#
# Usage:
#   ./bw-setup.sh          # restore home profile
#   ./bw-setup.sh work     # restore work profile

PROFILE="${1:-home}"

HOSTNAME=$(scutil --get LocalHostName 2>/dev/null || hostname -s)
HOSTNAME=$(echo "$HOSTNAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | sed 's/--*/-/g; s/^-//; s/-$//')
HOSTNAME=${HOSTNAME:-mac-$(date +%s | tail -c 7)}

echo "=== Stage 2: Bitwarden Setup ($PROFILE, $HOSTNAME) ==="
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/bw-auth.sh"
bw sync

# [1] Restore secrets
echo ""
echo "[1] Restoring secrets..."
SECRETS_ITEM="dotfiles-secrets-${PROFILE}"
if bw get item "$SECRETS_ITEM" &>/dev/null; then
  ITEM=$(bw get item "$SECRETS_ITEM")
  NOTES=$(echo "$ITEM" | jq -r '.notes // ""')
  if [ -n "$NOTES" ]; then
    printf '%s\n' "$NOTES" > ~/.secrets
    chmod 600 ~/.secrets
    echo "  ~/.secrets restored from $SECRETS_ITEM."
  else
    echo "  Warning: $SECRETS_ITEM exists but notes are empty."
  fi
else
  echo "  $SECRETS_ITEM not found in Bitwarden."
  echo "  Create it with: ./scripts/bw-secrets.sh $PROFILE"
fi

# [2] Restore SSH keys
echo ""
echo "[2] Restoring SSH keys..."
SSH_ITEM="ssh-keys-${HOSTNAME}"
mkdir -p ~/.ssh
chmod 700 ~/.ssh

if bw get item "$SSH_ITEM" &>/dev/null; then
  ITEM=$(bw get item "$SSH_ITEM")
  SSH_NOTES=$(echo "$ITEM" | jq -r '.notes // ""')

  if [ -n "$SSH_NOTES" ]; then
    awk '
      /^--- .+ ---$/ {
        if (outfile) close(outfile)
        fname = $0
        gsub(/^--- | ---$/, "", fname)
        outfile = ENVIRON["HOME"] "/.ssh/" fname
        next
      }
      outfile { print > outfile }
    ' <<< "$SSH_NOTES"

    for keyfile in ~/.ssh/personal_ed25519 ~/.ssh/work_ed25519; do
      if [ -f "$keyfile" ]; then
        chmod 600 "$keyfile"
        chmod 644 "$keyfile.pub" 2>/dev/null || true
        echo "  Restored $(basename "$keyfile")"
      fi
    done

    echo ""
    echo "[3] Adding keys to Keychain..."
    for keyfile in ~/.ssh/personal_ed25519 ~/.ssh/work_ed25519; do
      [ -f "$keyfile" ] && ssh-add --apple-use-keychain "$keyfile"
    done
  else
    echo "  Warning: $SSH_ITEM exists but notes are empty."
  fi
else
  echo "  $SSH_ITEM not found in Bitwarden."
  echo "  Generate new keys with: ./scripts/rotate-ssh-keys.sh"
fi

unset BW_SESSION

echo ""
echo "Done. Next steps (Stage 3):"
echo "  1. gh auth login"
echo "  2. Upload SSH keys to GitHub: gh ssh-key add ~/.ssh/personal_ed25519.pub --title \"${HOSTNAME}-personal\""
echo "  3. atuin login (key: grep ATUIN_KEY ~/.secrets | cut -d\"'\" -f2)"
