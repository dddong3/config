#!/bin/bash
set -eo pipefail

# Rotate SSH keys for this machine
# 1. Generate new key pairs (temp dir, then move)
# 2. Add to Keychain
# 3. Update per-host Bitwarden backup
# 4. Upload personal key to GitHub

HOSTNAME=$(scutil --get LocalHostName 2>/dev/null || hostname -s)
HOSTNAME=$(echo "$HOSTNAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | sed 's/--*/-/g; s/^-//; s/-$//')
HOSTNAME=${HOSTNAME:-mac-$(date +%s | tail -c 7)}

SSH_KEYS=(
  "personal_ed25519:${HOSTNAME}-personal"
  "work_ed25519:${HOSTNAME}-work"
)

echo "=== Rotate SSH Keys ($HOSTNAME) ==="
echo ""

# Generate new keys (to temp first, then move — avoids losing keys if keygen fails)
echo "[1] Generating new keys..."
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

while true; do
  read -rsp "  Enter passphrase for SSH keys: " SSH_PASSPHRASE; echo
  read -rsp "  Confirm passphrase: " SSH_PASSPHRASE_CONFIRM; echo
  if [ "$SSH_PASSPHRASE" = "$SSH_PASSPHRASE_CONFIRM" ]; then
    if [ -z "$SSH_PASSPHRASE" ]; then
      echo "  Error: passphrase cannot be empty."
    else
      break
    fi
  else
    echo "  Error: passphrases do not match."
  fi
done

for entry in "${SSH_KEYS[@]}"; do
  KEY_FILE="${entry%%:*}"
  KEY_COMMENT="${entry##*:}"
  ssh-keygen -t ed25519 -C "$KEY_COMMENT" -N "$SSH_PASSPHRASE" -f "$tmp_dir/$KEY_FILE"
done
unset SSH_PASSPHRASE SSH_PASSPHRASE_CONFIRM

for entry in "${SSH_KEYS[@]}"; do
  KEY_FILE="${entry%%:*}"
  mv "$tmp_dir/$KEY_FILE" "$HOME/.ssh/$KEY_FILE"
  mv "$tmp_dir/$KEY_FILE.pub" "$HOME/.ssh/$KEY_FILE.pub"
done

# Add to Keychain
echo ""
echo "[2] Adding to Keychain..."
for entry in "${SSH_KEYS[@]}"; do
  ssh-add --apple-use-keychain "$HOME/.ssh/${entry%%:*}"
done

# Upload to Bitwarden
echo ""
echo "[3] Updating Bitwarden backup..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/bw-auth.sh"

ITEM_NAME="ssh-keys-${HOSTNAME}"
BW_NOTES=$(jq -rn \
  --arg host "$HOSTNAME" \
  --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --rawfile personal_key "$HOME/.ssh/personal_ed25519" \
  --rawfile personal_pub "$HOME/.ssh/personal_ed25519.pub" \
  --rawfile work_key "$HOME/.ssh/work_ed25519" \
  --rawfile work_pub "$HOME/.ssh/work_ed25519.pub" \
  '"# \($host) — \($date)\n\n--- personal_ed25519 ---\n" + $personal_key + "\n--- personal_ed25519.pub ---\n" + $personal_pub + "\n--- work_ed25519 ---\n" + $work_key + "\n--- work_ed25519.pub ---\n" + $work_pub')

if bw get item "$ITEM_NAME" &>/dev/null; then
  ITEM=$(bw get item "$ITEM_NAME")
  ITEM_ID=$(echo "$ITEM" | jq -r '.id')
  ENCODED=$(echo "$ITEM" | jq --arg notes "$BW_NOTES" '.notes = $notes' | bw encode)
  bw edit item "$ITEM_ID" "$ENCODED" > /dev/null
else
  bw get template item | jq \
    --arg name "$ITEM_NAME" \
    --arg notes "$BW_NOTES" \
    '.name = $name | .type = 2 | .secureNote = {"type": 0} | .notes = $notes' \
    | bw encode | bw create item > /dev/null
fi
echo "  Bitwarden updated ($ITEM_NAME)."

# Upload to GitHub
echo ""
echo "[4] Re-upload SSH keys to GitHub hosts."
echo "  Rotated keys:"
for entry in "${SSH_KEYS[@]}"; do
  KEY_FILE="${entry%%:*}"
  echo "    ~/.ssh/$KEY_FILE.pub"
done
echo ""
echo "  Remove old keys and re-upload:"
echo "    gh ssh-key add ~/.ssh/<key>.pub --title \"${HOSTNAME}-<purpose>\""
echo "  For GHES/EMU:"
echo "    GH_HOST=github.example.com gh ssh-key add ~/.ssh/work_ed25519.pub --title \"${HOSTNAME}-work\""

# Verify
echo ""
echo "[5] Verifying..."
ssh -T git@github.com 2>&1 | grep -q "successfully" && echo "  GitHub SSH: OK" || echo "  GitHub SSH: FAIL"

unset BW_SESSION

echo ""
echo "Done. Remember to:"
echo "  - Deploy personal key to homelab: ssh-copy-id -i ~/.ssh/personal_ed25519.pub root@<server-ip>"
echo "  - Upload work key to work GitHub org (if applicable)"
