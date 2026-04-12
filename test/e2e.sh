#!/bin/bash
set -eo pipefail

# ── Config ──
VM_NAME="dotfiles-test"
VM_USER="admin"
VM_PASS="admin"
VM_IMAGE="ghcr.io/cirruslabs/macos-sequoia-vanilla:latest"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG="/tmp/dotfiles-e2e.log"
E2E_KEY="/tmp/dotfiles-e2e-key"
E2E_KEY_TITLE="dotfiles-e2e-$(date +%s)"

echo "=== Dotfiles E2E Test ==="
echo "Repo: $REPO_DIR"
echo "VM:   $VM_NAME ($VM_IMAGE)"
echo ""

# ── Prerequisites ──
for cmd in tart sshpass gh; do
  command -v "$cmd" &>/dev/null || { echo "Error: $cmd not found."; exit 1; }
done
gh auth status &>/dev/null || { echo "Error: gh not authenticated. Run: gh auth login"; exit 1; }

# ── 0. Generate temp SSH key and add to GitHub ──
echo "[0] Creating temporary SSH key for GitHub access..."
rm -f "$E2E_KEY" "$E2E_KEY.pub"
ssh-keygen -t ed25519 -C "$E2E_KEY_TITLE" -f "$E2E_KEY" -N "" -q
gh ssh-key add "$E2E_KEY.pub" --title "$E2E_KEY_TITLE"
echo "  Temp key added to GitHub as '$E2E_KEY_TITLE'"

cleanup() {
  echo "Cleaning up..."
  # Remove temp key from GitHub
  KEY_ID=$(gh ssh-key list --json id,title --jq ".[] | select(.title==\"$E2E_KEY_TITLE\") | .id" 2>/dev/null || true)
  if [ -n "$KEY_ID" ]; then
    gh ssh-key delete "$KEY_ID" --yes 2>/dev/null || true
    echo "  Removed temp SSH key from GitHub"
  fi
  rm -f "$E2E_KEY" "$E2E_KEY.pub"
  # Stop and delete VM
  kill $VM_PID 2>/dev/null || true
  tart stop "$VM_NAME" 2>/dev/null || true
  tart delete "$VM_NAME" 2>/dev/null || true
}
trap cleanup EXIT

# ── 1. Restore VM to clean state ──
echo "[1] Restoring VM to clean state..."
tart stop "$VM_NAME" 2>/dev/null || true
tart delete "$VM_NAME" 2>/dev/null || true
tart clone "$VM_IMAGE" "$VM_NAME"

# ── 2. Start VM (headless) ──
echo "[2] Starting VM..."
tart run "$VM_NAME" --no-graphics &
VM_PID=$!

# ── 3. Wait for SSH ──
echo "[3] Waiting for SSH (up to 5 min)..."
VM_IP=""
for i in $(seq 1 60); do
  VM_IP=$(tart ip "$VM_NAME" 2>/dev/null || true)
  if [ -n "$VM_IP" ]; then
    if SSHPASS="$VM_PASS" sshpass -e ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no \
       -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no \
       "$VM_USER@$VM_IP" true 2>/dev/null; then
      echo "  SSH ready at $VM_IP"
      break
    fi
  fi
  sleep 5
done
[ -z "$VM_IP" ] && { echo "Error: VM did not become reachable via SSH"; exit 1; }

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no"
export SSHPASS="$VM_PASS"
SSH="sshpass -e ssh $SSH_OPTS $VM_USER@$VM_IP"
SCP="sshpass -e scp $SSH_OPTS"

# ── 4. Configure NOPASSWD sudo ──
echo "[4] Configuring passwordless sudo..."
$SSH "echo '$VM_PASS' | sudo -S bash -c 'echo \"$VM_USER ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/$VM_USER'"

# ── 5. Enable Remote Login (SSH) if needed ──
$SSH "sudo systemsetup -setremotelogin on 2>/dev/null || true"

# ── 6. Inject temp SSH key into VM ──
echo "[5] Injecting temp SSH key into VM..."
$SSH "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
cat "$E2E_KEY" | $SSH "cat > ~/.ssh/id_ed25519 && chmod 600 ~/.ssh/id_ed25519"
cat "$E2E_KEY.pub" | $SSH "cat > ~/.ssh/id_ed25519.pub"
cat "$E2E_KEY" | $SSH "cat > ~/.ssh/homelab && chmod 600 ~/.ssh/homelab"
cat "$E2E_KEY.pub" | $SSH "cat > ~/.ssh/homelab.pub"
echo "  SSH keys injected (setup.sh will skip key generation)"

# ── 7. Copy repo into VM ──
echo "[6] Copying repo into VM..."
# Use tar+ssh instead of scp to avoid auth issues
tar -C "$(dirname "$REPO_DIR")" -cf - "$(basename "$REPO_DIR")" | $SSH "tar -C ~ -xf -"

# ── 8. Run setup.sh ──
echo "[7] Running setup.sh inside VM..."
echo "    (this may take 10-15 minutes for brew installs)"
echo ""
$SSH "cd ~/config && ./setup.sh" 2>&1 | tee "$LOG"

# ── 9. Results ──
echo ""
echo "==============================="
echo "=== E2E Test Results ==="
echo "==============================="
echo ""
grep -E '(✓|✗|Result:)' "$LOG" || true

echo ""
if grep -q '0 failed' "$LOG"; then
  echo "E2E TEST PASSED"
  exit 0
else
  FAILURES=$(grep -c '✗' "$LOG" || true)
  echo "E2E TEST FAILED ($FAILURES items failed)"
  echo "Full log: $LOG"
  exit 1
fi
