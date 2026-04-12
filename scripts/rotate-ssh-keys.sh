#!/bin/bash
set -eo pipefail

# Rotate SSH keys
# 1. Generate new key pairs
# 2. Add to Keychain
# 3. Upload to Bitwarden
# 4. Upload code key to GitHub

echo "=== Rotate SSH Keys ==="
echo ""

# Generate new keys
echo "[1] Generating new keys..."
rm -f ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub ~/.ssh/homelab ~/.ssh/homelab.pub

ssh-keygen -t ed25519 -C "dong3-code" -f ~/.ssh/id_ed25519
ssh-keygen -t ed25519 -C "dong3-homelab" -f ~/.ssh/homelab

# Add to Keychain
echo ""
echo "[2] Adding to Keychain..."
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
ssh-add --apple-use-keychain ~/.ssh/homelab

# Upload to Bitwarden
echo ""
echo "[3] Uploading to Bitwarden..."
command -v bw &>/dev/null || { echo "Error: bw not found."; exit 1; }

export BW_SESSION=$(bw unlock --raw)

cat << 'SCRIPT' > /tmp/upload-ssh.sh
#!/bin/bash
NOTES=$(jq -rn \
  --rawfile code_key "$HOME/.ssh/id_ed25519" \
  --rawfile code_pub "$HOME/.ssh/id_ed25519.pub" \
  --rawfile lab_key "$HOME/.ssh/homelab" \
  --rawfile lab_pub "$HOME/.ssh/homelab.pub" \
  '"--- id_ed25519 (code) ---\n" + $code_key + "\n--- id_ed25519.pub ---\n" + $code_pub + "\n--- homelab (private) ---\n" + $lab_key + "\n--- homelab.pub ---\n" + $lab_pub')
ITEM_ID=$(bw get item ssh-keys | jq -r '.id')
ENCODED=$(bw get item ssh-keys | jq --arg notes "$NOTES" '.notes = $notes' | bw encode)
bw edit item "$ITEM_ID" "$ENCODED" > /dev/null && echo "  Bitwarden updated."
SCRIPT
bash /tmp/upload-ssh.sh
rm -f /tmp/upload-ssh.sh

# Upload to GitHub
echo ""
echo "[4] Updating GitHub..."
if command -v gh &>/dev/null && gh auth status &>/dev/null; then
  # Remove old key
  OLD_ID=$(gh ssh-key list 2>/dev/null | grep ed25519 | awk '{print $4}' | head -1)
  [ -n "$OLD_ID" ] && gh ssh-key delete "$OLD_ID" --yes 2>/dev/null
  # Add new key
  KEY_TITLE="$(scutil --get ComputerName 2>/dev/null || hostname)-ed25519"
  gh ssh-key add ~/.ssh/id_ed25519.pub --title "$KEY_TITLE"
  echo "  GitHub updated ($KEY_TITLE)."
else
  echo "  gh not authenticated. Run manually:"
  echo "    gh ssh-key add ~/.ssh/id_ed25519.pub --title \"$(hostname)-ed25519\""
fi

unset BW_SESSION

# Verify
echo ""
echo "[5] Verifying..."
ssh -T git@github.com 2>&1 | grep -q "successfully" && echo "  GitHub SSH: OK" || echo "  GitHub SSH: FAIL"

diff <(cat ~/.ssh/id_ed25519) <(bw get notes ssh-keys | awk '/BEGIN OPENSSH/{c++} c==1{print; if(/END OPENSSH PRIVATE KEY/)exit}') > /dev/null 2>&1 && echo "  BW id_ed25519: OK" || echo "  BW id_ed25519: MISMATCH"

diff <(cat ~/.ssh/homelab) <(bw get notes ssh-keys | awk '/BEGIN OPENSSH/{c++} c==2{print; if(/END OPENSSH PRIVATE KEY/)exit}') > /dev/null 2>&1 && echo "  BW homelab: OK" || echo "  BW homelab: MISMATCH"

echo ""
echo "Done. Remember to deploy homelab key to servers:"
echo "  ssh-copy-id -i ~/.ssh/homelab.pub root@<server-ip>"
