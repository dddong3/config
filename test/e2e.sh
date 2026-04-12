#!/bin/bash
set -eo pipefail

# ── Config ──
VM_NAME="dotfiles-test"
VM_USER="admin"
VM_PASS="admin"
VM_IMAGE="ghcr.io/cirruslabs/macos-sequoia-vanilla:latest"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG="/tmp/dotfiles-e2e.log"

echo "=== Dotfiles E2E Test ==="
echo "Repo: $REPO_DIR"
echo "VM:   $VM_NAME ($VM_IMAGE)"
echo ""

# ── Prerequisites ──
for cmd in tart sshpass; do
  command -v "$cmd" &>/dev/null || { echo "Error: $cmd not found. Run: brew install cirruslabs/cli/tart cirruslabs/cli/sshpass"; exit 1; }
done

# ── 1. Restore VM to clean state ──
echo "[1] Restoring VM to clean state..."
tart stop "$VM_NAME" 2>/dev/null || true
tart delete "$VM_NAME" 2>/dev/null || true
tart clone "$VM_IMAGE" "$VM_NAME"

# ── 2. Start VM (headless) ──
echo "[2] Starting VM..."
tart run "$VM_NAME" --no-graphics &
VM_PID=$!
trap 'echo "Cleaning up..."; kill $VM_PID 2>/dev/null; tart stop "$VM_NAME" 2>/dev/null; tart delete "$VM_NAME" 2>/dev/null' EXIT

# ── 3. Wait for SSH ──
echo "[3] Waiting for SSH (up to 5 min)..."
VM_IP=""
for i in $(seq 1 60); do
  VM_IP=$(tart ip "$VM_NAME" 2>/dev/null || true)
  if [ -n "$VM_IP" ]; then
    if sshpass -p "$VM_PASS" ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no \
       -o UserKnownHostsFile=/dev/null "$VM_USER@$VM_IP" true 2>/dev/null; then
      echo "  SSH ready at $VM_IP"
      break
    fi
  fi
  sleep 5
done
[ -z "$VM_IP" ] && { echo "Error: VM did not become reachable via SSH"; exit 1; }

SSH="sshpass -p $VM_PASS ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $VM_USER@$VM_IP"
SCP="sshpass -p $VM_PASS scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# ── 4. Configure NOPASSWD sudo ──
echo "[4] Configuring passwordless sudo..."
$SSH "echo '$VM_PASS' | sudo -S bash -c 'echo \"$VM_USER ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/$VM_USER'"

# ── 5. Enable Remote Login (SSH) if needed ──
$SSH "sudo systemsetup -setremotelogin on 2>/dev/null || true"

# ── 6. Copy repo into VM ──
echo "[5] Copying repo into VM..."
$SCP -r "$REPO_DIR" "$VM_USER@$VM_IP:~/config"

# ── 7. Run setup.sh ──
echo "[6] Running setup.sh inside VM..."
echo "    (this may take 10-15 minutes for brew installs)"
echo ""
$SSH "cd ~/config && ./setup.sh" 2>&1 | tee "$LOG"

# ── 8. Results ──
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
