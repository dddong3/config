#!/bin/bash
set -eo pipefail

# Stage 2: Restore secrets and SSH keys from Bitwarden
# Run once after setup.sh on a new machine

echo "=== Bitwarden Setup ==="
echo ""

# ── Login ──
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/bw-auth.sh"
bw sync

# ── 1. Secrets ──
echo ""
echo "[1] Pulling secrets from Bitwarden..."
tmp=$(mktemp)
trap 'rm -f "$tmp" "$tmp_key" "$tmp_json"' EXIT

bw get notes dotfiles-secrets > "$tmp"
if [ -s "$tmp" ]; then
  mv "$tmp" ~/.secrets
  chmod 600 ~/.secrets
  echo "  Secrets saved to ~/.secrets"
else
  rm -f "$tmp"
  echo "  Error: dotfiles-secrets note is empty or not found."
  exit 1
fi

# ── 2. SSH keys ──
echo "[2] Restoring SSH keys from Bitwarden..."
notes=$(bw get notes ssh-keys 2>/dev/null)
if [ -z "$notes" ]; then
  echo "  Error: ssh-keys note not found."
  exit 1
fi

mkdir -p ~/.ssh

# Write keys atomically (mktemp with pre-set permissions to avoid exposure window)
tmp_key=$(mktemp ~/.ssh/.tmp.XXXXXX)
chmod 600 "$tmp_key"
echo "$notes" | awk '/BEGIN OPENSSH/{c++} c==1{print; if(/END OPENSSH PRIVATE KEY/)exit}' > "$tmp_key"
mv "$tmp_key" ~/.ssh/id_ed25519
echo "$notes" | awk '/ssh-ed25519.*dong3-code/{print}' > ~/.ssh/id_ed25519.pub

tmp_key=$(mktemp ~/.ssh/.tmp.XXXXXX)
chmod 600 "$tmp_key"
echo "$notes" | awk '/BEGIN OPENSSH/{c++} c==2{print; if(/END OPENSSH PRIVATE KEY/)exit}' > "$tmp_key"
mv "$tmp_key" ~/.ssh/homelab
echo "$notes" | awk '/ssh-ed25519.*dong3-homelab/{print}' > ~/.ssh/homelab.pub

# Validate keys are not empty
for key in ~/.ssh/id_ed25519 ~/.ssh/homelab; do
  if ! grep -q 'BEGIN OPENSSH' "$key" 2>/dev/null; then
    echo "  Error: $key is empty or malformed. Check Bitwarden note format."
    exit 1
  fi
done
for pub in ~/.ssh/id_ed25519.pub ~/.ssh/homelab.pub; do
  if ! grep -q 'ssh-ed25519' "$pub" 2>/dev/null; then
    echo "  Error: $pub is empty or malformed. Check Bitwarden note format."
    exit 1
  fi
done

echo "  SSH keys restored."

# ── 3. Add to Keychain ──
echo "[3] Adding SSH keys to Keychain..."
echo "  Enter the SSH key passphrase you set when generating the key."
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
ssh-add --apple-use-keychain ~/.ssh/homelab

# ── 4. Update Claude Code settings ──
echo "[4] Updating Claude Code settings..."
source ~/.secrets
if [ -f ~/.claude/settings.json ] && [ -n "$ANTHROPIC_BASE_URL" ] && [ -n "$ANTHROPIC_AUTH_TOKEN" ]; then
  tmp_json=$(mktemp)
  jq --arg url "$ANTHROPIC_BASE_URL" --arg tok "$ANTHROPIC_AUTH_TOKEN" \
     '.env.ANTHROPIC_BASE_URL = $url | .env.ANTHROPIC_AUTH_TOKEN = $tok' \
     ~/.claude/settings.json > "$tmp_json"
  mv "$tmp_json" ~/.claude/settings.json
  chmod 600 ~/.claude/settings.json
  echo "  Claude Code settings updated."
else
  echo "  Skipped (settings.json or tokens not found)."
fi

# ── Done ──
unset BW_SESSION
echo ""
echo "=== Bitwarden setup complete ==="
echo ""
echo "Next: Run Stage 3 steps (atuin login, gh auth login, etc.)"
