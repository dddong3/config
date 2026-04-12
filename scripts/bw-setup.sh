#!/bin/bash
set -eo pipefail

# Stage 2: Restore secrets and SSH keys from Bitwarden
# Run once after setup.sh on a new machine

command -v bw &>/dev/null || { echo "Error: bw not found. Run setup.sh first."; exit 1; }

echo "=== Bitwarden Setup ==="
echo ""

# ── Login ──
read -rp "Vaultwarden URL: " BW_SERVER_URL
bw config server "$BW_SERVER_URL"
bw login --check &>/dev/null || bw login || { echo "Error: bw login failed."; exit 1; }
BW_SESSION=$(bw unlock --raw)
export BW_SESSION

# ── 1. Secrets ──
echo ""
echo "[1] Pulling secrets from Bitwarden..."
tmp=$(mktemp)
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
echo "$notes" | awk '/BEGIN OPENSSH/{c++} c==1{print; if(/END OPENSSH PRIVATE KEY/)exit}' > ~/.ssh/id_ed25519
echo "$notes" | awk '/ssh-ed25519.*dong3-code/{print}' > ~/.ssh/id_ed25519.pub
chmod 600 ~/.ssh/id_ed25519

echo "$notes" | awk '/BEGIN OPENSSH/{c++} c==2{print; if(/END OPENSSH PRIVATE KEY/)exit}' > ~/.ssh/homelab
echo "$notes" | awk '/ssh-ed25519.*dong3-homelab/{print}' > ~/.ssh/homelab.pub
chmod 600 ~/.ssh/homelab

# Validate keys are not empty
for key in ~/.ssh/id_ed25519 ~/.ssh/homelab; do
  if ! grep -q 'BEGIN OPENSSH' "$key" 2>/dev/null; then
    echo "  Error: $key is empty or malformed. Check Bitwarden note format."
    exit 1
  fi
done

echo "  SSH keys restored."

# ── 3. Add to Keychain ──
echo "[3] Adding SSH keys to Keychain (enter passphrase when prompted)..."
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
ssh-add --apple-use-keychain ~/.ssh/homelab

# ── 4. Update Claude Code settings ──
echo "[4] Updating Claude Code settings..."
source ~/.secrets
if [ -f ~/.claude/settings.json ] && [ -n "$ANTHROPIC_BASE_URL" ] && [ -n "$ANTHROPIC_AUTH_TOKEN" ]; then
  sed -i '' "s|<your-api-base-url>|$ANTHROPIC_BASE_URL|" ~/.claude/settings.json
  sed -i '' "s|<your-auth-token>|$ANTHROPIC_AUTH_TOKEN|" ~/.claude/settings.json
  echo "  Claude Code settings updated."
else
  echo "  Skipped (settings.json not found or tokens missing from secrets)."
fi

# ── Done ──
unset BW_SESSION
echo ""
echo "=== Bitwarden setup complete ==="
echo ""
echo "Next: Run Stage 3 steps (atuin login, gh auth login, etc.)"
